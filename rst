using System;
using System.Data.Odbc;

namespace RedshiftConnectivityTest
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== Redshift ODBC Connectivity Test ===");
            Console.WriteLine();

            // Connection details - update these with your actual information
            string server = "your-redshift-cluster.redshift.amazonaws.com";
            string database = "your-database-name";
            string username = "your-username";
            string password = "your-password";
            string port = "5439"; // Default Redshift port

            // Build connection string
            string connectionString = string.Format(
                "Driver={{Amazon Redshift (x64)}};" +
                "Server={0};" +
                "Database={1};" +
                "UID={2};" +
                "PWD={3};" +
                "Port={4};" +
                "SSL=true;" +
                "SSLMode=require",
                server, database, username, password, port
            );

            Console.WriteLine("Attempting to connect to Redshift...");
            Console.WriteLine("Server: " + server);
            Console.WriteLine("Database: " + database);
            Console.WriteLine("Username: " + username);
            Console.WriteLine();

            TestConnection(connectionString);

            Console.WriteLine();
            Console.WriteLine("Press Enter to exit...");
            Console.ReadLine();
        }

        static void TestConnection(string connectionString)
        {
            OdbcConnection connection = null;
            
            try
            {
                Console.WriteLine("Opening connection...");
                connection = new OdbcConnection(connectionString);
                
                // Open the connection
                connection.Open();
                
                Console.WriteLine("✓ Connection established successfully!");
                
                // Check Redshift version
                string versionQuery = "SELECT version()";
                using (OdbcCommand command = new OdbcCommand(versionQuery, connection))
                {
                    string version = command.ExecuteScalar() != null ? command.ExecuteScalar().ToString() : "";
                    if (!string.IsNullOrEmpty(version))
                    {
                        Console.WriteLine("Redshift Version: " + version.Substring(0, Math.Min(version.Length, 100)) + "...");
                    }
                }
                
                // Check server time
                string timeQuery = "SELECT CURRENT_TIMESTAMP";
                using (OdbcCommand command = new OdbcCommand(timeQuery, connection))
                {
                    var serverTime = command.ExecuteScalar();
                    Console.WriteLine("Server Time: " + serverTime.ToString());
                }
                
                Console.WriteLine("✓ All tests passed successfully!");
            }
            catch (OdbcException odbcEx)
            {
                Console.WriteLine("✗ ODBC Error:");
                Console.WriteLine("Error Code: " + odbcEx.ErrorCode.ToString());
                Console.WriteLine("Message: " + odbcEx.Message);
                
                // Additional error details
                foreach (OdbcError error in odbcEx.Errors)
                {
                    Console.WriteLine("  - Source: " + error.Source);
                    Console.WriteLine("  - SQLState: " + error.SQLState);
                    Console.WriteLine("  - NativeError: " + error.NativeError.ToString());
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("✗ General Error:");
                Console.WriteLine("Error Type: " + ex.GetType().Name);
                Console.WriteLine("Message: " + ex.Message);
            }
            finally
            {
                // Close connection
                if (connection != null && connection.State == System.Data.ConnectionState.Open)
                {
                    connection.Close();
                    Console.WriteLine("Connection closed.");
                }
            }
        }
    }
}

// Important Notes:
// 1. Install Amazon Redshift ODBC Driver before running
// 2. Update connection details at the beginning of the program
// 3. Ensure port 5439 is open in your Security Group
// 4. Verify user has proper access permissions
