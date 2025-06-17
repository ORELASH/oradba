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
