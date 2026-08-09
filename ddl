#!/bin/bash
#===============================================================================
# check_mysql_conn_min.sh - minimal MySQL connection-usage check for SCOM
#
# You point it at the CNF file of each instance. It reads socket/port out of
# them (following !include / !includedir) and checks only those instances.
#
# Exit: 0 = OK | 1 = at or above threshold | 2 = error
#
# Portability: plain POSIX shell. No arrays, no [[ ]], no <<< herestrings,
# no $'..' quoting, no "set -u". Runs identically under bash 3/4/5, dash,
# ksh and busybox ash, so the shell the SCOM agent picks does not matter.
#===============================================================================

###############################################################################
#                         >>>  CONFIGURE HERE  <<<                            #
###############################################################################

# One CNF file per line - the same file the instance was started with.
# Optionally prefix it with NAME= to control the name shown in the alert;
# without a prefix the name is the cnf filename without its extension.
#
#   PROD1=/etc/my-prod1.cnf     reported as: PROD1
#   /etc/my.cnf                 reported as: my
#   QA=/etc/my-multi.cnf:mysqld7   mysqld_multi: read group [mysqld7] first
#
# !include and !includedir inside the file ARE followed, so pointing at
# /etc/mysql/my.cnf works even when socket= lives in conf.d/.
# Blank lines and lines starting with # are ignored.
INSTANCES="
PROD1=/etc/my-prod1.cnf
PROD2=/etc/my-prod2.cnf
"

THRESHOLD=80        # alert at or above this percentage

# 1 = print NOTHING and exit 0 when every instance is below the threshold.
# 0 = always print a line per instance (useful when testing by hand).
QUIET_OK=1

# Leave both empty for OS socket auth (script running as root / mysql).
MYSQL_USER=""
MYSQL_PASSWORD=""

###############################################################################

LC_ALL=C; export LC_ALL
CONNECT_TIMEOUT=5
HARD_TIMEOUT=15

NL='
'

#--- cnf_get <file> <key> <section>... -----------------------------------------
# Reads the option file, following !include / !includedir, and prints the last
# value of <key> found in any of the listed groups. Done entirely in awk: awk
# functions have real local variables (the extra parameters), so the recursion
# through included files cannot clobber its own state the way a POSIX shell
# function without "local" would.
cnf_get() {
    _file="$1"; _key="$2"; shift 2
    awk -v startfile="$_file" -v want="$_key" -v secs="$*" '
        function flat(f, depth,    line, t, cmd, x) {
            if (depth > 5) return
            while ((getline line < f) > 0) {
                if (line ~ /^[ \t]*!include[ \t]/) {
                    t = line
                    sub(/^[ \t]*!include[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
                    flat(t, depth + 1)
                } else if (line ~ /^[ \t]*!includedir[ \t]/) {
                    t = line
                    sub(/^[ \t]*!includedir[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
                    sub(/\/+$/, "", t)
                    cmd = "ls -1 " t "/*.cnf " t "/*.conf 2>/dev/null"
                    while ((cmd | getline x) > 0) flat(x, depth + 1)
                    close(cmd)
                } else {
                    handle(line)
                }
            }
            close(f)
        }
        function handle(l,    s, e, k, v) {
            sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l)
            if (l == "" || l ~ /^[#;]/) return
            if (l ~ /^\[/) {
                s = l; sub(/^\[[ \t]*/, "", s); sub(/[ \t]*\].*$/, "", s)
                cur = tolower(s); gsub(/-/, "_", cur); return
            }
            if (!(cur in ok)) return
            sub(/[ \t]+[#;].*$/, "", l)
            e = index(l, "="); if (e == 0) return
            k = substr(l, 1, e - 1); v = substr(l, e + 1)
            sub(/^[ \t]+/, "", k); sub(/[ \t]+$/, "", k)
            sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
            k = tolower(k); gsub(/-/, "_", k); sub(/^loose_/, "", k)
            if (k != want) return
            if (v ~ /^".*"$/ || v ~ /^'"'"'.*'"'"'$/) v = substr(v, 2, length(v) - 2)
            r = v
        }
        BEGIN {
            gsub(/-/, "_", want); want = tolower(want)
            n = split(secs, a, /[ \t]+/)
            for (i = 1; i <= n; i++) { s = tolower(a[i]); gsub(/-/, "_", s); ok[s] = 1 }
            cur = ""; r = ""
            flat(startfile, 0)
            print r
        }'
}

#--- is_number <string> --------------------------------------------------------
is_number() {
    case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

#--- credentials: private 0600 file, never visible in ps -----------------------
CRED=""
TMP_CNF=""
if [ -n "$MYSQL_USER" ]; then
    TMP_CNF=$(mktemp "${TMPDIR:-/tmp}/.mysqlmon.XXXXXX" 2>/dev/null)
    if [ -z "$TMP_CNF" ]; then
        echo "UNKNOWN - cannot create a temporary credentials file"; exit 2
    fi
    chmod 600 "$TMP_CNF" 2>/dev/null
    trap 'rm -f "$TMP_CNF"' EXIT INT TERM HUP
    echo "[client]"          >  "$TMP_CNF"
    echo "user=$MYSQL_USER"  >> "$TMP_CNF"
    if [ -n "$MYSQL_PASSWORD" ]; then
        echo "password=\"$MYSQL_PASSWORD\"" >> "$TMP_CNF"
    fi
    CRED="--defaults-extra-file=$TMP_CNF"
fi

# mysql client
MYSQL_BIN=""
for _c in mysql mariadb /usr/bin/mysql /usr/local/mysql/bin/mysql; do
    if command -v "$_c" >/dev/null 2>&1; then MYSQL_BIN="$_c"; break; fi
done
if [ -z "$MYSQL_BIN" ]; then
    echo "UNKNOWN - mysql client not found in PATH"; exit 2
fi

# timeout is optional - not present on every box
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout $HARD_TIMEOUT"
fi

SQL="SHOW GLOBAL VARIABLES LIKE 'max_connections';
     SHOW GLOBAL STATUS LIKE 'Threads_connected';
     SHOW GLOBAL STATUS LIKE 'Max_used_connections';"

TOTAL=0; ALERTS=0; ERRORS=0; DETAILS=""; WORST=-1; WORST_TXT="n/a"

while read -r ENTRY; do
    ENTRY=$(printf '%s' "$ENTRY" | sed 's/#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$ENTRY" ] && continue
    TOTAL=$((TOTAL + 1))

    # optional "NAME=" prefix
    NAME=""; REST="$ENTRY"
    case "$ENTRY" in
        *=*) NAME=$(printf '%s' "$ENTRY" | sed 's/=.*//;      s/[[:space:]]*$//')
             REST=$(printf '%s' "$ENTRY" | sed 's/^[^=]*=//;  s/^[[:space:]]*//') ;;
    esac

    # optional ":group" suffix for mysqld_multi
    CNF=$(printf '%s' "$REST" | sed 's/:[^:]*$//')
    GROUP=""
    case "$REST" in *:*) GROUP=$(printf '%s' "$REST" | sed 's/.*://') ;; esac

    # the name that shows up in the alert
    LABEL="$NAME"
    if [ -z "$LABEL" ]; then
        LABEL=$(basename "$CNF" | sed 's/\.[^.]*$//')
        [ -n "$GROUP" ] && LABEL="$LABEL:$GROUP"
    fi

    if [ ! -r "$CNF" ]; then
        ERRORS=$((ERRORS + 1))
        DETAILS="$DETAILS$LABEL - cnf not readable: $CNF$NL"
        continue
    fi

    SOCK=""; PORT=""
    if [ -n "$GROUP" ]; then                       # explicit group wins
        SOCK=$(cnf_get "$CNF" socket "$GROUP")
        PORT=$(cnf_get "$CNF" port   "$GROUP")
    fi
    [ -z "$SOCK" ] && SOCK=$(cnf_get "$CNF" socket mysqld server mysqld_safe client client-server)
    [ -z "$PORT" ] && PORT=$(cnf_get "$CNF" port   mysqld server mysqld_safe client client-server)

    # ---- query (no arrays: two explicit invocations) -------------------------
    if [ -n "$SOCK" ]; then
        WHERE="socket=$SOCK"
        RAW=$($TIMEOUT_CMD "$MYSQL_BIN" $CRED --protocol=SOCKET --socket="$SOCK" \
                --connect-timeout=$CONNECT_TIMEOUT -NBs -e "$SQL" 2>&1)
        RC=$?
    elif [ -n "$PORT" ]; then
        WHERE="127.0.0.1:$PORT"
        RAW=$($TIMEOUT_CMD "$MYSQL_BIN" $CRED --protocol=TCP --host=127.0.0.1 --port="$PORT" \
                --connect-timeout=$CONNECT_TIMEOUT -NBs -e "$SQL" 2>&1)
        RC=$?
    else
        ERRORS=$((ERRORS + 1))
        DETAILS="$DETAILS$LABEL - no socket= or port= found in $CNF$NL"
        continue
    fi

    if [ "$RC" -ne 0 ]; then
        # ERROR 1040 proves the instance is full - CRITICAL, not unknown.
        if printf '%s' "$RAW" | grep -E '1040|Too many connections' >/dev/null 2>&1; then
            ALERTS=$((ALERTS + 1))
            if [ "$WORST" -lt 1000 ]; then
                WORST=1000; WORST_TXT="$LABEL refused connections (limit reached)"
            fi
            DETAILS="$DETAILS$LABEL - CONNECTION LIMIT REACHED, usage 100% (ERROR 1040)$NL"
        else
            ERRMSG=$(printf '%s' "$RAW" | tr '\n' ' ' | cut -c1-140)
            ERRORS=$((ERRORS + 1))
            DETAILS="$DETAILS$LABEL - unreachable ($WHERE): $ERRMSG$NL"
        fi
        continue
    fi

    MAXC=$(printf '%s\n' "$RAW"  | awk '$1=="max_connections"      {print $2; exit}')
    CURC=$(printf '%s\n' "$RAW"  | awk '$1=="Threads_connected"    {print $2; exit}')
    PEAKC=$(printf '%s\n' "$RAW" | awk '$1=="Max_used_connections" {print $2; exit}')
    [ -z "$PEAKC" ] && PEAKC=0

    if ! is_number "$MAXC" || ! is_number "$CURC" || [ "$MAXC" -eq 0 ]; then
        ERRORS=$((ERRORS + 1))
        DETAILS="$DETAILS$LABEL - unparsable output from $WHERE$NL"
        continue
    fi
    is_number "$PEAKC" || PEAKC=0

    X10=$((CURC * 1000 / MAXC))
    PCT="$((X10 / 10)).$((X10 % 10))"
    PK10=$((PEAKC * 1000 / MAXC))
    PKPCT="$((PK10 / 10)).$((PK10 % 10))"
    FREE=$((MAXC - CURC))
    LIMIT=$((THRESHOLD * 10))
    if [ "$X10" -ge "$LIMIT" ]; then
        ALERTS=$((ALERTS + 1))
        DETAILS="$DETAILS$LABEL - connections $PCT% ($CURC/$MAXC), threshold $THRESHOLD%, peak $PEAKC ($PKPCT%)$NL"
    elif [ "$QUIET_OK" -ne 1 ]; then
        DETAILS="${DETAILS}OK: $LABEL - connections $PCT% ($CURC/$MAXC), free $FREE, peak $PEAKC ($PKPCT%)$NL"
    fi
    if [ "$X10" -gt "$WORST" ]; then
        WORST="$X10"; WORST_TXT="$LABEL at $PCT% ($CURC/$MAXC)"
    fi
done <<EOF
$INSTANCES
EOF

#------------------------------- verdict ---------------------------------------
# Anything wrong -> print ONLY the offending instances, one line each, name first.
# Nothing wrong -> print nothing at all.
if [ "$TOTAL" -eq 0 ]; then
    echo "CONFIG ERROR - the INSTANCES list at the top of the script is empty"; exit 2
fi
if [ "$ALERTS" -gt 0 ]; then
    printf '%s' "$DETAILS"; exit 1
fi
if [ "$ERRORS" -gt 0 ]; then
    printf '%s' "$DETAILS"; exit 2
fi
# Everything below the threshold: stay completely silent when QUIET_OK=1.
if [ "$QUIET_OK" -eq 1 ]; then
    exit 0
fi
echo "OK - all $TOTAL MySQL instance(s) below $THRESHOLD%; highest: $WORST_TXT"
printf '%s' "$DETAILS"; exit 0
