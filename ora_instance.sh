#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Oracle Instance Management
# ======================================================================
# Version: 3.0
# Description: Functions for listing and managing Oracle instances
# Usage: Source this file or run standalone with ./ora_instance.sh
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

# Enhanced function to list Oracle instances with detailed status
list_instances() {
    display_header "ORACLE INSTANCES"
    log_message "Listing Oracle instances"
    
    # Get list of Oracle instances using multiple methods
    # Method 1: From processes (with full process info for instance type detection)
    ps -ef | grep "[p]mon" > $TEMP_DIR/pmon_processes.tmp
    cat $TEMP_DIR/pmon_processes.tmp | awk '{print $NF}' | sed 's/ora_pmon_//g' | sed 's/asm_pmon_//g' > $TEMP_DIR/instance_list.tmp
    
    # Method 2: From oratab if available
    if [ -f /etc/oratab ]; then
        cat /etc/oratab | grep -v "^#" | grep -v "^$" | cut -d: -f1 >> $TEMP_DIR/instance_list.tmp
    fi
    
    # Remove duplicates and sort
    sort $TEMP_DIR/instance_list.tmp | uniq > $TEMP_DIR/instance_list_final.tmp
    
    # Check if any instances found
    if [ ! -s $TEMP_DIR/instance_list_final.tmp ]; then
        echo -e "${RED}No Oracle instances found running on this server${NC}"
        log_message "No Oracle instances found"
        cleanup_and_exit 1
    fi
    
    # Collect instance type info for each running instance
    > $TEMP_DIR/instance_types.tmp
    while read PMON_PROC; do
        INST=$(echo "$PMON_PROC" | awk '{print $NF}' | sed 's/ora_pmon_//g' | sed 's/asm_pmon_//g')
        
        # Detect instance type (ASM, RAC, etc.)
        if echo "$PMON_PROC" | grep -q "asm_pmon"; then
            echo "$INST:ASM" >> $TEMP_DIR/instance_types.tmp
        elif echo "$PMON_PROC" | grep -q "+"; then
            echo "$INST:RAC" >> $TEMP_DIR/instance_types.tmp
        else
            echo "$INST:SINGLE" >> $TEMP_DIR/instance_types.tmp
        fi
    done < $TEMP_DIR/pmon_processes.tmp
    
    # Get current ORACLE_SID
    CURRENT_SID=$ORACLE_SID
    
    # Display instances with enhanced status
    echo -e "${YELLOW}Available Oracle Instances:${NC}"
    echo -e "+------+--------------------+---------+------------+----------------+"
    echo -e "| ${YELLOW}Num${NC}  | ${YELLOW}Instance Name${NC}      | ${YELLOW}Status${NC}   | ${YELLOW}Type${NC}       | ${YELLOW}Version/Info${NC}    |"
    echo -e "+------+--------------------+---------+------------+----------------+"
    
    INSTANCE_NUM=1
    while read INSTANCE; do
        # Check if instance is running and get its type
        ps -ef | grep "[p]mon_$INSTANCE" > /dev/null
        RUNNING=$?
        if [ $RUNNING -eq 0 ]; then
            STATUS="${GREEN}Running${NC}"
            
            # Get instance type
            INSTANCE_TYPE=$(grep "^$INSTANCE:" $TEMP_DIR/instance_types.tmp | cut -d: -f2)
            if [ -z "$INSTANCE_TYPE" ]; then
                INSTANCE_TYPE="DB"
            fi
            
            # Get version info if possible by temporarily setting ORACLE_SID
            export ORACLE_SID=$INSTANCE
            
            if [ "$INSTANCE_TYPE" = "ASM" ]; then
                TYPE_INFO="${CYAN}ASM${NC}"
                VERSION=$(sqlplus -s / as sysasm <<EOF 2>/dev/null
set heading off pagesize 0 feedback off verify off
select substr(version,1,10) from v\\$instance;
exit;
EOF
                )
            else
                if [ "$INSTANCE_TYPE" = "RAC" ]; then
                    TYPE_INFO="${PURPLE}RAC-DB${NC}"
                else
                    TYPE_INFO="${BLUE}Single-DB${NC}"
                fi
                
                VERSION=$(sqlplus -s / as sysdba <<EOF 2>/dev/null
set heading off pagesize 0 feedback off verify off
select substr(version,1,10) from v\\$instance;
exit;
EOF
                )
            fi
            
            # If sqlplus failed, note it
            if [ -z "$VERSION" ]; then
                VERSION="${RED}No access${NC}"
            fi
            
        else
            STATUS="${RED}Down${NC}"
            TYPE_INFO="${YELLOW}Unknown${NC}"
            VERSION="${YELLOW}Unavailable${NC}"
        fi
        
        # Mark current instance if applicable
        DISPLAY_INSTANCE=$INSTANCE
        if [ "$INSTANCE" = "$CURRENT_SID" ]; then
            DISPLAY_INSTANCE="${CYAN}$INSTANCE (current)${NC}"
        fi
        
        # Print formatted entry
        printf "| %-4d | %-18b | %-7b | %-10b | %-14b |\n" $INSTANCE_NUM "$DISPLAY_INSTANCE" "$STATUS" "$TYPE_INFO" "$VERSION"
        INSTANCE_NUM=$((INSTANCE_NUM+1))
    done < $TEMP_DIR/instance_list_final.tmp
    echo -e "+------+--------------------+---------+------------+----------------+"
    
    # Restore original ORACLE_SID
    if [ -n "$CURRENT_SID" ]; then
        export ORACLE_SID=$CURRENT_SID
    fi
    
    # Let user select an instance
    echo -e "\nPlease select an instance number (1-$((INSTANCE_NUM-1))): "
    read SELECTION
    
    # Validate selection
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ $SELECTION -lt 1 ] || [ $SELECTION -gt $((INSTANCE_NUM-1)) ]; then
        echo -e "${RED}Invalid selection: $SELECTION${NC}"
        echo -e "Please enter a number between 1 and $((INSTANCE_NUM-1))"
        log_message "Invalid instance selection: $SELECTION"
        cleanup_and_exit 1
    fi
    
    SELECTED_INSTANCE=$(sed -n "${SELECTION}p" $TEMP_DIR/instance_list_final.tmp)
    
    echo -e "${GREEN}Selected instance: $SELECTED_INSTANCE${NC}"
    export ORACLE_SID=$SELECTED_INSTANCE
    log_message "Selected instance: $ORACLE_SID"
    
    # Try to set ORACLE_HOME if not already set
    if [ -z "$ORACLE_HOME" ] && [ -f /etc/oratab ]; then
        ORACLE_HOME=$(grep "^$ORACLE_SID:" /etc/oratab | cut -d: -f2)
        if [ -n "$ORACLE_HOME" ]; then
            export ORACLE_HOME
            echo -e "Set ORACLE_HOME to $ORACLE_HOME"
            log_message "Set ORACLE_HOME to $ORACLE_HOME"
        fi
    fi
    
    # Get instance details
    get_instance_details
}

# Function to get detailed instance information after selection
get_instance_details() {
    display_header "INSTANCE DETAILS: $ORACLE_SID"
    log_message "Getting details for instance: $ORACLE_SID"
    
    # Check instance status
    ps -ef | grep "[p]mon_$ORACLE_SID" > /dev/null
    INST_RUNNING=$?
    if [ $INST_RUNNING -ne 0 ]; then
        echo -e "${RED}Instance $ORACLE_SID is not running. Cannot retrieve details.${NC}"
        log_message "Instance $ORACLE_SID is not running"
        return
    fi
    
    # Determine if ASM instance
    IS_ASM=0
    ps -ef | grep "[a]sm_pmon_$ORACLE_SID" > /dev/null && IS_ASM=1
    
    if [ $IS_ASM -eq 1 ]; then
        echo -e "${YELLOW}ASM INSTANCE DETAILS:${NC}"
        sqlplus -s / as sysasm <<EOF
            set linesize 150
            set pagesize 100
            
            prompt ${YELLOW}INSTANCE VERSION:${NC}
            select instance_name, version, status, database_status 
            from v\$instance;
            
            prompt 
            prompt ${YELLOW}ASM DISK GROUPS:${NC}
            col name format a20
            col state format a12
            col type format a8
            col total_gb format 999,999.99
            col free_gb format 999,999.99
            col pct_used format 999.99
            
            select name, state, type,
                   total_mb/1024 total_gb,
                   free_mb/1024 free_gb,
                   (1-(free_mb/total_mb))*100 pct_used
            from v\$asm_diskgroup
            order by name;
            
            prompt 
            prompt ${YELLOW}ASM CLIENTS:${NC}
            col instance_name format a20
            col db_name format a12
            col status format a12
            
            select instance_name, db_name, status 
            from v\$asm_client
            order by db_name, instance_name;
            exit;
EOF
    else
        echo -e "${YELLOW}DATABASE INSTANCE DETAILS:${NC}"
        sqlplus -s / as sysdba <<EOF
            set linesize 150
            set pagesize 100
            
            prompt ${YELLOW}INSTANCE VERSION:${NC}
            select instance_name, version, status, database_status, instance_role, active_state, host_name
            from v\$instance;
            
            prompt 
            prompt ${YELLOW}DATABASE INFORMATION:${NC}
            col name format a12
            col created format a20
            col open_mode format a15
            col log_mode format a12
            col platform_name format a25
            
            select name, created, log_mode, open_mode, database_role, platform_name 
            from v\$database;
            
            prompt 
            prompt ${YELLOW}INSTANCE PARAMETERS:${NC}
            col parameter format a25
            col value format a40
            
            select name as parameter, value, isdefault 
            from v\$parameter 
            where name in ('db_name','db_unique_name','compatible','cluster_database','instance_number',
                          'sga_max_size','pga_aggregate_target','memory_target','memory_max_target',
                          'control_files','diagnostic_dest','db_recovery_file_dest',
                          'cpu_count','processes','sessions')
            order by name;
            
            prompt 
            prompt ${YELLOW}DATABASE SIZE:${NC}
            SELECT round(sum(bytes)/1024/1024/1024,2) || ' GB' as TOTAL_SIZE FROM dba_data_files;
            
            prompt 
            prompt ${YELLOW}TABLESPACE USAGE:${NC}
            col tablespace_name format a20
            col size_gb format 999.99
            col used_gb format 999.99
            col free_gb format 999.99
            col pct_used format 999.99
            
            SELECT df.tablespace_name,
                   ROUND(df.bytes/1024/1024/1024,2) size_gb,
                   ROUND(NVL((df.bytes-fs.bytes),df.bytes)/1024/1024/1024,2) used_gb,
                   ROUND(NVL(fs.bytes,0)/1024/1024/1024,2) free_gb,
                   ROUND(NVL((df.bytes-fs.bytes),df.bytes)/df.bytes*100,2) pct_used
            FROM (SELECT tablespace_name, SUM(bytes) bytes FROM dba_data_files GROUP BY tablespace_name) df,
                 (SELECT tablespace_name, SUM(bytes) bytes FROM dba_free_space GROUP BY tablespace_name) fs
            WHERE df.tablespace_name = fs.tablespace_name(+)
            ORDER BY pct_used DESC;
            exit;
EOF
    fi
}

# Check if this module is being run directly (standalone)
if is_module_standalone; then
    # If run directly, perform instance management
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool - Instance Management${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    list_instances
fi
