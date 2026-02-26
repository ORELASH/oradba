#!/usr/bin/ksh
# AIX System Monitor Script
# This script displays disk usage, CPU and memory information on login
# Configuration
# Default disk threshold is 10% (can be overridden by first argument)
if [ $# -ge 1 ] && [[ $1 =~ ^[0-9]+$ ]]; then
    DISK_THRESHOLD=$1
else
    DISK_THRESHOLD=10
fi

# Function to get disk space status
get_disk_space() {
    # On AIX, use df command with appropriate options
    CRITICAL_FS=$(df -kP | grep -v Filesystem | awk -v threshold="$DISK_THRESHOLD" '{ gsub(/%/,"",$5); if (100-$5 < threshold) print $0 }')
    
    DISK_STATUS=""
    
    if [ -n "$CRITICAL_FS" ]; then
        # Count critical filesystems
        FS_COUNT=$(echo "$CRITICAL_FS" | wc -l)
        DISK_STATUS="$FS_COUNT filesystems < ${DISK_THRESHOLD}% free"
    else
        DISK_STATUS="All OK (>${DISK_THRESHOLD}% free)"
    fi
    
    echo "$DISK_STATUS"
}

# Function to get CPU usage
get_cpu_usage() {
    # Use 'lparstat' to get CPU usage information on AIX
    CPU_INFO=$(lparstat 1 1 | tail -1)
    USER_CPU=$(echo $CPU_INFO | awk '{print $3}')
    SYS_CPU=$(echo $CPU_INFO | awk '{print $4}')
    IDLE_CPU=$(echo $CPU_INFO | awk '{print $6}')
    
    # Calculate total CPU usage - ensure we handle negative values
    # This can happen due to rounding errors in lparstat output
    TOTAL_CPU=$(echo "scale=1; 100 - $IDLE_CPU" | bc)
    # If result is negative (due to rounding errors), set to 0
    if (( $(echo "$TOTAL_CPU < 0" | bc -l) )); then
        TOTAL_CPU="0.0"
    fi
    
    echo "$TOTAL_CPU% used"
}

# Function to get memory usage
get_memory_usage() {
    # Use 'svmon' to get memory information on AIX
    MEM_INFO=$(svmon -G)
    
    # Extract memory values (in 4K pages)
    TOTAL_MEM=$(echo "$MEM_INFO" | grep "memory" | awk '{print $2}')
    USED_MEM=$(echo "$MEM_INFO" | grep "in use" | awk '{print $3}')
    
    # Calculate percentage
    MEM_USED_PERC=$(echo "scale=1; $USED_MEM * 100 / $TOTAL_MEM" | bc)
    
    echo "$MEM_USED_PERC% used"
}

# Get system status
DISK_STATUS=$(get_disk_space)
CPU_STATUS=$(get_cpu_usage)
MEM_STATUS=$(get_memory_usage)
CHECK_TIME=$(date +"%H:%M:%S %d/%m/%Y")

# Display all information in one row with boxes
echo "+--------------------------------------------------------------+"
echo "|                AIX SYSTEM STATUS MONITOR                 |"
echo "+--------------------------------------------------------------+"
printf "| Check Time: %-43s |\n" "$CHECK_TIME"
echo "+----------------------+----------------------+----------------------+"
echo "| DISK SPACE           | CPU USAGE             | MEMORY USAGE          |"
echo "+----------------------+----------------------+----------------------+"
printf "| %-20s | %-20s | %-20s |\n" "$DISK_STATUS" "$CPU_STATUS" "$MEM_STATUS"
echo "+----------------------+----------------------+----------------------+"

# Add detailed information for critical filesystems if any
CRITICAL_FS=$(df -kP | grep -v Filesystem | awk -v threshold="$DISK_THRESHOLD" '{ gsub(/%/,"",$5); if (100-$5 < threshold) print $0 }')
if [ -n "$CRITICAL_FS" ]; then
    echo "|                    CRITICAL FILESYSTEMS                    |"
    echo "+------------------------------------------------------------+"
    
    # Parse each critical filesystem and display
    IFS=$'\n'
    for line in $CRITICAL_FS; do
        fs_name=$(echo "$line" | awk '{print $1}')
        mount_point=$(echo "$line" | awk '{print $6}')
        size_kb=$(echo "$line" | awk '{print $2}')
        used_kb=$(echo "$line" | awk '{print $3}')
        free_perc=$(echo "$line" | awk '{print $5}')
        free_perc=${free_perc%\%*}  # Remove % sign
        
        # Calculate used percentage
        used_perc=$((100 - free_perc))
        
        # Convert KB to MB or GB for better readability
        size_mb=$(($size_kb / 1024))
        used_mb=$(($used_kb / 1024))
        
        if [ $size_mb -gt 1024 ]; then
            size_gb=$(echo "scale=1; $size_mb/1024" | bc)
            used_gb=$(echo "scale=1; $used_mb/1024" | bc)
            size_display="${size_gb}GB"
            used_display="${used_gb}GB"
        else
            size_display="${size_mb}MB"
            used_display="${used_mb}MB"
        fi
        
        # Truncate name if too long to prevent box from breaking
        if [ ${#fs_name} -gt 15 ]; then
            fs_name="${fs_name:0:12}..."
        fi
        
        if [ ${#mount_point} -gt 15 ]; then
            mount_point="${mount_point:0:12}..."
        fi
        
        # Format output line with fixed width
        printf "| %-15s %-15s %3d%% used (%s/%s) |\n" "$fs_name" "$mount_point" "$used_perc" "$used_display" "$size_display"
    done
    
    echo "+--------------------------------------------------+"
fi

exit 0
