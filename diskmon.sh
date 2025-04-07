#!/bin/bash
# AIX Disk Space Alert Script
# This script monitors disk usage and alerts when free space falls below 10%

# Configuration
LOG_FILE="/var/log/disk_space_alerts.log"
THRESHOLD=10  # Alert threshold percentage
ADMIN_EMAIL="admin@example.com"  # Change to your admin email
SEND_EMAIL=false  # Set to true to enable email alerts

# Function to get current date and time in a readable format
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Function to log alerts
log_alert() {
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
    fi
    
    echo "$(get_timestamp) - $1" >> "$LOG_FILE"
}

# Function to send email alert
send_email_alert() {
    if [ "$SEND_EMAIL" = true ]; then
        echo "$1" | mail -s "Disk Space Alert on $(hostname)" "$ADMIN_EMAIL"
    fi
}

# Function to display alert
display_alert() {
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
        free_space=$(echo "$line" | awk '{print $5}')
        free_space=${free_space%\%*}  # Remove % sign
        
        # Calculate available space
        used_space=$((100 - free_space))
        
        # Format output line with padding
        printf "║  %-50s %3d%% used / %3d%% free  ║\n" "$fs_name" "$used_space" "$free_space"
    done
    
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
}

# Main function to check disk space
check_disk_space() {
    # On AIX, use df command with appropriate options
    # -k shows sizes in KB
    # -P uses POSIX format for better parsing
    CRITICAL_FS=$(df -kP | grep -v Filesystem | awk -v threshold="$THRESHOLD" '{ gsub(/%/,"",$5); if (100-$5 < threshold) print $0 }')
    
    if [ -n "$CRITICAL_FS" ]; then
        # Construct alert message
        ALERT_MSG="Low disk space alert on $(hostname):\n\n"
        
        IFS=$'\n'
        for line in $CRITICAL_FS; do
            fs_name=$(echo "$line" | awk '{print $1}')
            mount_point=$(echo "$line" | awk '{print $6}')
            capacity=$(echo "$line" | awk '{print $5}')
            free_space=$((100 - ${capacity%\%*}))
            
            alert_line="Filesystem: $fs_name (Mounted at: $mount_point) has only ${free_space}% free space"
            ALERT_MSG="${ALERT_MSG}${alert_line}\n"
            log_alert "$alert_line"
        done
        
        # Display alert
        display_alert
        
        # Send email if enabled
        send_email_alert "$ALERT_MSG"
        
        return 1  # Return error code to indicate critical status
    else
        return 0  # Return success code to indicate all is well
    fi
}

# Execute main function
check_disk_space
exit $?
