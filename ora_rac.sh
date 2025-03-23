#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - RAC Diagnostics
# ======================================================================
# Version: 3.0
# Description: Functions for RAC diagnostics and interconnect checks
# Usage: Source this file or run standalone with ./ora_rac.sh
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

# Enhanced RAC interconnect latency check
check_interconnect_latency() {
    display_header "RAC INTERCONNECT LATENCY CHECK"
    log_message "Checking RAC interconnect latency"
    
    # Check if this is part of a RAC
    ps -ef | grep "[c]rsd.bin" > /dev/null
    CRS_RUNNING=$?
    
    if [ $CRS_RUNNING -ne 0 ]; then
        echo -e "${YELLOW}This does not appear to be an Oracle RAC node (crsd not running)${NC}"
        log_message "Not a RAC node - crsd not running"
        return
    fi
    
    echo -e "${GREEN}ORACLE RAC DETECTED - CHECKING INTERCONNECT LATENCY${NC}"
    log_message "Oracle RAC detected, checking interconnect latency"
    
    # Get Oracle version
    if [ -x $ORACLE_HOME/bin/oraversion ]; then
        ORA_VERSION=$($ORACLE_HOME/bin/oraversion -serverRelease)
        echo -e "Oracle version: $ORA_VERSION"
    fi
    
    # Get GI version
    if [ -x $ORACLE_HOME/bin/crsctl ]; then
        GI_VERSION=$($ORACLE_HOME/bin/crsctl query crs activeversion | grep "The active version")
        echo -e "Grid Infrastructure version: $GI_VERSION"
    fi
    
    # Get all cluster nodes
    if [ -x $ORACLE_HOME/bin/olsnodes ]; then
        echo -e "\n${YELLOW}CLUSTER NODES:${NC}"
        $ORACLE_HOME/bin/olsnodes -n -i -s -t
        
        # Get local node name
        LOCAL_NODE=$($ORACLE_HOME/bin/olsnodes -l)
        echo -e "Local node: $LOCAL_NODE"
    fi
    
    # Get interconnect IPs
    echo -e "\n${YELLOW}INTERCONNECT IPs:${NC}"
    if [ -x $ORACLE_HOME/bin/oifcfg ]; then
        $ORACLE_HOME/bin/oifcfg getif | grep cluster_interconnect
        
        # Get interconnect network details
        IC_SUBNET=$($ORACLE_HOME/bin/oifcfg getif | grep cluster_interconnect | awk '{print $1}')
        IC_INTERFACE=$($ORACLE_HOME/bin/oifcfg getif | grep cluster_interconnect | awk '{print $2}')
        echo -e "Interconnect subnet: $IC_SUBNET on interface $IC_INTERFACE"
    fi
    
    # If we didn't get the interface, try to detect it
    if [ -z "$IC_INTERFACE" ]; then
        if [ $IS_AIX -eq 1 ]; then
            IC_INTERFACE=$(netstat -rn | grep -v "lo0" | grep "169.254" | head -1 | awk '{print $NF}')
            if [ -z "$IC_INTERFACE" ]; then
                IC_INTERFACE=$(netstat -rn | grep -v "lo0" | grep "192.168" | head -1 | awk '{print $NF}')
            fi
        else
            # Linux detection
            IC_INTERFACE=$(ip route | grep -v "lo" | grep "169.254" | head -1 | awk '{print $3}')
            if [ -z "$IC_INTERFACE" ]; then
                IC_INTERFACE=$(ip route | grep -v "lo" | grep "192.168" | head -1 | awk '{print $3}')
            fi
        fi
        
        if [ -n "$IC_INTERFACE" ]; then
            echo -e "Detected possible interconnect interface: $IC_INTERFACE"
        else
            echo -e "${RED}Unable to detect interconnect interface${NC}"
            log_message "Unable to detect interconnect interface"
        fi
    fi
    
    # Get interface details if available
    if [ -n "$IC_INTERFACE" ]; then
        echo -e "\n${YELLOW}INTERCONNECT INTERFACE DETAILS:${NC}"
        if [ $IS_AIX -eq 1 ]; then
            ifconfig $IC_INTERFACE
            
            echo -e "\n${YELLOW}INTERCONNECT INTERFACE STATISTICS:${NC}"
            entstat -d $IC_INTERFACE | grep -i "Bytes\|Packets\|error\|collision\|dropout\|CRC"
        else
            ip addr show $IC_INTERFACE
            
            echo -e "\n${YELLOW}INTERCONNECT INTERFACE STATISTICS:${NC}"
            if command -v ethtool >/dev/null 2>&1; then
                ethtool -S $IC_INTERFACE | grep -i "error\|drop\|collision\|miss"
            fi
        fi
    fi
    
    # Run Oracle's clsecho latency test
    if [ -x $ORACLE_HOME/bin/clsecho ]; then
        echo -e "\n${YELLOW}INTERCONNECT LATENCY TEST RESULTS:${NC}"
        echo -e "${GREEN}NOTE: Optimal latency should be under 100 microseconds (0.1ms)${NC}"
        echo -e "${GREEN}      Acceptable latency should be under 500 microseconds (0.5ms)${NC}"
        echo -e "${RED}      Latency above 1000 microseconds (1ms) indicates potential problems${NC}"
        echo -e "Running clsecho test with $RAC_PING_COUNT pings..."
        
        # Run with timeout to prevent hanging
        run_with_timeout 60 $ORACLE_HOME/bin/clsecho -s $RAC_PING_COUNT > $TEMP_DIR/clsecho.out 2>&1
        
        if [ -s $TEMP_DIR/clsecho.out ]; then
            cat $TEMP_DIR/clsecho.out | grep -i "average latency"
            
            # Extract and analyze the latency value
            LATENCY=$(cat $TEMP_DIR/clsecho.out | grep -i "average latency" | awk '{print $NF}')
            if [ -n "$LATENCY" ]; then
                LATENCY_NUM=$(echo $LATENCY | sed 's/[^0-9\.]//g')
                # Use bc for floating point comparison if available
                if command -v bc >/dev/null 2>&1; then
                    if (( $(echo "$LATENCY_NUM < 100" | bc -l) )); then
                        echo -e "${GREEN}Excellent latency: $LATENCY (under 100 microseconds)${NC}"
                        log_message "Excellent interconnect latency: $LATENCY"
                    elif (( $(echo "$LATENCY_NUM < 500" | bc -l) )); then
                        echo -e "${YELLOW}Good latency: $LATENCY (under 500 microseconds)${NC}"
                        log_message "Good interconnect latency: $LATENCY"
                    elif (( $(echo "$LATENCY_NUM < 1000" | bc -l) )); then
                        echo -e "${YELLOW}Acceptable latency: $LATENCY (under 1ms)${NC}"
                        log_message "Acceptable interconnect latency: $LATENCY"
                    else
                        echo -e "${RED}Poor latency: $LATENCY (over 1ms) - investigate potential issues${NC}"
                        log_message "Poor interconnect latency: $LATENCY - above maximum recommended value"
                    fi
                else
                    # Simpler comparison without bc
                    if [ $(echo "$LATENCY_NUM" | cut -d. -f1) -lt 100 ]; then
                        echo -e "${GREEN}Excellent latency: $LATENCY (under 100 microseconds)${NC}"
                        log_message "Excellent interconnect latency: $LATENCY"
                    elif [ $(echo "$LATENCY_NUM" | cut -d. -f1) -lt 500 ]; then
                        echo -e "${YELLOW}Good latency: $LATENCY (under 500 microseconds)${NC}"
                        log_message "Good interconnect latency: $LATENCY"
                    elif [ $(echo "$LATENCY_NUM" | cut -d. -f1) -lt 1000 ]; then
                        echo -e "${YELLOW}Acceptable latency: $LATENCY (under 1ms)${NC}"
                        log_message "Acceptable interconnect latency: $LATENCY"
                    else
                        echo -e "${RED}Poor latency: $LATENCY (over 1ms) - investigate potential issues${NC}"
                        log_message "Poor interconnect latency: $LATENCY - above maximum recommended value"
                    fi
                fi
            fi
        else
            echo -e "${RED}No output from clsecho test${NC}"
            log_message "clsecho test failed - no output"
        fi
    fi
    
    # Alternative latency check using ping if clsecho fails
    if [ ! -x $ORACLE_HOME/bin/clsecho ] || [ ! -s $TEMP_DIR/clsecho.out ]; then
        echo -e "\n${YELLOW}USING PING FOR BASIC LATENCY TEST:${NC}"
        echo -e "Note: This is less accurate than clsecho for RAC latency"
        log_message "Using ping for basic latency test"
        
        # Get other nodes' IPs
        if [ -x $ORACLE_HOME/bin/olsnodes ]; then
            OTHER_NODES=$($ORACLE_HOME/bin/olsnodes | grep -v $LOCAL_NODE)
            
            for NODE in $OTHER_NODES; do
                NODE_IP=$($ORACLE_HOME/bin/olsnodes -i | grep $NODE | awk '{print $2}')
                if [ -n "$NODE_IP" ]; then
                    echo -e "Pinging node $NODE ($NODE_IP)..."
                    ping -c 10 $NODE_IP | grep "round-trip"
                fi
            done
        fi
    fi
}

# Enhanced function to check cluster resources in RAC environment
check_cluster_resources() {
    display_header "CLUSTER RESOURCES"
    log_message "Checking cluster resources"
    
    # Check if this is a RAC/GI installation
    if [ ! -x $ORACLE_HOME/bin/crsctl ]; then
        echo -e "${YELLOW}This does not appear to be a Grid Infrastructure installation${NC}"
        echo -e "crsctl command not found in $ORACLE_HOME/bin"
        log_message "Not a Grid Infrastructure installation"
        return
    fi
    
    echo -e "${YELLOW}GRID INFRASTRUCTURE VERSION:${NC}"
    $ORACLE_HOME/bin/crsctl query crs activeversion
    $ORACLE_HOME/bin/crsctl query crs softwareversion
    
    echo -e "\n${YELLOW}CLUSTER NODES AND NETWORK:${NC}"
    if [ -x $ORACLE_HOME/bin/olsnodes ]; then
        $ORACLE_HOME/bin/olsnodes -n -i -s -t
    fi
    
    echo -e "\n${YELLOW}NETWORK INTERFACES:${NC}"
    if [ -x $ORACLE_HOME/bin/oifcfg ]; then
        $ORACLE_HOME/bin/oifcfg getif
    fi
    
    echo -e "\n${YELLOW}CLUSTER TIME SYNCHRONIZATION:${NC}"
    if [ -x $ORACLE_HOME/bin/crsctl ]; then
        $ORACLE_HOME/bin/crsctl check ctss
    fi
    
    echo -e "\n${YELLOW}CLUSTERWARE RESOURCES:${NC}"
    log_message "Checking clusterware resources"
    run_with_timeout 30 $ORACLE_HOME/bin/crsctl status resource -t > $TEMP_DIR/crs_resources.out 2>&1
    
    if [ -s $TEMP_DIR/crs_resources.out ]; then
        cat $TEMP_DIR/crs_resources.out
    else
        echo -e "${RED}Unable to get cluster resource status${NC}"
        log_message "Unable to get cluster resource status"
    fi
    
    echo -e "\n${YELLOW}ASM DISK GROUPS:${NC}"
    log_message "Checking ASM disk groups"
    # Check if ASM is running
    ps -ef | grep "[a]sm_pmon" > /dev/null
    ASM_RUNNING=$?
    
    if [ $ASM_RUNNING -eq 0 ]; then
        # Connect to ASM to get disk group info
        ORACLE_SID_ORIG=$ORACLE_SID
        
        # Get ASM instance name
        ASM_SID=$(ps -ef | grep "[a]sm_pmon" | head -1 | awk '{print $NF}' | sed 's/asm_pmon_//g')
        export ORACLE_SID=$ASM_SID
        
        sqlplus -s / as sysasm <<EOF
            set linesize 150
            set pagesize 100
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
            exit;
EOF
        
        # Restore original ORACLE_SID
        export ORACLE_SID=$ORACLE_SID_ORIG
    else
        echo -e "ASM not running on this node"
        log_message "ASM not running on this node"
    fi
    
    # Check for OCR and voting disk information
    echo -e "\n${YELLOW}OCR AND VOTING DISK INFORMATION:${NC}"
    if [ -x $ORACLE_HOME/bin/ocrcheck ]; then
        $ORACLE_HOME/bin/ocrcheck
    fi
    
    if [ -x $ORACLE_HOME/bin/crsctl ]; then
        echo -e "\n${YELLOW}VOTING DISKS:${NC}"
        $ORACLE_HOME/bin/crsctl query css votedisk
    fi
    
    # Check cluster health
    echo -e "\n${YELLOW}CLUSTER HEALTH CHECK:${NC}"
    if [ -x $ORACLE_HOME/bin/cluvfy ]; then
        run_with_timeout 60 $ORACLE_HOME/bin/cluvfy comp healthcheck -collect cluster
    fi
    
    log_message "Completed checking cluster resources"
}

# Function to check RAC database configuration
check_rac_database() {
    display_header "RAC DATABASE CONFIGURATION"
    log_message "Checking RAC database configuration"
    
    sqlplus -s / as sysdba <<EOF
        set linesize 150
        set pagesize 100
        
        prompt ${YELLOW}DATABASE INSTANCES:${NC}
        col inst_id format 999
        col instance_name format a15
        col host_name format a25
        col status format a10
        col version format a15
        
        select inst_id, instance_name, host_name, status, version
        from gv\$instance
        order by inst_id;
        
        prompt 
        prompt ${YELLOW}RAC DATABASE PARAMETERS:${NC}
        col name format a30
        col value format a40
        
        select name, value
        from v\$parameter
        where name in (
            'cluster_database',
            'cluster_database_instances',
            'instance_number',
            'thread',
            'undo_tablespace',
            'remote_listener',
            'local_listener',
            'dispatchers',
            'gcs_server_processes',
            'parallel_instance_group'
        )
        order by name;
        
        prompt 
        prompt ${YELLOW}SERVICES CONFIGURATION:${NC}
        col service_name format a30
        col network_name format a30
        col pdb format a15
        
        select name as service_name, network_name, pdb
        from dba_services
        order by pdb, name;
        
        exit;
EOF

    # Check interconnect usage
    echo -e "\n${YELLOW}INTERCONNECT USAGE:${NC}"
    sqlplus -s / as sysdba <<EOF
        set linesize 200
        set pagesize 100
        
        col name format a60
        col value format a15
        
        select name, value
        from gv\$sysstat
        where name like 'gc%' or name like 'gcs%' 
        order by name, inst_id;
        
        exit;
EOF

    log_message "Completed checking RAC database configuration"
}

# Check if this module is being run directly (standalone)
if is_module_standalone; then
    # If run directly, perform RAC checks
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool - RAC Diagnostics${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    # Try to load instance_manager if available
    if [ -f "$SCRIPT_DIR/ora_instance.sh" ]; then
        source "$SCRIPT_DIR/ora_instance.sh"
        list_instances  # Select an instance first
    else
        echo -e "${YELLOW}Warning: ora_instance.sh not found. Some functionality may be limited.${NC}"
        # Try to set a default ORACLE_SID from running instances
        if [ -z "$ORACLE_SID" ]; then
            DEFAULT_SID=$(ps -ef | grep pmon | grep -v grep | head -1 | awk '{print $NF}' | sed 's/.*_//g')
            if [ -n "$DEFAULT_SID" ]; then
                export ORACLE_SID=$DEFAULT_SID
                echo -e "${YELLOW}Using detected ORACLE_SID: $ORACLE_SID${NC}"
            fi
        fi
    fi
    
    # Now check RAC
    check_interconnect_latency
    check_cluster_resources
    check_rac_database
fi
