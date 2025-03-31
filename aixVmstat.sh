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

# Memory information using svmon only (no bootinfo -r which needs root)
echo -e "\n${GREEN}Memory Information:${NC}"

# Get memory usage from svmon
svmon -G | awk '
  BEGIN { found_header = 0; }
  {
    if($1 == "memory" && $2 == "page") {
      found_header = 1;
    }
    else if(found_header == 1) {
      # This is the first data line after header
      printf "  Total memory pages: %s\n", $1;
      printf "  Used memory pages: %s\n", $2;
      printf "  Free memory pages: %s\n", $3;
      
      # Calculate memory in MB (assuming 4K pages)
      total_mb = $1 * 4 / 1024;
      used_mb = $2 * 4 / 1024;
      free_mb = $3 * 4 / 1024;
      
      printf "  Total physical memory: %.0f MB\n", total_mb;
      printf "  Used memory: %.0f MB\n", used_mb;
      printf "  Free memory: %.0f MB\n", free_mb;
      printf "  Memory utilization: %.1f%%\n", ($2/$1)*100;
      
      # We're done with what we need
      exit;
    }
  }
'

echo -e "\n${BLUE}======== End of Summary ========${NC}"
