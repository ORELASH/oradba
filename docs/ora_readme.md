# Oracle DBA Diagnostic Tool

## Overview
A comprehensive portable diagnostic tool for Oracle databases running on AIX or Linux environments. This tool helps DBAs quickly identify system issues and provides detailed information about database performance, configuration, and health.

## Features

### System Diagnostics
- OS metrics (CPU, memory, disk space)
- Virtualization detection and configuration
- OS tuning parameters for Oracle optimization
- Network interface statistics and errors

### Oracle Instance Diagnostics
- Instance discovery and selection with detailed information
- Non-default parameters with categorization
- Alert log analysis with error highlighting
- Listener error detection and analysis
- Pluggable Database (PDB) status and metrics (for Oracle 12c+)

### RAC Diagnostics
- Interconnect latency testing with threshold analysis
- Grid Infrastructure status and version
- Cluster resource status
- ASM disk group utilization

### Performance Diagnostics
- Session statistics and analysis
- Blocking session detection
- Long-running query identification

## Requirements
- AIX or Linux operating system
- Oracle Database installed
- BASH shell
- Must be run as the 'oracle' user

## Usage

### No Installation Required
Simply copy or extract all files to a single directory of your choice. All scripts are designed to work directly without installation.

### Running the Tool
1. Make all scripts executable if needed:
   ```
   $ chmod +x *.sh
   ```

2. Run the tool as the oracle user:
   ```
   $ ./ora_dba.sh
   ```

3. The tool provides a menu with the following options:
   - Full system diagnostic (all checks)
   - System metrics only (OS and hardware)
   - Oracle instance diagnostics
   - RAC/GI diagnostics
   - Performance diagnostics

### Files Structure
All files reside in a single directory:
```
├── ora_dba.sh               # Main script
├── ora_common.sh            # Common functions & variables 
├── ora_system.sh            # System metrics collection
├── ora_virt.sh              # Virtualization information
├── ora_instance.sh          # Oracle instance management
├── ora_alerts.sh            # Alert & listener error analysis
├── ora_params.sh            # Oracle parameter analysis
├── ora_rac.sh               # RAC-specific diagnostics
├── ora_pdb.sh               # PDB analysis
├── ora_sessions.sh          # Session & lock analysis
└── README.md                # Documentation
```

## Standalone Module Operation
Each module can be run independently for specific diagnostic purposes:
```
$ ./ora_system.sh
```

### Module Descriptions
- **ora_common.sh**: Common functions and variables used across modules
- **ora_system.sh**: OS-specific system metrics collection
- **ora_virt.sh**: Virtualization-specific information
- **ora_instance.sh**: Oracle instance listing and management
- **ora_alerts.sh**: Alert log and listener error analysis
- **ora_params.sh**: Oracle parameter analysis
- **ora_rac.sh**: RAC-specific diagnostics including interconnect latency
- **ora_pdb.sh**: PDB analysis for Oracle 12c+
- **ora_sessions.sh**: Session and lock analysis

## RAC Interconnect Latency Thresholds
This tool uses the following thresholds for RAC interconnect latency:
- **Excellent**: < 100 microseconds (0.1ms)
- **Good**: < 500 microseconds (0.5ms)
- **Acceptable**: < 1000 microseconds (1ms)
- **Poor**: > 1000 microseconds (1ms)

## License and Usage
This tool is provided for use by Oracle DBAs and system administrators.
