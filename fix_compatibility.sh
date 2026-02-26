#!/bin/bash
# ======================================================================
# AIX/Linux Compatibility Fixer for oradba Project
# ======================================================================

echo "==================================="
echo "Fixing compatibility issues..."
echo "==================================="

# Function to replace readlink -f with portable version
fix_readlink() {
    file="$1"
    echo "Fixing readlink in: $(basename $file)"

    # Create backup
    cp "$file" "$file.bak"

    # Replace readlink -f with portable version
    sed -i 's/readlink -f "\$0"/pwd -P/g' "$file" 2>/dev/null || \
    sed -i '' 's/readlink -f "\$0"/pwd -P/g' "$file" 2>/dev/null

    # If the above doesn't work, use a more comprehensive replacement
    if grep -q 'SCRIPT_DIR=$(dirname "$(readlink -f' "$file"; then
        # Add portable function at the top
        temp_file=$(mktemp)
        cat > "$temp_file" << 'EOF'
#!/bin/bash

# Portable get_script_dir function for AIX/Linux compatibility
get_script_dir() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    echo "$DIR"
}

SCRIPT_DIR=$(get_script_dir)

EOF
        # Remove old SCRIPT_DIR line and prepend new function
        grep -v 'SCRIPT_DIR=$(dirname' "$file" | tail -n +2 >> "$temp_file"
        mv "$temp_file" "$file"
    fi

    chmod +x "$file"
}

# Fix all oracle scripts
for script in oracle/ora_*.sh oracle/oracle-security-scan.sh; do
    if [ -f "$script" ] && grep -q 'readlink -f' "$script"; then
        fix_readlink "$script"
    fi
done

# Add missing shebangs
echo ""
echo "Adding missing shebangs..."

for script in misc/aixVmstat.sh misc/diskmon.sh misc/newpy.sh; do
    if [ -f "$script" ]; then
        first_line=$(head -n 1 "$script")
        if [[ ! "$first_line" =~ ^#! ]]; then
            echo "Adding shebang to: $(basename $script)"
            temp_file=$(mktemp)
            echo '#!/bin/bash' > "$temp_file"
            cat "$script" >> "$temp_file"
            mv "$temp_file" "$script"
            chmod +x "$script"
        fi
    fi
done

echo ""
echo "==================================="
echo "Compatibility fixes applied!"
echo "==================================="
echo ""
echo "Run ./check_compatibility.sh to verify"
