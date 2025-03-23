#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Alert Log Analysis
# ======================================================================
# Version: 3.0
# Description: Functions for checking alert logs and listener errors
# Usage: Source this file or run standalone with ./ora_alerts.sh
# Dependencies: ora_common.sh
# ======================================================================

# Find script directory for proper module sourcing
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")

# Check if common functions are already loaded
if [ -z "$TEMP_DIR" ] || [ -z "$LOG_FILE" ]; then
    # Try to locate and source the common.sh file
    if [ -f "$SCRIPT_DIR/ora_common.sh" ]; then
        source "$SCRIPT_DIR/ora_common.sh"
    else
        echo "Error: Cannot find ora_common.sh. This script requires the common functions."
        exit 1
    fi
fi

# Function to check Oracle Listener errors in the last hour
check_listener_errors() {
    display_header "ORACLE LISTENER ERRORS (LAST $LISTENER_ERROR_HOURS HOUR(S))"
    log_message "Checking listener errors in the last $LISTENER_ERROR_HOURS hour(s)"
    
    # Try multiple methods to find listener log
    LISTENER_LOG=""
    
    # Method 1: From ps output
    LISTENER_LOG_FROM_PS=$(ps -ef | grep tnslsnr | grep -v grep | awk '{for(i=1;i<=NF;i++){if($i ~ /log/){print $i}}}' | sed 's/.*=//g')
    
    # Method 2: From environment
    if [ -z "$LISTENER_LOG_FROM_PS" ] && [ -n "$ORACLE_HOME" ]; then
        LISTENER_LOG_FROM_ENV="$ORACLE_HOME/network/log"
    fi
    
    # Method 3: From diagnostic_dest parameter
    DIAG_DEST=$(sqlplus -s / as sysdba <<EOF
        set heading off feedback off pagesize 0 verify off
        select value from v\$parameter where name='diagnostic_dest';
        exit;
EOF
    )
    
    if [ -n "$DIAG_DEST" ]; then
        LISTENER_LOG_FROM_DIAG="$DIAG_DEST/diag/tnslsnr/$HOSTNAME/listener/trace"
    fi
    
    # Check each potential location
    for LOG_LOCATION in "$LISTENER_LOG_FROM_PS" "$LISTENER_LOG_FROM_ENV" "$LISTENER_LOG_FROM_DIAG"; do
        if [ -n "$LOG_LOCATION" ] && [ -d "$LOG_LOCATION" ]; then
            LISTENER_LOG="$LOG_LOCATION"
            break
        fi
    done
    
    if [ -z "$LISTENER_LOG" ]; then
        echo -e "${RED}Unable to locate listener log directory${NC}"
        log_message "Unable to locate listener log directory"
    else
        echo -e "Checking listener logs in: $LISTENER_LOG"
        log_message "Checking listener logs in: $LISTENER_LOG"
        
        # Use find with correct time format for minutes
        HOURS_AGO=$((LISTENER_ERROR_HOURS * 60))
        
        # Get all potential log files
        find $LISTENER_LOG -name "*.log" -type f -mmin -$HOURS_AGO > $TEMP_DIR/listener_logs.tmp
        
        if [ -s $TEMP_DIR/listener_logs.tmp ]; then
            LISTENER_ERRORS=$(cat $(cat $TEMP_DIR/listener_logs.tmp) | grep -i "TNS-\|error\|warn\|fail" 2>/dev/null)
            
            if [ -n "$LISTENER_ERRORS" ]; then
                echo -e "${YELLOW}Found listener errors/warnings:${NC}"
                echo "$LISTENER_ERRORS" | grep -i "TNS-\|error\|warn\|fail" | sort | uniq -c | sort -nr
                
                echo -e "\n${YELLOW}Most recent errors:${NC}"
                echo "$LISTENER_ERRORS" | tail -20
                
                log_message "Found listener errors/warnings"
            else
                echo -e "${GREEN}No listener errors found in the last $LISTENER_ERROR_HOURS hour(s)${NC}"
                log_message "No listener errors found"
            fi
        else
            echo -e "${GREEN}No recent listener log files found${NC}"
            log_message "No recent listener log files found"
        fi
    fi
}

# Enhanced function to display alert log entries with better formatting
display_alerts() {
    display_header "ALERT LOG (LAST $HISTORY_HOURS HOURS)"
    log_message "Checking alert log for the last $HISTORY_HOURS hours"
    
    # Find diagnostic directory
    DIAG_DEST=$(sqlplus -s / as sysdba <<EOF
        set heading off pagesize 0 feedback off verify off
        select value from v\$parameter where name='diagnostic_dest';
        exit;
EOF
    )
    
    if [ -z "$DIAG_DEST" ]; then
        echo -e "${RED}Unable to determine diagnostic_dest parameter${NC}"
        log_message "Unable to determine diagnostic_dest parameter"
        return
    fi
    
    # Handle case sensitivity for different OS
    ALERT_LOG="${DIAG_DEST}/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log"
    
    # Try alternative paths if the first one fails
    if [ ! -f "$ALERT_LOG" ]; then
        ORACLE_SID_LOWER=$(echo $ORACLE_SID | tr '[:upper:]' '[:lower:]')
        ALERT_LOG="${DIAG_DEST}/diag/rdbms/${ORACLE_SID_LOWER}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log"
    fi
    
    if [ ! -f "$ALERT_LOG" ]; then
        ALERT_LOG="${DIAG_DEST}/diag/rdbms/${ORACLE_SID_LOWER}/${ORACLE_SID_LOWER}/trace/alert_${ORACLE_SID_LOWER}.log"
    fi
    
    if [ -f "$ALERT_LOG" ]; then
        echo -e "${YELLOW}Alert log found: $ALERT_LOG${NC}"
        log_message "Alert log found: $ALERT_LOG"
        
        # Calculate time for minutes ago
        MINUTES_AGO=$((HISTORY_HOURS * 60))
        
        # First try to get date-based errors
        CURRENT_DATE=$(date +"%Y-%m-%d")
        
        # Use perl for date calculation to be compatible with both AIX and Linux
        YESTERDAY_DATE=$(perl -e 'use POSIX qw(strftime); print strftime "%Y-%m-%d", localtime(time()-86400);' 2>/dev/null)
        
        # Get errors based on modification time and grep for errors
        find "$ALERT_LOG" -type f -mmin -$MINUTES_AGO > $TEMP_DIR/alert_log_list.tmp
        
        if [ -s $TEMP_DIR/alert_log_list.tmp ]; then
            echo -e "\n${YELLOW}Critical events from the last $HISTORY_HOURS hours:${NC}"
            
            # Extract relevant error patterns with context
            cat $ALERT_LOG | grep -A 3 -B 1 -i "ORA-\|error\|warn\|fail\|corrupt\|exception\|incident" | 
                grep -v "failover\|information\|success" | tail -$ALERT_LOG_ENTRIES > $TEMP_DIR/alert_errors.tmp
            
            if [ -s $TEMP_DIR/alert_errors.tmp ]; then
                # Format and highlight errors
                cat $TEMP_DIR/alert_errors.tmp | 
                    sed -e "s/ORA-[0-9]\+/${RED}&${NC}/g" -e "s/Error/${RED}&${NC}/g" -e "s/WARNING/${YELLOW}&${NC}/g" |
                    sed -e "s/\(^.*incident.*$\)/${RED}\1${NC}/" -e "s/\(^.*corrupt.*$\)/${RED}\1${NC}/"
                
                # Count error occurrences by type
                echo -e "\n${YELLOW}Error summary:${NC}"
                grep -o "ORA-[0-9]\+" $TEMP_DIR/alert_errors.tmp | sort | uniq -c | sort -nr | head -10
                
                log_message "Found critical events in alert log"
            else
                echo -e "${GREEN}No critical errors found in the alert log for the last $HISTORY_HOURS hours${NC}"
                log_message "No critical errors found in alert log"
            fi
        else
            echo -e "${GREEN}Alert log has not been modified in the last $HISTORY_HOURS hours${NC}"
            log_message "Alert log not modified in the specified time period"
        fi
    else
        echo -e "${RED}Alert log not found at any of the expected locations:${NC}"
        echo -e "- ${DIAG_DEST}/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log"
        echo -e "- ${DIAG_DEST}/diag/rdbms/${ORACLE_SID_LOWER}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log"
        echo -e "- ${DIAG_DEST}/diag/rdbms/${ORACLE_SID_LOWER}/${ORACLE_SID_LOWER}/trace/alert_${ORACLE_SID_LOWER}.log"
        
        log_message "Alert log not found at expected locations"
    fi
}

# Check if this module is being run directly (standalone)
if is_module_standalone; then
    # If run directly, we need instance selection before checking alerts
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool - Alert Log Analysis${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    # Load instance_manager if available
    if [ -f "$SCRIPT_DIR/ora_instance.sh" ]; then
        source "$SCRIPT_DIR/ora_instance.sh"
        list_instances  # Select an instance first
        
        # Now check alerts and listener errors
        check_listener_errors
        display_alerts
    else
        echo -e "${RED}Error: ora_instance.sh is required to select an Oracle instance${NC}"
        echo -e "Please make sure ora_instance.sh is in the same directory."
        exit 1
    fi
fi
