#!/bin/sh
# ======================================================================
# AIX/Linux Compatibility Checker for oradba Project
# ======================================================================
# This script checks all shell scripts for AIX/Linux compatibility issues
# and provides recommendations for fixes
# ======================================================================

# Color codes (POSIX compatible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
    if [ "$(uname -s)" = "AIX" ]; then
        echo "AIX"
    elif [ "$(uname -s)" = "Linux" ]; then
        echo "Linux"
    else
        echo "Unknown"
    fi
}

OS_TYPE=$(detect_os)

echo "${BLUE}========================================${NC}"
echo "${BLUE}AIX/Linux Compatibility Checker${NC}"
echo "${BLUE}Current OS: ${OS_TYPE}${NC}"
echo "${BLUE}========================================${NC}"
echo ""

# Counter for issues
ISSUES_FOUND=0
WARNINGS_FOUND=0
FILES_CHECKED=0

# Check for common incompatible commands
check_script() {
    script_file="$1"
    script_name=$(basename "$script_file")

    FILES_CHECKED=$((FILES_CHECKED + 1))

    echo "${YELLOW}Checking: ${script_name}${NC}"

    # Check shebang
    first_line=$(head -n 1 "$script_file")
    if echo "$first_line" | grep -q '#!/bin/bash'; then
        echo "  ${GREEN}✓${NC} Shebang: #!/bin/bash (Good for both AIX and Linux)"
    elif echo "$first_line" | grep -q '#!/bin/sh'; then
        echo "  ${GREEN}✓${NC} Shebang: #!/bin/sh (POSIX compatible)"
    elif echo "$first_line" | grep -q '#!/usr/bin/env bash'; then
        echo "  ${GREEN}✓${NC} Shebang: #!/usr/bin/env bash (Portable)"
    else
        echo "  ${RED}✗${NC} Missing or invalid shebang"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # Check for readlink -f (not available on AIX)
    if grep -q 'readlink -f' "$script_file"; then
        echo "  ${RED}✗${NC} Uses 'readlink -f' (not available on AIX)"
        echo "     Recommendation: Use alternative method"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # Check for GNU-specific stat
    if grep -q 'stat --format' "$script_file" || grep -q 'stat -c' "$script_file"; then
        echo "  ${RED}✗${NC} Uses GNU stat format (incompatible with AIX)"
        echo "     Recommendation: Use ls -l and awk instead"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # Check for bash arrays (not in POSIX sh)
    if grep -qE '\[[0-9]+\]=' "$script_file" || grep -qE 'declare -a' "$script_file"; then
        if echo "$first_line" | grep -q '#!/bin/sh$'; then
            echo "  ${YELLOW}⚠${NC} Uses bash arrays with /bin/sh shebang"
            echo "     Recommendation: Change shebang to #!/bin/bash"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
    fi

    # Check for [[  ]] (bash-specific)
    if grep -q '\[\[' "$script_file"; then
        if echo "$first_line" | grep -q '#!/bin/sh$'; then
            echo "  ${YELLOW}⚠${NC} Uses [[ ]] with /bin/sh shebang"
            echo "     Recommendation: Use [ ] or change to #!/bin/bash"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
    fi

    # Check for process substitution <(...)
    if grep -q '<(' "$script_file"; then
        if echo "$first_line" | grep -q '#!/bin/sh$'; then
            echo "  ${YELLOW}⚠${NC} Uses process substitution with /bin/sh"
            echo "     Recommendation: Change shebang to #!/bin/bash"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
    fi

    # Check for GNU grep -P (PCRE)
    if grep -q 'grep -P' "$script_file"; then
        echo "  ${RED}✗${NC} Uses 'grep -P' (not available on AIX)"
        echo "     Recommendation: Use basic regex or awk"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # Check for seq command (not always available)
    if grep -q ' seq ' "$script_file"; then
        echo "  ${YELLOW}⚠${NC} Uses 'seq' command (may not be available)"
        echo "     Recommendation: Use awk or while loop"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi

    # Check for specific ps flags
    if grep -qE 'ps aux|ps -ef' "$script_file"; then
        echo "  ${GREEN}✓${NC} Uses standard ps flags (compatible)"
    fi
    if grep -q 'ps --' "$script_file"; then
        echo "  ${RED}✗${NC} Uses GNU ps long options (not on AIX)"
        echo "     Recommendation: Use POSIX ps flags"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # Check for find -printf (GNU-specific)
    if grep -q 'find.*-printf' "$script_file"; then
        echo "  ${RED}✗${NC} Uses 'find -printf' (GNU-specific)"
        echo "     Recommendation: Use -exec or xargs with awk"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    # Check for date command differences
    if grep -qE 'date -d|date --date' "$script_file"; then
        echo "  ${RED}✗${NC} Uses GNU date format (incompatible with AIX)"
        echo "     Recommendation: Use portable date format"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi

    echo ""
}

# Find all shell scripts
echo "${BLUE}Scanning for shell scripts...${NC}"
echo ""

# Check oracle directory
if [ -d "oracle" ]; then
    for script in oracle/*.sh; do
        if [ -f "$script" ]; then
            check_script "$script"
        fi
    done
fi

# Check network directory
if [ -d "network" ]; then
    for script in network/*.sh; do
        if [ -f "$script" ]; then
            check_script "$script"
        fi
    done
fi

# Check misc directory
if [ -d "misc" ]; then
    for script in misc/*.sh; do
        if [ -f "$script" ]; then
            check_script "$script"
        fi
    done
fi

# Summary
echo "${BLUE}========================================${NC}"
echo "${BLUE}Summary${NC}"
echo "${BLUE}========================================${NC}"
echo "Files checked: ${FILES_CHECKED}"
echo "${RED}Issues found: ${ISSUES_FOUND}${NC}"
echo "${YELLOW}Warnings: ${WARNINGS_FOUND}${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
    echo "${GREEN}✓ All scripts are compatible with both AIX and Linux!${NC}"
elif [ $ISSUES_FOUND -eq 0 ]; then
    echo "${YELLOW}⚠ Some warnings found, but no critical issues${NC}"
else
    echo "${RED}✗ Issues found that need to be fixed for full compatibility${NC}"
fi

echo ""
echo "${BLUE}========================================${NC}"
echo "${BLUE}Platform-Specific Testing${NC}"
echo "${BLUE}========================================${NC}"
echo ""

# Test common commands
echo "Testing common commands on ${OS_TYPE}:"
echo ""

# Test bash availability
if command -v bash >/dev/null 2>&1; then
    bash_version=$(bash --version 2>&1 | head -n 1)
    echo "${GREEN}✓${NC} bash: ${bash_version}"
else
    echo "${RED}✗${NC} bash: Not found"
fi

# Test awk
if command -v awk >/dev/null 2>&1; then
    echo "${GREEN}✓${NC} awk: Available"
else
    echo "${RED}✗${NC} awk: Not found"
fi

# Test sed
if command -v sed >/dev/null 2>&1; then
    echo "${GREEN}✓${NC} sed: Available"
else
    echo "${RED}✗${NC} sed: Not found"
fi

# Test grep
if command -v grep >/dev/null 2>&1; then
    echo "${GREEN}✓${NC} grep: Available"
    # Check for -E flag
    if echo "test" | grep -E "test" >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} grep -E: Supported"
    else
        echo "  ${RED}✗${NC} grep -E: Not supported"
    fi
fi

# Test sqlplus (for Oracle scripts)
if command -v sqlplus >/dev/null 2>&1; then
    echo "${GREEN}✓${NC} sqlplus: Available"
else
    echo "${YELLOW}⚠${NC} sqlplus: Not found (required for Oracle DBA tools)"
fi

echo ""
echo "${BLUE}========================================${NC}"
echo "${BLUE}Recommendations${NC}"
echo "${BLUE}========================================${NC}"
echo ""

if [ "$OS_TYPE" = "AIX" ]; then
    echo "Running on AIX - Additional recommendations:"
    echo "  • Install GNU coreutils if needed (gstat, gdate, etc.)"
    echo "  • Use 'bash' instead of 'sh' for advanced features"
    echo "  • Test all scripts before production use"
elif [ "$OS_TYPE" = "Linux" ]; then
    echo "Running on Linux - Additional recommendations:"
    echo "  • Scripts should work out of the box"
    echo "  • Consider testing on AIX if targeting both platforms"
else
    echo "Unknown OS - Manual testing required"
fi

echo ""

exit 0
