#!/bin/bash
# AIX System Monitor Script
# This script displays disk usage, CPU and memory information on login
# Configuration
DISK_THRESHOLD=10  # Alert threshold percentage for disk space

# Function to check disk space and display alert
check_disk_space() {
    # On AIX, use df command with appropriate options
    # -k shows sizes in KB
    # -P uses POSIX format for better parsing
    CRITICAL_FS=$(df -kP | grep -v Filesystem | awk -v threshold="$DISK_THRESHOLD" '{ gsub(/%/,"",$5); if (100-$5 < threshold) print $0 }')
    
    echo "+------------------------------------------------------------+"
    echo "|                     DISK SPACE STATUS                      |"
    echo "+------------------------------------------------------------+"
    
    if [ -n "$CRITICAL_FS" ]; then
        echo "|                                                            |"
        echo "| The following filesystems have less than ${DISK_THRESHOLD}% free space:   |"
        echo "|                                                            |"
        
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
        
    else
        echo "|                                                            |"
        echo "| All filesystems have more than ${DISK_THRESHOLD}% free space.           |"
        echo "| Disk status: OK                                            |"
    fi
    
    echo "|                                                            |"
    echo "+------------------------------------------------------------+"
}

# Function to check CPU usage
check_cpu_usage() {
    echo "+------------------------------------------------------------+"
    echo "|                       CPU USAGE                            |"
    echo "+------------------------------------------------------------+"
    echo "|                                                            |"
    
    # Use 'lparstat' to get CPU usage information on AIX
    CPU_INFO=$(lparstat 1 1 | tail -1)
    USER_CPU=$(echo $CPU_INFO | awk '{print $3}')
    SYS_CPU=$(echo $CPU_INFO | awk '{print $4}')
    IDLE_CPU=$(echo $CPU_INFO | awk '{print $6}')
    PHYS_CPU=$(lsdev -Cc processor | wc -l)
    
    # Calculate total CPU usage
    TOTAL_CPU=$(echo "scale=1; 100 - $IDLE_CPU" | bc)
    
    printf "| CPU Usage: %5.1f%% (User: %5.1f%%, System: %5.1f%%)        |\n" $TOTAL_CPU $USER_CPU $SYS_CPU
    printf "| Physical CPUs: %-3d                                      |\n" $PHYS_CPU
    
    # Add warning if CPU usage is high (above 80%)
    if (( $(echo "$TOTAL_CPU > 80" | bc -l) )); then
        echo "| WARNING: High CPU usage detected!                          |"
    fi
    
    echo "|                                                            |"
    echo "+------------------------------------------------------------+"
}

# Function to check memory usage
check_memory_usage() {
    echo "+------------------------------------------------------------+"
    echo "|                     MEMORY USAGE                           |"
    echo "+------------------------------------------------------------+"
    echo "|                                                            |"
    
    # Use 'svmon' to get memory information on AIX
    MEM_INFO=$(svmon -G)
    
    # Extract memory values (in 4K pages)
    TOTAL_MEM=$(echo "$MEM_INFO" | grep "memory" | awk '{print $2}')
    USED_MEM=$(echo "$MEM_INFO" | grep "in use" | awk '{print $3}')
    
    # Convert to MB
    TOTAL_MEM_MB=$(echo "scale=1; $TOTAL_MEM * 4 / 1024" | bc)
    USED_MEM_MB=$(echo "scale=1; $USED_MEM * 4 / 1024" | bc)
    
    # Calculate free memory and percentages
    FREE_MEM_MB=$(echo "scale=1; $TOTAL_MEM_MB - $USED_MEM_MB" | bc)
    MEM_USED_PERC=$(echo "scale=1; $USED_MEM_MB * 100 / $TOTAL_MEM_MB" | bc)
    
    # Convert to GB if greater than 1024MB
    if (( $(echo "$TOTAL_MEM_MB > 1024" | bc -l) )); then
        TOTAL_MEM_GB=$(echo "scale=2; $TOTAL_MEM_MB / 1024" | bc)
        USED_MEM_GB=$(echo "scale=2; $USED_MEM_MB / 1024" | bc)
        FREE_MEM_GB=$(echo "scale=2; $FREE_MEM_MB / 1024" | bc)
        printf "| Memory: %5.2f GB total, %5.2f GB used (%4.1f%%)           |\n" $TOTAL_MEM_GB $USED_MEM_GB $MEM_USED_PERC
        printf "| Free memory: %5.2f GB                                    |\n" $FREE_MEM_GB
    else
        printf "| Memory: %5.1f MB total, %5.1f MB used (%4.1f%%)           |\n" $TOTAL_MEM_MB $USED_MEM_MB $MEM_USED_PERC
        printf "| Free memory: %5.1f MB                                    |\n" $FREE_MEM_MB
    fi
    
    # Add warning if memory usage is high (above 90%)
    if (( $(echo "$MEM_USED_PERC > 90" | bc -l) )); then
        echo "| WARNING: High memory usage detected!                       |"
    fi
    
    echo "|                                                            |"
    echo "+------------------------------------------------------------+"
}

# Print script execution time
echo ""
echo "System check performed at: $(date)"
echo ""

# Execute check functions
check_disk_space
check_cpu_usage
check_memory_usage

exit 0
