#!/bin/bash
#===============================================================================
# check_mysql_connections.sh
#
# Purpose : Check MySQL connection usage (Threads_connected / max_connections)
#           and alert when usage crosses a configurable threshold (default 80%).
# Used by : SCOM - Unix/Linux Shell Command Two State Monitor
#
# Exit codes (consumed by SCOM):
#   0 = OK       - usage below threshold
#   1 = ALERT    - usage at or above threshold
#   2 = UNKNOWN  - script/connection error (mysql missing, auth failed, etc.)
#
# Output: single line to STDOUT, suitable for the SCOM alert description.
#
# Credentials: read from a defaults-file (my.cnf style), NOT from the command
# line, so the password never appears in `ps` output.
#   Example /etc/scom/mysql-monitor.cnf  (chmod 600, owned by the SCOM user):
#     [client]
#     user=scom_monitor
#     password=SomeStrongPassword
#     host=127.0.0.1
#     port=3306
#
# Required MySQL grant:
#   CREATE USER 'scom_monitor'@'localhost' IDENTIFIED BY 'SomeStrongPassword';
#   GRANT PROCESS ON *.* TO 'scom_monitor'@'localhost';
#
# Usage:
#   ./check_mysql_connections.sh [-c <defaults-file>] [-w <percent>] [-t <sec>]
#===============================================================================

set -u
set -o pipefail

#------------------------------- Defaults --------------------------------------
DEFAULTS_FILE="${MYSQL_DEFAULTS_FILE:-/etc/scom/mysql-monitor.cnf}"
THRESHOLD="${MYSQL_CONN_THRESHOLD:-80}"     # percent
CONNECT_TIMEOUT=5                            # seconds
MYSQL_BIN=""

#------------------------------- Arguments -------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [options]
  -c <file>     MySQL defaults-file with credentials (default: ${DEFAULTS_FILE})
  -w <percent>  Alert threshold in percent (default: ${THRESHOLD})
  -t <seconds>  Connect timeout (default: ${CONNECT_TIMEOUT})
  -h            Show this help
EOF
}

while getopts ":c:w:t:h" opt; do
    case "${opt}" in
        c) DEFAULTS_FILE="${OPTARG}" ;;
        w) THRESHOLD="${OPTARG}" ;;
        t) CONNECT_TIMEOUT="${OPTARG}" ;;
        h) usage; exit 0 ;;
        \?) echo "UNKNOWN - invalid option: -${OPTARG}"; exit 2 ;;
        :)  echo "UNKNOWN - option -${OPTARG} requires an argument"; exit 2 ;;
    esac
done

#------------------------------- Validation ------------------------------------
if ! [[ "${THRESHOLD}" =~ ^[0-9]+$ ]] || [ "${THRESHOLD}" -lt 1 ] || [ "${THRESHOLD}" -gt 100 ]; then
    echo "UNKNOWN - threshold must be an integer between 1 and 100 (got: ${THRESHOLD})"
    exit 2
fi

for candidate in mysql mariadb; do
    if command -v "${candidate}" >/dev/null 2>&1; then
        MYSQL_BIN="$(command -v "${candidate}")"
        break
    fi
done

if [ -z "${MYSQL_BIN}" ]; then
    echo "UNKNOWN - mysql client not found in PATH"
    exit 2
fi

if [ ! -r "${DEFAULTS_FILE}" ]; then
    echo "UNKNOWN - credentials file not readable: ${DEFAULTS_FILE}"
    exit 2
fi

#------------------------------- Query -----------------------------------------
# One round trip: max_connections, Threads_connected, Max_used_connections.
# --defaults-file must be the FIRST argument to the mysql client.
SQL="SELECT VARIABLE_NAME, VARIABLE_VALUE
     FROM performance_schema.global_variables
     WHERE VARIABLE_NAME = 'max_connections'
     UNION ALL
     SELECT VARIABLE_NAME, VARIABLE_VALUE
     FROM performance_schema.global_status
     WHERE VARIABLE_NAME IN ('Threads_connected','Max_used_connections');"

RAW=$("${MYSQL_BIN}" --defaults-file="${DEFAULTS_FILE}" \
        --connect-timeout="${CONNECT_TIMEOUT}" \
        --batch --skip-column-names --silent \
        -e "${SQL}" 2>&1)
RC=$?

if [ ${RC} -ne 0 ]; then
    # Fall back to SHOW syntax (older servers / performance_schema disabled)
    RAW=$("${MYSQL_BIN}" --defaults-file="${DEFAULTS_FILE}" \
            --connect-timeout="${CONNECT_TIMEOUT}" \
            --batch --skip-column-names --silent \
            -e "SHOW GLOBAL VARIABLES LIKE 'max_connections';
                SHOW GLOBAL STATUS LIKE 'Threads_connected';
                SHOW GLOBAL STATUS LIKE 'Max_used_connections';" 2>&1)
    RC=$?
fi

if [ ${RC} -ne 0 ]; then
    ERR=$(echo "${RAW}" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-200)
    echo "UNKNOWN - failed to query MySQL (rc=${RC}): ${ERR}"
    exit 2
fi

MAX_CONN=$(echo "${RAW}"  | awk '$1=="max_connections"      {print $2; exit}')
CUR_CONN=$(echo "${RAW}"  | awk '$1=="Threads_connected"    {print $2; exit}')
PEAK_CONN=$(echo "${RAW}" | awk '$1=="Max_used_connections" {print $2; exit}')
PEAK_CONN="${PEAK_CONN:-0}"

if ! [[ "${MAX_CONN}" =~ ^[0-9]+$ ]] || ! [[ "${CUR_CONN}" =~ ^[0-9]+$ ]] || [ "${MAX_CONN}" -eq 0 ]; then
    echo "UNKNOWN - could not parse MySQL output (max_connections='${MAX_CONN}', Threads_connected='${CUR_CONN}')"
    exit 2
fi

#------------------------------- Calculation -----------------------------------
# Integer math with one decimal place, no dependency on bc/python.
PCT_X10=$(( CUR_CONN * 1000 / MAX_CONN ))
USED_PCT="$(( PCT_X10 / 10 )).$(( PCT_X10 % 10 ))"
FREE_CONN=$(( MAX_CONN - CUR_CONN ))
PEAK_PCT_X10=$(( PEAK_CONN * 1000 / MAX_CONN ))
PEAK_PCT="$(( PEAK_PCT_X10 / 10 )).$(( PEAK_PCT_X10 % 10 ))"

DETAILS="used=${CUR_CONN} max=${MAX_CONN} free=${FREE_CONN} usage=${USED_PCT}% threshold=${THRESHOLD}% peak_since_start=${PEAK_CONN} (${PEAK_PCT}%)"

#------------------------------- Verdict ---------------------------------------
if [ "${PCT_X10}" -ge $(( THRESHOLD * 10 )) ]; then
    echo "CRITICAL - MySQL connections above ${THRESHOLD}%: ${DETAILS}"
    exit 1
fi

echo "OK - MySQL connections normal: ${DETAILS}"
exit 0
