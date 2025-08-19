import psycopg2
from psycopg2 import sql
from config import REDSHIFT_CONFIG, DATASHARE_NAME, DRY_RUN

def maintain_datashare():
    conn = psycopg2.connect(**REDSHIFT_CONFIG)
    conn.autocommit = True
    cur = conn.cursor()

    try:
        # --- שלב 1: מה יש כבר ב-datashare ---
        cur.execute("""
            SELECT object_type, object_name, schema_name
            FROM svv_datashare_objects
            WHERE share_name = %s
        """, (DATASHARE_NAME,))
        existing = cur.fetchall()

        existing_schemas = {row[1] for row in existing if row[0] == 'schema'}
        existing_tables  = {(row[2], row[1]) for row in existing if row[0] == 'table'}

        # --- שלב 2: מה יש בפועל ב-DB ---
        cur.execute("""
            SELECT schema_name
            FROM information_schema.schemata
            WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_internal')
        """)
        all_schemas = {row[0] for row in cur.fetchall()}

        cur.execute("""
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_internal')
        """)
        all_tables = {(row[0], row[1]) for row in cur.fetchall()}

        # --- שלב 3: חישוב דלתא ---
        missing_schemas = all_schemas - existing_schemas
        missing_tables  = all_tables - existing_tables

        obsolete_schemas = existing_schemas - all_schemas
        obsolete_tables  = existing_tables - all_tables

        print("\n📊 Delta summary:")
        print("Schemas to add:", missing_schemas or "None")
        print("Tables to add:", missing_tables or "None")
        print("Schemas to drop:", obsolete_schemas or "None")
        print("Tables to drop:", obsolete_tables or "None")

        # --- שלב 4: הוספת סכמות חסרות ---
        for schema in missing_schemas:
            add_schema = sql.SQL("ALTER DATASHARE {} ADD SCHEMA {}").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema)
            )
            _execute_or_print(cur, add_schema, f"Add schema {schema}")

            include_new = sql.SQL("ALTER DATASHARE {} SET INCLUDE NEW = TRUE FOR SCHEMA {}").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema)
            )
            _execute_or_print(cur, include_new, f"Enable INCLUDE NEW for schema {schema}")

        # --- שלב 5: הוספת טבלאות חסרות ---
        for schema, table in missing_tables:
            query = sql.SQL("ALTER DATASHARE {} ADD TABLE {}.{}").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema),
                sql.Identifier(table)
            )
            _execute_or_print(cur, query, f"Add table {schema}.{table}")

        # --- שלב 6: הורדת סכמות מיותרות ---
        for schema in obsolete_schemas:
            query = sql.SQL("ALTER DATASHARE {} DROP SCHEMA {}").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema)
            )
            _execute_or_print(cur, query, f"Drop schema {schema}")

        # --- שלב 7: הורדת טבלאות מיותרות ---
        for schema, table in obsolete_tables:
            query = sql.SQL("ALTER DATASHARE {} DROP TABLE {}.{}").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema),
                sql.Identifier(table)
            )
            _execute_or_print(cur, query, f"Drop table {schema}.{table}")

    finally:
        cur.close()
        conn.close()


def _execute_or_print(cur, query, description):
    """מריץ או מדפיס בהתאם ל-DRY_RUN"""
    if DRY_RUN:
        print("   ➡️", query.as_string(cur))
    else:
        try:
            cur.execute(query)
            print(f"✅ {description}")
        except Exception as e:
            print(f"⚠️ Failed {description}: {e}")


if __name__ == "__main__":
    maintain_datashare()
