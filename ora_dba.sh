#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Main Script
# ======================================================================
# Version: 3.0
# Author: DBA Team
# Description: Main script for Oracle database diagnostics on AIX/Linux
# Usage: Run as oracle user: ./ora_dba.sh
# ======================================================================

# Get the actual script directory regardless of where it's called from
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")

# Load the common functions
source "$SCRIPT_DIR/ora_common.sh" || {
    echo "Error: Unable to load common functions from $SCRIPT_DIR/ora_common.sh"
    echo "Make sure you run this script from its directory or a proper symlink"
    exit 1
}

# Initialize the environment
init_environment

# Display banner
clear
echo -e "${GREEN}Oracle DBA Diagnostic Tool${NC}"
echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
echo -e "${YELLOW}Date: $(date)${NC}"
echo ""

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
        source "$SCRIPT_DIR/ora_system.sh"
        source "$SCRIPT_DIR/ora_virt.sh"
        source "$SCRIPT_DIR/ora_alerts.sh"
        source "$SCRIPT_DIR/ora_instance.sh"
        source "$SCRIPT_DIR/ora_rac.sh"
        source "$SCRIPT_DIR/ora_params.sh"
        source "$SCRIPT_DIR/ora_pdb.sh"
        source "$SCRIPT_DIR/ora_sessions.sh"
        
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
        source "$SCRIPT_DIR/ora_system.sh"
        source "$SCRIPT_DIR/ora_virt.sh"
        
        display_system_metrics
        display_virt_info
        ;;
    3)
        # Oracle instance diagnostics
        source "$SCRIPT_DIR/ora_instance.sh"
        source "$SCRIPT_DIR/ora_alerts.sh"
        source "$SCRIPT_DIR/ora_params.sh"
        source "$SCRIPT_DIR/ora_pdb.sh"
        source "$SCRIPT_DIR/ora_sessions.sh"
        
        list_instances
        display_alerts
        display_non_default_params
        list_pdbs
        check_sessions_and_locks
        ;;
    4)
        # RAC/GI diagnostics
        source "$SCRIPT_DIR/ora_instance.sh"
        source "$SCRIPT_DIR/ora_rac.sh"
        
        list_instances
        check_interconnect_latency
        check_cluster_resources
        ;;
    5)
        # Performance diagnostics
        source "$SCRIPT_DIR/ora_instance.sh"
        source "$SCRIPT_DIR/ora_sessions.sh"
        source "$SCRIPT_DIR/ora_params.sh"
        source "$SCRIPT_DIR/ora_rac.sh"
        
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
