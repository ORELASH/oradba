#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Parameter Analysis
# ======================================================================
# Version: 3.0
# Description: Functions for analyzing Oracle parameters
# Usage: Source this file or run standalone with ./ora_params.sh
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

# Enhanced function to display non-default parameters with categories
display_non_default_params() {
    display_header "NON-DEFAULT PARAMETERS"
    log_message "Checking non-default Oracle parameters"
    
    # Create SQL script with improved formatting
    cat > $TEMP_DIR/nondefault_params.sql << 'EOF'
set linesize 150
set pagesize 1000
set feedback off
set verify off
column name format a40
column value format a60
column isdefault format a8
column description format a80
break on category skip 1

select 
    case 
        when regexp_like(name, '^pga|^sga|^memory|^db_cache|^shared_pool|^large_pool|^java_pool|^streams_pool|^result_cache') then 'Memory Management'
        when regexp_like(name, '^optimizer|^query|^star|^cursor|^result|^parallel|^session') then 'Query Optimization'
        when regexp_like(name, '^db_file|^dbwr|^disk|^io|^filesystemio|^asynch') then 'I/O Parameters'
        when regexp_like(name, '^log|^archive|^control|^db_recovery|^fast_start|^backup') then 'Recovery & Backup'
        when regexp_like(name, '^undo|^rollback') then 'Undo Management'
        when regexp_like(name, '^cluster|^gcs|^lms|^interconnect') then 'RAC Parameters'
        when regexp_like(name, '^event|^diag|^trace|^dump|^max_dump|^timed_statistics') then 'Diagnostic Parameters'
        when regexp_like(name, '^sec|^audit') then 'Security Parameters'
        else 'Other Parameters'
    end as category,
    name, 
    value, 
    isdefault
from v$parameter
where isdefault='FALSE'
order by category, name;
EOF

    # Execute SQL script
    echo -e "Querying for non-default parameters..."
    
    sqlplus -s / as sysdba @$TEMP_DIR/nondefault_params.sql
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error executing SQL query for non-default parameters${NC}"
        echo -e "Trying simplified query..."
        log_message "Error with categorized parameter query, using simplified query"
        
        # Fallback to simple query if the first one fails
        sqlplus -s / as sysdba <<EOF
            set linesize 150
            set pagesize 100
            col name format a40
            col value format a60
            col isdefault format a10
            select name, value, isdefault
            from v\$parameter
            where isdefault='FALSE'
            order by name;
            exit;
EOF
    fi
    
    # Additional check for hidden parameters
    echo -e "\n${YELLOW}CHECKING HIDDEN PARAMETERS:${NC}"
    log_message "Checking hidden parameters"
    
    sqlplus -s / as sysdba <<EOF
        set linesize 150
        set pagesize 100
        col parameter format a40
        col value format a40
        select x.ksppinm parameter, y.ksppstvl value
        from sys.x\$ksppi x, sys.x\$ksppcv y
        where x.inst_id = userenv('Instance') and y.inst_id = userenv('Instance')
        and x.indx = y.indx
        and substr(x.ksppinm,1,1) = '_'
        and y.ksppstvl != y.ksppstdf
        and rownum <= 20;
        exit;
EOF

    # Display critical initialization parameters
    echo -e "\n${YELLOW}CRITICAL INITIALIZATION PARAMETERS:${NC}"
    log_message "Checking critical initialization parameters"
    
    sqlplus -s / as sysdba <<EOF
        set linesize 150
        set pagesize 100
        col parameter format a40
        col value format a40
        col description format a50
        
        select name as parameter, value, isdefault,
               ismodified as modified
        from v\$parameter
        where name in (
            'db_block_size',
            'db_recovery_file_dest_size',
            'diagnostic_dest',
            'memory_max_target',
            'memory_target',
            'pga_aggregate_target',
            'processes',
            'sga_max_size',
            'sga_target',
            'shared_pool_size'
        )
        order by name;
        exit;
EOF

    # Display memory parameters
    echo -e "\n${YELLOW}MEMORY PARAMETERS:${NC}"
    log_message "Checking memory parameters"
    
    sqlplus -s / as sysdba <<EOF
        set linesize 150
        set pagesize 100
        
        select name, value, isdefault,
               ismodified as modified
        from v\$parameter
        where name in (
            'memory_max_target',
            'memory_target',
            'pga_aggregate_target',
            'sga_max_size',
            'sga_target',
            'shared_pool_size',
            'large_pool_size',
            'java_pool_size',
            'db_cache_size'
        )
        order by name;
        exit;
EOF

    log_message "Completed checking non-default parameters"
}

# Function to display parameter change history
display_param_history() {
    display_header "PARAMETER CHANGE HISTORY"
    log_message "Checking parameter change history"
    
    # Query alert log for parameter changes
    echo -e "${YELLOW}PARAMETER CHANGES FROM ALERT LOG:${NC}"
    
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
        echo -e "Checking alert log for parameter changes: $ALERT_LOG"
        grep -i "ALTER SYSTEM SET" $ALERT_LOG | tail -30
    else
        echo -e "${RED}Alert log not found.${NC}"
    fi
    
    # Check SPFILE for parameters
    echo -e "\n${YELLOW}SPFILE PARAMETERS:${NC}"
    
    sqlplus -s / as sysdba <<EOF
        set linesize 150
        set pagesize 1000
        set feedback off
        
        col parameter format a40
        col value format a60
        col type format a10
        
        select distinct a.sid, a.name as parameter, a.value, 
               decode(a.isspecified,'TRUE','SPFILE','PFILE') as from_file
        from v\$spparameter a, v\$parameter b
        where a.isspecified = 'TRUE'
        and a.name = b.name
        and (b.isdefault='FALSE' or a.sid != '*')
        order by a.sid, a.name;
        exit;
EOF

    log_message "Completed checking parameter change history"
}

# Check if this module is being run directly (standalone)
if is_module_standalone; then
    # If run directly, we need instance selection before checking parameters
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool - Parameter Analysis${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    # Load instance_manager if available
    if [ -f "$SCRIPT_DIR/ora_instance.sh" ]; then
        source "$SCRIPT_DIR/ora_instance.sh"
        list_instances  # Select an instance first
        
        # Now check parameters
        display_non_default_params
        display_param_history
    else
        echo -e "${RED}Error: ora_instance.sh is required to select an Oracle instance${NC}"
        echo -e "Please make sure ora_instance.sh is in the same directory."
        exit 1
    fi
fi
