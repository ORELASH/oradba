import oracledb

class OracleConnection:
    """חיבור יחיד ל-Oracle עם Connection ID משלך."""

    def __init__(self, dsn, user, password, prefix="CONN"):
        self.dsn = dsn
        self.user = user
        self.password = password
        self.prefix = prefix
        self.connection_id = f"{prefix}-000001"
        self.connection = None

    def open(self):
        """פותח חיבור יחיד ל-Oracle ומגדיר Client Identifier."""
        try:
            self.connection = oracledb.connect(
                user=self.user,
                password=self.password,
                dsn=self.dsn
            )
            print(f"[{self.connection_id}] Connected to Oracle.")

            # הגדרת מזהה בחיבור (נראה בצד ה־DB)
            cur = self.connection.cursor()
            cur.execute("BEGIN DBMS_SESSION.SET_IDENTIFIER(:id); END;", {"id": self.connection_id})
            cur.close()

        except oracledb.Error as e:
            print(f"[{self.connection_id}] Failed to connect: {e}")
            raise

    def execute_scalar(self, sql, params=None):
        """מריץ שאילתה שמחזירה ערך יחיד (כמו SELECT COUNT(*))."""
        if not self.connection:
            raise RuntimeError("Connection is not open.")

        print(f"[{self.connection_id}] Executing SQL: {sql}")
        cur = self.connection.cursor()
        cur.execute(sql, params or {})
        row = cur.fetchone()
        cur.close()
        return row[0] if row else None

    def execute_nonquery(self, sql, params=None):
        """מריץ פקודה שלא מחזירה ערך (כמו INSERT / UPDATE / DELETE)."""
        if not self.connection:
            raise RuntimeError("Connection is not open.")

        print(f"[{self.connection_id}] Executing NonQuery: {sql}")
        cur = self.connection.cursor()
        cur.execute(sql, params or {})
        self.connection.commit()
        affected = cur.rowcount
        cur.close()
        return affected

    def close(self):
        """סוגר את החיבור."""
        if self.connection:
            try:
                self.connection.close()
                print(f"[{self.connection_id}] Connection closed.")
            except Exception as e:
                print(f"[{self.connection_id}] Error closing connection: {e}")
            self.connection = None


# ----------------------------
# דוגמת שימוש
# ----------------------------
if __name__ == "__main__":
    dsn = "myhost:1521/ORCLPDB1"   # לדוגמה: "10.0.0.5:1521/ORCL"
    user = "your_user"
    password = "your_password"

    db = OracleConnection(dsn, user, password, prefix="APP1")

    try:
        db.open()

        # שאילתה לדוגמה
        count = db.execute_scalar("SELECT COUNT(*) FROM DUAL")
        print(f"[{db.connection_id}] Result: {count}")

        # דוגמה לעדכון (אם תרצה)
        # rows = db.execute_nonquery("UPDATE MY_TABLE SET FLAG=1 WHERE ID=:id", {"id": 123})
        # print(f"[{db.connection_id}] Rows affected: {rows}")

    except oracledb.Error as e:
        print("Oracle error:", e)
    finally:
        db.close()
