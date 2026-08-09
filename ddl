#!/bin/bash
#===============================================================================
# check_mysql_conn_min.sh - minimal MySQL connection-usage check for SCOM
#
# You point it at the CNF file of each instance. It reads socket/port out of
# them (following !include / !includedir) and checks only those instances.
#
# Exit: 0 = OK | 1 = at or above threshold | 2 = error
#===============================================================================

###############################################################################
#                         >>>  CONFIGURE HERE  <<<                            #
###############################################################################

# One CNF file per line - the same file the instance was started with.
#
#   /etc/my.cnf                 plain: socket/port taken from [mysqld]/[server]
#   /etc/my-multi.cnf:mysqld7   mysqld_multi: read group [mysqld7] first
#
# !include and !includedir inside the file ARE followed, so pointing at
# /etc/mysql/my.cnf works even when socket= lives in conf.d/.
# Blank lines and lines starting with # are ignored.
INSTANCES="
/etc/my.cnf
/etc/mysql/inst2.cnf
"

THRESHOLD=80        # alert at or above this percentage

# 1 = print NOTHING and exit 0 when every instance is below the threshold.
#     Only instances at/above THRESHOLD (or that failed) produce output.
# 0 = always print a line per instance (useful when testing by hand).
QUIET_OK=1

# Leave both empty for OS socket auth (script running as root / mysql).
MYSQL_USER=""
MYSQL_PASSWORD=""

###############################################################################

set -u
export LC_ALL=C
CONNECT_TIMEOUT=5

#--- flatten a cnf, following !include / !includedir ---------------------------
flatten() {
    local f="$1" d="${2:-0}" line t x
    [ "${d}" -gt 5 ] && return 0
    [ -f "${f}" ] && [ -r "${f}" ] || return 0
    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
            '!include '*|'!include	'*)
                t="$(printf '%s' "${line#\!include}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                flatten "${t}" $((d + 1)) ;;
            '!includedir '*|'!includedir	'*)
                t="$(printf '%s' "${line#\!includedir}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                for x in "${t}"/*.cnf "${t}"/*.conf; do
                    [ -f "${x}" ] && flatten "${x}" $((d + 1))
                done ;;
            *) printf '%s\n' "${line}" ;;
        esac
    done < "${f}"
}

#--- cnf_get <flattened-text> <key> <section>... : last match wins -------------
cnf_get() {
    local text="$1" key="$2"; shift 2
    printf '%s\n' "${text}" | awk -v want="${key}" -v secs="$*" '
        BEGIN { gsub(/-/, "_", want); want = tolower(want)
                n = split(secs, a, /[ \t]+/)
                for (i = 1; i <= n; i++) { s = tolower(a[i]); gsub(/-/, "_", s); ok[s] = 1 } }
        { l = $0; sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l)
          if (l == "" || l ~ /^[#;]/) next
          if (l ~ /^\[/) { s = l; sub(/^\[[ \t]*/, "", s); sub(/[ \t]*\].*$/, "", s)
                           cur = tolower(s); gsub(/-/, "_", cur); next }
          if (!(cur in ok)) next
          sub(/[ \t]+[#;].*$/, "", l)
          e = index(l, "="); if (e == 0) next
          k = substr(l, 1, e - 1); v = substr(l, e + 1)
          sub(/^[ \t]+/, "", k); sub(/[ \t]+$/, "", k)
          sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
          k = tolower(k); gsub(/-/, "_", k); sub(/^loose_/, "", k)
          if (k != want) next
          if (v ~ /^".*"$/ || v ~ /^'"'"'.*'"'"'$/) v = substr(v, 2, length(v) - 2)
          r = v }
        END { print r }'
}

#--- credentials: private 0600 file, never visible in ps -----------------------
CRED=""
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
    ENTRY="${ENTRY%%#*}"
    ENTRY="$(printf '%s' "${ENTRY}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "${ENTRY}" ] && continue
    TOTAL=$((TOTAL + 1))

    # optional ":group" suffix for mysqld_multi
    CNF="${ENTRY%%:*}"; GROUP=""
    [ "${ENTRY}" != "${CNF}" ] && GROUP="${ENTRY#*:}"
    LABEL="$(basename "${CNF}")"; LABEL="${LABEL%.*}"
    [ -n "${GROUP}" ] && LABEL="${LABEL}:${GROUP}"

    if [ ! -r "${CNF}" ]; then
        ERRORS=$((ERRORS + 1))
        DETAILS="${DETAILS}UNKNOWN  [${LABEL}] cnf not readable: ${CNF}"$'\n'
        continue
    fi

    FLAT="$(flatten "${CNF}")"
    SOCK=""; PORT=""
    if [ -n "${GROUP}" ]; then                       # explicit group wins
        SOCK="$(cnf_get "${FLAT}" socket "${GROUP}")"
        PORT="$(cnf_get "${FLAT}" port   "${GROUP}")"
    fi
    [ -z "${SOCK}" ] && SOCK="$(cnf_get "${FLAT}" socket mysqld server mysqld_safe client client-server)"
    [ -z "${PORT}" ] && PORT="$(cnf_get "${FLAT}" port   mysqld server mysqld_safe client client-server)"

    if [ -n "${SOCK}" ]; then
        CONN=( --protocol=SOCKET "--socket=${SOCK}" ); WHERE="socket=${SOCK}"
    elif [ -n "${PORT}" ]; then
        CONN=( --protocol=TCP --host=127.0.0.1 "--port=${PORT}" ); WHERE="127.0.0.1:${PORT}"
    else
        ERRORS=$((ERRORS + 1))
        DETAILS="${DETAILS}UNKNOWN  [${LABEL}] no socket= or port= found in ${CNF}"$'\n'
        continue
    fi

    RAW="$(timeout 15 mysql ${CRED:+"${CRED}"} "${CONN[@]}" \
             "--connect-timeout=${CONNECT_TIMEOUT}" -NBs -e "${SQL}" 2>&1)"
    RC=$?

    if [ ${RC} -ne 0 ]; then
        # ERROR 1040 proves the instance is full - CRITICAL, not unknown.
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
    LINE="[${LABEL}] used=${CURC} max=${MAXC} free=$(( MAXC - CURC )) usage=${PCT}% peak=${PEAKC} ($(( PK10 / 10 )).$(( PK10 % 10 ))%) ${WHERE} cnf=${CNF}"

    if [ ${X10} -ge $(( THRESHOLD * 10 )) ]; then
        ALERTS=$((ALERTS + 1)); DETAILS="${DETAILS}CRITICAL ${LINE}"$'\n'
    elif [ "${QUIET_OK}" -ne 1 ]; then
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
# Everything is below the threshold: stay completely silent when QUIET_OK=1.
if [ "${QUIET_OK}" -eq 1 ]; then
    exit 0
fi
echo "OK - all ${TOTAL} MySQL instance(s) below ${THRESHOLD}%; highest: ${WORST_TXT}"
printf '%s' "${DETAILS}"; exit 0
