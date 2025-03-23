#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Virtualization Information
# ======================================================================
# Version: 3.0
# Description: Functions for collecting virtualization info for AIX/Linux
# Usage: Source this file or run standalone with ./ora_virt.sh
# Dependencies: ora_common.sh
# ======================================================================

# Find script directory for proper module sourcing
SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")

# Check if common functions are already loaded
if [ -z "$TEMP_DIR" ] || [ -z "$LOG_FILE" ]; then
    # Try to locate and source the common.sh file
    if [ -f "$SCRIPT_DIR/ora_common.sh" ]; then
        source "$SCRIPT_DIR/ora_common.sh"
    else
        echo "Error: Cannot find ora_common.sh. This script requires the common functions."
        exit 1
    fi
fi

# Function to display virtualization information
display_virt_info() {
    display_header "VIRTUALIZATION INFORMATION"
    log_message "Collecting virtualization information"
    
    if [ $IS_AIX -eq 1 ]; then
        display_aix_virt_info
    else
        display_linux_virt_info
    fi
    
    log_message "Completed collecting virtualization information"
}

# Function to display AIX specific virtualization information
display_aix_virt_info() {
    # Try to determine if system is using VIOS
    HMC_MANAGED=0
    VIOS_SERVER=0
    
    # Check for VIOS server
    if [ -x /usr/bin/lsmap ]; then
        VIOS_SERVER=1
    fi
    
    # Check for HMC managed LPAR
    HMC_INFO=$(lsrsrc IBM.MCP 2>/dev/null)
    if [ $? -eq 0 ]; then
        HMC_MANAGED=1
    fi
    
    if [ $VIOS_SERVER -eq 1 ]; then
        echo -e "${GREEN}This system appears to be a VIOS server${NC}"
        log_message "System detected as VIOS server"
        
        echo -e "\n${YELLOW}VIOS VERSION:${NC}"
        ioslevel 2>/dev/null
        
        echo -e "\n${YELLOW}VIOS BUILD LEVEL:${NC}"
        if [ -f /usr/ios/cli/ioscli.level ]; then
            cat /usr/ios/cli/ioscli.level 2>/dev/null
        fi
        
        echo -e "\n${YELLOW}VIRTUAL SCSI MAPPINGS:${NC}"
        lsmap -all 2>/dev/null | grep -v "NO MAPPING"
        
        echo -e "\n${YELLOW}VIRTUAL ETHERNET MAPPINGS:${NC}"
        lsmap -all -net 2>/dev/null | grep -v "NO MAPPING"
        
        echo -e "\n${YELLOW}SHARED STORAGE POOLS:${NC}"
        if [ -x /usr/bin/lssp ]; then
            /usr/bin/lssp -status 2>/dev/null
        else
            echo -e "Shared Storage Pools feature not installed"
        fi
        
        echo -e "\n${YELLOW}NPIV MAPPINGS:${NC}"
        lsmap -npiv -all 2>/dev/null | grep -v "NO MAPPING"
        
        echo -e "\n${YELLOW}SEA CONFIGURATION:${NC}"
        lsdev -virtual | grep ent
        
    elif [ $HMC_MANAGED -eq 1 ]; then
        echo -e "${GREEN}This system appears to be managed by an HMC${NC}"
        log_message "System detected as HMC-managed LPAR"
        
        echo -e "\n${YELLOW}LPAR INFORMATION:${NC}"
        lparstat -i 2>/dev/null
        
        echo -e "\n${YELLOW}VIRTUAL DEVICES:${NC}"
        lsdev -virtual 2>/dev/null
        
        echo -e "\n${YELLOW}VIRTUAL ADAPTERS:${NC}"
        for VDEV in $(lsdev -virtual 2>/dev/null | grep -E 'ent|vscsi' | awk '{print $1}'); do
            echo -e "Device: $VDEV"
            lsattr -El $VDEV 2>/dev/null | grep -E 'backing|remote'
        done
        
        echo -e "\n${YELLOW}VIOS CLIENT RESOURCE ALLOCATION:${NC}"
        lparstat 1 1 2>/dev/null
    else
        echo -e "${YELLOW}This appears to be a standalone AIX system (non-VIOS, non-LPAR)${NC}"
        log_message "System detected as standalone AIX (non-VIOS)"
        echo -e "For more hardware information, run 'lscfg -v'"
    fi
}

# Function to display Linux specific virtualization information
display_linux_virt_info() {
    echo -e "${YELLOW}CHECKING FOR VIRTUALIZATION:${NC}"
    VIRT_TYPE="Unknown"
    
    # Use systemd-detect-virt if available
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "Unknown")
    fi
    
    # If unknown or none, try alternative detection methods
    if [[ "$VIRT_TYPE" == "Unknown" || "$VIRT_TYPE" == "none" ]]; then
        # Try /proc/cpuinfo
        if [ -f /proc/cpuinfo ]; then
            CPUINFO=$(cat /proc/cpuinfo)
            if echo "$CPUINFO" | grep -qi "vmware"; then
                VIRT_TYPE="VMware"
            elif echo "$CPUINFO" | grep -qi "qemu"; then
                VIRT_TYPE="QEMU/KVM"
            elif echo "$CPUINFO" | grep -qi "xen"; then
                VIRT_TYPE="Xen"
            elif [ -e /proc/xen ]; then
                VIRT_TYPE="Xen"
            fi
        fi
        
        # Check for Docker/container
        if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
            VIRT_TYPE="Docker"
        elif grep -q lxc /proc/1/cgroup 2>/dev/null; then
            VIRT_TYPE="LXC"
        fi
        
        # Check dmesg for virtualization hints
        DMESG_OUT=$(dmesg 2>/dev/null | grep -i "virtual\|hypervisor\|vmware\|kvm\|xen")
        if [ -n "$DMESG_OUT" ] && [ "$VIRT_TYPE" == "Unknown" ]; then
            if echo "$DMESG_OUT" | grep -qi "vmware"; then
                VIRT_TYPE="VMware"
            elif echo "$DMESG_OUT" | grep -qi "kvm"; then
                VIRT_TYPE="KVM"
            elif echo "$DMESG_OUT" | grep -qi "xen"; then
                VIRT_TYPE="Xen"
            elif echo "$DMESG_OUT" | grep -qi "hypervisor"; then
                VIRT_TYPE="Hypervisor-detected"
            fi
        fi
    fi
    
    echo -e "Virtualization type: $VIRT_TYPE"
    
    # Additional virtualization info
    if [[ "$VIRT_TYPE" != "Unknown" && "$VIRT_TYPE" != "none" ]]; then
        echo -e "\n${YELLOW}VIRTUAL HARDWARE DETAILS:${NC}"
        echo -e "Processors: $(nproc)"
        echo -e "Memory: $(free -h | grep Mem | awk '{print $2}')"
        
        if [ "$VIRT_TYPE" == "VMware" ]; then
            echo -e "\n${YELLOW}VMWARE SPECIFIC INFO:${NC}"
            if command -v vmware-toolbox-cmd >/dev/null 2>&1; then
                echo -e "VMware Tools version: $(vmware-toolbox-cmd -v)"
                echo -e "VMware Disk Space: $(vmware-toolbox-cmd stat raw disk)"
                echo -e "VMware Memory: $(vmware-toolbox-cmd stat raw mem)"
            else
                echo -e "VMware Tools not installed or command not found"
            fi
        elif [[ "$VIRT_TYPE" == "QEMU" || "$VIRT_TYPE" == "KVM" || "$VIRT_TYPE" == "QEMU/KVM" ]]; then
            echo -e "\n${YELLOW}KVM/QEMU SPECIFIC INFO:${NC}"
            if command -v lspci >/dev/null 2>&1; then
                echo -e "Virtual devices:"
                lspci | grep -i "virtio"
            fi
        elif [ "$VIRT_TYPE" == "Xen" ]; then
            echo -e "\n${YELLOW}XEN SPECIFIC INFO:${NC}"
            if [ -d /sys/hypervisor/uuid ]; then
                echo -e "Xen UUID: $(cat /sys/hypervisor/uuid 2>/dev/null)"
            fi
            if command -v xentop >/dev/null 2>&1; then
                echo -e "Xen detected with xentop available"
            fi
        elif [[ "$VIRT_TYPE" == "Docker" || "$VIRT_TYPE" == "LXC" ]]; then
            echo -e "\n${YELLOW}CONTAINER SPECIFIC INFO:${NC}"
            echo -e "Container cgroup info:"
            grep -v "^#" /proc/1/cgroup 2>/dev/null | head -5
        fi
    else
        echo -e "This appears to be a physical server."
    fi
    
    # Check for OVM/OCI specific features
    if [ -d /sys/firmware/ovm-info ]; then
        echo -e "\n${YELLOW}ORACLE VM/OCI SPECIFIC INFO:${NC}"
        if [ -f /sys/firmware/ovm-info/instance_id ]; then
            echo -e "OCI Instance ID: $(cat /sys/firmware/ovm-info/instance_id 2>/dev/null)"
        fi
    fi
}

# Check if this module is being run directly (standalone)
if is_module_standalone; then
    # If run directly, perform virtualization check
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool - Virtualization Information${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    display_virt_info
fi
