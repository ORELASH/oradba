#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - System Metrics
# ======================================================================
# Version: 3.1
# Description: Functions for collecting system metrics for AIX/Linux
# Usage: Source this file or run standalone with ./ora_system.sh
# Dependencies: ora_common.sh
# ======================================================================

# Find script directory for proper module sourcing
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="."
fi

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
        
        # System model - AIX-safe grep
        echo -e "\n${YELLOW}SYSTEM MODEL:${NC}"
        prtconf | grep "System Model"
        
        # Number of CPUs and Memory - AIX-safe grep with individual commands
        echo -e "\n${YELLOW}CPU AND MEMORY:${NC}"
        prtconf | grep "Number Of Processors"
        prtconf | grep "Good Memory Size" | sed 's/Good //'
        
        # AIX Resource Metrics
        echo -e "\n${YELLOW}RESOURCE METRICS:${NC}"
        echo -e "$(date) - Resource utilization snapshot"
        vmstat 1 3
        
        # Disk usage with warning for filesystems over threshold
        echo -e "\n${YELLOW}DISK USAGE:${NC}"
        echo -e "Warning level set to $MOUNT_WARNING_THRESHOLD% usage"
        df -g | awk -v threshold=$MOUNT_WARNING_THRESHOLD 'NR==1 {print; next} {used=$4/$3*100; if (used > threshold) {printf "*** WARNING *** "}; print $0}'
        
        # Process info
        echo -e "\n${YELLOW}TOP CPU PROCESSES:${NC}"
        ps -eo user,pid,pcpu,pmem,vsz,args | sort -r -k 3 | head -$MAX_TOP_PROCESSES
        
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
        
        # Network errors - Avoid complex grep with multiple patterns
        echo -e "\n${YELLOW}NETWORK ERRORS:${NC}"
        for IFACE in $(ifconfig -a | grep '^en' | awk '{print $1}'); do
            echo -e "Interface $IFACE stats:"
            # Use multiple simple greps instead of complex patterns
            echo "Errors:"
            entstat -d $IFACE | grep -i "error"
            echo "Collisions:"
            entstat -d $IFACE | grep -i "collision"
            echo "Drops:"
            entstat -d $IFACE | grep -i "drop"
            echo "Misses:"
            entstat -d $IFACE | grep -i "miss"
            echo "CRC errors:"
            entstat -d $IFACE | grep -i "crc"
        done
        
        # Check AIX tuning parameters for Oracle
        check_aix_tuning
        
    else
        # Linux-specific metrics (no changes needed)
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
        check_linux_tuning
    fi
    
    log_message "Completed collecting system metrics"
}

# Function to check AIX specific Oracle tuning parameters
check_aix_tuning() {
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
    # Use a safer approach for AIX JFS parameters
    mount | grep jfs > /tmp/jfs_mounts.tmp
    mount | grep jfs2 >> /tmp/jfs_mounts.tmp
    
    cat /tmp/jfs_mounts.tmp | awk '{print $1, $3}' | while read FS TYPE; do
        echo -e "Filesystem: $FS - Type: $TYPE"
        if [ "$TYPE" = "jfs2" ]; then
            # Use individual greps instead of compound pattern
            mount | grep $FS | grep cio
            mount | grep $FS | grep dio
            mount | grep $FS | grep agblksize
        fi
    done
    rm -f /tmp/jfs_mounts.tmp
    
    echo -e "\n${YELLOW}ASYNCHRONOUS I/O:${NC}"
    lsdev -C | grep aio
    lsattr -El aio0
}

# Function to check Linux specific Oracle tuning parameters (unchanged)
check_linux_tuning() {
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
    
    echo -e "\n${YELLOW}DISK SCHEDULER SETTINGS:${NC}"
    for disk in /sys/block/sd*/queue/scheduler; do
        if [ -f "$disk" ]; then
            echo -e "$(basename $(dirname $(dirname $disk))): $(cat $disk)"
        fi
    done
}

# Check if this script is sourced or run directly
# More reliable method for standalone detection
is_module_standalone() {
    # If the BASH_SOURCE and $0 are the same, then this script is being run directly
    [[ "${BASH_SOURCE[0]}" == "${0}" ]]
}

# Check if this module is being run directly (standalone)
if is_module_standalone; then
    # If run directly, perform system metrics check
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool - System Metrics${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    # Detect OS type if not already set
    if [ -z "$OS_TYPE" ]; then
        OS_TYPE=$(uname -s)
        if [ "$OS_TYPE" = "AIX" ]; then
            IS_AIX=1
        else
            IS_AIX=0
        fi
    fi
    
    # Set default values if not defined in ora_common.sh
    if [ -z "$MOUNT_WARNING_THRESHOLD" ]; then
        MOUNT_WARNING_THRESHOLD=80
    fi
    
    if [ -z "$MAX_TOP_PROCESSES" ]; then
        MAX_TOP_PROCESSES=10
    fi
    
    if [ -z "$IO_SAMPLES" ]; then
        IO_SAMPLES=3
    fi
    
    # Define colors if not already defined
    if [ -z "$GREEN" ]; then
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        NC='\033[0m' # No Color
    fi
    
    display_system_metrics
fi
