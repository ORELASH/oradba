

#!/bin/bash
# Oracle Monitor Quick Download and Setup
# One-liner: curl -s https://raw.githubusercontent.com/your-repo/oracle-monitor/main/get_oracle_monitor.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=================================================="
echo "  Oracle Database Network Monitor"
echo "  Quick Download & Setup for RHEL8 PPC64LE"
echo "=================================================="

# Check if running as root for installation
if [[ $EUID -eq 0 ]]; then
    INSTALL_MODE=true
    log "Running as root - will install after download"
else
    INSTALL_MODE=false
    log "Running as user - will only download package"
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "ppc64le" ]]; then
    warning "This package is optimized for PowerPC (ppc64le), detected: $ARCH"
fi

# Check OS
if [[ -f /etc/redhat-release ]]; then
    OS_VERSION=$(cat /etc/redhat-release)
    log "Detected OS: $OS_VERSION"
else
    warning "Not detected as RHEL system"
fi

# Create package directory
PACKAGE_DIR="/tmp/oracle-monitor-$(date +%Y%m%d-%H%M%S)"
log "Creating package at: $PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cd "$PACKAGE_DIR"

# Create directory structure
mkdir -p {bin,config,docs,grafana,systemd}

# Download/create all package files
log "Creating package files..."

# Main Python monitoring script
cat > bin/oracle_monitor_influx.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
Oracle Database Network Monitor for RHEL8 PPC
Version: 1.0
"""

import pyshark
import struct
import threading
import time
import logging
import argparse
import signal
import sys
from collections import defaultdict
from datetime import datetime, timezone
import json
import re

try:
    from influxdb_client import InfluxDBClient, Point, WritePrecision
    from influxdb_client.client.write_api import SYNCHRONOUS
except ImportError:
    print("Error: influxdb-client package not installed")
    print("Install with: pip3 install influxdb-client")
    sys.exit(1)

class OracleInfluxMonitor:
    def __init__(self, interface='eth0', influx_config=None):
        self.interface = interface
        self.active_sessions = defaultdict(dict)
        self.stats = {
            'total_queries': 0,
            'total_errors': 0,
            'slow_queries': 0
        }
        
        # InfluxDB Configuration
        self.influx_config = influx_config or {
            'url': 'http://localhost:8086',
            'token': 'your-influx-token',
            'org': 'oracle-monitoring',
            'bucket': 'oracle-metrics'
        }
        
        # Initialize InfluxDB client
        self.influx_client = InfluxDBClient(
            url=self.influx_config['url'],
            token=self.influx_config['token'],
            org=self.influx_config['org']
        )
        self.write_api = self.influx_client.write_api(write_options=SYNCHRONOUS)
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
    def parse_tns_packet(self, packet):
        """Parse Oracle TNS packet structure"""
        try:
            if not hasattr(packet, 'tcp') or not hasattr(packet.tcp, 'payload'):
                return None
                
            payload = packet.tcp.payload
            if not hasattr(payload, 'binary_value') or len(payload.binary_value) < 8:
                return None
                
            data = payload.binary_value
            
            # TNS Header parsing
            tns_length = struct.unpack('>H', data[:2])[0]
            tns_type = data[4]
            
            return {
                'length': tns_length,
                'type': tns_type,
                'data': data[8:] if len(data) > 8 else b'',
                'timestamp': packet.sniff_time.timestamp(),
                'packet_size': len(data)
            }
            
        except Exception as e:
            self.logger.debug(f"TNS parsing error: {e}")
            return None
    
    def extract_sql_from_tns(self, tns_data, tns_type):
        """Extract SQL from TNS data"""
        try:
            if tns_type != 6:  # TNS Data packet
                return None
                
            data_str = tns_data.decode('utf-8', errors='ignore')
            
            # SQL patterns
            sql_patterns = [
                r'\b(SELECT\s+.+?\s+FROM\s+\w+)',
                r'\b(INSERT\s+INTO\s+\w+)',
                r'\b(UPDATE\s+\w+\s+SET)',
                r'\b(DELETE\s+FROM\s+\w+)',
                r'\b(CREATE\s+\w+)',
                r'\b(ALTER\s+\w+)',
                r'\b(DROP\s+\w+)',
                r'\b(COMMIT\b)',
                r'\b(ROLLBACK\b)'
            ]
            
            for pattern in sql_patterns:
                match = re.search(pattern, data_str, re.IGNORECASE)
                if match:
                    sql = match.group(1).strip()
                    sql = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', sql)
                    return ' '.join(sql.split())[:500]
                    
        except Exception as e:
            self.logger.debug(f"SQL extraction error: {e}")
            
        return None
    
    def write_metrics_to_influx(self, measurement, tags, fields, timestamp=None):
        """Write metrics to InfluxDB"""
        try:
            point = Point(measurement)
            
            for key, value in tags.items():
                point = point.tag(key, str(value))
            
            for key, value in fields.items():
                if isinstance(value, (int, float)):
                    point = point.field(key, value)
                else:
                    point = point.field(key, str(value))
            
            if timestamp:
                point = point.time(timestamp, WritePrecision.MS)
            else:
                point = point.time(datetime.now(timezone.utc), WritePrecision.MS)
            
            self.write_api.write(bucket=self.influx_config['bucket'], record=point)
            
        except Exception as e:
            self.logger.error(f"InfluxDB write error: {e}")
    
    def process_packet(self, packet):
        """Process each packet"""
        try:
            if not hasattr(packet, 'ip'):
                return
                
            src_ip = packet.ip.src
            dst_ip = packet.ip.dst
            src_port = packet.tcp.srcport
            dst_port = packet.tcp.dstport
            
            stream_id = f"{src_ip}:{src_port}-{dst_ip}:{dst_port}"
            direction = "request" if dst_port == '1521' else "response"
            
            tns_info = self.parse_tns_packet(packet)
            if not tns_info:
                return
            
            timestamp_ms = int(tns_info['timestamp'] * 1000)
            
            if direction == "request":
                sql = self.extract_sql_from_tns(tns_info['data'], tns_info['type'])
                
                self.active_sessions[stream_id] = {
                    'start_time': tns_info['timestamp'],
                    'sql': sql,
                    'client_ip': src_ip,
                    'server_ip': dst_ip,
                    'request_size': tns_info['packet_size']
                }
                
                if sql:
                    self.logger.info(f"SQL Query: {sql[:100]}...")
                    
            elif direction == "response" and stream_id in self.active_sessions:
                session = self.active_sessions.pop(stream_id)
                duration_ms = (tns_info['timestamp'] - session['start_time']) * 1000
                is_slow = duration_ms > 1000
                
                self.stats['total_queries'] += 1
                if is_slow:
                    self.stats['slow_queries'] += 1
                
                self.logger.info(f"Query completed: {duration_ms:.2f}ms")
                
                # Determine query type
                query_type = "UNKNOWN"
                if session['sql']:
                    sql_upper = session['sql'].upper()
                    if sql_upper.startswith('SELECT'):
                        query_type = "SELECT"
                    elif sql_upper.startswith('INSERT'):
                        query_type = "INSERT"
                    elif sql_upper.startswith('UPDATE'):
                        query_type = "UPDATE"
                    elif sql_upper.startswith('DELETE'):
                        query_type = "DELETE"
                
                # Write to InfluxDB
                self.write_metrics_to_influx(
                    measurement="oracle_queries",
                    tags={
                        "client_ip": session['client_ip'],
                        "server_ip": session['server_ip'],
                        "query_type": query_type,
                        "status": "completed",
                        "is_slow": str(is_slow)
                    },
                    fields={
                        "duration_ms": round(duration_ms, 2),
                        "request_size": session['request_size'],
                        "response_size": tns_info['packet_size'],
                        "sql_preview": session['sql'][:200] if session['sql'] else ""
                    },
                    timestamp=timestamp_ms
                )
                
        except Exception as e:
            self.logger.error(f"Packet processing error: {e}")
    
    def start_monitoring(self):
        """Start monitoring"""
        try:
            self.logger.info(f"Starting Oracle monitoring on {self.interface}")
            
            capture = pyshark.LiveCapture(
                interface=self.interface,
                display_filter='tcp.port == 1521 and tcp.len > 0'
            )
            
            for packet in capture.sniff_continuously():
                self.process_packet(packet)
                
        except KeyboardInterrupt:
            self.logger.info("Monitoring stopped")
        except Exception as e:
            self.logger.error(f"Monitoring error: {e}")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """Cleanup"""
        try:
            self.influx_client.close()
        except:
            pass

def main():
    parser = argparse.ArgumentParser(description='Oracle Network Monitor')
    parser.add_argument('-i', '--interface', default='eth0')
    parser.add_argument('--influx-url', default='http://localhost:8086')
    parser.add_argument('--influx-token', required=True)
    parser.add_argument('--influx-org', default='oracle-monitoring')
    parser.add_argument('--influx-bucket', default='oracle-metrics')
    
    args = parser.parse_args()
    
    influx_config = {
        'url': args.influx_url,
        'token': args.influx_token,
        'org': args.influx_org,
        'bucket': args.influx_bucket
    }
    
    monitor = OracleInfluxMonitor(args.interface, influx_config)
    monitor.start_monitoring()

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

# Installation script
cat > bin/install_oracle_monitor.sh << 'INSTALL_SCRIPT'
#!/bin/bash
# Quick Oracle Monitor Installation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo ./install_oracle_monitor.sh"
    exit 1
fi

# Check dependencies
log "Checking InfluxDB..."
if ! curl -sf http://localhost:8086/health >/dev/null; then
    error "InfluxDB not running on localhost:8086"
    exit 1
fi

# Install packages
log "Installing packages..."
dnf install -y python3-pip tcpdump wireshark tshark libpcap-devel || {
    error "Failed to install packages"
    exit 1
}

pip3 install influxdb-client pandas pyshark || {
    error "Failed to install Python packages"
    exit 1
}

# Create user
log "Creating user..."
useradd -r -d /opt/oracle-monitor -s /bin/bash oracle-monitor 2>/dev/null || true
usermod -a -G wireshark oracle-monitor

# Setup directories
mkdir -p /opt/oracle-monitor /var/log/oracle-monitor
chown oracle-monitor:oracle-monitor /opt/oracle-monitor /var/log/oracle-monitor

# Get configuration
log "Configuration setup..."
echo "Enter your InfluxDB settings:"

read -p "InfluxDB URL [http://localhost:8086]: " INFLUX_URL
read -p "InfluxDB Token: " INFLUX_TOKEN
read -p "InfluxDB Org [oracle-monitoring]: " INFLUX_ORG
read -p "InfluxDB Bucket [oracle-metrics]: " INFLUX_BUCKET
read -p "Network Interface [eth0]: " INTERFACE

INFLUX_URL=${INFLUX_URL:-http://localhost:8086}
INFLUX_ORG=${INFLUX_ORG:-oracle-monitoring}
INFLUX_BUCKET=${INFLUX_BUCKET:-oracle-metrics}
INTERFACE=${INTERFACE:-eth0}

if [[ -z "$INFLUX_TOKEN" ]]; then
    error "InfluxDB token required"
    exit 1
fi

# Save config
cat > /etc/default/oracle-monitor << EOF
INFLUX_URL=$INFLUX_URL
INFLUX_TOKEN=$INFLUX_TOKEN
INFLUX_ORG=$INFLUX_ORG
INFLUX_BUCKET=$INFLUX_BUCKET
NETWORK_INTERFACE=$INTERFACE
EOF
chmod 600 /etc/default/oracle-monitor

# Install files
cp oracle_monitor_influx.py /opt/oracle-monitor/
chmod +x /opt/oracle-monitor/oracle_monitor_influx.py
chown oracle-monitor:oracle-monitor /opt/oracle-monitor/oracle_monitor_influx.py

# Create service
cat > /etc/systemd/system/oracle-monitor.service << 'EOF'
[Unit]
Description=Oracle Database Network Monitor
After=network-online.target

[Service]
Type=simple
User=oracle-monitor
Group=oracle-monitor
WorkingDirectory=/opt/oracle-monitor
ExecStart=/usr/bin/python3 /opt/oracle-monitor/oracle_monitor_influx.py \
    --interface=${NETWORK_INTERFACE} \
    --influx-url=${INFLUX_URL} \
    --influx-token=${INFLUX_TOKEN} \
    --influx-org=${INFLUX_ORG} \
    --influx-bucket=${INFLUX_BUCKET}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
CapabilityBoundingSet=CAP_NET_RAW CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_RAW CAP_NET_ADMIN
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=-/etc/default/oracle-monitor

[Install]
WantedBy=multi-user.target
EOF

# Setup capabilities
setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap 2>/dev/null || true

# Start service
systemctl daemon-reload
systemctl enable oracle-monitor
systemctl start oracle-monitor

if systemctl is-active --quiet oracle-monitor; then
    success "Oracle Monitor installed and running!"
    echo
    echo "Next steps:"
    echo "1. Import grafana/oracle-dashboard.json to Grafana"
    echo "2. Configure switch mirror port for Oracle traffic"
    echo "3. Monitor: journalctl -fu oracle-monitor"
else
    error "Service failed to start"
    systemctl status oracle-monitor
fi
INSTALL_SCRIPT

# Create Grafana dashboard
cat > grafana/oracle-dashboard.json << 'DASHBOARD'
{
  "dashboard": {
    "title": "Oracle Database Performance Monitor",
    "tags": ["oracle", "database"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Query Rate (per minute)",
        "type": "stat",
        "targets": [
          {
            "query": "from(bucket: \"oracle-metrics\") |> range(start: v.timeRangeStart, stop: v.timeRangeStop) |> filter(fn: (r) => r[\"_measurement\"] == \"oracle_queries\") |> filter(fn: (r) => r[\"status\"] == \"completed\") |> aggregateWindow(every: 1m, fn: count, createEmpty: false)",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": { "mode": "thresholds" },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 50},
                {"color": "red", "value": 100}
              ]
            }
          }
        }
      },
      {
        "title": "Average Response Time (ms)",
        "type": "stat",
        "targets": [
          {
            "query": "from(bucket: \"oracle-metrics\") |> range(start: v.timeRangeStart, stop: v.timeRangeStop) |> filter(fn: (r) => r[\"_measurement\"] == \"oracle_queries\") |> filter(fn: (r) => r[\"_field\"] == \"duration_ms\") |> aggregateWindow(every: 1m, fn: mean, createEmpty: false)",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": { "mode": "thresholds" },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 500},
                {"color": "red", "value": 1000}
              ]
            },
            "unit": "ms"
          }
        }
      },
      {
        "title": "Query Response Time Over Time",
        "type": "timeseries",
        "targets": [
          {
            "query": "from(bucket: \"oracle-metrics\") |> range(start: v.timeRangeStart, stop: v.timeRangeStop) |> filter(fn: (r) => r[\"_measurement\"] == \"oracle_queries\") |> filter(fn: (r) => r[\"_field\"] == \"duration_ms\") |> aggregateWindow(every: 30s, fn: mean, createEmpty: false)",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": { "mode": "palette-classic" },
            "unit": "ms"
          }
        }
      },
      {
        "title": "Query Types Distribution",
        "type": "piechart",
        "targets": [
          {
            "query": "from(bucket: \"oracle-metrics\") |> range(start: v.timeRangeStart, stop: v.timeRangeStop) |> filter(fn: (r) => r[\"_measurement\"] == \"oracle_queries\") |> filter(fn: (r) => r[\"status\"] == \"completed\") |> group(columns: [\"query_type\"]) |> count()",
            "refId": "A"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "version": 1
  }
}
DASHBOARD

# Documentation
cat > docs/README.md << 'DOCS'
# Oracle Database Network Monitor

## Overview
Passive Oracle database monitoring via network traffic analysis.

## Features
- Zero-impact monitoring through port mirroring
- Real-time metrics collection
- InfluxDB integration
- Grafana dashboards
- Optimized for RHEL8 PPC64LE

## Installation
```bash
sudo ./bin/install_oracle_monitor.sh
```

## Configuration
Edit `/etc/default/oracle-monitor` to modify settings.

## Service Management
```bash
# Status
systemctl status oracle-monitor

# Logs
journalctl -fu oracle-monitor

# Restart
systemctl restart oracle-monitor
```

## Switch Configuration
Configure mirror port to forward Oracle traffic (TCP/1521) to monitoring server.

Example (Cisco):
```
monitor session 1 source interface gi1/0/1
monitor session 1 destination interface gi1/0/24
```

## Grafana Setup
1. Import `grafana/oracle-dashboard.json`
2. Configure InfluxDB datasource
3. Verify data is flowing

## Support
Check logs for troubleshooting: `journalctl -u oracle-monitor`
DOCS

# Configuration template
cat > config/oracle-monitor.conf << 'CONFIG'
# Oracle Monitor Configuration
# Copy to /etc/default/oracle-monitor

INFLUX_URL=http://localhost:8086
INFLUX_TOKEN=your-token-here
INFLUX_ORG=oracle-monitoring
INFLUX_BUCKET=oracle-metrics
NETWORK_INTERFACE=eth0
CONFIG

# SystemD service
cat > systemd/oracle-monitor.service << 'SERVICE'
[Unit]
Description=Oracle Database Network Monitor
After=network-online.target

[Service]
Type=simple
User=oracle-monitor
Group=oracle-monitor
WorkingDirectory=/opt/oracle-monitor
ExecStart=/usr/bin/python3 /opt/oracle-monitor/oracle_monitor_influx.py \
    --interface=${NETWORK_INTERFACE} \
    --influx-url=${INFLUX_URL} \
    --influx-token=${INFLUX_TOKEN} \
    --influx-org=${INFLUX_ORG} \
    --influx-bucket=${INFLUX_BUCKET}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
CapabilityBoundingSet=CAP_NET_RAW CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_RAW CAP_NET_ADMIN
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=-/etc/default/oracle-monitor

[Install]
WantedBy=multi-user.target
SERVICE

# Make executable
chmod +x bin/*.sh bin/*.py

# Create package info
cat > PACKAGE_INFO.txt << 'INFO'
Oracle Database Network Monitor Package
Version: 1.0
Platform: RHEL8 PPC64LE
Created: $(date)
Package Location: $PACKAGE_DIR

Files:
- bin/oracle_monitor_influx.py (Main monitoring script)
- bin/install_oracle_monitor.sh (Quick installer)
- grafana/oracle-dashboard.json (Grafana dashboard)
- systemd/oracle-monitor.service (SystemD service)
- docs/README.md (Documentation)
- config/oracle-monitor.conf (Configuration template)

Installation:
1. cd $PACKAGE_DIR
2. sudo ./bin/install_oracle_monitor.sh
3. Import grafana/oracle-dashboard.json to Grafana
4. Configure switch mirror port
INFO

success "Package created successfully!"
echo
echo "📦 Package Directory: $PACKAGE_DIR"
echo
echo "📋 Package Contents:"
echo "   ├── bin/                            # Executables"
echo "   │   ├── oracle_monitor_influx.py   # Main script"
echo "   │   └── install_oracle_monitor.sh  # Installer"
echo "   ├── grafana/                        # Grafana files"
echo "   │   └── oracle-dashboard.json      # Dashboard"
echo "   ├── systemd/                        # Service files"
echo "   │   └── oracle-monitor.service     # SystemD service"
echo "   ├── docs/                           # Documentation"
echo "   │   └── README.md                  # Instructions"
echo "   └── config/                         # Configuration"
echo "       └── oracle-monitor.conf        # Config template"
echo
echo "🚀 Quick Installation:"
echo "   cd $PACKAGE_DIR"
echo "   sudo ./bin/install_oracle_monitor.sh"
echo
echo "📦 Create Archive:"
echo "   tar -czf oracle-monitor-v1.0.tar.gz -C $(dirname $PACKAGE_DIR) $(basename $PACKAGE_DIR)"
echo

if [[ "$INSTALL_MODE" == "true" ]]; then
    echo
    read -p "Install now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Starting installation..."
        ./bin/install_oracle_monitor.sh
    fi
fi

echo
success "Package ready at: $PACKAGE_DIR"
echo "Next: Import grafana/oracle-dashboard.json to Grafana"
