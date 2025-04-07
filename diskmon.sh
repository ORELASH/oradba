#!/bin/bash
# AIX Disk Space Simple Alert Script
# This script only displays disk usage when free space falls below 10%

# Configuration
THRESHOLD=10  # Alert threshold percentage

# Function to check disk space and display alert
check_disk_space() {
    # On AIX, use df command with appropriate options
    # -k shows sizes in KB
    # -P uses POSIX format for better parsing
    CRITICAL_FS=$(df -kP | grep -v Filesystem | awk -v threshold="$THRESHOLD" '{ gsub(/%/,"",$5); if (100-$5 < threshold) print $0 }')
    
    if [ -n "$CRITICAL_FS" ]; then
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                     DISK SPACE ALERT                             ║"
        echo "╠══════════════════════════════════════════════════════════════════╣"
        echo "║                                                                  ║"
        echo "║  The following filesystems have less than ${THRESHOLD}% free space:     ║"
        echo "║                                                                  ║"
        
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
                size_gb=$(echo "scale=2; $size_mb/1024" | bc)
                used_gb=$(echo "scale=2; $used_mb/1024" | bc)
                size_display="${size_gb}GB"
                used_display="${used_gb}GB"
            else
                size_display="${size_mb}MB"
                used_display="${used_mb}MB"
            fi
            
            # Format output line with padding
            printf "║  %-20s %-25s %3d%% used (%s/%s)  ║\n" "$fs_name" "$mount_point" "$used_perc" "$used_display" "$size_display"
        done
        
        echo "║                                                                  ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
    fi
}

# Execute main function
check_disk_space
exit 0
