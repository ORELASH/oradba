#!/bin/ksh

# Define colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== AIX System Resources Summary =====${NC}"

# CPU count
CPU_COUNT=$(lsdev -Cc processor | wc -l)
echo -e "\n${GREEN}CPU Information:${NC}"
echo "  Number of CPUs: $CPU_COUNT"

# CPU utilization
echo -e "\n${GREEN}CPU Utilization:${NC}"
vmstat 1 2 | tail -1 | awk '{
    printf "  User CPU: %s%%\n", $13;
    printf "  System CPU: %s%%\n", $14;
    printf "  Idle CPU: %s%%\n", $15;
    printf "  Wait I/O: %s%%\n", $16;
    printf "  Total CPU utilization: %s%%\n", (100-$15);
}'

# Memory information
echo -e "\n${GREEN}Memory Information:${NC}"
# Get total memory from bootinfo
TOTAL_MEM=$(bootinfo -r)
echo "  Total physical memory: $TOTAL_MEM MB"

# Get memory usage from svmon
svmon -G | head -3 | awk '{
    if(NR==1) {
        printf "  Memory metrics (in 4K pages):\n";
    }
    else if(NR==2) {
        # Column headers, skip
    }
    else if(NR==3) {
        printf "  Total memory pages: %s\n", $1;
        printf "  Used memory pages: %s\n", $2;
        printf "  Free memory pages: %s\n", $3;
        printf "  Memory utilization: %.1f%%\n", ($2/$1)*100;
    }
}'

echo -e "\n${BLUE}======== End of Summary ========${NC}"
