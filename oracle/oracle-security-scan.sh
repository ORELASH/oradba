#!/bin/bash
# Oracle Database Security Scan Script
# ======================================
# This script automatically detects all Oracle instances and performs a comprehensive 
# security scan on each instance, generating a detailed report of potential security issues.

# Set default values
BASE_OUTPUT_DIR="./oracle_security_scan_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$BASE_OUTPUT_DIR/scan.log"
ORACLE_USER="SYS"
ORACLE_PASSWORD=""
INSTANCES_FILE="$BASE_OUTPUT_DIR/instances.txt"
COMBINED_REPORT="$BASE_OUTPUT_DIR/combined_report.html"
HTML_HEADER="security_header.html"
HTML_FOOTER="security_footer.html"
AUTO_DETECT=true
PARALLEL_MAX=5  # Maximum number of parallel scans

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage information
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -u, --user USERNAME       Oracle username (default: SYS)"
    echo "  -p, --password PASSWORD   Oracle password (will prompt if not provided)"
    echo "  -l, --list-instances      Only list Oracle instances without scanning"
    echo "  -i, --instance INSTANCE   Scan specific instance(s) (comma-separated, overrides auto-detection)"
    echo "  -m, --max-parallel NUM    Maximum number of parallel scans (default: 5)"
    echo "  -o, --output-dir DIR      Base output directory (default: ./oracle_security_scan_TIMESTAMP)"
    echo "  -h, --help                Show this help"
    echo ""
    echo "Example:"
    echo "  $0                        # Auto-detect and scan all instances"
    echo "  $0 -u SYSTEM -i ORCL      # Scan only ORCL instance as SYSTEM user"
    echo "  $0 -l                     # Only list instances without scanning"
}

# Function to log messages
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to detect Oracle instances
detect_oracle_instances() {
    log "Detecting Oracle instances..."
    mkdir -p "$BASE_OUTPUT_DIR"
    
    # Try multiple detection methods and combine results
    
    # Method 1: Search for Oracle processes
    log "Searching for Oracle processes..."
    ps -ef | grep pmon | grep -v grep | awk '{print $NF}' | sed 's/.*_pmon_//' > "$INSTANCES_FILE.tmp1"
    
    # Method 2: Check Oracle inventory
    log "Checking Oracle inventory..."
    if [ -f /etc/oratab ]; then
        grep -v "^#" /etc/oratab | grep -v "^$" | cut -d: -f1 > "$INSTANCES_FILE.tmp2"
    else
        touch "$INSTANCES_FILE.tmp2"  # Create empty file if oratab doesn't exist
    fi
    
    # Method 3: Try tnsnames.ora
    log "Checking tnsnames.ora..."
    ORACLE_HOME=$(ps -ef | grep pmon | grep -v grep | head -1 | awk '{print $NF}' | sed 's/.*_pmon_//' | xargs dirname 2>/dev/null) || true
    if [ -n "$ORACLE_HOME" ] && [ -f "$ORACLE_HOME/network/admin/tnsnames.ora" ]; then
        grep -v "^#" "$ORACLE_HOME/network/admin/tnsnames.ora" | grep "=" | cut -d= -f1 | tr -d " " > "$INSTANCES_FILE.tmp3"
    else
        touch "$INSTANCES_FILE.tmp3"  # Create empty file if tnsnames.ora doesn't exist
    fi
    
    # Method 4: Try listener status
    log "Checking listener status..."
    lsnrctl status | grep "Instance " | awk '{print $NF}' | sort -u > "$INSTANCES_FILE.tmp4" 2>/dev/null || touch "$INSTANCES_FILE.tmp4"
    
    # Combine all methods and remove duplicates
    cat "$INSTANCES_FILE.tmp1" "$INSTANCES_FILE.tmp2" "$INSTANCES_FILE.tmp3" "$INSTANCES_FILE.tmp4" | sort -u > "$INSTANCES_FILE"
    
    # Remove temporary files
    rm -f "$INSTANCES_FILE.tmp1" "$INSTANCES_FILE.tmp2" "$INSTANCES_FILE.tmp3" "$INSTANCES_FILE.tmp4"
    
    # Check if any instances were found
    if [ ! -s "$INSTANCES_FILE" ]; then
        log "${YELLOW}No Oracle instances detected automatically.${NC}"
        log "Please specify an instance with the -i option or check Oracle installation."
        return 1
    else
        INSTANCE_COUNT=$(wc -l < "$INSTANCES_FILE")
        log "${GREEN}Detected $INSTANCE_COUNT Oracle instance(s):${NC}"
        cat "$INSTANCES_FILE" | while read INSTANCE; do
            log "  - $INSTANCE"
        done
        return 0
    fi
}

# Function to create HTML header for combined report
create_combined_html_header() {
    cat > "$COMBINED_REPORT" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oracle Database Security Scan - Combined Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #0055a4;
            border-bottom: 2px solid #0055a4;
            padding-bottom: 10px;
        }
        h2 {
            color: #0077cc;
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        .summary {
            margin: 20px 0;
            padding: 15px;
            background-color: #f8f8f8;
            border-left: 5px solid #0077cc;
        }
        .instance-summary {
            margin: 20px 0;
            padding: 15px;
            background-color: #f0f8ff;
            border-left: 5px solid #0077cc;
        }
        .critical {
            color: #d32f2f;
            font-weight: bold;
        }
        .warning {
            color: #ffa000;
            font-weight: bold;
        }
        .info {
            color: #388e3c;
            font-weight: bold;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th, td {
            text-align: left;
            padding: 12px;
            border: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .timestamp {
            color: #666;
            font-style: italic;
        }
        .nav {
            background-color: #f2f2f2;
            padding: 10px;
            margin-bottom: 20px;
        }
        .footer {
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }
    </style>
</head>
<body>
    <h1>Oracle Database Security Scan - Combined Report</h1>
    <div class="timestamp">Generated on: $(date '+%Y-%m-%d %H:%M:%S')</div>
    
    <div class="summary">
        <h2>Executive Summary</h2>
        <p>This report presents the findings of a comprehensive security scan performed across all detected Oracle database instances.</p>
        <p>Number of instances scanned: <span id="instance-count">0</span></p>
        <table>
            <tr>
                <th>Instance</th>
                <th>Critical Issues</th>
                <th>Warnings</th>
                <th>Information</th>
                <th>Report Link</th>
            </tr>
            <!-- Instance summaries will be added here -->
        </table>
    </div>
    
    <h2>Individual Instance Reports</h2>
    <p>Click on the instance name in the table above to view the detailed report for each database instance.</p>
    
    <div class="footer">
        <p>Oracle Database Security Scan completed. This report contains findings that should be reviewed by database administrators and security personnel.</p>
    </div>
</body>
</html>
EOF
}

# Function to update the combined report with instance information
update_combined_report() {
    local instance="$1"
    local critical_count="$2"
    local warning_count="$3"
    local info_count="$4"
    local report_path="$5"
    
    # Increment instance count
    local current_count=$(grep -o '<span id="instance-count">[0-9]*</span>' "$COMBINED_REPORT" | sed 's/<span id="instance-count">\([0-9]*\)<\/span>/\1/')
    local new_count=$((current_count + 1))
    sed -i "s/<span id=\"instance-count\">[0-9]*<\/span>/<span id=\"instance-count\">$new_count<\/span>/g" "$COMBINED_REPORT"
    
    # Add instance row to the summary table
    local instance_row="<tr><td>$instance</td><td class=\"critical\">$critical_count</td><td class=\"warning\">$warning_count</td><td class=\"info\">$info_count</td><td><a href=\"$report_path\" target=\"_blank\">View Report</a></td></tr>"
    sed -i "s|<!-- Instance summaries will be added here -->|$instance_row\n            <!-- Instance summaries will be added here -->|" "$COMBINED_REPORT"
}

# Function to create HTML header for individual instance report
create_html_header() {
    local output_dir="$1"
    local instance="$2"
    local report_file="$output_dir/security_report.html"
    local header_file="$output_dir/header.html"
    
    cat > "$header_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oracle Database Security Scan Report - $instance</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #0055a4;
            border-bottom: 2px solid #0055a4;
            padding-bottom: 10px;
        }
        h2 {
            color: #0077cc;
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        h3 {
            color: #333;
            margin-top: 20px;
        }
        .summary {
            margin: 20px 0;
            padding: 15px;
            background-color: #f8f8f8;
            border-left: 5px solid #0077cc;
        }
        .critical {
            background-color: #ffebee;
            border-left: 5px solid #d32f2f;
            padding: 10px;
            margin: 10px 0;
        }
        .warning {
            background-color: #fff8e1;
            border-left: 5px solid #ffa000;
            padding: 10px;
            margin: 10px 0;
        }
        .info {
            background-color: #e8f5e9;
            border-left: 5px solid #388e3c;
            padding: 10px;
            margin: 10px 0;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th, td {
            text-align: left;
            padding: 12px;
            border: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .issue-count {
            font-weight: bold;
        }
        .critical-count {
            color: #d32f2f;
        }
        .warning-count {
            color: #ffa000;
        }
        .info-count {
            color: #388e3c;
        }
        .timestamp {
            color: #666;
            font-style: italic;
        }
        .nav {
            background-color: #f2f2f2;
            padding: 10px;
            margin-bottom: 20px;
        }
        .nav a {
            margin-right: 15px;
            color: #0077cc;
            text-decoration: none;
        }
        .nav a:hover {
            text-decoration: underline;
        }
        .footer {
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }
    </style>
</head>
<body>
    <h1>Oracle Database Security Scan Report - $instance</h1>
    <div class="timestamp">Generated on: $(date '+%Y-%m-%d %H:%M:%S')</div>
    
    <div class="nav">
        <a href="#summary">Summary</a>
        <a href="#accounts">User Accounts</a>
        <a href="#privileges">Privileges</a>
        <a href="#passwords">Password Policies</a>
        <a href="#system">System Settings</a>
        <a href="#encryption">Encryption</a>
        <a href="#auditing">Auditing</a>
        <a href="#network">Network Access</a>
        <a href="#recommendations">Recommendations</a>
    </div>
    
    <div class="summary" id="summary">
        <h2>Executive Summary</h2>
        <p>This report presents the findings of a comprehensive security scan performed on the Oracle database instance: <strong>$instance</strong>.</p>
        <p class="issue-count">
            <span class="critical-count">Critical Issues: <span id="critical-count">0</span></span> | 
            <span class="warning-count">Warnings: <span id="warning-count">0</span></span> | 
            <span class="info-count">Information: <span id="info-count">0</span></span>
        </p>
    </div>
EOF

    cat "$header_file" > "$report_file"
    rm -f "$header_file"
}

# Function to create HTML footer
create_html_footer() {
    local output_dir="$1"
    local footer_file="$output_dir/footer.html"
    
    cat > "$footer_file" << EOF
    <div class="footer">
        <p>Oracle Database Security Scan completed. This report contains findings that should be reviewed by database administrators and security personnel.</p>
        <p>Scan performed using the Oracle Security Scan Tool.</p>
    </div>
</body>
</html>
EOF
}

# Function to execute SQL and output results
execute_sql() {
    local output_dir="$1"
    local instance="$2"
    local title="$3"
    local description="$4"
    local severity="$5"  # critical, warning, or info
    local category="$6"
    local sql_query="$7"
    local sql_output_dir="$output_dir/sql_outputs"
    local output_file="$sql_output_dir/${category}_$(echo "$title" | tr ' ' '_').html"
    local temp_file="$sql_output_dir/temp.out"
    local report_file="$output_dir/security_report.html"
    
    log "[$instance] Executing: $title"
    
    # Create directory for SQL output
    mkdir -p "$sql_output_dir"
    
    # Execute the SQL query
    echo -e "${sql_query}" | sqlplus -S "$ORACLE_USER/$ORACLE_PASSWORD@$instance AS SYSDBA" > "$temp_file" 2>> "$LOG_FILE"
    
    # Check if the command was successful
    if [ $? -ne 0 ]; then
        log "[$instance] ${RED}Error executing SQL query for: $title${NC}"
        echo "<h3 id=\"${category}-$(echo "$title" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')\">$title</h3>" >> "$output_file"
        echo "<div class=\"warning\"><p>Error executing this check. See log file for details.</p></div>" >> "$output_file"
        return 1
    fi
    
    # Check if the output contains any data (excluding headers and SQL prompt)
    local result_count=$(grep -v "^$" "$temp_file" | grep -v "rows selected" | grep -v "no rows selected" | wc -l)
    result_count=$((result_count - 3))  # Adjust for header lines
    if [ $result_count -lt 0 ]; then
        result_count=0
    fi
    
    # Generate HTML output for this check
    cat > "$output_file" << EOF
<h3 id="${category}-$(echo "$title" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')">${title}</h3>
<div class="${severity}">
    <p><strong>Description:</strong> ${description}</p>
    <p><strong>Severity:</strong> ${severity^}</p>
    <p><strong>Results:</strong> Found ${result_count} items to review</p>
EOF
    
    # If we have results, format them as a table
    if [ $result_count -gt 0 ]; then
        # Convert fixed-width output to HTML table
        echo "<table>" >> "$output_file"
        
        # Get header line and convert to table header
        head -2 "$temp_file" | tail -1 | awk '
        {
            print "<tr>"
            for(i=1; i<=NF; i++) {
                print "<th>" $i "</th>"
            }
            print "</tr>"
        }' >> "$output_file"
        
        # Skip header and format remaining lines
        grep -v "^$" "$temp_file" | grep -v "rows selected" | grep -v "no rows selected" | tail -n +4 | awk '
        {
            if (NF > 0) {
                print "<tr>"
                for(i=1; i<=NF; i++) {
                    print "<td>" $i "</td>"
                }
                print "</tr>"
            }
        }' >> "$output_file"
        
        echo "</table>" >> "$output_file"
        
        # Update count based on severity
        if [ "$severity" == "critical" ]; then
            critical_count=$((critical_count + 1))
            sed -i "s/<span id=\"critical-count\">[0-9]*<\/span>/<span id=\"critical-count\">$critical_count<\/span>/g" "$report_file"
        elif [ "$severity" == "warning" ]; then
            warning_count=$((warning_count + 1))
            sed -i "s/<span id=\"warning-count\">[0-9]*<\/span>/<span id=\"warning-count\">$warning_count<\/span>/g" "$report_file"
        else
            info_count=$((info_count + 1))
            sed -i "s/<span id=\"info-count\">[0-9]*<\/span>/<span id=\"info-count\">$info_count<\/span>/g" "$report_file"
        fi
    fi
    
    echo "</div>" >> "$output_file"
    
    # Clean up
    rm -f "$temp_file"
    
    return 0
}

# Function to generate a section of the report
generate_section() {
    local output_dir="$1"
    local section_id="$2"
    local section_title="$3"
    local section_description="$4"
    local report_file="$output_dir/security_report.html"
    
    cat >> "$report_file" << EOF
    <h2 id="${section_id}">${section_title}</h2>
    <p>${section_description}</p>
EOF
    
    # Append all SQL outputs for this section
    for file in "$output_dir/sql_outputs/${section_id}_"*; do
        if [ -f "$file" ]; then
            cat "$file" >> "$report_file"
        fi
    done
}

# Function to generate final recommendations
generate_recommendations() {
    local output_dir="$1"
    local report_file="$output_dir/security_report.html"
    
    cat >> "$report_file" << EOF
    <h2 id="recommendations">Recommendations</h2>
    <div class="info">
        <p>Based on the findings in this report, consider implementing the following security measures:</p>
        <ul>
            <li>Implement a strong password policy including complexity requirements and regular password rotation.</li>
            <li>Lock and/or remove unused default accounts.</li>
            <li>Implement the principle of least privilege - restrict user rights to only what is necessary.</li>
            <li>Enable and configure auditing for sensitive operations.</li>
            <li>Consider implementing Transparent Data Encryption (TDE) for sensitive data.</li>
            <li>Regularly review and remove excessive privileges from users and roles.</li>
            <li>Monitor and secure network access to the database.</li>
            <li>Implement Oracle security patches and updates according to a regular schedule.</li>
            <li>Remove or secure public access to system tables and packages.</li>
            <li>Review and validate DB links, especially those using fixed credentials.</li>
        </ul>
    </div>
EOF
}

# Function to finalize the report
finalize_report() {
    local output_dir="$1"
    local instance="$2"
    local critical_count=$(grep -o '<span id="critical-count">[0-9]*</span>' "$output_dir/security_report.html" | sed 's/<span id="critical-count">\([0-9]*\)<\/span>/\1/')
    local warning_count=$(grep -o '<span id="warning-count">[0-9]*</span>' "$output_dir/security_report.html" | sed 's/<span id="warning-count">\([0-9]*\)<\/span>/\1/')
    local info_count=$(grep -o '<span id="info-count">[0-9]*</span>' "$output_dir/security_report.html" | sed 's/<span id="info-count">\([0-9]*\)<\/span>/\1/')
    
    # Append footer
    cat "$output_dir/footer.html" >> "$output_dir/security_report.html"
    
    # Remove temporary files
    rm -f "$output_dir/footer.html"
    
    # Get relative path for report
    local rel_path=$(realpath --relative-to="$BASE_OUTPUT_DIR" "$output_dir/security_report.html")
    
    # Update combined report
    update_combined_report "$instance" "$critical_count" "$warning_count" "$info_count" "$rel_path"
    
    log "[$instance] ${GREEN}Report generated at: $output_dir/security_report.html${NC}"
    log "[$instance] Findings: $critical_count critical, $warning_count warnings, $info_count informational items"
    
    return 0
}

# Function to scan a single Oracle instance
scan_instance() {
    local instance="$1"
    local output_dir="$BASE_OUTPUT_DIR/$instance"
    
    # Create output directory for this instance
    mkdir -p "$output_dir"
    mkdir -p "$output_dir/sql_outputs"
    
    log "[$instance] Starting security scan..."
    
    # Initialize counters
    critical_count=0
    warning_count=0
    info_count=0
    
    # Create HTML header and footer
    create_html_header "$output_dir" "$instance"
    create_html_footer "$output_dir"
    
    # Check connection to the instance
    log "[$instance] Testing connection..."
    echo "SELECT 'Connection successful' FROM dual;" | sqlplus -S "$ORACLE_USER/$ORACLE_PASSWORD@$instance AS SYSDBA" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        log "[$instance] ${RED}Failed to connect to Oracle instance.${NC}"
        cat >> "$output_dir/security_report.html" << EOF
    <div class="critical">
        <p><strong>Error:</strong> Failed to connect to Oracle instance $instance.</p>
        <p>Please check your Oracle credentials and ensure the instance is running.</p>
    </div>
EOF
        cat "$output_dir/footer.html" >> "$output_dir/security_report.html"
        rm -f "$output_dir/footer.html"
        update_combined_report "$instance" "Error" "Error" "Error" "$(realpath --relative-to="$BASE_OUTPUT_DIR" "$output_dir/security_report.html")"
        return 1
    fi
    
    # 1. User Accounts Checks
    log "[$instance] Performing User Account checks..."
    
    execute_sql "$output_dir" "$instance" "Default Accounts" "Check for default accounts that are still enabled" "critical" "accounts" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN username FORMAT A15
COLUMN account_status FORMAT A16
COLUMN profile FORMAT A10
COLUMN authentication_type FORMAT A20
COLUMN created FORMAT A12

SELECT username, account_status, profile, 
       authentication_type, TO_CHAR(created, 'YYYY-MM-DD') as created
FROM dba_users
WHERE username IN ('SYS', 'SYSTEM', 'DBSNMP', 'OUTLN', 'MDSYS', 'ORDSYS', 
                   'ORDPLUGINS', 'CTXSYS', 'DSSYS', 'PERFSTAT', 
                   'WKPROXY', 'WKSYS', 'WMSYS', 'XDB', 'ANONYMOUS', 
                   'ODM', 'ODM_MTR', 'OLAPSYS', 'TRACESVR', 'ORACLE_OCM')
AND account_status = 'OPEN'
ORDER BY username;
"
    
    execute_sql "$output_dir" "$instance" "Inactive Accounts" "Check for accounts that haven't been used for 180+ days" "warning" "accounts" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN username FORMAT A15
COLUMN account_status FORMAT A16
COLUMN lock_date FORMAT A12
COLUMN expiry_date FORMAT A12
COLUMN last_login FORMAT A20

SELECT username, account_status, 
       TO_CHAR(lock_date, 'YYYY-MM-DD') as lock_date, 
       TO_CHAR(expiry_date, 'YYYY-MM-DD') as expiry_date, 
       to_char(last_login, 'YYYY-MM-DD HH24:MI:SS') as last_login
FROM dba_users
WHERE account_status = 'OPEN'
  AND (last_login < sysdate-180 OR last_login IS NULL)
ORDER BY last_login;
"
    
    execute_sql "$output_dir" "$instance" "Expiring Passwords" "Check for accounts with passwords expiring within 30 days" "warning" "accounts" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN username FORMAT A15
COLUMN account_status FORMAT A16
COLUMN lock_date FORMAT A12
COLUMN expiry_date FORMAT A12
COLUMN profile FORMAT A10

SELECT username, account_status, 
       TO_CHAR(lock_date, 'YYYY-MM-DD') as lock_date, 
       TO_CHAR(expiry_date, 'YYYY-MM-DD') as expiry_date, 
       profile
FROM dba_users
WHERE account_status NOT LIKE '%LOCKED%'
AND expiry_date IS NOT NULL
AND expiry_date < SYSDATE+30
ORDER BY expiry_date;
"
    
    # 2. Password Policy Checks
    log "[$instance] Performing Password Policy checks..."
    
    execute_sql "$output_dir" "$instance" "Password Policies" "Check password policy settings for profiles" "warning" "passwords" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN profile FORMAT A15
COLUMN resource_name FORMAT A25
COLUMN limit FORMAT A20

SELECT profile, resource_name, limit
FROM dba_profiles
WHERE resource_name IN ('FAILED_LOGIN_ATTEMPTS', 
                        'PASSWORD_LIFE_TIME', 
                        'PASSWORD_REUSE_TIME', 
                        'PASSWORD_REUSE_MAX', 
                        'PASSWORD_VERIFY_FUNCTION', 
                        'PASSWORD_LOCK_TIME',
                        'PASSWORD_GRACE_TIME')
ORDER BY profile, resource_name;
"
    
    execute_sql "$output_dir" "$instance" "Weak Password Verification" "Profiles without password verification functions" "critical" "passwords" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN profile FORMAT A15
COLUMN limit FORMAT A40

SELECT profile, limit
FROM dba_profiles
WHERE resource_name = 'PASSWORD_VERIFY_FUNCTION'
AND (limit = 'DEFAULT' OR limit = 'NULL')
ORDER BY profile;
"
    
    # 3. Privilege Checks
    log "[$instance] Performing Privilege checks..."
    
    execute_sql "$output_dir" "$instance" "Excessive Privileges" "Users with powerful system privileges" "critical" "privileges" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN grantee FORMAT A20
COLUMN privilege FORMAT A30
COLUMN admin_option FORMAT A12

SELECT grantee, privilege, admin_option
FROM dba_sys_privs
WHERE privilege IN ('ALTER DATABASE', 'ALTER SYSTEM', 'AUDIT SYSTEM', 
                    'CREATE EXTERNAL JOB', 'SYSDBA', 'SYSOPER', 
                    'UNLIMITED TABLESPACE', 'EXEMPT ACCESS POLICY')
AND grantee NOT IN ('SYS', 'SYSTEM')
ORDER BY grantee, privilege;
"
    
    execute_sql "$output_dir" "$instance" "Powerful Roles" "Users granted powerful roles" "critical" "privileges" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN grantee FORMAT A20
COLUMN granted_role FORMAT A25
COLUMN admin_option FORMAT A12
COLUMN default_role FORMAT A12

SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE granted_role IN ('DBA', 'IMP_FULL_DATABASE', 'EXP_FULL_DATABASE', 
                      'SELECT_CATALOG_ROLE', 'DELETE_CATALOG_ROLE', 
                      'EXECUTE_CATALOG_ROLE', 'ALTER_SYSTEM', 'RESOURCE', 
                      'HS_ADMIN_ROLE', 'AQ_ADMINISTRATOR_ROLE')
AND grantee NOT IN ('SYS', 'SYSTEM')
ORDER BY grantee, granted_role;
"
    
    execute_sql "$output_dir" "$instance" "Direct System Object Access" "Non-system users with direct access to system objects" "warning" "privileges" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN grantee FORMAT A20
COLUMN privilege FORMAT A20
COLUMN owner FORMAT A10
COLUMN table_name FORMAT A30

SELECT grantee, privilege, owner, table_name
FROM dba_tab_privs
WHERE owner IN ('SYS', 'SYSTEM', 'DBSNMP')
AND grantee NOT IN ('SYS', 'SYSTEM', 'DBA')
ORDER BY grantee, privilege;
"
    
    execute_sql "$output_dir" "$instance" "Public Grants on System Objects" "System objects accessible to all users (PUBLIC)" "warning" "privileges" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN owner FORMAT A10
COLUMN table_name FORMAT A30
COLUMN privilege FORMAT A20

SELECT owner, table_name, privilege, grantee
FROM dba_tab_privs
WHERE grantee = 'PUBLIC'
AND owner IN ('SYS', 'SYSTEM')
ORDER BY owner, table_name, privilege;
"
    
    execute_sql "$output_dir" "$instance" "Dangerous UTL Package Access" "Users with access to potentially dangerous UTL_ packages" "critical" "privileges" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN grantee FORMAT A20
COLUMN owner FORMAT A10
COLUMN table_name FORMAT A15
COLUMN privilege FORMAT A10

SELECT grantee, owner, table_name, privilege
FROM dba_tab_privs
WHERE table_name IN ('UTL_FILE', 'UTL_HTTP', 'UTL_SMTP', 'UTL_TCP', 'DBMS_LOB')
AND grantee NOT IN ('SYS', 'SYSTEM', 'DBA')
ORDER BY grantee, table_name;
"
    
    # 4. System Settings Checks
    log "[$instance] Performing System Settings checks..."
    
    execute_sql "$output_dir" "$instance" "Security Parameters" "Database security-related parameters" "info" "system" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN name FORMAT A30
COLUMN value FORMAT A40

SELECT name, value 
FROM v\$parameter
WHERE name IN (
    'audit_trail', 
    'audit_sys_operations',
    'audit_file_dest',
    'compatible', 
    'global_names',
    'os_authent_prefix',
    'os_roles',
    'remote_listener',
    'remote_login_passwordfile',
    'remote_os_authent',
    'remote_os_roles',
    'sec_case_sensitive_logon',
    'sql92_security',
    'utl_file_dir')
ORDER BY name;
"
    
    execute_sql "$output_dir" "$instance" "Invalid Objects" "Invalid database objects that could indicate security issues" "warning" "system" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN owner FORMAT A15
COLUMN object_name FORMAT A30
COLUMN object_type FORMAT A20
COLUMN status FORMAT A10

SELECT owner, object_name, object_type, status
FROM dba_objects
WHERE status != 'VALID'
ORDER BY owner, object_type, object_name;
"
    
    execute_sql "$output_dir" "$instance" "Java Objects" "Java objects in the database that could pose security risks" "info" "system" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN owner FORMAT A15
COLUMN object_name FORMAT A30
COLUMN object_type FORMAT A20
COLUMN status FORMAT A10

SELECT owner, object_name, object_type, status
FROM dba_objects
WHERE object_type LIKE '%JAVA%'
ORDER BY owner, object_name;
"
    
    execute_sql "$output_dir" "$instance" "Potential SQL Injection Vulnerabilities" "Stored code with potential SQL injection vulnerabilities" "critical" "system" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN name FORMAT A30
COLUMN text FORMAT A120

SELECT name, text
FROM all_source
WHERE (upper(text) LIKE '%EXECUTE IMMEDIATE%' OR upper(text) LIKE '%DBMS_SQL.PARSE%')
  AND (upper(text) LIKE '%&%' OR upper(text) LIKE '%||%')
ORDER BY name;
"
    
    # 5. Encryption Checks
    log "[$instance] Performing Encryption checks..."
    
    execute_sql "$output_dir" "$instance" "Transparent Data Encryption Status" "Status of Transparent Data Encryption" "info" "encryption" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON

SELECT * FROM v\$encryption_wallet;
"
    
    execute_sql "$output_dir" "$instance" "Encrypted Columns" "Columns using transparent data encryption" "info" "encryption" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN owner FORMAT A15
COLUMN table_name FORMAT A25
COLUMN column_name FORMAT A25
COLUMN encryption_alg FORMAT A20

SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns
ORDER BY owner, table_name, column_name;
"
    
    # 6. Auditing Checks
    log "[$instance] Performing Auditing checks..."
    
    execute_sql "$output_dir" "$instance" "Audit Settings" "Current audit settings" "info" "auditing" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON

SELECT name, value
FROM v\$parameter
WHERE name LIKE '%audit%'
ORDER BY name;
"
    
    execute_sql "$output_dir" "$instance" "Statement Audit Policies" "Configured statement audit policies" "info" "auditing" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON

SELECT * FROM dba_stmt_audit_opts;
"
    
    execute_sql "$output_dir" "$instance" "Privilege Audit Policies" "Configured privilege audit policies" "info" "auditing" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON

SELECT * FROM dba_priv_audit_opts;
"
    
    execute_sql "$output_dir" "$instance" "Fine-Grained Audit Policies" "Configured fine-grained audit policies" "info" "auditing" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN policy_name FORMAT A25
COLUMN object_schema FORMAT A15
COLUMN object_name FORMAT A25
COLUMN policy_column FORMAT A15
COLUMN enabled FORMAT A7

SELECT policy_name, object_schema, object_name, policy_column,
       enabled, handler_schema, handler, audit_trail
FROM dba_audit_policies
ORDER BY policy_name;
"
    
    # 7. Network Access Checks
    log "[$instance] Performing Network Access checks..."
    
    execute_sql "$output_dir" "$instance" "Database Links" "Database links that could pose security risks" "warning" "network" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN owner FORMAT A15
COLUMN db_link FORMAT A30
COLUMN username FORMAT A15
COLUMN host FORMAT A40

SELECT owner, db_link, username, host
FROM dba_db_links
ORDER BY owner, db_link;
"
    
    execute_sql "$output_dir" "$instance" "Public Database Links" "Database links accessible to all users" "critical" "network" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN db_link FORMAT A30
COLUMN username FORMAT A15
COLUMN host FORMAT A40

SELECT * FROM dba_db_links WHERE owner = 'PUBLIC';
"
    
    execute_sql "$output_dir" "$instance" "Directory Objects" "Directory objects that could allow file access" "warning" "network" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN directory_name FORMAT A30
COLUMN directory_path FORMAT A70

SELECT directory_name, directory_path
FROM dba_directories
ORDER BY directory_name;
"
    
    execute_sql "$output_dir" "$instance" "Network Access Control Lists" "Network access control lists (ACLs)" "info" "network" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN host FORMAT A30
COLUMN lower_port FORMAT A10
COLUMN upper_port FORMAT A10
COLUMN principal FORMAT A20
COLUMN privilege FORMAT A15
COLUMN grant_type FORMAT A10

SELECT host, lower_port, upper_port, ace_order, principal, 
       privilege, TO_CHAR(start_date, 'YYYY-MM-DD') as start_date, 
       TO_CHAR(end_date, 'YYYY-MM-DD') as end_date, grant_type
FROM dba_network_acls a, dba_network_acl_privileges p
WHERE a.acl = p.acl
ORDER BY host, lower_port, ace_order;
"
    
    execute_sql "$output_dir" "$instance" "Virtual Private Database Policies" "VPD policies for row-level security" "info" "network" "
SET PAGESIZE 1000
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
COLUMN policy_name FORMAT A25
COLUMN object_schema FORMAT A15
COLUMN object_name FORMAT A25
COLUMN policy_function FORMAT A25
COLUMN function_schema FORMAT A15

SELECT policy_name, object_schema, object_name, policy_function,
       enable, sel, ins, upd, del, function_schema
FROM dba_policies
ORDER BY object_schema, object_name, policy_name;
"
    
    # Generate the report sections
    log "[$instance] Generating report sections..."
    
    # Generate user accounts section
    generate_section "$output_dir" "accounts" "User Accounts" "This section reviews user account security, including default accounts, inactive accounts, and accounts with expiring passwords."
    
    # Generate password policies section
    generate_section "$output_dir" "passwords" "Password Policies" "This section examines password policies, including complexity requirements, expiration settings, and account lockout configurations."
    
    # Generate privileges section
    generate_section "$output_dir" "privileges" "Privileges and Roles" "This section analyzes user privileges, role assignments, and access to system objects that could pose security risks."
    
    # Generate system settings section
    generate_section "$output_dir" "system" "System Settings" "This section reviews database system parameters and settings that affect security."
    
    # Generate encryption section
    generate_section "$output_dir" "encryption" "Data Encryption" "This section examines the configuration and use of Oracle Transparent Data Encryption (TDE) and other encryption features."
    
    # Generate auditing section
    generate_section "$output_dir" "auditing" "Auditing and Monitoring" "This section reviews the configuration of database auditing features."
    
    # Generate network access section
    generate_section "$output_dir" "network" "Network Security" "This section examines network-related security settings, including database links and access control lists."
    
    # Generate recommendations
    generate_recommendations "$output_dir"
    
    # Finalize the report
    finalize_report "$output_dir" "$instance"
    
    log "[$instance] ${GREEN}Security scan completed!${NC}"
    
    return 0
}

# Main function to run security scan on all instances
run_security_scan() {
    mkdir -p "$BASE_OUTPUT_DIR"
    
    # Create combined report
    create_combined_html_header
    
    # Detect Oracle instances if auto-detection is enabled
    if [ "$AUTO_DETECT" = true ]; then
        detect_oracle_instances
        if [ $? -ne 0 ]; then
            log "${RED}Failed to detect Oracle instances.${NC}"
            exit 1
        fi
    fi
    
    # Get the number of instances to scan
    INSTANCE_COUNT=$(wc -l < "$INSTANCES_FILE")
    log "Preparing to scan $INSTANCE_COUNT Oracle instance(s)"
    
    # Scan instances in parallel, but limit the max number of parallel jobs
    cat "$INSTANCES_FILE" | while read instance; do
        # Count running jobs
        running_jobs=$(jobs -p | wc -l)
        # If we've reached the max, wait for one to finish
        while [ $running_jobs -ge $PARALLEL_MAX ]; do
            sleep 2
            running_jobs=$(jobs -p | wc -l)
        done
        # Start scan in background
        scan_instance "$instance" &
        sleep 1  # Small delay to avoid race conditions
    done
    
    # Wait for all background jobs to complete
    wait
    
    log "${GREEN}All security scans completed!${NC}"
    log "Combined report available at: ${BLUE}$COMBINED_REPORT${NC}"
    log "Individual reports are in instance-specific directories under: ${BLUE}$BASE_OUTPUT_DIR${NC}"
    
    return 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -u|--user)
            ORACLE_USER="$2"
            shift 2
            ;;
        -p|--password)
            ORACLE_PASSWORD="$2"
            shift 2
            ;;
        -l|--list-instances)
            list_only=true
            shift
            ;;
        -i|--instance)
            AUTO_DETECT=false
            IFS=',' read -r -a selected_instances <<< "$2"
            mkdir -p "$BASE_OUTPUT_DIR"
            > "$INSTANCES_FILE"
            for inst in "${selected_instances[@]}"; do
                echo "$inst" >> "$INSTANCES_FILE"
            done
            shift 2
            ;;
        -m|--max-parallel)
            PARALLEL_MAX="$2"
            shift 2
            ;;
        -o|--output-dir)
            BASE_OUTPUT_DIR="$2"
            COMBINED_REPORT="$BASE_OUTPUT_DIR/combined_report.html"
            INSTANCES_FILE="$BASE_OUTPUT_DIR/instances.txt"
            LOG_FILE="$BASE_OUTPUT_DIR/scan.log"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if Oracle sqlplus is available
if ! command -v sqlplus &> /dev/null; then
    echo -e "${RED}Error: Oracle sqlplus command not found.${NC}"
    echo "Please ensure that Oracle client is installed and sqlplus is in your PATH."
    exit 1
fi

# Only list instances if requested
if [ "$list_only" = true ]; then
    detect_oracle_instances
    exit 0
fi

# If password is not provided, prompt for it
if [ -z "$ORACLE_PASSWORD" ]; then
    echo -n "Enter Oracle password for $ORACLE_USER: "
    read -s ORACLE_PASSWORD
    echo ""
fi

# Run the security scan
run_security_scan

exit 0