import psycopg2
from psycopg2 import sql
from config import REDSHIFT_CONFIG, DATASHARE_NAME, DRY_RUN

def update_datashare():
    conn = psycopg2.connect(**REDSHIFT_CONFIG)
    conn.autocommit = True
    cur = conn.cursor()

    try:
        # --- שלב 1: שליפת סכמות ---
        cur.execute("""
            SELECT schema_name
            FROM information_schema.schemata
            WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_internal')
        """)
        schemas = [row[0] for row in cur.fetchall()]

        for schema in schemas:
            print(f"\n📂 Schema: {schema}")

            # פקודות על הסכמה
            add_schema = sql.SQL("ALTER DATASHARE {} ADD SCHEMA {}").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema)
            )
            include_new = sql.SQL("ALTER DATASHARE {} ADD SCHEMA {} INCLUDE NEW").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema)
            )

            _execute_or_print(cur, add_schema, f"Add schema {schema}")
            _execute_or_print(cur, include_new, f"Add schema {schema} with INCLUDE NEW")

            # --- שלב 2: טבלאות ---
            cur.execute(sql.SQL("""
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = %s
            """), [schema])

            tables = [row[0] for row in cur.fetchall()]
            for table in tables:
                add_table = sql.SQL("ALTER DATASHARE {} ADD TABLE {}.{}").format(
                    sql.Identifier(DATASHARE_NAME),
                    sql.Identifier(schema),
                    sql.Identifier(table)
                )
                _execute_or_print(cur, add_table, f"Add table {schema}.{table}")

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
            print(f"⚠️ Skipped {description}: {e}")

if __name__ == "__main__":
    update_datashare()
