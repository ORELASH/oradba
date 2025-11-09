// Requires: .NET Framework 4.0
using System;
using System.Collections.Generic;
using System.Data.Odbc;
using System.Threading;

namespace OracleOdbcConnectionManager
{
    // עטיפה של חיבור + מזהה
    public class ManagedConnection : IDisposable
    {
        public string ConnectionId { get; private set; }
        public OdbcConnection Connection { get; private set; }
        bool _disposed = false;

        internal ManagedConnection(string connectionId, OdbcConnection connection)
        {
            ConnectionId = connectionId;
            Connection = connection;
        }

        public void Dispose()
        {
            if (_disposed) return;
            try
            {
                if (Connection != null)
                {
                    if (Connection.State != System.Data.ConnectionState.Closed)
                        Connection.Close();
                    Connection.Dispose();
                }
            }
            finally
            {
                _disposed = true;
            }
        }
    }

    // מנהל חיבורים שיוצר ManagedConnection עם PREFIX + counter
    public class ConnectionManager
    {
        private readonly string _odbcConnectionString;
        private readonly object _counterLock = new object();
        private long _counter = 0;

        public ConnectionManager(string odbcConnectionString)
        {
            if (string.IsNullOrEmpty(odbcConnectionString))
                throw new ArgumentNullException("odbcConnectionString");
            _odbcConnectionString = odbcConnectionString;
        }

        // יוצר ומחזיר חיבור פתוח עם ConnectionId מבוסס prefix
        public ManagedConnection CreateOpenConnection(string prefix = "CONN")
        {
            if (prefix == null) prefix = "CONN";

            long idNum = Interlocked.Increment(ref _counter); // בטוח לת'רדס
            string connectionId = string.Format("{0}-{1:D6}", prefix, idNum);

            var conn = new OdbcConnection(_odbcConnectionString);
            try
            {
                conn.Open();
                // פה אפשר לרשום ל־log: connection opened עם id
                Console.WriteLine("[{0}] Opened ODBC connection (State={1})", connectionId, conn.State);
                return new ManagedConnection(connectionId, conn);
            }
            catch
            {
                // על כשל — ניקוי
                conn.Dispose();
                throw;
            }
        }

        // עוזר להריץ שאילתה שמחזירה scalar (לדוגמה)
        public object ExecuteScalar(ManagedConnection mconn, string sql, params OdbcParameter[] parameters)
        {
            if (mconn == null) throw new ArgumentNullException("mconn");
            if (mconn.Connection.State != System.Data.ConnectionState.Open)
                throw new InvalidOperationException("Connection is not open.");

            using (var cmd = mconn.Connection.CreateCommand())
            {
                cmd.CommandText = sql;
                if (parameters != null && parameters.Length > 0)
                {
                    cmd.Parameters.AddRange(parameters);
                }
                Console.WriteLine("[{0}] Executing SQL: {1}", mconn.ConnectionId, sql);
                return cmd.ExecuteScalar();
            }
        }

        // עוזר להריץ שאילתת non-query
        public int ExecuteNonQuery(ManagedConnection mconn, string sql, params OdbcParameter[] parameters)
        {
            if (mconn == null) throw new ArgumentNullException("mconn");
            if (mconn.Connection.State != System.Data.ConnectionState.Open)
                throw new InvalidOperationException("Connection is not open.");

            using (var cmd = mconn.Connection.CreateCommand())
            {
                cmd.CommandText = sql;
                if (parameters != null && parameters.Length > 0)
                    cmd.Parameters.AddRange(parameters);
                Console.WriteLine("[{0}] Executing NonQuery: {1}", mconn.ConnectionId, sql);
                return cmd.ExecuteNonQuery();
            }
        }
    }

    class Program
    {
        static void Main(string[] args)
        {
            // החלף ב־ODBC connection string שלך (DSN=...,Uid=...,Pwd=... או Driver=...;...)
            string odbcConnectionString = "DSN=YourOracleDSN;Uid=your_user;Pwd=your_password;";
            var mgr = new ConnectionManager(odbcConnectionString);

            // דוגמה ליצירת שני חיבורים עם פריפקסים שונים
            ManagedConnection conn1 = null;
            ManagedConnection conn2 = null;
            try
            {
                conn1 = mgr.CreateOpenConnection("APP1");
                conn2 = mgr.CreateOpenConnection("BATCH");

                // דוגמה: שאילתה פשוטה (התאם לטבלה/שאילתא באורקל שלך)
                string sql = "SELECT COUNT(*) FROM DUAL"; // DUAL לדוגמה ב־Oracle
                object result1 = mgr.ExecuteScalar(conn1, sql);
                Console.WriteLine("[{0}] Result: {1}", conn1.ConnectionId, result1);

                // דוגמה להרצת NonQuery (אין כאן שינוי אמיתי ב־DUAL — רק דוגמה)
                // string insertSql = "INSERT INTO MY_TABLE (COL1) VALUES (?)";
                // var param = new OdbcParameter("p1", "value1");
                // int affected = mgr.ExecuteNonQuery(conn2, insertSql, param);
                // Console.WriteLine("[{0}] Rows affected: {1}", conn2.ConnectionId, affected);
            }
            catch (OdbcException oex)
            {
                Console.WriteLine("ODBC error: " + oex.Message);
            }
            catch (Exception ex)
            {
                Console.WriteLine("General error: " + ex.Message);
            }
            finally
            {
                if (conn1 != null) conn1.Dispose();
                if (conn2 != null) conn2.Dispose();
            }
        }
    }
}
