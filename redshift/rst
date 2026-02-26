using System;
using System.Data.Odbc;
using Microsoft.Win32;

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

            // Try different driver names - uncomment the one that works
            // Option 1: 64-bit driver
            string driverName = "Amazon Redshift (x64)";
            
            // Option 2: 32-bit driver (uncomment if using 32-bit)
            //string driverName = "Amazon Redshift (x86)";
            
            // Option 3: Alternative driver name
            //string driverName = "Amazon Redshift ODBC Driver (x64)";
            
            // Option 4: PostgreSQL driver (alternative)
            //string driverName = "PostgreSQL ANSI";

            // Build connection string
            string connectionString = string.Format(
                "Driver={{{0}}};" +
                "Server={1};" +
                "Database={2};" +
                "UID={3};" +
                "PWD={4};" +
                "Port={5};" +
                "SSL=true;" +
                "SSLMode=require",
                driverName, server, database, username, password, port
            );

            Console.WriteLine("Testing Redshift ODBC Connection...");
            Console.WriteLine("Driver: " + driverName);
            Console.WriteLine("Server: " + server);
            Console.WriteLine("Database: " + database);
            Console.WriteLine("Username: " + username);
            Console.WriteLine();

            // First, check available ODBC drivers
            ListAvailableDrivers();

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

        static void ListAvailableDrivers()
        {
            Console.WriteLine("=== Available ODBC Drivers ===");
            
            try
            {
                RegistryKey driversKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers");
                if (driversKey != null)
                {
                    string[] driverNames = driversKey.GetValueNames();
                    
                    if (driverNames.Length == 0)
                    {
                        Console.WriteLine("No ODBC drivers found!");
                    }
                    else
                    {
                        Console.WriteLine("Found " + driverNames.Length + " ODBC drivers:");
                        foreach (string driverName in driverNames)
                        {
                            Console.WriteLine("  - " + driverName);
                        }
                    }
                    driversKey.Close();
                }
                else
                {
                    Console.WriteLine("Unable to access ODBC drivers registry");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error reading ODBC drivers: " + ex.Message);
            }
            
            Console.WriteLine();
        }
    }
}

// Important Notes:
// 1. Install Amazon Redshift ODBC Driver before running
// 2. Update connection details at the beginning of the program
// 3. Ensure port 5439 is open in your Security Group
// 4. Verify user has proper access permissions

// Troubleshooting IM002 Error:
// 1. Download and install Amazon Redshift ODBC Driver from:
//    https://docs.aws.amazon.com/redshift/latest/mgmt/configure-odbc-connection.html
// 2. Check if you need 32-bit or 64-bit version (match your application)
// 3. Try different driver names in the code above
// 4. Verify driver installation in Windows ODBC Data Source Administrator
// 5. Alternative: Use PostgreSQL driver as Redshift is PostgreSQL-compatible
