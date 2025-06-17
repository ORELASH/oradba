# מדריך מלא לניטור Oracle DB עם Zeek דרך Port Mirror

## דרישות מוקדמות
- Linux 8.8 PPC
- Port Mirror מוגדר על Switch/Router
- Zeek מותקן
- InfluxDB מותקן
- Grafana מותקן

## שלב 1: הגדרת Zeek לניטור Oracle Traffic

### 1.1 יצירת סקריפט Zeek מתקדם לOracle
```bash
sudo nano /opt/zeek/share/zeek/site/oracle-monitor.zeek
```

הוסף את התוכן הבא:
```zeek
@load base/protocols/conn
@load base/utils/time

module Oracle;

export {
    redef enum Log::ID += { LOG };
    
    type Info: record {
        ts: time &log;
        uid: string &log;
        id: conn_id &log;
        oracle_command: string &optional &log;
        oracle_response_code: string &optional &log;
        oracle_user: string &optional &log;
        oracle_sid: string &optional &log;
        query_duration: interval &optional &log;
        bytes_sent: count &optional &log;
        bytes_received: count &optional &log;
        connection_state: string &optional &log;
        oracle_version: string &optional &log;
        service_name: string &optional &log;
        error_code: string &optional &log;
        sql_type: string &optional &log;
    };
    
    global log_oracle: event(rec: Info);
    global oracle_ports: set[port] = { 1521/tcp, 1522/tcp, 1523/tcp, 1526/tcp };
}

# Active connections tracking tables
global oracle_connections: table[string] of Info;
global connection_start_times: table[string] of time;

redef likely_server_ports += oracle_ports;

event zeek_init() {
    Log::create_stream(Oracle::LOG, [$columns=Info, $path="oracle"]);
}

# זיהוי TNS (Transparent Network Substrate) headers
function analyze_tns_packet(payload: string): Info {
    local info: Info;
    
    if (|payload| < 8)
        return info;
    
    # TNS Packet Header Analysis
    local packet_length = bytestring_to_count(payload[0:2], T);
    local packet_checksum = bytestring_to_count(payload[2:4], T);
    local packet_type = bytestring_to_count(payload[4:5], T);
    local reserved_byte = bytestring_to_count(payload[5:6], T);
    local header_checksum = bytestring_to_count(payload[6:8], T);
    
    # TNS Packet Types
    switch (packet_type) {
        case 1:
            info$oracle_command = "CONNECT";
            info$connection_state = "CONNECTING";
            break;
        case 2:
            info$oracle_command = "ACCEPT";
            info$connection_state = "ACCEPTED";
            break;
        case 3:
            info$oracle_command = "ACK";
            break;
        case 4:
            info$oracle_command = "REFUSE";
            info$connection_state = "REFUSED";
            break;
        case 5:
            info$oracle_command = "REDIRECT";
            break;
        case 6:
            info$oracle_command = "DATA";
            # SQL data analysis
            if (|payload| > 20) {
                local data_payload = payload[8:];
                if ("SELECT" in data_payload)
                    info$sql_type = "SELECT";
                else if ("INSERT" in data_payload)
                    info$sql_type = "INSERT";
                else if ("UPDATE" in data_payload)
                    info$sql_type = "UPDATE";
                else if ("DELETE" in data_payload)
                    info$sql_type = "DELETE";
                else if ("CREATE" in data_payload)
                    info$sql_type = "CREATE";
                else if ("ALTER" in data_payload)
                    info$sql_type = "ALTER";
                else if ("DROP" in data_payload)
                    info$sql_type = "DROP";
            }
            break;
        case 7:
            info$oracle_command = "NULL";
            break;
        case 9:
            info$oracle_command = "ABORT";
            info$connection_state = "ABORTED";
            break;
        case 11:
            info$oracle_command = "RESEND";
            break;
        case 12:
            info$oracle_command = "MARKER";
            break;
        case 13:
            info$oracle_command = "ATTENTION";
            break;
        case 14:
            info$oracle_command = "CONTROL";
            break;
        default:
            info$oracle_command = fmt("UNKNOWN_TYPE_%d", packet_type);
    }
    
    return info;
}

# Identify Connect Data
function extract_connect_data(payload: string): Info {
    local info: Info = [$ts=network_time(), $uid="", $id=[$orig_h=0.0.0.0, $orig_p=0/tcp, $resp_h=0.0.0.0, $resp_p=0/tcp]];
    
    if ("SERVICE_NAME=" in payload) {
        local service_start = strstr(payload, "SERVICE_NAME=") + 13;
        local service_end = strstr(payload[service_start:], ")");
        if (service_end > 0)
            info$service_name = payload[service_start:service_start + service_end];
    }
    
    if ("SID=" in payload) {
        local sid_start = strstr(payload, "SID=") + 4;
        local sid_end = strstr(payload[sid_start:], ")");
        if (sid_end > 0)
            info$oracle_sid = payload[sid_start:sid_start + sid_end];
    }
    
    # Identify Oracle version
    if ("PROGRAM=" in payload) {
        local prog_start = strstr(payload, "PROGRAM=") + 8;
        local prog_end = strstr(payload[prog_start:], ")");
        if (prog_end > 0) {
            local program = payload[prog_start:prog_start + prog_end];
            if ("oracle" in to_lower(program))
                info$oracle_version = program;
        }
    }
    
    return info;
}

event connection_established(c: connection) {
    if (c$id$resp_p in oracle_ports) {
        local connection_key = fmt("%s:%d->%s:%d", c$id$orig_h, c$id$orig_p, c$id$resp_h, c$id$resp_p);
        connection_start_times[connection_key] = network_time();
        
        local rec: Oracle::Info = [
            $ts=network_time(),
            $uid=c$uid,
            $id=c$id,
            $connection_state="ESTABLISHED"
        ];
        
        oracle_connections[connection_key] = rec;
        Log::write(Oracle::LOG, rec);
    }
}

event connection_state_remove(c: connection) {
    if (c$id$resp_p in oracle_ports) {
        local connection_key = fmt("%s:%d->%s:%d", c$id$orig_h, c$id$orig_p, c$id$resp_h, c$id$resp_p);
        
        if (connection_key in connection_start_times) {
            local duration = network_time() - connection_start_times[connection_key];
            
            local rec: Oracle::Info = [
                $ts=network_time(),
                $uid=c$uid,
                $id=c$id,
                $connection_state="CLOSED",
                $query_duration=duration
            ];
            
            if (c$conn?$orig_bytes)
                rec$bytes_sent = c$conn$orig_bytes;
            if (c$conn?$resp_bytes)
                rec$bytes_received = c$conn$resp_bytes;
            
            Log::write(Oracle::LOG, rec);
            delete connection_start_times[connection_key];
            delete oracle_connections[connection_key];
        }
    }
}

event tcp_packet(c: connection, is_orig: bool, flags: string, seq: count, ack: count, len: count, payload: string) {
    if (c$id$resp_p in oracle_ports && len > 8) {
        local conn_id = fmt("%s:%d->%s:%d", c$id$orig_h, c$id$orig_p, c$id$resp_h, c$id$resp_p);
        
        # ניתוח TNS packet
        local tns_info = analyze_tns_packet(payload);
        
        # ניתוח Connect Data במידת הצורך
        if (tns_info$oracle_command == "CONNECT" || tns_info$oracle_command == "DATA") {
            local connect_info = extract_connect_data(payload);
            if (connect_info?$service_name)
                tns_info$service_name = connect_info$service_name;
            if (connect_info?$oracle_sid)
                tns_info$oracle_sid = connect_info$oracle_sid;
            if (connect_info?$oracle_version)
                tns_info$oracle_version = connect_info$oracle_version;
        }
        
        local rec: Oracle::Info = [
            $ts=network_time(),
            $uid=c$uid,
            $id=c$id,
            $bytes_sent=is_orig ? len : 0,
            $bytes_received=is_orig ? 0 : len
        ];
        
        # העתקת נתונים מניתוח TNS
        if (tns_info?$oracle_command)
            rec$oracle_command = tns_info$oracle_command;
        if (tns_info?$connection_state)
            rec$connection_state = tns_info$connection_state;
        if (tns_info?$service_name)
            rec$service_name = tns_info$service_name;
        if (tns_info?$oracle_sid)
            rec$oracle_sid = tns_info$oracle_sid;
        if (tns_info?$oracle_version)
            rec$oracle_version = tns_info$oracle_version;
        if (tns_info?$sql_type)
            rec$sql_type = tns_info$sql_type;
        
        Log::write(Oracle::LOG, rec);
    }
}

### 1.2 הוספת הסקריפט ל-local.zeek
```bash
sudo nano /opt/zeek/share/zeek/site/local.zeek
```

הוסף בסוף הקובץ:
```zeek
@load ./oracle-monitor.zeek

# Mirror interface configuration
redef interface = "eth1";  # Replace with your Mirror interface

# Optimization settings
redef default_file_bsize = 1024*1024;
redef Log::default_rotation_interval = 1hr;
```

### 1.3 הגדרת Zeek לממשק Mirror
```bash
sudo nano /opt/zeek/etc/node.cfg
```

ערוך את הקובץ:
```ini
[zeek]
type=standalone
host=localhost
interface=eth1    # Port Mirror interface
```

### 1.4 הפעלה מחדש של Zeek
```bash
sudo /opt/zeek/bin/zeekctl install
sudo /opt/zeek/bin/zeekctl restart
```

## שלב 2: הגדרת InfluxDB

### 2.1 יצירת מסד נתונים ומשתמש
```bash
influx
```

בתוך InfluxDB CLI:
```sql
CREATE DATABASE oracle_monitoring
USE oracle_monitoring

CREATE USER "zeek_user" WITH PASSWORD "ZeekOracle2025!"
GRANT ALL ON oracle_monitoring TO zeek_user

-- יצירת Retention Policies
CREATE RETENTION POLICY "realtime" ON oracle_monitoring DURATION 24h REPLICATION 1
CREATE RETENTION POLICY "hourly" ON oracle_monitoring DURATION 7d REPLICATION 1  
CREATE RETENTION POLICY "daily" ON oracle_monitoring DURATION 90d REPLICATION 1 DEFAULT

exit
```

### 2.2 הגדרת Continuous Queries לאגרגציה
```bash
influx -database oracle_monitoring
```

```sql
-- Hourly aggregation
CREATE CONTINUOUS QUERY "oracle_hourly_cq" ON oracle_monitoring
BEGIN
  SELECT mean(bytes_sent) AS avg_bytes_sent,
         mean(bytes_received) AS avg_bytes_received,
         count(connection_count) AS total_connections,
         count(DISTINCT uid) AS unique_connections
  INTO "hourly"."oracle_connections_hourly"
  FROM "oracle_connections"
  GROUP BY time(1h), orig_h, resp_h
END

-- Daily aggregation
CREATE CONTINUOUS QUERY "oracle_daily_cq" ON oracle_monitoring  
BEGIN
  SELECT mean(avg_bytes_sent) AS avg_bytes_sent,
         mean(avg_bytes_received) AS avg_bytes_received,
         sum(total_connections) AS total_connections,
         mean(unique_connections) AS avg_unique_connections
  INTO "daily"."oracle_connections_daily"
  FROM "hourly"."oracle_connections_hourly"
  GROUP BY time(1d), orig_h, resp_h
END
```

## שלב 3: סקריפט העברת נתונים מ-Zeek ל-InfluxDB

### 3.1 יצירת סקריפט Python מתקדם
```bash
sudo mkdir -p /opt/zeek/scripts
sudo nano /opt/zeek/scripts/zeek_to_influx.py
```

```python
#!/usr/bin/env python3
import json
import time
import re
import os
import sys
from datetime import datetime
from influxdb import InfluxDBClient
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import logging

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/zeek_to_influx.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

class ZeekOracleLogHandler(FileSystemEventHandler):
    def __init__(self, influx_client):
        self.client = influx_client
        self.log_positions = {}
        self.stats = {
            'total_processed': 0,
            'connections': 0,
            'sql_queries': 0,
            'errors': 0
        }
    
    def on_modified(self, event):
        if event.src_path.endswith('oracle.log'):
            self.process_oracle_log(event.src_path)
    
    def process_oracle_log(self, log_file):
        try:
            with open(log_file, 'r') as f:
                # Read from last position
                last_pos = self.log_positions.get(log_file, 0)
                f.seek(last_pos)
                
                lines_processed = 0
                for line in f:
                    if line.startswith('#') or line.strip() == '':
                        continue
                    
                    try:
                        record = self.parse_oracle_log_line(line.strip())
                        if record:
                            self.send_to_influxdb(record)
                            lines_processed += 1
                            self.stats['total_processed'] += 1
                    
                    except Exception as e:
                        logging.error(f"Error processing line: {e}")
                        self.stats['errors'] += 1
                
                # Save current position
                self.log_positions[log_file] = f.tell()
                
                if lines_processed > 0:
                    logging.info(f"Processed {lines_processed} Oracle log entries")
                
        except Exception as e:
            logging.error(f"Error reading log file {log_file}: {e}")
    
    def parse_oracle_log_line(self, line):
        """Parse Zeek Oracle log line"""
        fields = line.split('\t')
        
        if len(fields) < 6:
            return None
        
        try:
            timestamp = float(fields[0])
            uid = fields[1]
            orig_h = fields[2]
            orig_p = int(fields[3]) if fields[3] != '-' else 0
            resp_h = fields[4]
            resp_p = int(fields[5]) if fields[5] != '-' else 0
            
            record = {
                'timestamp': timestamp,
                'uid': uid,
                'orig_h': orig_h,
                'orig_p': orig_p,
                'resp_h': resp_h,
                'resp_p': resp_p
            }
            
            # Add additional fields if they exist
            if len(fields) > 6 and fields[6] != '-':
                record['oracle_command'] = fields[6]
            if len(fields) > 7 and fields[7] != '-':
                record['oracle_response_code'] = fields[7]
            if len(fields) > 8 and fields[8] != '-':
                record['oracle_user'] = fields[8]
            if len(fields) > 9 and fields[9] != '-':
                record['oracle_sid'] = fields[9]
            if len(fields) > 10 and fields[10] != '-':
                record['query_duration'] = float(fields[10])
            if len(fields) > 11 and fields[11] != '-':
                record['bytes_sent'] = int(fields[11])
            if len(fields) > 12 and fields[12] != '-':
                record['bytes_received'] = int(fields[12])
            if len(fields) > 13 and fields[13] != '-':
                record['connection_state'] = fields[13]
            if len(fields) > 14 and fields[14] != '-':
                record['oracle_version'] = fields[14]
            if len(fields) > 15 and fields[15] != '-':
                record['service_name'] = fields[15]
            if len(fields) > 16 and fields[16] != '-':
                record['error_code'] = fields[16]
            if len(fields) > 17 and fields[17] != '-':
                record['sql_type'] = fields[17]
            
            return record
            
        except (ValueError, IndexError) as e:
            logging.error(f"Error parsing fields: {e}")
            return None
    
    def send_to_influxdb(self, record):
        """Send record to InfluxDB"""
        timestamp_ns = int(record['timestamp'] * 1000000000)
        
        # Different measurements by data type
        measurements = []
        
        # General connections measurement
        connection_point = {
            "measurement": "oracle_connections",
            "time": timestamp_ns,
            "tags": {
                "orig_h": record['orig_h'],
                "resp_h": record['resp_h'],
                "uid": record['uid']
            },
            "fields": {
                "orig_p": record['orig_p'],
                "resp_p": record['resp_p'],
                "connection_count": 1
            }
        }
        
        # Add additional fields to measurement
        if 'bytes_sent' in record:
            connection_point["fields"]["bytes_sent"] = record['bytes_sent']
        if 'bytes_received' in record:
            connection_point["fields"]["bytes_received"] = record['bytes_received']
        if 'query_duration' in record:
            connection_point["fields"]["query_duration"] = record['query_duration']
        
        # Add additional tags
        if 'oracle_command' in record:
            connection_point["tags"]["command"] = record['oracle_command']
        if 'connection_state' in record:
            connection_point["tags"]["state"] = record['connection_state']
        if 'service_name' in record:
            connection_point["tags"]["service"] = record['service_name']
        if 'oracle_sid' in record:
            connection_point["tags"]["sid"] = record['oracle_sid']
        
        measurements.append(connection_point)
        
        # Separate measurement for Oracle commands
        if 'oracle_command' in record:
            command_point = {
                "measurement": "oracle_commands",
                "time": timestamp_ns,
                "tags": {
                    "command": record['oracle_command'],
                    "orig_h": record['orig_h'],
                    "resp_h": record['resp_h']
                },
                "fields": {
                    "count": 1
                }
            }
            
            if 'sql_type' in record:
                command_point["tags"]["sql_type"] = record['sql_type']
            if 'query_duration' in record:
                command_point["fields"]["duration"] = record['query_duration']
            
            measurements.append(command_point)
            
                    # Measurement for SQL queries
        if 'sql_type' in record:
            sql_point = {
                "measurement": "oracle_sql_queries",
                "time": timestamp_ns,
                "tags": {
                    "sql_type": record['sql_type'],
                    "orig_h": record['orig_h'],
                    "service": record.get('service_name', 'unknown')
                },
                "fields": {
                    "count": 1
                }
            }
            
            if 'query_duration' in record:
                sql_point["fields"]["duration"] = record['query_duration']
            if 'bytes_sent' in record:
                sql_point["fields"]["request_size"] = record['bytes_sent']
            if 'bytes_received' in record:
                sql_point["fields"]["response_size"] = record['bytes_received']
            
            measurements.append(sql_point)
            self.stats['sql_queries'] += 1
        
        # Measurement for errors
        if 'error_code' in record:
            error_point = {
                "measurement": "oracle_errors",
                "time": timestamp_ns,
                "tags": {
                    "error_code": record['error_code'],
                    "orig_h": record['orig_h'],
                    "resp_h": record['resp_h']
                },
                "fields": {
                    "count": 1
                }
            }
            measurements.append(error_point)
        
        # Send to InfluxDB
        try:
            self.client.write_points(measurements, retention_policy='realtime')
            if 'oracle_command' in record and record['oracle_command'] in ['CONNECT', 'ACCEPT']:
                self.stats['connections'] += 1
        except Exception as e:
            logging.error(f"Error writing to InfluxDB: {e}")
            self.stats['errors'] += 1
    
    def print_stats(self):
        """Print statistics"""
        logging.info(f"Stats: Total: {self.stats['total_processed']}, "
                    f"Connections: {self.stats['connections']}, "
                    f"SQL Queries: {self.stats['sql_queries']}, "
                    f"Errors: {self.stats['errors']}")

def main():
    # InfluxDB connection settings
    influx_config = {
        'host': 'localhost',
        'port': 8086,
        'username': 'zeek_user',
        'password': 'ZeekOracle2025!',
        'database': 'oracle_monitoring'
    }
    
    try:
        # Connect to InfluxDB
        client = InfluxDBClient(**influx_config)
        client.ping()
        logging.info("Connected to InfluxDB successfully")
        
        # Setup log file monitoring
        event_handler = ZeekOracleLogHandler(client)
        observer = Observer()
        
        # Monitor current logs directory
        log_dir = '/opt/zeek/logs/current'
        if os.path.exists(log_dir):
            observer.schedule(event_handler, path=log_dir, recursive=False)
            logging.info(f"Monitoring directory: {log_dir}")
        else:
            logging.error(f"Log directory not found: {log_dir}")
            return
        
        observer.start()
        
        # Main loop with statistics
        try:
            while True:
                time.sleep(300)  # הדפס סטטיסטיקות כל 5 דקות
                event_handler.print_stats()
        except KeyboardInterrupt:
            logging.info("Shutting down...")
            observer.stop()
        
        observer.join()
        
    except Exception as e:
        logging.error(f"Failed to connect to InfluxDB: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
```

### 3.2 התקנת תלויות Python
```bash
sudo pip3 install influxdb watchdog python-dateutil
```

### 3.3 יצירת שירות systemd
```bash
sudo nano /etc/systemd/system/zeek-influx.service
```

```ini
[Unit]
Description=Zeek Oracle to InfluxDB Data Transfer
After=network.target influxdb.service zeek.service
Requires=influxdb.service

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/python3 /opt/zeek/scripts/zeek_to_influx.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 3.4 הפעלת השירות
```bash
sudo chmod +x /opt/zeek/scripts/zeek_to_influx.py
sudo systemctl daemon-reload
sudo systemctl enable zeek-influx.service
sudo systemctl start zeek-influx.service
```

## שלב 4: הגדרת Grafana

### 4.1 הוספת InfluxDB כמקור נתונים
1. פתח Grafana: `http://your_server:3000`
2. התחבר (admin/admin)
3. Configuration > Data Sources > Add data source
4. בחר InfluxDB ו הגדר:
   - URL: `http://localhost:8086`
   - Database: `oracle_monitoring`
   - User: `zeek_user`
   - Password: `ZeekOracle2025!`

### 4.2 יצירת Dashboard מקיף

#### Panel 1: Oracle Connections Over Time
```sql
SELECT count("connection_count") FROM "oracle_connections" WHERE $timeFilter GROUP BY time($__interval), "orig_h" fill(0)
```

#### Panel 2: Oracle Commands Distribution
```sql
SELECT count("count") FROM "oracle_commands" WHERE $timeFilter GROUP BY time($__interval), "command" fill(0)
```

#### Panel 3: SQL Query Types
```sql
SELECT count("count") FROM "oracle_sql_queries" WHERE $timeFilter GROUP BY time($__interval), "sql_type" fill(0)
```

#### Panel 4: Data Transfer Rates
```sql
SELECT mean("bytes_sent"), mean("bytes_received") FROM "oracle_connections" WHERE $timeFilter GROUP BY time($__interval) fill(0)
```

#### Panel 5: Top Oracle Clients
```sql
SELECT sum("connection_count") FROM "oracle_connections" WHERE $timeFilter GROUP BY "orig_h" ORDER BY time DESC LIMIT 10
```

#### Panel 6: Oracle Services Activity
```sql
SELECT count("connection_count") FROM "oracle_connections" WHERE $timeFilter GROUP BY time($__interval), "service" fill(0)
```

### 4.3 JSON Dashboard מוכן
```bash
sudo nano /tmp/oracle_network_dashboard.json
```

```json
{
  "dashboard": {
    "id": null,
    "title": "Oracle Database Network Monitoring",
    "tags": ["oracle", "network", "zeek"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Oracle Connections Over Time",
        "type": "graph",
        "targets": [
          {
            "query": "SELECT count(\"connection_count\") FROM \"oracle_connections\" WHERE $timeFilter GROUP BY time($__interval), \"orig_h\" fill(0)",
            "rawQuery": true,
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "legend": {"show": true, "values": true, "current": true}
      },
      {
        "id": 2,
        "title": "Oracle Commands",
        "type": "piechart",
        "targets": [
          {
            "query": "SELECT sum(\"count\") FROM \"oracle_commands\" WHERE $timeFilter GROUP BY \"command\"",
            "rawQuery": true,
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "SQL Query Types",
        "type": "graph",
        "targets": [
          {
            "query": "SELECT count(\"count\") FROM \"oracle_sql_queries\" WHERE $timeFilter GROUP BY time($__interval), \"sql_type\" fill(0)",
            "rawQuery": true,
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Data Transfer (Bytes)",
        "type": "graph",
        "targets": [
          {
            "query": "SELECT mean(\"bytes_sent\") AS \"Sent\", mean(\"bytes_received\") AS \"Received\" FROM \"oracle_connections\" WHERE $timeFilter GROUP BY time($__interval) fill(0)",
            "rawQuery": true,
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      },
      {
        "id": 5,
        "title": "Top Oracle Clients",
        "type": "table",
        "targets": [
          {
            "query": "SELECT \"orig_h\", sum(\"connection_count\") as \"Total Connections\" FROM \"oracle_connections\" WHERE $timeFilter GROUP BY \"orig_h\" ORDER BY \"Total Connections\" DESC LIMIT 10",
            "rawQuery": true,
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16}
      },
      {
        "id": 6,
        "title": "Oracle Services",
        "type": "singlestat",
        "targets": [
          {
            "query": "SELECT count(DISTINCT \"service\") FROM \"oracle_connections\" WHERE $timeFilter",
            "rawQuery": true,
            "refId": "A"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 12, "y": 16}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

## שלב 5: הפעלה ובדיקות

### 5.1 הפעלת כל השירותים
```bash
# הפעלת InfluxDB
sudo systemctl start influxdb
sudo systemctl enable influxdb

# הפעלת Grafana
sudo systemctl start grafana-server  
sudo systemctl enable grafana-server

# הפעלת Zeek
sudo /opt/zeek/bin/zeekctl start

# הפעלת סקריפט הניטור
sudo systemctl start zeek-influx
```

### 5.2 בדיקת תקינות המערכת
```bash
# בדיקת Port Mirror
sudo tcpdump -i eth1 port 1521 -c 10

# בדיקת לוגי Zeek
tail -f /opt/zeek/logs/current/oracle.log

# בדיקת נתונים ב-InfluxDB
influx -database oracle_monitoring -execute "SELECT count(*) FROM oracle_connections WHERE time > now() - 1h"

# בדיקת סטטוס השירותים
sudo systemctl status zeek-influx
sudo systemctl status influxdb
sudo systemctl status grafana-server
```

### 5.3 פתרון בעיות נפוצות

#### אם Zeek לא מזהה תעבורת Oracle:
```bash
# ודא שממשק Mirror מוגדר נכון
ip link show
sudo tcpdump -i eth1 -nn | grep 1521

# בדוק הגדרות Zeek
sudo /opt/zeek/bin/zeek -i eth1 -C local.zeek
```

#### אם אין נתונים ב-InfluxDB:
```bash
# בדוק לוגים
sudo journalctl -u zeek-influx -f

# בדוק חיבור InfluxDB
curl -i http://localhost:8086/ping
```

#### אם Grafana לא מציג נתונים:
```bash
# בדוק שאילתות ב-InfluxDB
influx -database oracle_monitoring -execute "SHOW MEASUREMENTS"
influx -database oracle_monitoring -execute "SELECT * FROM oracle_connections LIMIT 5"
```

## שלב 6: אופטימיזציה וכוונון

### 6.1 כוונון ביצועי InfluxDB
```bash
sudo nano /etc/influxdb/influxdb.conf
```

```ini
[meta]
  dir = "/var/lib/influxdb/meta"

[data]
  dir = "/var/lib/influxdb/data"
  wal-dir = "/var/lib/influxdb/wal"
  cache-max-memory-size = "1g"
  cache-snapshot-memory-size = "25m"
  max-series-per-database = 1000000
  max-values-per-tag = 100000

[http]
  enabled = true
  bind-address = ":8086"
  max-body-size = "25m"
  max-concurrent-queries = 0
  max-enqueued-queries = 0
```

### 6.2 כוונון Zeek
```bash
sudo nano /opt/zeek/etc/zeek.cfg
```

```ini
# Memory optimization
redef dpd_buffer_size = 1024;
redef default_file_bsize = 1024*1024;
redef Log::default_rotation_interval = 1hr;
redef Log::default_mail_dest = "";
```

### 6.3 הגדרת Alerts ב-Grafana
1. עבור לפאנל "Oracle Connections"
2. לחץ Edit > Alert
3. הגדר Conditions:
   - WHEN `avg()` OF `query(A, 5m, now)` IS ABOVE `100`
4. הגדר Notifications לפי הצורך

## סיכום ותחזוקה

### מה המערכת מספקת:
- **ניטור תעבורת רשת Oracle** דרך Port Mirror
- **זיהוי פקודות TNS** (Connect, Data, Accept, וכו')
- **ניתוח שאילתות SQL** (SELECT, INSERT, UPDATE, וכו')
- **מטריקות תעבורת נתונים** (bytes sent/received)
- **ניטור חיבורים פעילים** ומשך זמן שאילתות
- **גרפים אינטראקטיביים** ב-Grafana

### תחזוקה שוטפת:
```bash
# ניקוי לוגים ישנים
sudo find /opt/zeek/logs -name "*.log.gz" -mtime +30 -delete

# ניטור שימוש בדיסק
df -h /var/lib/influxdb

# בדיקת ביצועי השירותים
sudo systemctl status zeek-influx
sudo /opt/zeek/bin/zeekctl status
```

המערכת כעת מוכנה לניטור מלא של Oracle DB דרך ניתוח תעבורת רשת בלבד!
