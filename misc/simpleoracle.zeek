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

global oracle_connections: table[string] of Info;
global connection_start_times: table[string] of time;

redef likely_server_ports += oracle_ports;

event zeek_init() {
    Log::create_stream(Oracle::LOG, [$columns=Info, $path="oracle"]);
}

function analyze_tns_packet(payload: string): Info {
    local info: Info = [$ts=network_time(), $uid="", $id=[$orig_h=0.0.0.0, $orig_p=0/tcp, $resp_h=0.0.0.0, $resp_p=0/tcp]];

    if (|payload| < 8)
        return info;

    local packet_type = bytestring_to_count(payload[4:5], T);

    switch (packet_type) {
        case 1: info$oracle_command = "CONNECT"; info$connection_state = "CONNECTING"; break;
        case 2: info$oracle_command = "ACCEPT"; info$connection_state = "ACCEPTED"; break;
        case 3: info$oracle_command = "ACK"; break;
        case 4: info$oracle_command = "REFUSE"; info$connection_state = "REFUSED"; break;
        case 5: info$oracle_command = "REDIRECT"; break;
        case 6:
            info$oracle_command = "DATA";
            if (|payload| > 20) {
                local data_payload = payload[8:];
                local sql_keywords: vector of string = vector("SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP");
                for (i in sql_keywords) {
                    if (sql_keywords[i] in data_payload) {
                        info$sql_type = sql_keywords[i];
                        break;
                    }
                }
            }
            break;
        case 7: info$oracle_command = "NULL"; break;
        case 9: info$oracle_command = "ABORT"; info$connection_state = "ABORTED"; break;
        case 11: info$oracle_command = "RESEND"; break;
        case 12: info$oracle_command = "MARKER"; break;
        case 13: info$oracle_command = "ATTENTION"; break;
        case 14: info$oracle_command = "CONTROL"; break;
        default:
            info$oracle_command = fmt("UNKNOWN_TYPE_%d", packet_type);
            break;
    }

    return info;
}

function extract_field(payload: string, key: string): string {
    local pos = strstr(payload, key);
    if (pos < 0)
        return "";

    local start = pos + |key|;
    local rem = payload[start:];
    local end = strstr(rem, ")");
    if (end < 0)
        return "";

    return rem[0:end];
}

function extract_connect_data(payload: string): Info {
    local info: Info = [$ts=network_time(), $uid="", $id=[$orig_h=0.0.0.0, $orig_p=0/tcp, $resp_h=0.0.0.0, $resp_p=0/tcp]];

    local svc = extract_field(payload, "SERVICE_NAME=");
    if (svc != "")
        info$service_name = svc;

    local sid = extract_field(payload, "SID=");
    if (sid != "")
        info$oracle_sid = sid;

    local prog = extract_field(payload, "PROGRAM=");
    if (prog != "" && /oracle/i in prog)
        info$oracle_version = prog;

    return info;
}

event connection_established(c: connection) {
    if (c$id$resp_p in oracle_ports) {
        local key = fmt("%s:%d->%s:%d", c$id$orig_h, c$id$orig_p, c$id$resp_h, c$id$resp_p);
        connection_start_times[key] = network_time();

        local rec: Oracle::Info = [
            $ts=network_time(),
            $uid=c$uid,
            $id=c$id,
            $connection_state="ESTABLISHED"
        ];

        oracle_connections[key] = rec;
        Log::write(Oracle::LOG, rec);
    }
}

event connection_state_remove(c: connection) {
    if (c$id$resp_p in oracle_ports) {
        local key = fmt("%s:%d->%s:%d", c$id$orig_h, c$id$orig_p, c$id$resp_h, c$id$resp_p);
        if (key in connection_start_times) {
            local duration = network_time() - connection_start_times[key];
            local rec: Oracle::Info = [
                $ts=network_time(),
                $uid=c$uid,
                $id=c$id,
                $connection_state="CLOSED",
                $query_duration=duration
            ];

            if (c?$conn) {
                if (c$conn?$orig_bytes)
                    rec$bytes_sent = c$conn$orig_bytes;
                if (c$conn?$resp_bytes)
                    rec$bytes_received = c$conn$resp_bytes;
            }

            Log::write(Oracle::LOG, rec);
            delete connection_start_times[key];
            delete oracle_connections[key];
        }
    }
}

event tcp_packet(c: connection, is_orig: bool, flags: string, seq: count, ack: count, len: count, payload: string) {
    if (c$id$resp_p in oracle_ports && len > 8) {
        local key = fmt("%s:%d->%s:%d", c$id$orig_h, c$id$orig_p, c$id$resp_h, c$id$resp_p);
        local tns_info = analyze_tns_packet(payload);

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

        if (tns_info?$oracle_command) rec$oracle_command = tns_info$oracle_command;
        if (tns_info?$connection_state) rec$connection_state = tns_info$connection_state;
        if (tns_info?$service_name) rec$service_name = tns_info$service_name;
        if (tns_info?$oracle_sid) rec$oracle_sid = tns_info$oracle_sid;
        if (tns_info?$oracle_version) rec$oracle_version = tns_info$oracle_version;
        if (tns_info?$sql_type) rec$sql_type = tns_info$sql_type;

        Log::write(Oracle::LOG, rec);
    }
}
