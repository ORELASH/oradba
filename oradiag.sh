#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Portable Version
# ======================================================================
# Version: 3.0
# This script provides comprehensive diagnostics for Oracle databases 
# running on AIX or Linux systems with VIOS/virtualization and RAC configurations
# ======================================================================

# Configuration variables (adjust as needed)
TEMP_DIR="/tmp/ora_diag_$$"
LOG_FILE="$TEMP_DIR/ora_diag.log"
MAX_TOP_PROCESSES=15
HISTORY_HOURS=24
LISTENER_ERROR_HOURS=1
ALERT_LOG_ENTRIES=100
RAC_PING_COUNT=30
MOUNT_WARNING_THRESHOLD=90
IO_SAMPLES=5

# Detect OS type
OS_TYPE=$(uname -s)
if [ "$OS_TYPE" = "AIX" ]; then
    IS_AIX=1
    IS_LINUX=0
else
    IS_AIX=0
    IS_LINUX=1
fi

# Set terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ======================================================================
# Common functions
# ======================================================================

# Initialize environment
init_environment() {
    # Start time for execution tracking
    START_TIME=$(date +%s)
    
    # Create temporary directory
    mkdir -p $TEMP_DIR 2>/dev/null
    
    # Check if running as ORACLE user
    if [ "$(whoami)" != "oracle" ]; then
        echo -e "${RED}This script must be run as the ORACLE user${NC}"
        cleanup_and_exit 1
    fi
    
    # Set TERM if not already set
    if [ -z "$TERM" ]; then
        export TERM=vt100
    fi
    
    # Detect Oracle Home if not set
    if [ -z "$ORACLE_HOME" ]; then
        POSSIBLE_ORACLE_HOME=$(dirname $(dirname $(ps -ef | grep pmon | grep -v grep | head -1 | awk '{print $NF}' | sed 's/ora_pmon_//g')))
        if [ -n "$POSSIBLE_ORACLE_HOME" ]; then
            export ORACLE_HOME=$POSSIBLE_ORACLE_HOME
            echo -e "${YELLOW}ORACLE_HOME not set, using detected value: $ORACLE_HOME${NC}"
        else
            echo -e "${RED}ORACLE_HOME not set and could not be detected${NC}"
        fi
    fi
    
    # Log script start
    log_message "Oracle DBA Diagnostic Tool started at $(date) on $OS_TYPE"
}

# Log message to log file
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# Cleanup temporary files on exit
cleanup_and_exit() {
    EXIT_CODE=${1:-0}
    
    # Calculate execution time
    END_TIME=$(date +%s)
    EXECUTION_TIME=$((END_TIME - START_TIME))
    
    log_message "Script completed with exit code $EXIT_CODE in $EXECUTION_TIME seconds"
    
    echo -e "Cleaning up temporary files..."
    rm -rf $TEMP_DIR
    
    echo -e "${GREEN}Script completed in $EXECUTION_TIME seconds${NC}"
    exit $EXIT_CODE
}

# Handle script interruption
trap_handler() {
    echo -e "${RED}Script interrupted. Cleaning up...${NC}"
    log_message "Script interrupted by user"
    cleanup_and_exit 2
}

# Set trap for SIGINT and SIGTERM
trap trap_handler INT TERM

# Function to display header
display_header() {
    echo -e "\n${BLUE}=========================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================================${NC}"
}

# Function to run command with timeout (AIX doesn't have timeout command)
run_with_timeout() {
    TIMEOUT=$1
    shift
    CMD="$@"
    
    log_message "Running command with $TIMEOUT second timeout: $CMD"
    
    # Start command in background
    $CMD &
    CMD_PID=$!
    
    # Wait for command to complete or timeout
    COUNTER=0
    while [ $COUNTER -lt $TIMEOUT ]; do
        if ! kill -0 $CMD_PID 2>/dev/null; then
            # Command completed
            wait $CMD_PID
            RESULT=$?
            log_message "Command completed with status $RESULT"
            return $RESULT
        fi
        sleep 1
        COUNTER=$((COUNTER + 1))
    done
    
    # Command timed out, kill it
    kill -9 $CMD_PID 2>/dev/null
    wait $CMD_PID 2>/dev/null
    echo -e "${RED}Command timed out after $TIMEOUT seconds: $CMD${NC}"
    log_message "Command timed out after $TIMEOUT seconds: $CMD"
    return 124
}

# ======================================================================
# System metrics collection 
# ======================================================================

# Function to display system metrics
display_system_metrics() {
    display_header "SYSTEM METRICS"
    log_message "Collecting system metrics"
    
    # OS Version and Hostname
    echo -e "${YELLOW}OS VERSION & HOSTNAME:${NC}"
    echo -e "$(uname -a)"
    
    if [ $IS_AIX -eq 1 ]; then
        # AIX-specific metrics
        echo -e "\n${YELLOW}AIX VERSION AND UPTIME:${NC}"
        echo -e "$(oslevel -s) - Up $(uptime | awk -F, '{print $1}' | awk '{$1=$2=""; print $0}')"
        
        # System model
        echo -e "\n${YELLOW}SYSTEM MODEL:${NC}"
        prtconf | grep "System Model" 
        
        # Number of CPUs and Memory
        echo -e "\n${YELLOW}CPU AND MEMORY:${NC}"
        prtconf | grep -E "Number Of Processors|Good Memory Size" | sed 's/Good //'
        
        # AIX Resource Metrics
        echo -e "\n${YELLOW}RESOURCE METRICS:${NC}"
        echo -e "$(date) - Resource utilization snapshot"
        vmstat 1 3
        
        # Disk usage with warning for filesystems over threshold
        echo -e "\n${YELLOW}DISK USAGE:${NC}"
        echo -e "Warning level set to $MOUNT_WARNING_THRESHOLD% usage"
        df -g | awk -v threshold=$MOUNT_WARNING_THRESHOLD 'NR==1 {print; next} {used=$4/$3*100; color=""; reset=""; if (used > threshold) {color="\033[0;31m"; reset="\033[0m"}; printf "%s%s%s\n", color, $0, reset}'
        
        # Process info
        echo -e "\n${YELLOW}TOP CPU PROCESSES:${NC}"
        ps -eo user,pid,pcpu,pmem,vsz,args | sort -k3 -r | head -$MAX_TOP_PROCESSES
        
        # Memory details
        echo -e "\n${YELLOW}MEMORY USAGE DETAILS:${NC}"
        svmon -G -O unit=MB
        
        # Paging space with utilization percentage
        echo -e "\n${YELLOW}PAGING SPACE:${NC}"
        lsps -a
        
        # I/O statistics
        echo -e "\n${YELLOW}I/O STATISTICS (${IO_SAMPLES} SAMPLES):${NC}"
        iostat 1 $IO_SAMPLES
        
        # Network interfaces with stats
        echo -e "\n${YELLOW}NETWORK INTERFACES:${NC}"
        netstat -in
        
        # Network errors
        echo -e "\n${YELLOW}NETWORK ERRORS:${NC}"
        for IFACE in $(ifconfig -a | grep '^en' | awk '{print $1}'); do
            echo -e "Interface $IFACE stats:"
            entstat -d $IFACE | grep -i "error\|collision\|drop\|miss\|crc"
        done
        
        # Check AIX tuning parameters for Oracle
        echo -e "\n${YELLOW}AIX PERFORMANCE TUNING PARAMETERS FOR ORACLE:${NC}"
        echo -e "${YELLOW}NETWORK TUNING:${NC}"
        CHECK_PARAMS="tcp_recvspace tcp_sendspace rfc1323 sb_max udp_recvspace"
        for PARAM in $CHECK_PARAMS; do
            VALUE=$(no -o $PARAM 2>/dev/null)
            echo -e "$PARAM = $VALUE"
        done
        
        echo -e "\n${YELLOW}VMM TUNING:${NC}"
        CHECK_PARAMS="minperm maxperm lru_file_repage maxclient"
        for PARAM in $CHECK_PARAMS; do
            VALUE=$(vmo -o $PARAM 2>/dev/null)
            echo -e "$PARAM = $VALUE"
        done
        
        echo -e "\n${YELLOW}DISK I/O TUNING:${NC}"
        CHECK_PARAMS="maxpgahead minpgahead"
        for PARAM in $CHECK_PARAMS; do
            VALUE=$(vmo -o $PARAM 2>/dev/null)
            echo -e "$PARAM = $VALUE"
        done
        
        echo -e "\n${YELLOW}JFS/JFS2 PARAMETERS:${NC}"
        mount | grep -E 'jfs|jfs2' | awk '{print $1, $3}' | while read FS TYPE; do
            echo -e "Filesystem: $FS - Type: $TYPE"
            if [ "$TYPE" = "jfs2" ]; then
                mount | grep $FS | grep -o -E 'cio|dio|agblksize'
            fi
        done
        
        echo -e "\n${YELLOW}ASYNCHRONOUS I/O:${NC}"
        lsdev -C | grep aio
        lsattr -El aio0
        
    else
        # Linux-specific metrics
        echo -e "\n${YELLOW}UPTIME AND LOAD:${NC}"
        uptime
        
        # CPU info
        echo -e "\n${YELLOW}CPU INFO:${NC}"
        lscpu | grep -E "^CPU\(s\):|^Core|^Socket|^Model name"
        
        # Memory info
        echo -e "\n${YELLOW}MEMORY INFO:${NC}"
        free -h
        
        # Disk usage with warning for filesystems over threshold
        echo -e "\n${YELLOW}DISK USAGE:${NC}"
        echo -e "Warning level set to $MOUNT_WARNING_THRESHOLD% usage"
        df -h | awk -v threshold=$MOUNT_WARNING_THRESHOLD 'NR==1 {print; next} {sub(/%/,""); if (NF==6) {used=$5} else {used=$4}; color=""; reset=""; if (used > threshold) {color="\033[0;31m"; reset="\033[0m"}; printf "%s%s%s\n", color, $0, reset}'
        
        # Process info - on Linux we can use top in batch mode
        echo -e "\n${YELLOW}TOP CPU PROCESSES:${NC}"
        top -b -n 1 -o %CPU | head -n $((MAX_TOP_PROCESSES + 7))
        
        # I/O statistics
        echo -e "\n${YELLOW}I/O STATISTICS:${NC}"
        iostat -x 1 $IO_SAMPLES
        
        # Network interfaces with stats
        echo -e "\n${YELLOW}NETWORK INTERFACES:${NC}"
        ip addr show
        
        # Network errors
        echo -e "\n${YELLOW}NETWORK ERRORS:${NC}"
        netstat -i
        
        # Linux tuning parameters for Oracle
        echo -e "\n${YELLOW}LINUX PERFORMANCE TUNING PARAMETERS FOR ORACLE:${NC}"
        echo -e "${YELLOW}KERNEL PARAMETERS:${NC}"
        CHECK_PARAMS="fs.aio-max-nr fs.file-max kernel.sem kernel.shmmax kernel.shmall net.ipv4.ip_local_port_range net.core.rmem_default net.core.rmem_max net.core.wmem_default net.core.wmem_max"
        for PARAM in $CHECK_PARAMS; do
            VALUE=$(sysctl -n $PARAM 2>/dev/null)
            echo -e "$PARAM = $VALUE"
        done
        
        echo -e "\n${YELLOW}SECURITY LIMITS FOR ORACLE USER:${NC}"
        su - oracle -c 'ulimit -a'
        
        echo -e "\n${YELLOW}TRANSPARENT HUGEPAGE SETTINGS:${NC}"
        cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo "Not available"
    fi
    
    log_message "Completed collecting system metrics"
}

# ======================================================================
# Virtualization information
# ======================================================================

# Function to display virtualization information
display_virt_info() {
    display_header "VIRTUALIZATION INFORMATION"
    log_message "Collecting virtualization information"
    
    if [ $IS_AIX -eq 1 ]; then
        # Try to determine if system is using VIOS
        HMC_MANAGED=0
        VIOS_SERVER=0
        
        # Check for VIOS server
        if [ -x /usr/bin/lsmap ]; then
            VIOS_SERVER=1
        fi
        
        # Check for HMC managed LPAR
        HMC_INFO=$(lsrsrc IBM.MCP 2>/dev/null)
        if [ $? -eq 0 ]; then
            HMC_MANAGED=1
        fi
        
        if [ $VIOS_SERVER -eq 1 ]; then
            echo -e "${GREEN}This system appears to be a VIOS server${NC}"
            log_message "System detected as VIOS server"
            
            echo -e "\n${YELLOW}VIOS VERSION:${NC}"
            ioslevel 2>/dev/null
            
            echo -e "\n${YELLOW}VIOS BUILD LEVEL:${NC}"
            if [ -f /usr/ios/cli/ioscli.level ]; then
                cat /usr/ios/cli/ioscli.level 2>/dev/null
            fi
            
            echo -e "\n${YELLOW}VIRTUAL SCSI MAPPINGS:${NC}"
            lsmap -all 2>/dev/null | grep -v "NO MAPPING"
            
            echo -e "\n${YELLOW}VIRTUAL ETHERNET MAPPINGS:${NC}"
            lsmap -all -net 2>/dev/null | grep -v "NO MAPPING"
            
            echo -e "\n${YELLOW}SHARED STORAGE POOLS:${NC}"
            if [ -x /usr/bin/lssp ]; then
                /usr/bin/lssp -status 2>/dev/null
            else
                echo -e "Shared Storage Pools feature not installed"
            fi
            
            echo -e "\n${YELLOW}NPIV MAPPINGS:${NC}"
            lsmap -npiv -all 2>/dev/null | grep -v "NO MAPPING"
            
            echo -e "\n${YELLOW}SEA CONFIGURATION:${NC}"
            lsdev -virtual | grep ent
            
        elif [ $HMC_MANAGED -eq 1 ]; then
            echo -e "${GREEN}This system appears to be managed by an HMC${NC}"
            log_message "System detected as HMC-managed LPAR"
            
            echo -e "\n${YELLOW}LPAR INFORMATION:${NC}"
            lparstat -i 2>/dev/null
            
            echo -e "\n${YELLOW}VIRTUAL DEVICES:${NC}"
            lsdev -virtual 2>/dev/null
            
            echo -e "\n${YELLOW}VIRTUAL ADAPTERS:${NC}"
            for VDEV in $(lsdev -virtual 2>/dev/null | grep -E 'ent|vscsi' | awk '{print $1}'); do
                echo -e "Device: $VDEV"
                lsattr -El $VDEV 2>/dev/null | grep -E 'backing|remote'
            done
            
            echo -e "\n${YELLOW}VIOS CLIENT RESOURCE ALLOCATION:${NC}"
            lparstat 1 1 2>/dev/null
        else
            echo -e "${YELLOW}This appears to be a standalone AIX system (non-VIOS, non-LPAR)${NC}"
            log_message "System detected as standalone AIX (non-VIOS)"
            echo -e "For more hardware information, run 'lscfg -v'"
        fi
    else
        # Linux virtualization detection
        echo -e "${YELLOW}CHECKING FOR VIRTUALIZATION:${NC}"
        VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "Unknown")
        if [[ "$VIRT_TYPE" == "Unknown" || "$VIRT_TYPE" == "none" ]]; then
            # Try alternative detection methods
            if [ -f /proc/cpuinfo ]; then
                CPUINFO=$(cat /proc/cpuinfo)
                if echo "$CPUINFO" | grep -qi "vmware"; then
                    VIRT_TYPE="VMware"
                elif echo "$CPUINFO" | grep -qi "qemu"; then
                    VIRT_TYPE="QEMU/KVM"
                elif echo "$CPUINFO" | grep -qi "xen"; then
                    VIRT_TYPE="Xen"
                elif [ -e /proc/xen ]; then
                    VIRT_TYPE="Xen"
                fi
            fi
            
            # Check for Docker/container
            if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
                VIRT_TYPE="Docker"
            elif grep -q lxc /proc/1/cgroup 2>/dev/null; then
                VIRT_TYPE="LXC"
            fi
        fi
        
        echo -e "Virtualization type: $VIRT_TYPE"
        
        # Additional virtualization info
        if [[ "$VIRT_TYPE" != "Unknown" && "$VIRT_TYPE" != "none" ]]; then
            echo -e "\n${YELLOW}VIRTUAL HARDWARE DETAILS:${NC}"
            echo -e "Processors: $(nproc)"
            echo -e "Memory: $(free -h | grep Mem | awk '{print $2}')"
            
            if [ "$VIRT_TYPE" == "VMware" ]; then
                echo -e "\n${YELLOW}VMWARE SPECIFIC INFO:${NC}"
                if command -v vmware-toolbox-cmd >/dev/null 2>&1; then
                    echo -e "VMware Tools version: $(vmware-toolbox-cmd -v)"
                    echo -e "VMware Disk Space: $(vmware-toolbox-cmd stat raw disk)"
                    echo -e "VMware Memory: $(vmware-toolbox-cmd stat raw mem)"
                else
                    echo -e "VMware Tools not installed or command not found"
                fi
            elif [[ "$VIRT_TYPE" == "QEMU" || "$VIRT_TYPE" == "KVM" || "$VIRT_TYPE" == "QEMU/KVM" ]]; then
                echo -e "\n${YELLOW}KVM/QEMU SPECIFIC INFO:${NC}"
                if command -v lspci >/dev/null 2>&1; then
                    echo -e "Virtual devices:"
                    lspci | grep -i "virtio"
                fi
            fi
        else
            echo -e "This appears to be a physical server."
        fi
    fi
    
    log_message "Completed collecting virtualization information"
}

# ======================================================================
# Oracle instance management
# ======================================================================

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
        INST=$(echo "$PMON_PROC" | awk '{print $NF}' | sed 's/ora_pmon_//g')
        
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
        RUNNING=$(ps -ef | grep pmon | grep -q $INSTANCE; echo $?)
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
        if [ "$INSTANCE" = "$CURRENT_SID" ]; then
            INSTANCE="${CYAN}$INSTANCE (current)${NC}"
        fi
        
        # Print formatted entry
        printf "| %-4d | %-18b | %-7b | %-10b | %-14b |\n" $INSTANCE_NUM "$INSTANCE" "$STATUS" "$TYPE_INFO" "$VERSION"
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
}

# ======================================================================
# Oracle alerts and logs checking
# ======================================================================

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

# ======================================================================
# Oracle parameter checking
# ======================================================================

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

    log_message "Completed checking non-default parameters"
}

# ======================================================================
# RAC diagnostics 
# ======================================================================

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
    ASM_RUNNING=$(ps -ef | grep asm_pmon | grep -v grep | wc -l)
    
    if [ $ASM_RUNNING -gt 0 ]; then
        # Connect to ASM to get disk group info
        ORACLE_SID_ORIG=$ORACLE_SID
        
        # Get ASM instance name
        ASM_SID=$(ps -ef | grep asm_pmon | grep -v grep | awk '{print $NF}' | sed 's/asm_pmon_//g')
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
    
    log_message "Completed checking cluster resources"
}

# ======================================================================
# PDB information collection
# ======================================================================

# Enhanced function to list PDBs with status details
list_pdbs() {
    display_header "PLUGGABLE DATABASES (PDBs)"
    log_message "Checking for PDBs"
    
    # Check Oracle version
    VERSION=$(sqlplus -s / as sysdba <<EOF
        set heading off pagesize 0 feedback off verify off
        select version from v\$instance;
        exit;
EOF
    )
    
    # Remove trailing spaces
    VERSION=$(echo $VERSION | tr -d ' ')
    
    echo -e "Oracle Database Version: $VERSION"
    
    # If Oracle 12c or higher, list PDBs with detailed status
    if [[ $VERSION == 12* || $VERSION == 18* || $VERSION == 19* || $VERSION == 21* ]]; then
        log_message "Oracle version supports PDBs: $VERSION"
        
        # Create SQL script for PDB info
        cat > $TEMP_DIR/pdb_info.sql << 'EOF'
set linesize 150
set pagesize 1000
set feedback off
set verify off
column con_id format 999
column name format a20
column open_mode format a12
column restricted format a10
column status format a10
column total_size format a12
column allocated_size format a15
column creation_time format a20

-- Basic PDB information
select con_id, name, open_mode, restricted, 
       status, to_char(creation_time, 'YYYY-MM-DD HH24:MI:SS') as creation_time
from v$pdbs
order by con_id;

-- PDB space usage
select con_id, name, 
       round(total_size/1024/1024/1024,2)||' GB' as total_size,
       round(allocated_size/1024/1024/1024,2)||' GB' as allocated_size
from (
    select con_id, 
           name,
           sum(bytes) over (partition by con_id) total_size,
           sum(decode(autoextensible,'YES',maxbytes,'NO',bytes)) over (partition by con_id) allocated_size
    from cdb_data_files
    where con_id > 2
)
group by con_id, name, total_size, allocated_size
order by con_id;

-- PDB Services
select con_id, pdb, name, network_name 
from cdb_services
where con_id > 2
order by con_id, name;
EOF

        # Run SQL script
        sqlplus -s / as sysdba @$TEMP_DIR/pdb_info.sql
        
        # If that fails, try simpler query
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error executing detailed PDB query${NC}"
            echo -e "Trying simplified query..."
            log_message "Error with detailed PDB query, using simplified query"
            
            sqlplus -s / as sysdba <<EOF
                set linesize 150
                set pagesize 100
                col name format a30
                col open_mode format a15
                col restricted format a10
                col status format a15
                select con_id, name, open_mode, restricted, status 
                from v\$pdbs
                order by con_id;
                exit;
EOF
        fi
    else
        echo -e "${YELLOW}This Oracle instance does not support PDBs (version $VERSION)${NC}"
        echo -e "PDBs are available in Oracle 12c and later versions"
        log_message "Oracle version does not support PDBs: $VERSION"
    fi
}

# ======================================================================
# Oracle session and lock checking
# ======================================================================

# Function to check for Oracle locks and sessions
check_sessions_and_locks() {
    display_header "ORACLE SESSIONS AND LOCKS"
    log_message "Checking Oracle sessions and locks"
    
    # Get active session count
    echo -e "${YELLOW}ACTIVE SESSIONS:${NC}"
    sqlplus -s / as sysdba <<EOF
        set linesize 150
        set pagesize 100
        
        select status, count(*) 
        from v\$session
        group by status;
        
        select username, count(*) 
        from v\$session
        where username is not null
        group by username
        order by count(*) desc;
        exit;
EOF

    # Check for blocking sessions
    echo -e "\n${YELLOW}BLOCKING SESSIONS:${NC}"
    log_message "Checking for blocking sessions"
    sqlplus -s / as sysdba <<EOF
        set linesize 200
        set pagesize 1000
        col blocker_sid format 9999
        col blocked_sid format 9999
        col blocker_user format a15
        col blocked_user format a15
        col blocker_status format a10
        col wait_event format a30
        col blocked_sql format a60
        
        select 
            s1.sid blocker_sid,
            s1.username blocker_user,
            s1.status blocker_status,
            s2.sid blocked_sid,
            s2.username blocked_user,
            s2.event wait_event,
            substr(q.sql_text,1,60) blocked_sql
        from 
            v\$lock l1, 
            v\$session s1, 
            v\$lock l2, 
            v\$session s2,
            v\$sql q
        where 
            s1.sid = l1.sid and
            s2.sid = l2.sid and
            l1.block = 1 and
            l2.request > 0 and
            l1.id1 = l2.id1 and
            l1.id2 = l2.id2 and
            s2.sql_id = q.sql_id(+);
        exit;
EOF

    # Check for long running queries
    echo -e "\n${YELLOW}LONG RUNNING QUERIES (OVER 10 MINUTES):${NC}"
    log_message "Checking for long running queries"
    sqlplus -s / as sysdba <<EOF
        set linesize 200
        set pagesize 100
        col username format a15
        col sid format 9999
        col serial# format 99999
        col machine format a20
        col elapsed_time format a15
        col sql_text format a70
        
        select 
            s.username,
            s.sid,
            s.serial#,
            s.machine,
            to_char(floor(s.last_call_et/3600), '09') || ':' || 
            to_char(floor(mod(s.last_call_et,3600)/60), '09') || ':' ||
            to_char(mod(s.last_call_et,60), '09') as elapsed_time,
            substr(q.sql_text,1,70) as sql_text
        from 
            v\$session s,
            v\$sql q
        where 
            s.sql_id = q.sql_id
            and s.status = 'ACTIVE'
            and s.username is not null
            and s.last_call_et > 600
        order by s.last_call_et desc;
        exit;
EOF

    log_message "Completed checking sessions and locks"
}

# ======================================================================
# Main functions
# ======================================================================

# Main function
main() {
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    # Initialize environment
    init_environment
    
    # Display menu of options
    display_header "DIAGNOSTIC OPTIONS"
    echo -e "1. Full system diagnostic (all checks)"
    echo -e "2. System metrics only (OS and hardware)"
    echo -e "3. Oracle instance diagnostics"
    echo -e "4. RAC/GI diagnostics"
    echo -e "5. Performance diagnostics"
    echo -e "6. Exit"
    echo -e "\nEnter your choice (1-6): "
    read CHOICE
    
    case $CHOICE in
        1)
            # Full diagnostics
            display_system_metrics
            display_virt_info
            check_listener_errors
            list_instances
            check_interconnect_latency
            display_alerts
            display_non_default_params
            check_cluster_resources
            list_pdbs
            check_sessions_and_locks
            ;;
        2)
            # System metrics only
            display_system_metrics
            display_virt_info
            ;;
        3)
            # Oracle instance diagnostics
            list_instances
            display_alerts
            display_non_default_params
            list_pdbs
            check_sessions_and_locks
            ;;
        4)
            # RAC/GI diagnostics
            list_instances
            check_interconnect_latency
            check_cluster_resources
            ;;
        5)
            # Performance diagnostics
            list_instances
            check_sessions_and_locks
            display_non_default_params
            check_interconnect_latency
            ;;
        6)
            # Exit
            echo -e "${GREEN}Exiting...${NC}"
            cleanup_and_exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice: $CHOICE${NC}"
            cleanup_and_exit 1
            ;;
    esac
    
    echo -e "${GREEN}Diagnostic check complete${NC}"
    cleanup_and_exit 0
}

# Run the main function
main
