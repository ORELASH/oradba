#!/bin/bash
#===============================================================================
# check_mysql_conn_min.sh - minimal MySQL connection-usage check for SCOM
#
# Checks only the instances listed below. Alerts above THRESHOLD percent.
#
# Exit: 0 = OK | 1 = above threshold | 2 = error
#===============================================================================

###############################################################################
#                         >>>  CONFIGURE HERE  <<<                            #
###############################################################################

# One instance per line. Each line may be:
#   /path/to/mysql.sock   - a unix socket
#   3306                  - a TCP port on 127.0.0.1
#   /etc/my.cnf           - a cnf file; socket= / port= are read out of THAT
#                           file only (!include / !includedir are not followed)
# Blank lines and lines starting with # are ignored.
INSTANCES="
/var/lib/mysql/mysql.sock
/var/lib/mysql2/mysql.sock
3308
"

THRESHOLD=80        # alert at or above this percentage

# Leave both empty for OS socket auth (script running as root / mysql).
MYSQL_USER=""
MYSQL_PASSWORD=""

###############################################################################

set -u
export LC_ALL=C

CONNECT_TIMEOUT=5

# --- credentials: written to a private 0600 file, never passed via ps --------
CRED=""
TMP_CNF=""
if [ -n "${MYSQL_USER}" ]; then
    TMP_CNF="$(mktemp "${TMPDIR:-/tmp}/.mysqlmon.XXXXXX")" || { echo "UNKNOWN - mktemp failed"; exit 2; }
    chmod 600 "${TMP_CNF}"
    trap 'rm -f "${TMP_CNF}"' EXIT INT TERM HUP
    { echo "[client]"; echo "user=${MYSQL_USER}"
      [ -n "${MYSQL_PASSWORD}" ] && echo "password=\"${MYSQL_PASSWORD}\""; } > "${TMP_CNF}"
    CRED="--defaults-extra-file=${TMP_CNF}"
fi

command -v mysql >/dev/null 2>&1 || { echo "UNKNOWN - mysql client not found in PATH"; exit 2; }

SQL="SHOW GLOBAL VARIABLES LIKE 'max_connections';
     SHOW GLOBAL STATUS LIKE 'Threads_connected';
     SHOW GLOBAL STATUS LIKE 'Max_used_connections';"

TOTAL=0; ALERTS=0; ERRORS=0; DETAILS=""; WORST=-1; WORST_TXT="n/a"

while read -r ENTRY; do
    ENTRY="${ENTRY%%#*}"; ENTRY="$(echo "${ENTRY}" | tr -d '[:space:]')"
    [ -z "${ENTRY}" ] && continue
    TOTAL=$((TOTAL + 1))

    # --- decide how to connect ------------------------------------------------
    case "${ENTRY}" in
        *.cnf|*.conf)
            SOCK="$(awk -F= '/^[[:space:]]*socket[[:space:]]*=/ {gsub(/[[:space:]"'"'"']/,"",$2); s=$2} END{print s}' "${ENTRY}" 2>/dev/null)"
            PORT="$(awk -F= '/^[[:space:]]*port[[:space:]]*=/   {gsub(/[[:space:]"'"'"']/,"",$2); p=$2} END{print p}' "${ENTRY}" 2>/dev/null)"
            LABEL="$(basename "${ENTRY}")"; LABEL="${LABEL%.*}"
            ;;
        /*) SOCK="${ENTRY}"; PORT=""; LABEL="$(basename "${ENTRY}" .sock)" ;;
        *)  SOCK="";         PORT="${ENTRY}"; LABEL="port${ENTRY}" ;;
    esac

    if [ -n "${SOCK}" ]; then
        CONN=( --protocol=SOCKET "--socket=${SOCK}" ); WHERE="socket=${SOCK}"
    elif [ -n "${PORT}" ]; then
        CONN=( --protocol=TCP --host=127.0.0.1 "--port=${PORT}" ); WHERE="127.0.0.1:${PORT}"
    else
        ERRORS=$((ERRORS + 1))
        DETAILS="${DETAILS}UNKNOWN  [${LABEL}] no socket or port found in ${ENTRY}"$'\n'
        continue
    fi

    # --- query ----------------------------------------------------------------
    RAW="$(timeout 15 mysql ${CRED:+"${CRED}"} "${CONN[@]}" \
             "--connect-timeout=${CONNECT_TIMEOUT}" -NBs -e "${SQL}" 2>&1)"
    RC=$?

    if [ ${RC} -ne 0 ]; then
        # ERROR 1040 proves the instance is full - that is CRITICAL, not unknown.
        if echo "${RAW}" | grep -qE '1040|Too many connections'; then
            ALERTS=$((ALERTS + 1))
            [ 1000 -gt ${WORST} ] && { WORST=1000; WORST_TXT="${LABEL} refused connections (limit reached)"; }
            DETAILS="${DETAILS}CRITICAL [${LABEL}] CONNECTION LIMIT REACHED (ERROR 1040), usage>=100% ${WHERE}"$'\n'
        else
            ERRORS=$((ERRORS + 1))
            DETAILS="${DETAILS}UNKNOWN  [${LABEL}] ${WHERE} - $(echo "${RAW}" | tr '\n' ' ' | cut -c1-140)"$'\n'
        fi
        continue
    fi

    MAXC="$(echo "${RAW}"  | awk '$1=="max_connections"      {print $2; exit}')"
    CURC="$(echo "${RAW}"  | awk '$1=="Threads_connected"    {print $2; exit}')"
    PEAKC="$(echo "${RAW}" | awk '$1=="Max_used_connections" {print $2; exit}')"; PEAKC="${PEAKC:-0}"

    if ! [[ "${MAXC}" =~ ^[0-9]+$ ]] || ! [[ "${CURC}" =~ ^[0-9]+$ ]] || [ "${MAXC}" -eq 0 ]; then
        ERRORS=$((ERRORS + 1))
        DETAILS="${DETAILS}UNKNOWN  [${LABEL}] ${WHERE} - unparsable output"$'\n'
        continue
    fi

    X10=$(( CURC * 1000 / MAXC ))
    PCT="$(( X10 / 10 )).$(( X10 % 10 ))"
    PK10=$(( PEAKC * 1000 / MAXC ))
    LINE="[${LABEL}] used=${CURC} max=${MAXC} free=$(( MAXC - CURC )) usage=${PCT}% peak=${PEAKC} ($(( PK10 / 10 )).$(( PK10 % 10 ))%) ${WHERE}"

    if [ ${X10} -ge $(( THRESHOLD * 10 )) ]; then
        ALERTS=$((ALERTS + 1)); DETAILS="${DETAILS}CRITICAL ${LINE}"$'\n'
    else
        DETAILS="${DETAILS}OK       ${LINE}"$'\n'
    fi
    [ ${X10} -gt ${WORST} ] && { WORST=${X10}; WORST_TXT="${LABEL} at ${PCT}% (${CURC}/${MAXC})"; }
done <<< "${INSTANCES}"

#------------------------------- verdict ---------------------------------------
if [ ${TOTAL} -eq 0 ]; then
    echo "UNKNOWN - the INSTANCES list at the top of the script is empty"; exit 2
fi
if [ ${ALERTS} -gt 0 ]; then
    echo "CRITICAL - ${ALERTS}/${TOTAL} MySQL instance(s) at or above ${THRESHOLD}%; worst: ${WORST_TXT}"
    printf '%s' "${DETAILS}"; exit 1
fi
if [ ${ERRORS} -gt 0 ]; then
    echo "UNKNOWN - ${ERRORS}/${TOTAL} MySQL instance(s) could not be queried"
    printf '%s' "${DETAILS}"; exit 2
fi
echo "OK - all ${TOTAL} MySQL instance(s) below ${THRESHOLD}%; highest: ${WORST_TXT}"
printf '%s' "${DETAILS}"; exit 0
