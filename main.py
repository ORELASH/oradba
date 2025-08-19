import psycopg2
from psycopg2 import sql
from config import REDSHIFT_CONFIG, DATASHARE_NAME

def dry_run_update_datashare():
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

            add_schema = sql.SQL("ALTER DATASHARE {} ADD SCHEMA {}").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema)
            ).as_string(cur)

            include_new = sql.SQL("ALTER DATASHARE {} ADD SCHEMA {} INCLUDE NEW").format(
                sql.Identifier(DATASHARE_NAME),
                sql.Identifier(schema)
            ).as_string(cur)

            print("   ➡️", add_schema)
            print("   ➡️", include_new)

            # --- שלב 2: שליפת טבלאות ---
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
                ).as_string(cur)
                print("   ➡️", add_table)

    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    dry_run_update_datashare()
