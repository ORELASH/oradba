#!/bin/bash

# Define colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Title
echo -e "${BLUE}===== System Resource Monitoring =====\n${NC}"

# Get CPU information
CPU_COUNT=$(nproc)
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^[ \t]*//')
echo -e "${GREEN}CPU Information:${NC}"
echo "Number of CPUs: $CPU_COUNT"
echo "CPU Model: $CPU_MODEL"
echo ""

# Run vmstat and process results
echo -e "${GREEN}Current System Data:${NC}"
vmstat 1 2 | tail -1 | awk '
{
    # Memory information (in KB)
    printf "Memory:\n"
    printf "  Free memory: %s KB\n", $4
    printf "  Cached memory: %s KB\n", $5
    printf "  Buffer memory: %s KB\n", $6
    
    # Swap information
    printf "\nSwap:\n"
    printf "  Swap in: %s KB/s\n", $7
    printf "  Swap out: %s KB/s\n", $8
    
    # I/O information
    printf "\nI/O Activity:\n"
    printf "  Blocks read: %s blocks/s\n", $9
    printf "  Blocks written: %s blocks/s\n", $10
    
    # System information
    printf "\nSystem Activity:\n"
    printf "  Interrupts: %s/s\n", $11
    printf "  Context switches: %s/s\n", $12
    
    # CPU information
    printf "\nCPU Usage:\n"
    printf "  User time: %s%%\n", $13
    printf "  System time: %s%%\n", $14
    printf "  Idle time: %s%%\n", $15
    printf "  I/O wait time: %s%%\n", $16
}'

# Add overall memory information from free
echo -e "\n${GREEN}Total Memory Summary:${NC}"
free -h | grep -v + | sed 's/:/: /' | sed 's/^/  /'

# Add CPU load information
echo -e "\n${GREEN}System Load:${NC}"
uptime | awk '{ 
    printf "  Uptime: %s %s %s\n", $3, $4, $5;
    printf "  Load Average (1, 5, 15 minutes): %s\n", substr($0, index($0, "load average:") + 14);
}'

echo -e "\n${BLUE}======== End of System Report ========${NC}"
