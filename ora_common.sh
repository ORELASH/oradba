#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Common Functions
# ======================================================================
# Version: 3.0
# Description: Common variables and functions used by all modules
# Usage: Source this file in other scripts
# Dependencies: None
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

# Find script directory - important for portability
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")
fi

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
        POSSIBLE_ORACLE_HOME=$(dirname $(dirname $(ps -ef | grep "[p]mon" | head -1 | awk '{print $NF}' | sed 's/ora_pmon_//g')))
        if [ -n "$POSSIBLE_ORACLE_HOME" ]; then
            export ORACLE_HOME=$POSSIBLE_ORACLE_HOME
            echo -e "${YELLOW}ORACLE_HOME not set, using detected value: $ORACLE_HOME${NC}"
        else
            echo -e "${RED}ORACLE_HOME not set and could not be detected${NC}"
        fi
    fi
    
    # Log script start
    log_message "Oracle DBA Diagnostic Tool started at $(date) on $OS_TYPE"
    log_message "Script directory: $SCRIPT_DIR"
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

# Function to check if a module is standalone
# If the script is being run directly, set up the environment
# This allows modules to be run independently
is_module_standalone() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        # This script is being run directly
        # Create a basic environment for standalone operation
        SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
        
        # Check if common.sh is available and load it
        if [ "${BASH_SOURCE[0]}" != "ora_common.sh" ] && [ "${BASH_SOURCE[0]}" != "./ora_common.sh" ]; then
            if [ -f "$SCRIPT_DIR/ora_common.sh" ]; then
                source "$SCRIPT_DIR/ora_common.sh"
            else
                # If common.sh is not available, create a minimal environment
                TEMP_DIR="/tmp/ora_diag_$$"
                LOG_FILE="$TEMP_DIR/ora_diag.log"
                mkdir -p $TEMP_DIR 2>/dev/null
                
                # Set terminal colors
                RED='\033[0;31m'
                GREEN='\033[0;32m'
                YELLOW='\033[0;33m'
                BLUE='\033[0;34m'
                PURPLE='\033[0;35m'
                CYAN='\033[0;36m'
                NC='\033[0m' # No Color
                
                # Detect OS type
                OS_TYPE=$(uname -s)
                if [ "$OS_TYPE" = "AIX" ]; then
                    IS_AIX=1
                    IS_LINUX=0
                else
                    IS_AIX=0
                    IS_LINUX=1
                fi
                
                # Minimal log_message function
                log_message() {
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
                }
                
                # Minimal display_header function
                display_header() {
                    echo -e "\n${BLUE}=========================================================${NC}"
                    echo -e "${BLUE}$1${NC}"
                    echo -e "${BLUE}=========================================================${NC}"
                }
            fi
        fi
        
        # Initialize environment if the function exists and this isn't common.sh itself
        if [ "$(type -t init_environment)" = "function" ] && [ "${BASH_SOURCE[0]}" != "ora_common.sh" ] && [ "${BASH_SOURCE[0]}" != "./ora_common.sh" ]; then
            init_environment
        fi
        
        return 0  # True, this is standalone
    fi
    
    return 1  # False, not standalone
}

# If this script is run directly, display usage information
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "${YELLOW}This is a module containing common functions and should not be run directly.${NC}"
    echo -e "${YELLOW}Please run the main script ora_dba.sh instead.${NC}"
    exit 1
fi
