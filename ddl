#!/bin/bash
# MySQL connection usage check for SCOM.
# Prints the instance name only when it is at/above THRESHOLD or unreachable.
# Silent + exit 0 when everything is fine.  Exit 1 = over threshold, 2 = error.

###############################  CONFIGURE  ###################################
# One instance per line:  NAME=target
#   NAME=3306                       TCP on 127.0.0.1:3306
#   NAME=10.0.0.5:3307              TCP on that host and port
#   NAME=/var/lib/mysql/mysql.sock  unix socket
INSTANCES="
PROD1=3306
PROD2=3307
"

THRESHOLD=80

MYSQL_USER="scom_monitor"
MYSQL_PASSWORD="ChangeMe"
###############################################################################

# Passed through the environment, never on the command line, so the password
# does not show up in `ps` for every user on the box.
export MYSQL_PWD="$MYSQL_PASSWORD"

STATUS=0
while read -r LINE; do
    case "$LINE" in ''|\#*) continue ;; esac
    NAME=${LINE%%=*}
    TARGET=${LINE#*=}

    case "$TARGET" in
        /*)   CONN="--socket=$TARGET" ;;
        *:*)  CONN="--host=${TARGET%:*} --port=${TARGET##*:}" ;;
        *)    CONN="--host=127.0.0.1 --port=$TARGET" ;;
    esac

    Q1=$(mysql -u"$MYSQL_USER" $CONN -NBs -e "SHOW GLOBAL VARIABLES LIKE 'max_connections'" 2>&1)
    Q2=$(mysql -u"$MYSQL_USER" $CONN -NBs -e "SHOW GLOBAL STATUS LIKE 'Threads_connected'"  2>&1)

    # Match on the variable NAME, never just field 2: an error line such as
    # "ERROR 1040 (HY000): Too many connections" would otherwise yield "1040",
    # which looks like a valid number and would hide the alert.
    MAX=$(printf '%s\n' "$Q1" | awk '$1=="max_connections"   {print $2; exit}')
    CUR=$(printf '%s\n' "$Q2" | awk '$1=="Threads_connected" {print $2; exit}')

    BAD=0
    case "$MAX" in ''|*[!0-9]*) BAD=1 ;; esac
    case "$CUR" in ''|*[!0-9]*) BAD=1 ;; esac
    [ "$MAX" = 0 ] && BAD=1
    if [ "$BAD" -eq 1 ]; then
        # At 100% the server refuses the monitoring connection (ERROR 1040):
        # that is "full", not "down" - two very different alerts.
        case "$Q1$Q2" in
            *1040*|*"Too many connections"*) echo "$NAME - connections FULL (100%)"
                                             [ "$STATUS" -eq 0 ] && STATUS=1 ;;
            *)                               echo "$NAME - unreachable"; STATUS=2 ;;
        esac
        continue
    fi

    PCT=$((CUR * 100 / MAX))
    if [ "$PCT" -ge "$THRESHOLD" ]; then
        echo "$NAME - $PCT% ($CUR/$MAX)"
        [ "$STATUS" -eq 0 ] && STATUS=1
    fi
done <<EOF
$INSTANCES
EOF

exit $STATUS
