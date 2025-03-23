#!/bin/bash
# ======================================================================
# Oracle DBA Diagnostic Tool - Session Analysis
# ======================================================================
# Version: 3.0
# Description: Functions for analyzing Oracle sessions and locks
# Usage: Source this file or run standalone with ./ora_sessions.sh
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

# Function to check for Oracle locks and sessions
check_sessions_and_locks() {
    display_header "ORACLE SESSIONS AND LOCKS"
    log_message "Checking Oracle sessions and locks"
    
    # Get active session count
    echo -e "${YELLOW}ACTIVE SESSIONS:${NC}"
    sqlplus -s / as sysdba <<EOF
        set linesize 150
        set pagesize 100
        
        select status, count(*) 
        from v\$session
        group by status;
        
        select username, count(*) 
        from v\$session
        where username is not null
        group by username
        order by count(*) desc;
        exit;
EOF

    # Check for blocking sessions
    echo -e "\n${YELLOW}BLOCKING SESSIONS:${NC}"
    log_message "Checking for blocking sessions"
    sqlplus -s / as sysdba <<EOF
        set linesize 200
        set pagesize 1000
        col blocker_sid format 9999
        col blocked_sid format 9999
        col blocker_user format a15
        col blocked_user format a15
        col blocker_status format a10
        col wait_event format a30
        col blocked_sql format a60
        
        select 
            s1.sid blocker_sid,
            s1.username blocker_user,
            s1.status blocker_status,
            s2.sid blocked_sid,
            s2.username blocked_user,
            s2.event wait_event,
            substr(q.sql_text,1,60) blocked_sql
        from 
            v\$lock l1, 
            v\$session s1, 
            v\$lock l2, 
            v\$session s2,
            v\$sql q
        where 
            s1.sid = l1.sid and
            s2.sid = l2.sid and
            l1.block = 1 and
            l2.request > 0 and
            l1.id1 = l2.id1 and
            l1.id2 = l2.id2 and
            s2.sql_id = q.sql_id(+);
        exit;
EOF

    # Check for long running queries
    echo -e "\n${YELLOW}LONG RUNNING QUERIES (OVER 10 MINUTES):${NC}"
    log_message "Checking for long running queries"
    sqlplus -s / as sysdba <<EOF
        set linesize 200
        set pagesize 100
        col username format a15
        col sid format 9999
        col serial# format 99999
        col machine format a20
        col elapsed_time format a15
        col sql_text format a70
        
        select 
            s.username,
            s.sid,
            s.serial#,
            s.machine,
            to_char(floor(s.last_call_et/3600), '09') || ':' || 
            to_char(floor(mod(s.last_call_et,3600)/60), '09') || ':' ||
            to_char(mod(s.last_call_et,60), '09') as elapsed_time,
            substr(q.sql_text,1,70) as sql_text
        from 
            v\$session s,
            v\$sql q
        where 
            s.sql_id = q.sql_id
            and s.status = 'ACTIVE'
            and s.username is not null
            and s.last_call_et > 600
        order by s.last_call_et desc;
        exit;
EOF

    # Check for sessions with high resource usage
    echo -e "\n${YELLOW}SESSIONS WITH HIGH RESOURCE USAGE:${NC}"
    log_message "Checking for sessions with high resource usage"
    sqlplus -s / as sysdba <<EOF
        set linesize 180
        set pagesize 100
        col username format a15
        col sid format 9999
        col program format a30
        col machine format a20
        col logical_reads format 999,999,999
        col physical_reads format 999,999,999
        col cpu_usage format 999,999,999
        
        select 
            s.username, 
            s.sid, 
            s.program, 
            s.machine,
            se.value as logical_reads
        from 
            v\$session s,
            v\$sesstat se,
            v\$statname st
        where 
            s.sid = se.sid
            and se.statistic# = st.statistic#
            and st.name = 'session logical reads'
            and se.value > 1000000
            and s.username is not null
        order by se.value desc;
        
        select 
            s.username, 
            s.sid, 
            s.program, 
            s.machine,
            se.value as physical_reads
        from 
            v\$session s,
            v\$sesstat se,
            v\$statname st
        where 
            s.sid = se.sid
            and se.statistic# = st.statistic#
            and st.name = 'physical reads'
            and se.value > 10000
            and s.username is not null
        order by se.value desc;
        
        select 
            s.username, 
            s.sid, 
            s.program, 
            s.machine,
            se.value as cpu_usage
        from 
            v\$session s,
            v\$sesstat se,
            v\$statname st
        where 
            s.sid = se.sid
            and se.statistic# = st.statistic#
            and st.name = 'CPU used by this session'
            and se.value > 1000000
            and s.username is not null
        order by se.value desc;
        exit;
EOF

    # Check for resource-intensive SQL statements
    echo -e "\n${YELLOW}RESOURCE-INTENSIVE SQL STATEMENTS:${NC}"
    log_message "Checking for resource-intensive SQL statements"
    sqlplus -s / as sysdba <<EOF
        set linesize 180
        set pagesize 100
        col sql_id format a15
        col buffer_gets format 999,999,999
        col disk_reads format 999,999,999
        col executions format 999,999
        col rows_processed format 999,999
        col sql_text format a70
        
        select 
            sql_id,
            buffer_gets,
            disk_reads,
            executions,
            rows_processed,
            substr(sql_text,1,70) as sql_text
        from 
            v\$sqlarea
        where 
            buffer_gets > 1000000
            or disk_reads > 100000
        order by 
            buffer_gets + 10 * disk_reads desc
        fetch first 10 rows only;
        exit;
EOF

    log_message "Completed checking sessions and locks"
}

# Function to kill a specific session
kill_session() {
    local SID=$1
    local SERIAL=$2
    
    if [ -z "$SID" ] || [ -z "$SERIAL" ]; then
        echo -e "${RED}Error: SID and SERIAL# must be provided.${NC}"
        echo -e "Usage: kill_session <sid> <serial#>"
        return 1
    fi
    
    echo -e "${YELLOW}Killing session $SID,$SERIAL...${NC}"
    log_message "Attempting to kill session $SID,$SERIAL"
    
    sqlplus -s / as sysdba <<EOF
        begin
            execute immediate 'alter system kill session ''$SID,$SERIAL'' immediate';
        exception
            when others then
                dbms_output.put_line('Error killing session: ' || sqlerrm);
        end;
        /
        
        set serveroutput on
        begin
            dbms_output.put_line('Session kill command executed. Status:');
        end;
        /
        
        set linesize 150
        set pagesize 100
        col username format a15
        col sid format 9999
        col serial# format 99999
        col status format a10
        col program format a30
        
        select sid, serial#, username, status, program
        from v\$session
        where sid = $SID and serial# = $SERIAL;
        exit;
EOF
}

# Function to display session wait events
display_wait_events() {
    display_header "SESSION WAIT EVENTS"
    log_message "Checking session wait events"
    
    sqlplus -s / as sysdba <<EOF
        set linesize 180
        set pagesize 100
        col event format a40
        col total_waits format 999,999,999
        col time_waited format 999,999,999
        col avg_wait format 9,999.99
        
        prompt ${YELLOW}SYSTEM-WIDE WAIT EVENTS:${NC}
        select 
            event,
            total_waits,
            round(time_waited/100,2) as time_waited_secs,
            round(average_wait/100,2) as avg_wait_ms
        from 
            v\$system_event
        where 
            event not like '%idle%'
            and event not like '%rdbms ipc%'
            and event not like '%SQL*Net%'
            and total_waits > 0
        order by 
            time_waited desc
        fetch first 15 rows only;
        
        prompt 
        prompt ${YELLOW}SESSION WAIT EVENTS:${NC}
        col sid format 9999
        col username format a15
        col event format a35
        col state format a15
        col seconds_in_wait format 999,999
        
        select 
            s.sid,
            s.username,
            s.event,
            s.state,
            s.seconds_in_wait
        from 
            v\$session s
        where 
            s.username is not null
            and s.wait_time = 0
            and s.state != 'WAITING'
        order by 
            s.seconds_in_wait desc
        fetch first 15 rows only;
        exit;
EOF

    log_message "Completed checking session wait events"
}

# Check if this module is being run directly (standalone)
if is_module_standalone; then
    # If run directly, we need instance selection before checking sessions
    clear
    echo -e "${GREEN}Oracle DBA Diagnostic Tool - Session Analysis${NC}"
    echo -e "${YELLOW}Running as: $(whoami) on $(hostname) - OS: $OS_TYPE${NC}"
    echo -e "${YELLOW}Date: $(date)${NC}"
    echo ""
    
    # Load instance_manager if available
    if [ -f "$SCRIPT_DIR/ora_instance.sh" ]; then
        source "$SCRIPT_DIR/ora_instance.sh"
        list_instances  # Select an instance first
    else
        echo -e "${YELLOW}Warning: ora_instance.sh not found. Some functionality may be limited.${NC}"
        # Try to set a default ORACLE_SID from running instances
        if [ -z "$ORACLE_SID" ]; then
            DEFAULT_SID=$(ps -ef | grep pmon | grep -v grep | head -1 | awk '{print $NF}' | sed 's/.*_//g')
            if [ -n "$DEFAULT_SID" ]; then
                export ORACLE_SID=$DEFAULT_SID
                echo -e "${YELLOW}Using detected ORACLE_SID: $ORACLE_SID${NC}"
            fi
        fi
    fi
    
    # Now check sessions
    check_sessions_and_locks
    display_wait_events
    
    # Ask if user wants to kill a session
    echo -e "\n${YELLOW}Would you like to kill a specific session? (y/n):${NC} "
    read KILL_SESSION
    
    if [[ "$KILL_SESSION" == "y" || "$KILL_SESSION" == "Y" ]]; then
        echo -e "Enter SID: "
        read SID
        echo -e "Enter SERIAL#: "
        read SERIAL
        
        if [ -n "$SID" ] && [ -n "$SERIAL" ]; then
            kill_session $SID $SERIAL
        else
            echo -e "${RED}SID and SERIAL# are required to kill a session.${NC}"
        fi
    fi
fi
