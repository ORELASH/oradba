# --- שלב 4: הוספת סכמות חסרות ---
for schema in missing_schemas:
    # קודם מוסיפים את הסכמה
    add_schema = sql.SQL("ALTER DATASHARE {} ADD SCHEMA {}").format(
        sql.Identifier(DATASHARE_NAME),
        sql.Identifier(schema)
    )
    _execute_or_print(cur, add_schema, f"Add schema {schema}")

    # ואז מפעילים INCLUDE NEW
    include_new = sql.SQL("ALTER DATASHARE {} SET INCLUDE NEW = TRUE FOR SCHEMA {}").format(
        sql.Identifier(DATASHARE_NAME),
        sql.Identifier(schema)
    )
    _execute_or_print(cur, include_new, f"Enable INCLUDE NEW for schema {schema}")
