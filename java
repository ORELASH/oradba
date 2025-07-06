# MSSQL Kerberos Connection Test - Minimal Version

Quick and simple utility to test MSSQL connection with Kerberos authentication.

## Prerequisites

- Java 8+ installed
- Machine joined to domain
- User logged into domain account

## Quick Setup

### 1. Download JDBC Driver
```bash
# Download Microsoft JDBC Driver for SQL Server
# https://docs.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server
```

### 2. Update Configuration
Edit `MinimalMSSQLKerberosTest.java`:
```java
private static final String SERVER = "your-sql-server.domain.com";
private static final String DATABASE = "your_database";
private static final String DOMAIN = "YOUR_DOMAIN.COM";
private static final String KDC = "your-domain-controller.com";
```

### 3. Run

**Linux/Mac:**
```bash
# Compile and run
javac -cp "mssql-jdbc-12.4.2.jre11.jar" MinimalMSSQLKerberosTest.java

java -Djava.security.krb5.realm=YOUR_DOMAIN.COM \
     -Djava.security.krb5.kdc=your-domain-controller.com \
     -cp ".:mssql-jdbc-12.4.2.jre11.jar" \
     MinimalMSSQLKerberosTest
```

**Windows:**
```cmd
# Compile and run
javac -cp "mssql-jdbc-12.4.2.jre11.jar" MinimalMSSQLKerberosTest.java

java -Djava.security.krb5.realm=YOUR_DOMAIN.COM ^
     -Djava.security.krb5.kdc=your-domain-controller.com ^
     -cp ".;mssql-jdbc-12.4.2.jre11.jar" ^
     MinimalMSSQLKerberosTest
```

## Expected Output

```
Kerberos properties configured
Testing connection to: your-sql-server.domain.com
Database: your_database
✅ Connection successful!
Connected as: DOMAIN\username
Server version: Microsoft SQL Server 2019 (RTM) - 15.0.2000.5...
System user: DOMAIN\username
Server time: 2025-07-06 14:30:15.123
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| Authentication failed | Check domain membership and time sync |
| Network error | Check firewall and connectivity |
| Class not found | Verify JDBC driver path |
| Encryption not supported | Update Java version |

## Debug Mode

Add this parameter for detailed logging:
```bash
-Dsun.security.krb5.debug=true
```

## Files Structure

```
project/
├── MinimalMSSQLKerberosTest.java
├── mssql-jdbc-12.4.2.jre11.jar
└── run-test.sh (or run-test.bat)
```

---

**Note:** This is a minimal version. For comprehensive diagnostics, use the full version with `KerberosDiagnostics`.
