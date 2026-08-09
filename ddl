#!/bin/bash
#===============================================================================
# check_mysql_connections.sh
#
# Purpose : Auto-discover EVERY MySQL/MariaDB instance running on this server,
#           check connection usage (Threads_connected / max_connections) on each
#           one, and alert when any instance crosses a threshold (default 80%).
#
# Used by : SCOM - Unix/Linux Shell Command Two State Monitor
#
# Self-contained: no external config file, no companion files, no bc/python.
# Runs as-is under an OS user that has local access to the MySQL instances
# (typically root or the mysql user, using unix_socket / auth_socket auth).
#
# Discovery logic:
#   1. Find every running mysqld / mariadbd process (excluding mysqld_safe).
#   2. Read its exact argv from /proc/<pid>/cmdline (falls back to ps).
#   3. Take --socket / --port / --defaults-file straight off the command line.
#   4. Whatever is missing there is resolved by parsing that instance's .cnf
#      file (following !include / !includedir, honouring --defaults-group-suffix
#      and [mysqld] / [server] / [mysqldN] groups).
#   5. Connect per instance over its own socket (or 127.0.0.1:port).
#
# Exit codes (consumed by SCOM):
#   0 = OK       - all instances below threshold
#   1 = ALERT    - at least one instance at/above threshold
#   2 = UNKNOWN  - no instance found, or an instance could not be queried
#
# Output: line 1 = summary for the SCOM alert description,
#         following lines = one detail line per instance.
#
# Usage:
#   ./check_mysql_connections.sh [-w 80] [-t 5] [-i <filter>] [-u user]
#                                [-e <cred-file>] [-l] [-v] [-h]
#===============================================================================

set -u
set -o pipefail
export LC_ALL=C

###############################################################################
#                        >>>  CREDENTIALS - EDIT HERE  <<<                    #
#                                                                             #
# Leave BOTH empty to use OS-level socket authentication (auth_socket /       #
# unix_socket) - recommended when the script runs as root or as mysql.        #
#                                                                             #
# Otherwise put the monitoring user + password here. The password is never    #
# passed on the command line: the script writes a private 0600 temp option    #
# file and removes it on exit, so it never shows up in `ps`.                  #
#                                                                             #
# These can also be supplied at runtime, without touching the file, via the   #
# MYSQL_MON_USER / MYSQL_MON_PASSWORD environment variables or the -u flag.   #
###############################################################################
MYSQL_USER="${MYSQL_MON_USER:-}"
MYSQL_PASSWORD="${MYSQL_MON_PASSWORD:-}"

###############################################################################
# Optional: per-instance credentials, when different instances use different  #
# users/passwords. Match on the instance label (see `-l`), its socket path,   #
# its port, or its cnf path. First match wins; falls through to the globals   #
# above when nothing matches. Format of the echoed value: user<TAB>password   #
###############################################################################
creds_for_instance() {
    local label="$1" socket="$2" port="$3" cnf="$4"
    case "${label}|${socket}|${port}|${cnf}" in
        # --- examples, uncomment and adapt -----------------------------------
        # *"|3307|"*)            printf 'scom_mon\tPassForPort3307' ;;
        # "prod_db|"*)           printf 'scom_mon\tPassForProd'     ;;
        # *"/etc/mysql/qa.cnf")  printf 'qa_monitor\tQaPass'        ;;
        *) return 1 ;;
    esac
}
###############################################################################

#------------------------------- Defaults --------------------------------------
THRESHOLD=80          # alert percentage
CONNECT_TIMEOUT=5     # mysql client connect timeout (seconds)
HARD_TIMEOUT=15       # wall-clock kill switch per instance (seconds)
FILTER=""             # only check instances matching this string
EXTRA_CRED_FILE=""    # optional --defaults-extra-file for credentials
LIST_ONLY=0
VERBOSE=0
MAX_INCLUDE_DEPTH=10

#--------------------- private temp option file (0600) --------------------------
# Created eagerly in the PARENT shell so the EXIT trap always knows the path -
# make_cred_file() runs inside command substitution (a subshell), so a lazily
# assigned path would never reach the trap and the file would be left behind.
TMP_CNF="$(mktemp "${TMPDIR:-/tmp}/.mysqlmon.XXXXXXXX" 2>/dev/null)" || TMP_CNF=""
[ -n "${TMP_CNF}" ] && chmod 600 "${TMP_CNF}" 2>/dev/null
cleanup() { [ -n "${TMP_CNF}" ] && rm -f "${TMP_CNF}"; return 0; }
trap cleanup EXIT INT TERM HUP

# make_cred_file <user> <password>  -> path of the 0600 option file
make_cred_file() {
    local u="$1" p="$2"
    [ -n "${TMP_CNF}" ] || return 1
    {
        echo "[client]"
        echo "user=${u}"
        [ -n "${p}" ] && echo "password=\"${p}\""
    } > "${TMP_CNF}"
    printf '%s' "${TMP_CNF}"
}

SCRIPT_NAME="$(basename "$0")"

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]

  -w <percent>  Alert threshold, 1-100            (default: ${THRESHOLD})
  -t <seconds>  MySQL connect timeout             (default: ${CONNECT_TIMEOUT})
  -T <seconds>  Hard timeout per instance         (default: ${HARD_TIMEOUT})
  -i <filter>   Only check instances whose id/socket/port/cnf matches <filter>
  -u <user>     MySQL monitoring user (overrides MYSQL_USER at top of script)
  -e <file>     Ready-made option file with the credentials, used as
                --defaults-extra-file. Highest priority. Example content:
                    [client]
                    user=scom_monitor
                    password=SomeStrongPassword
  -l            List discovered instances and exit (no checks, exit 0)
  -v            Verbose: print discovery details to stderr
  -h            This help

Password sources, in priority order:
  1. -e <file>
  2. creds_for_instance() at the top of this script (per-instance)
  3. MYSQL_USER / MYSQL_PASSWORD at the top of this script,
     or the MYSQL_MON_USER / MYSQL_MON_PASSWORD environment variables
  4. nothing -> OS socket auth, plus ~/.my.cnf of the user running the script

There is deliberately no -p flag: a password given on the command line is
visible to every user on the box via ps.

Exit codes: 0 = OK, 1 = threshold exceeded, 2 = unknown / error
EOF
}

while getopts ":w:t:T:i:u:e:lvh" opt; do
    case "${opt}" in
        w) THRESHOLD="${OPTARG}" ;;
        t) CONNECT_TIMEOUT="${OPTARG}" ;;
        T) HARD_TIMEOUT="${OPTARG}" ;;
        i) FILTER="${OPTARG}" ;;
        u) MYSQL_USER="${OPTARG}" ;;
        e) EXTRA_CRED_FILE="${OPTARG}" ;;
        l) LIST_ONLY=1 ;;
        v) VERBOSE=1 ;;
        h) usage; exit 0 ;;
        \?) echo "UNKNOWN - invalid option: -${OPTARG}"; exit 2 ;;
        :)  echo "UNKNOWN - option -${OPTARG} requires an argument"; exit 2 ;;
    esac
done

log() { [ "${VERBOSE}" -eq 1 ] && echo "[debug] $*" >&2; return 0; }

#------------------------------- Validation ------------------------------------
if ! [[ "${THRESHOLD}" =~ ^[0-9]+$ ]] || [ "${THRESHOLD}" -lt 1 ] || [ "${THRESHOLD}" -gt 100 ]; then
    echo "UNKNOWN - threshold must be an integer between 1 and 100 (got: ${THRESHOLD})"
    exit 2
fi
for v in CONNECT_TIMEOUT HARD_TIMEOUT; do
    if ! [[ "${!v}" =~ ^[0-9]+$ ]] || [ "${!v}" -lt 1 ]; then
        echo "UNKNOWN - ${v} must be a positive integer (got: ${!v})"
        exit 2
    fi
done
if [ -n "${EXTRA_CRED_FILE}" ] && [ ! -r "${EXTRA_CRED_FILE}" ]; then
    echo "UNKNOWN - credentials file not readable: ${EXTRA_CRED_FILE}"
    exit 2
fi

# Locate a client binary
MYSQL_BIN=""
for c in mysql mariadb; do
    if command -v "${c}" >/dev/null 2>&1; then MYSQL_BIN="$(command -v "${c}")"; break; fi
done
if [ -z "${MYSQL_BIN}" ]; then
    for c in /usr/bin/mysql /usr/local/mysql/bin/mysql /usr/bin/mariadb /opt/mysql/bin/mysql; do
        if [ -x "${c}" ]; then MYSQL_BIN="${c}"; break; fi
    done
fi
if [ -z "${MYSQL_BIN}" ]; then
    echo "UNKNOWN - mysql/mariadb client binary not found in PATH"
    exit 2
fi

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="$(command -v timeout)"

#=============================== CNF PARSING ===================================
# Flatten an option file, following !include / !includedir recursively.
flatten_cnf() {
    local file="$1" depth="${2:-0}" line target d f
    [ "${depth}" -gt "${MAX_INCLUDE_DEPTH}" ] && return 0
    [ -f "${file}" ] && [ -r "${file}" ] || return 0
    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
            '!include '*|'!include	'*)
                target="${line#\!include}"
                target="$(printf '%s' "${target}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                flatten_cnf "${target}" $((depth + 1))
                ;;
            '!includedir '*|'!includedir	'*)
                d="${line#\!includedir}"
                d="$(printf '%s' "${d}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
                for f in "${d}"/*.cnf "${d}"/*.conf; do
                    [ -f "${f}" ] && flatten_cnf "${f}" $((depth + 1))
                done
                ;;
            *)
                printf '%s\n' "${line}"
                ;;
        esac
    done < "${file}"
}

# cnf_value <flattened-text> <key> <section1> [section2 ...]
# Returns the LAST matching value (MySQL semantics: last wins).
# Key matching normalises '-' vs '_' and the 'loose-' prefix.
cnf_value() {
    local text="$1" key="$2"; shift 2
    local sections="$*"
    printf '%s\n' "${text}" | awk -v want_key="${key}" -v want_secs="${sections}" '
        BEGIN {
            gsub(/[-]/, "_", want_key); want_key = tolower(want_key)
            n = split(want_secs, arr, /[ \t]+/)
            for (i = 1; i <= n; i++) { s = tolower(arr[i]); gsub(/[-]/, "_", s); ok[s] = 1 }
            cur = ""; result = ""
        }
        {
            line = $0
            sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line)
            if (line == "" || line ~ /^[#;]/) next
            if (line ~ /^\[/) {
                s = line
                sub(/^\[[ \t]*/, "", s); sub(/[ \t]*\].*$/, "", s)
                cur = tolower(s); gsub(/[-]/, "_", cur)
                next
            }
            if (!(cur in ok)) next
            sub(/[ \t]+[#;].*$/, "", line)
            eq = index(line, "=")
            if (eq == 0) next
            k = substr(line, 1, eq - 1); v = substr(line, eq + 1)
            sub(/^[ \t]+/, "", k); sub(/[ \t]+$/, "", k)
            sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
            k = tolower(k); gsub(/[-]/, "_", k); sub(/^loose_/, "", k)
            if (k != want_key) next
            if (v ~ /^".*"$/ || v ~ /^'"'"'.*'"'"'$/) v = substr(v, 2, length(v) - 2)
            result = v
        }
        END { print result }
    '
}

# Default option-file search path, used when the server has no --defaults-file.
default_cnf_files() {
    printf '%s\n' /etc/my.cnf /etc/mysql/my.cnf /etc/mysql/mariadb.cnf \
                  /usr/etc/my.cnf /usr/local/mysql/etc/my.cnf
}

#=============================== DISCOVERY =====================================
# Emits one TAB-separated record per instance:
#   pid <TAB> cnf <TAB> socket <TAB> port <TAB> host <TAB> label
discover_instances() {
    local pids pid argv arg
    local cnf socket port datadir label group_suffix flat sec_list sec_suffixed k val s f

    # Collect candidate PIDs: real server processes only, not mysqld_safe.
    pids="$(ps -eo pid=,comm= 2>/dev/null \
            | awk '$2 ~ /^(mysqld|mariadbd|mysqld-debug|mysqld-nt)$/ {print $1}')"
    if [ -z "${pids}" ]; then
        pids="$(ps -eo pid=,args= 2>/dev/null \
                | grep -E '(^|/)(mysqld|mariadbd)( |$)' \
                | grep -v -E 'mysqld_safe|mysqld_multi|check_mysql_connections' \
                | awk '{print $1}')"
    fi
    [ -z "${pids}" ] && return 0

    for pid in ${pids}; do
        cnf=""; socket=""; port=""; datadir=""; group_suffix=""

        # --- exact argv, NUL-separated on Linux -------------------------------
        if [ -r "/proc/${pid}/cmdline" ]; then
            argv="$(tr '\0' '\n' < "/proc/${pid}/cmdline")"
        else
            argv="$(ps -o args= -p "${pid}" 2>/dev/null | tr ' ' '\n')"
        fi

        while IFS= read -r arg; do
            case "${arg}" in
                --defaults-file=*)        cnf="${arg#*=}" ;;
                --defaults-extra-file=*)  [ -z "${cnf}" ] && cnf="${arg#*=}" ;;
                --defaults-group-suffix=*) group_suffix="${arg#*=}" ;;
                --socket=*)               socket="${arg#*=}" ;;
                --port=*)                 port="${arg#*=}" ;;
                --datadir=*)              datadir="${arg#*=}" ;;
            esac
        done <<< "${argv}"

        # --- fall back to the standard option-file search path ----------------
        if [ -z "${cnf}" ]; then
            while IFS= read -r f; do
                if [ -f "${f}" ] && [ -r "${f}" ]; then cnf="${f}"; break; fi
            done < <(default_cnf_files)
        fi

        # --- fill the gaps from the cnf ---------------------------------------
        # A --defaults-group-suffix group always wins over the plain group, so it
        # is looked up first and the base groups are only a fallback.
        sec_list="mysqld server mysqld_safe"
        sec_suffixed=""
        [ -n "${group_suffix}" ] && sec_suffixed="mysqld${group_suffix} server${group_suffix}"
        if [ -n "${cnf}" ] && [ -r "${cnf}" ]; then
            flat="$(flatten_cnf "${cnf}")"
            for k in socket port datadir; do
                [ -n "$(eval "printf '%s' \"\${${k}}\"")" ] && continue
                val=""
                [ -n "${sec_suffixed}" ] && val="$(cnf_value "${flat}" "${k}" ${sec_suffixed})"
                [ -z "${val}" ] && val="$(cnf_value "${flat}" "${k}" ${sec_list})"
                [ -n "${val}" ] && eval "${k}=\"\${val}\""
            done
        fi

        # --- last resort: probe the well-known socket locations ----------------
        if [ -z "${socket}" ]; then
            for s in /var/lib/mysql/mysql.sock /var/run/mysqld/mysqld.sock \
                     /run/mysqld/mysqld.sock /tmp/mysql.sock; do
                [ -S "${s}" ] && { socket="${s}"; break; }
            done
        fi
        [ -z "${port}" ] && port="3306"

        # --- human-readable instance label ------------------------------------
        if [ -n "${socket}" ]; then
            label="$(basename "${socket}")"; label="${label%.sock}"
        elif [ -n "${datadir}" ]; then
            label="$(basename "${datadir%/}")"
        else
            label="port${port}"
        fi
        [ -n "${group_suffix}" ] && label="${label}${group_suffix}"

        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
               "${pid}" "${cnf:--}" "${socket:--}" "${port}" "127.0.0.1" "${label}"
    done
}

#=============================== QUERY =========================================
# resolve_creds <label> <socket> <port> <cnf>
# Echoes the --defaults-extra-file argument to use (may be empty).
resolve_creds() {
    local label="$1" socket="$2" port="$3" cnf="$4"
    local pair u p

    # 1. explicit -e file wins
    if [ -n "${EXTRA_CRED_FILE}" ]; then
        printf '%s' "--defaults-extra-file=${EXTRA_CRED_FILE}"
        return 0
    fi

    # 2. per-instance credentials
    if pair="$(creds_for_instance "${label}" "${socket}" "${port}" "${cnf}")"; then
        u="${pair%%$'\t'*}"; p="${pair#*$'\t'}"
        [ "${p}" = "${pair}" ] && p=""
        printf '%s' "--defaults-extra-file=$(make_cred_file "${u}" "${p}")"
        return 0
    fi

    # 3. global user/password
    if [ -n "${MYSQL_USER}" ]; then
        printf '%s' "--defaults-extra-file=$(make_cred_file "${MYSQL_USER}" "${MYSQL_PASSWORD}")"
        return 0
    fi

    # 4. nothing -> socket auth + the caller's ~/.my.cnf
    printf ''
}

# run_mysql <socket> <port> <sql> <cred-arg>
run_mysql() {
    local socket="$1" port="$2" sql="$3" cred="${4:-}"
    local -a args=()

    # --defaults-extra-file must be the first argument if used.
    [ -n "${cred}" ] && args+=( "${cred}" )

    if [ -n "${socket}" ] && [ "${socket}" != "-" ]; then
        args+=( "--protocol=SOCKET" "--socket=${socket}" )
    else
        args+=( "--protocol=TCP" "--host=127.0.0.1" "--port=${port}" )
    fi
    args+=( "--connect-timeout=${CONNECT_TIMEOUT}" --batch --skip-column-names --silent
            --unbuffered -e "${sql}" )

    if [ -n "${TIMEOUT_BIN}" ]; then
        "${TIMEOUT_BIN}" -s TERM "${HARD_TIMEOUT}" "${MYSQL_BIN}" "${args[@]}" 2>&1
    else
        "${MYSQL_BIN}" "${args[@]}" 2>&1
    fi
}

SQL_PS="SELECT VARIABLE_NAME, VARIABLE_VALUE FROM performance_schema.global_variables
        WHERE VARIABLE_NAME='max_connections'
        UNION ALL
        SELECT VARIABLE_NAME, VARIABLE_VALUE FROM performance_schema.global_status
        WHERE VARIABLE_NAME IN ('Threads_connected','Max_used_connections','Uptime');"

SQL_SHOW="SHOW GLOBAL VARIABLES LIKE 'max_connections';
          SHOW GLOBAL STATUS LIKE 'Threads_connected';
          SHOW GLOBAL STATUS LIKE 'Max_used_connections';
          SHOW GLOBAL STATUS LIKE 'Uptime';"

#=============================== MAIN ==========================================
INSTANCES="$(discover_instances)"

if [ -z "${INSTANCES}" ]; then
    echo "UNKNOWN - no running mysqld/mariadbd process found on $(hostname -s 2>/dev/null || hostname)"
    exit 2
fi

if [ -n "${FILTER}" ]; then
    INSTANCES="$(printf '%s\n' "${INSTANCES}" | grep -F -- "${FILTER}")"
    if [ -z "${INSTANCES}" ]; then
        echo "UNKNOWN - no MySQL instance matches filter '${FILTER}'"
        exit 2
    fi
fi

if [ "${LIST_ONLY}" -eq 1 ]; then
    echo "Discovered MySQL instances:"
    printf '%s\n' "${INSTANCES}" | while IFS=$'\t' read -r pid cnf socket port host label; do
        printf '  label=%-24s pid=%-7s port=%-6s socket=%-32s cnf=%s\n' \
               "${label}" "${pid}" "${port}" "${socket}" "${cnf}"
    done
    exit 0
fi

TOTAL=0; ALERTS=0; ERRORS=0
DETAILS=""
WORST_PCT_X10=-1
WORST_LINE=""

while IFS=$'\t' read -r PID CNF SOCKET PORT HOST LABEL; do
    [ -z "${PID:-}" ] && continue
    TOTAL=$((TOTAL + 1))
    log "instance ${LABEL}: pid=${PID} socket=${SOCKET} port=${PORT} cnf=${CNF}"

    CRED="$(resolve_creds "${LABEL}" "${SOCKET}" "${PORT}" "${CNF}")"
    log "instance ${LABEL}: creds=${CRED:-<socket auth>}"

    RAW="$(run_mysql "${SOCKET}" "${PORT}" "${SQL_PS}" "${CRED}")"; RC=$?
    if [ ${RC} -ne 0 ]; then
        RAW="$(run_mysql "${SOCKET}" "${PORT}" "${SQL_SHOW}" "${CRED}")"; RC=$?
    fi

    if [ ${RC} -ne 0 ]; then
        ERRORS=$((ERRORS + 1))
        ERR="$(printf '%s' "${RAW}" | tr '\n' ' ' | sed 's/  */ /g; s/^ //' | cut -c1-160)"
        DETAILS="${DETAILS}UNKNOWN  [${LABEL}] pid=${PID} cnf=${CNF} - query failed (rc=${RC}): ${ERR}"$'\n'
        continue
    fi

    MAXC="$(printf  '%s\n' "${RAW}" | awk -F'\t' '$1=="max_connections"      {print $2; exit}')"
    CURC="$(printf  '%s\n' "${RAW}" | awk -F'\t' '$1=="Threads_connected"    {print $2; exit}')"
    PEAKC="$(printf '%s\n' "${RAW}" | awk -F'\t' '$1=="Max_used_connections" {print $2; exit}')"
    UPT="$(printf   '%s\n' "${RAW}" | awk -F'\t' '$1=="Uptime"               {print $2; exit}')"
    PEAKC="${PEAKC:-0}"; UPT="${UPT:-0}"

    if ! [[ "${MAXC}" =~ ^[0-9]+$ ]] || ! [[ "${CURC}" =~ ^[0-9]+$ ]] || [ "${MAXC}" -eq 0 ]; then
        ERRORS=$((ERRORS + 1))
        DETAILS="${DETAILS}UNKNOWN  [${LABEL}] pid=${PID} - unparsable output (max='${MAXC}' cur='${CURC}')"$'\n'
        continue
    fi

    PCT_X10=$(( CURC * 1000 / MAXC ))
    PCT="$(( PCT_X10 / 10 )).$(( PCT_X10 % 10 ))"
    PEAK_X10=$(( PEAKC * 1000 / MAXC ))
    PEAK_PCT="$(( PEAK_X10 / 10 )).$(( PEAK_X10 % 10 ))"
    FREE=$(( MAXC - CURC ))

    CONN_DESC="socket=${SOCKET}"
    [ "${SOCKET}" = "-" ] && CONN_DESC="tcp=${HOST}:${PORT}"

    LINE="[${LABEL}] used=${CURC} max=${MAXC} free=${FREE} usage=${PCT}% peak=${PEAKC} (${PEAK_PCT}%) pid=${PID} ${CONN_DESC} cnf=${CNF} uptime=${UPT}s"

    if [ "${PCT_X10}" -ge $(( THRESHOLD * 10 )) ]; then
        ALERTS=$((ALERTS + 1))
        DETAILS="${DETAILS}CRITICAL ${LINE}"$'\n'
    else
        DETAILS="${DETAILS}OK       ${LINE}"$'\n'
    fi

    if [ "${PCT_X10}" -gt "${WORST_PCT_X10}" ]; then
        WORST_PCT_X10="${PCT_X10}"
        WORST_LINE="${LABEL} at ${PCT}% (${CURC}/${MAXC})"
    fi
done <<< "${INSTANCES}"

#------------------------------- Verdict ---------------------------------------
if [ "${ALERTS}" -gt 0 ]; then
    echo "CRITICAL - ${ALERTS}/${TOTAL} MySQL instance(s) at or above ${THRESHOLD}% connection usage; worst: ${WORST_LINE}"
    printf '%s' "${DETAILS}"
    exit 1
fi

if [ "${ERRORS}" -gt 0 ]; then
    echo "UNKNOWN - ${ERRORS}/${TOTAL} MySQL instance(s) could not be queried"
    printf '%s' "${DETAILS}"
    exit 2
fi

echo "OK - all ${TOTAL} MySQL instance(s) below ${THRESHOLD}% connection usage; highest: ${WORST_LINE}"
printf '%s' "${DETAILS}"
exit 0
