# Oracle DBA Diagnostic Tools

Comprehensive Oracle database diagnostics toolkit for AIX and Linux platforms.

## 🎯 Features

- **Automated Instance Discovery** - Find all running Oracle instances
- **System Diagnostics** - CPU, memory, disk, network metrics
- **RAC Support** - Interconnect latency, cluster status, ASM
- **Performance Analysis** - Sessions, blocks, long-running queries
- **Security Scanning** - Comprehensive security audit
- **Alert Analysis** - Automated error detection
- **PDB Support** - Oracle 12c+ Pluggable Databases

## 📋 Files

| File | Purpose | Lines |
|------|---------|-------|
| `ora_dba.sh` | Main interactive menu | 120 |
| `ora_common.sh` | Common functions & variables | 226 |
| `ora_system.sh` | System metrics collection | 258 |
| `ora_virt.sh` | Virtualization detection | 219 |
| `ora_instance.sh` | Instance management | 299 |
| `ora_alerts.sh` | Alert log analysis | 202 |
| `ora_params.sh` | Parameter analysis | 254 |
| `ora_rac.sh` | RAC diagnostics | 400 |
| `ora_sessions.sh` | Session & lock analysis | 373 |
| `oracle-security-scan.sh` | Security audit tool | 1,212 |

## 🚀 Quick Start

### Prerequisites
- Oracle Database 11g+ or Oracle Client
- Running as `oracle` user
- sqlplus in PATH
- Bash 4.0+

### Usage

```bash
# Interactive menu
./ora_dba.sh

# Run specific diagnostic
./ora_system.sh    # System metrics only
./ora_rac.sh       # RAC diagnostics only
./ora_sessions.sh  # Performance diagnostics

# Security scan
./oracle-security-scan.sh              # Auto-detect all instances
./oracle-security-scan.sh -i ORCL      # Scan specific instance
./oracle-security-scan.sh -l           # List instances only
```

## 📊 Main Menu Options

1. **Full system diagnostic** - Runs all checks
2. **System metrics only** - OS and hardware
3. **Oracle instance diagnostics** - Instance analysis
4. **RAC/GI diagnostics** - RAC interconnect and cluster
5. **Performance diagnostics** - Sessions, blocks, queries
6. **Exit**

## 🔍 What Each Module Does

### ora_system.sh - System Metrics
- OS type and version
- CPU count and usage
- Memory (total, used, free, swap)
- Disk space and I/O
- Network interfaces and errors
- Load average

### ora_virt.sh - Virtualization
- Detects: VMware, PowerVM, LPAR, KVM, Xen
- Shows: VM type, configuration, resources
- Platform-specific metrics

### ora_instance.sh - Instance Management
- Lists all running instances
- Instance status and uptime
- Database version and edition
- Connection details (host, port, SID)
- PDB information (12c+)

### ora_alerts.sh - Alert Analysis
- Alert log parsing
- Error categorization (ORA-, TNS-, etc.)
- Recent errors highlighting
- Listener error detection
- Severity assessment

### ora_params.sh - Parameters
- Non-default parameters
- Parameter categorization (memory, CPU, I/O)
- Recommended vs actual values
- Change history

### ora_rac.sh - RAC Diagnostics
- Interconnect latency testing
- Grid Infrastructure status
- Cluster resource status
- ASM disk group utilization
- Voting disks and OCR

**Latency Thresholds:**
- Excellent: < 100 μs
- Good: < 500 μs
- Acceptable: < 1000 μs
- Poor: > 1000 μs

### ora_sessions.sh - Performance
- Active sessions
- Blocking sessions
- Long-running queries (> 5 minutes)
- Session statistics
- Lock wait analysis

### oracle-security-scan.sh - Security Audit
- Password policy check
- User privilege analysis
- Network security
- Audit settings
- Default accounts
- Generates HTML report

**Options:**
```bash
-u USERNAME      Oracle username (default: SYS)
-p PASSWORD      Oracle password (will prompt if not provided)
-l               List instances only
-i INSTANCE      Scan specific instance(s)
-m NUM           Max parallel scans (default: 5)
-o DIR           Output directory
```

## 🖥️ Platform Support

| Feature | AIX | Linux | Notes |
|---------|-----|-------|-------|
| Instance Discovery | ✅ | ✅ | |
| System Metrics | ✅ | ✅ | |
| RAC Diagnostics | ✅ | ✅ | |
| Virtualization | ✅ | ✅ | AIX: PowerVM, LPAR<br>Linux: VMware, KVM, Xen |
| Alert Analysis | ✅ | ✅ | |
| Security Scan | ✅ | ✅ | |

## 📝 Output Examples

### System Metrics Output
```
=================================
OS: Linux
Version: Red Hat Enterprise Linux 8.5
=================================
CPU: 16 cores
Memory: 64 GB (48 GB used, 16 GB free)
Swap: 8 GB (2 GB used)
Disk: /u01 - 500 GB (320 GB used, 64%)
Load Average: 2.34, 1.98, 1.76
```

### RAC Latency Output
```
=================================
RAC Interconnect Latency
=================================
Node 1 -> Node 2: 85 μs [EXCELLENT]
Node 1 -> Node 3: 120 μs [GOOD]
Node 2 -> Node 3: 450 μs [GOOD]
```

### Security Scan Output
```
Scanning instance: ORCL
[✓] Password policy: Configured
[✗] Default accounts: scott/tiger found
[✓] Network encryption: Enabled
[!] Audit settings: Not configured

Report saved to: oracle_security_scan_20260225_140530/ORCL_report.html
```

## ⚠️ Requirements

### Mandatory
- Oracle Database or Client installed
- User must be `oracle` or have Oracle environment set
- sqlplus accessible in PATH

### Optional (for full functionality)
- Grid Infrastructure (for RAC diagnostics)
- ASM (for disk group analysis)
- DBA privileges (for security scan)

### Setting Oracle Environment
```bash
# Add to ~/.bash_profile or run before using tools
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=ORCL
```

## 🔧 Troubleshooting

### "sqlplus: command not found"
```bash
# Check Oracle environment
echo $ORACLE_HOME
echo $PATH | grep oracle

# Set environment
export ORACLE_HOME=/path/to/oracle
export PATH=$ORACLE_HOME/bin:$PATH
```

### "ORA-01017: invalid username/password"
```bash
# For security scan, provide correct credentials
./oracle-security-scan.sh -u SYS -p <password>
```

### "Cannot find running instances"
```bash
# Check if Oracle is running
ps -ef | grep pmon

# Check /etc/oratab
cat /etc/oratab
```

### RAC Diagnostics Not Working
```bash
# Check Grid Infrastructure
crsctl stat res -t
crsctl check crs

# Verify cluster membership
olsnodes -n
```

## 📖 Related Documentation

- [Oracle Monitoring Guide](../docs/oracle_monitoring_guide.md) - Comprehensive monitoring guide (30KB)
- [Main README](../README.md) - Project overview and installation

## 🤝 Contributing

Found a bug or have a feature request? Please open an issue or submit a pull request.

---

**Platform:** AIX 7.1+ | Linux (RHEL 7+, Ubuntu 18.04+)
**Oracle:** 11g, 12c, 18c, 19c, 21c
**Status:** Production Ready
