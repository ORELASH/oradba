[root@linx108883a5n scripts]# cat scom_functions.sh
#!/bin/bash

#################################################################################################################################################
# ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS # ALWAYS #
#################################################################################################################################################


export MYPATH=`dirname "$0"`
MYPATH=`(cd "$MYPATH" && pwd )`
LOG_FILE=$MYPATH/../logs/scom.log
ERROR_FILE=$MYPATH/../logs/scom_error.log
KEY_FILE="/mongodb/certificate/patrol.pem"
CA_FILE="/mongodb/certificate/CA.pem"


# Uses tee to send output to scom and to log
logprint()
{
        echo "$(date +%T): $*" | tee -a $LOG_FILE
}

# Formats time from seconds to a more readable format
format_time ()
{
        local time_in_seconds=$1
        local hours=$(( time_in_seconds / 3600 ))
        local minutes=$(( ( time_in_seconds % 3600 ) / 60 ))
        local seconds=$(( time_in_seconds % 60 ))
        echo "${hours} hours, ${minutes} minutes, ${seconds}, seconds."
}

# Checks which instances of mongo are running on the server
check_instances ()
{

        # Finds each instance of mongo, and takes the conf from there
        mongo_confs=$(cat /etc/mongotab | grep -v "^#" | awk -F ":" '{print $4}')

        # Finds the name of each conf
        instances=$(grep "replSetName" $mongo_confs | awk -F '"' '{print $2}')

        # Exits the script if no mongo instanace is found
        if [[ $(echo $instances | wc -w) -eq 0 ]]; then
                exit 1
        fi

}

# Takes mongo_conf (set in the loop calling the function) and retrieves all relevant information from it
each_instance ()
{

        # just basic checks for later use
        instance=$(grep "replSetName" $mongo_conf | awk -F '"' '{print $2}')
        local_address=$(hostname -f)
        local_port=$(grep "port" $mongo_conf | awk '{print $2}')
        replica_set_name=$(grep replSetName $mongo_conf | awk -F '"' '{print $2}')
        log=$(grep mongod.log $mongo_conf | awk '{print $2}')

        # Checks whether the mongo instance is in-memory mongo
        grep "inMemorySizeGB" $mongo_conf > /dev/null
        mongo_inmem=$?
}

# Checks for any errors in the output of the script, if any is detected tells the user as much and where to find it
error_handling ()
{
        if [[ $(wc -l $ERROR_FILE | awk '{print $1}') -gt 1 ]]; then
                printf "Some errors logged in script. Refer to $ERROR_FILE for details.\n"
        fi
}

double_check ()
{
        local func="$1"
        func_output=`$func`
        if [[ -n $func_output ]]; then
                        sleep 1
                        $func
        fi
}



################################################################################################################################################
# CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL # CRITICAL #
################################################################################################################################################
# These checks are all critical, and will appear in scom as critical.

# Checks whether local connection can be established.
check_local_connection ()
{
        # Connects to mongo locally and attempts to ping it
        mongosh --port $local_port --quiet --eval '
        db.runCommand("ping").ok
        ' > /dev/null
        local_connection=$?

        # If no connection can be established, prints an error accordingly and skips to next instance
    if [[ $local_connection -ne 0 ]]; then
        logprint "$alert_prefix not available!"
        continue
    fi
}

# Checks connection from local node to primary server
check_primary_connection ()
{
        # Connects to mongo locally and checks whether it can find a primary server.
        mongosh --port $local_port --quiet --eval '
        db.isMaster().primary
        ' > /dev/null
        primary_connection=$?
    if [[ $primary_connection -ne 0 ]]; then
        logprint "$alert_prefix has lost connection to primary server!"
    fi

}

# Checks whether there are too many open connections to the database
check_excess_connections_critical ()
{
        # Connects and authenticates, checks how many connections are open
        mongo_connections=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
        --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
        db.serverStatus().connections.current
        ')

        # If there are more than 25000 connections, prints an error accordingly.
        if [[ $mongo_connections -ge 25000 ]]; then
                logprint "$alert_prefix has excess amount of open connections - ${mongo_connections}"
        fi
}

# Checks whether memory usage is too high for an inmem mongo instance
check_memory_critical ()
{
        # connects to mongo, checks how much memory is in use by the mongo instance
        mongo_memory_used=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
         --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
         db.serverStatus().mem.resident
                ')

        # Checks how the maximum configured memory for mongo
        mongo_memory_max=$(cat $mongo_conf | grep "inMemorySizeGB" | cut -d':' -f2| tr -d ' ')
        mongo_memory_max_mb=$((mongo_memory_max * 1024))

        # If the memory in use is greater than 90% of the maximum configured memory, prints an error accordingly.
        if [[ $mongo_memory_used -gt $((mongo_memory_max*922)) ]]; then
          logprint "$alert_prefix has critical memory usage - ${mongo_memory_used}/${mongo_memory_max_mb}MB"
        fi
}


# Deprecated after a61 lied about lag, replaced by check_lag_from_primary
check_lag ()
{
        # Checks the time since epoch of the local node, and calculates how far it is behind the primary.
        mongo_lag=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
        --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
        status = rs.status();
        selfMember = status.members.find(member => member.self);
        if (selfMember.stateStr === "PRIMARY")
        {
                print(0);
        } else {
         primaryStatus = status.members.find(member => member.stateStr === "PRIMARY");
                secondaryStatus = selfMember;
                if (primaryStatus && secondaryStatus) {
                        lagMillis = new Date(primaryStatus.optimeDate) - new Date(secondaryStatus.optimeDate);
                        lagSeconds = lagMillis / 1000;
                        print(lagSeconds);
        }}
        ')

        # If the lag is bigger than 10 minutes, prints an error accordingly.
        if [[ $mongo_lag -gt 600 ]]; then
                logprint "$alert_prefix is $mongo_lag seconds behind primary. Please contact DBAmongo."
        fi

}

check_certificate_date_critical ()
{
soon_to_expire=0
for cert in $certs; do
        certinfo=$(openssl x509 -enddate -noout -in $cert | cut -d'=' -f2)
        if [[ $(grep subject $cert | sed 's/\//\n/g' | grep CN) ]]; then
                subject=$(grep subject $cert | sed 's/\//\n/g' | grep CN)
        else
                subject="unknown_cert"
        fi
        ttl=$((($(date -d "${certinfo}" +%s) - $(date  +%s))/86400))
        if [[ $ttl -le 3 ]]; then
                        logprint "$alert_prefix has one or more certificates expiring in the next 3 days!"
                fi
                return
done
}

check_lag_from_primary ()
{

        # Checks that the replica set is not a single instance replica set
        cluster_member_amount=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
        --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
        rs.status().members.length
        ')

        if [[ $cluster_member_amount -gt 1 ]]; then

        # Checks that the current member is the primary
        is_primary=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
        --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
        db.isMaster().ismaster
        ')

        if [[ $is_primary == true ]]; then

                # Checks the replication information of the secondaries
                all_secondary_repl_info=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
                --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
                rs.printSecondaryReplicationInfo()
                ')

                        # Checks whether there is more than 0.1 hours lag (6 mins) on each replica)
                        for i in $(seq 1 $((cluster_member_amount - 1))); do
                                secondary_repl_info=$(echo $all_secondary_repl_info | awk -F "---" -v idx="$i" '{print $idx}')
                                secondary_repl_lag_hours=$(echo $secondary_repl_info | grep -oP "(?<=\()[0-9]+(\.[0-9]+)?(?= hrs\))")
                                secondary_name=$(echo $secondary_repl_info | grep -oP "(?<=source: )[A-Za-z0-9]+")
                                if (( $(echo "$secondary_repl_lag_hours >= 4" | bc -l) )); then
                                                logprint "$alert_prefix has a secondary ($secondary_name) that is $secondary_repl_lag_hours hours behind it. Please contact
BAmongo."
                                fi
                        done
                fi
        fi
}


check_certificate_date_critical ()
{
certs=$(ls /mongodb/certificate/*.pem)
for cert in $certs; do
        certinfo=$(openssl x509 -enddate -noout -in $cert | cut -d'=' -f2)
        ttl=$((($(date -d "${certinfo}" +%s) - $(date  +%s))/86400))
        if [[ $ttl -le 3 ]]; then
                logprint "$alert_prefix has one or more certificates expiring in the next 3 days!"
        fi
        return
done
}


#############################################################################################################################################
# WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING # WARNING #
#############################################################################################################################################
# These checks are for warnings, and print as warnings in scom.

# same as above but no print to be used for warnings (no reason to test anything if node is down)
check_local_connection_noprint ()
{

        # Connects to mongo locally and attempts to ping it
        mongosh --port $local_port --quiet --eval '
        db.runCommand("ping").ok
        ' > /dev/null
        local_connection=$?

        # If no connection can be established, skips to next instance
        if [[ $local_connection -ne 0 ]]; then
                continue
        fi
}


# Same as check_excess_connections_critical, but configured for 20000 connections rather than 25000
check_excess_connections_warning ()
{
        # Connects to mongo, checks how many connections are ope
        mongo_connections=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
        --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
        db.serverStatus().connections.current
        ')

        # If there are more than 20000 connections, prints an error accordingly.
        if [[ $mongo_connections -ge 20000 ]]; then
                logprint "$alert_prefix has excess amount of open connections - ${mongo_connections}"
        fi
}

# Same as check_memory_critical, but configured for 70% rather than 90%
check_memory_warning ()
{
        # connects to mongo, checks how much memory is in use by the mongo instance
        mongo_memory_used=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
        --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
        db.serverStatus().mem.resident
        ')

        # Checks how the maximum configured memory for mongo
        mongo_memory_max=$(cat $mongo_conf | grep "inMemorySizeGB" | cut -d':' -f2| tr -d ' ')
        mongo_memory_max_mb=$((mongo_memory_max * 1024))

        # If the memory in use is greater than 75% of the maximum configured memory, prints an error accordingly.
        if [[ $mongo_memory_used -gt $((mongo_memory_max*768)) ]]; then
        logprint "$alert_prefix has critical memory usage - ${mongo_memory_used}/${mongo_memory_max_mb}MB"
        fi
}

# Checks whether the oplong is longer than 3 hours
check_oplog_length ()
{
        # Connects to mongo, checks how long the oplog is (in seconds)
        mongo_oplog_length=$(mongosh --tls --tlsCertificateKeyFile ${KEY_FILE} --tlsCAFile ${CA_FILE} --authenticationDatabase '$external' \
        --authenticationMechanism MONGODB-X509 --host ${local_address} --port ${local_port} --quiet --eval '
        db.getReplicationInfo().timeDiff
        ')
        in_memory=$(grep -vE '^\s*#' "$mongo_conf" | grep -q "inMemory" && echo true || echo false)

        # If the oplog is shorter than 3 hours, prints a message accordingly.
        if [[ $mongo_oplog_length -lt 10800 && $in_memory == false ]] ; then

                # Formats the time for easier reading
                mongo_oplog_length_formatted=$(format_time $mongo_oplog_length)
                logprint "$alert_prefix has oplog too short - oplog is only $mongo_oplog_length_formatted"
        fi
}

check_certificate_date ()
{
soon_to_expire=0
for cert in $certs; do
        certinfo=$(openssl x509 -enddate -noout -in $cert | cut -d'=' -f2)
        if [[ $(grep subject $cert | sed 's/\//\n/g' | grep CN) ]]; then
                subject=$(grep subject $cert | sed 's/\//\n/g' | grep CN)
        else
                subject="unknown_cert"
        fi
        ttl=$((($(date -d "${certinfo}" +%s) - $(date  +%s))/86400))
        if [[ $ttl -le 14 ]]; then
                        logprint "$alert_prefix has one or more certificates expiring in the next 14 days"
        fi
        return
done
}



# Does some test (passed as argument $2), checks if it's different from the previous run of the same test (saved to
# a hidden file in /tmp/ named after the test type (passed as argument $1) and if the current run ($2) and the last run ($1)
# are different from one another, prints an alert prefix and the alert  itself (passed as argument $3)
check_changes ()
{

        # Used to separate tests by a unique name given per test
        subject=$1

        # The test itself, passed as a string into eval to be run as a command
        latest_occurence=$(eval "$2")

        # The file in which latest occurence is saved and will be saved when the function ends
        last_occurence_file="/tmp/.${instance}_last_${subject}"

        # If the file exists (should always be true except for first run
        # and the test for latest occurence found anything
        if [[ -e $last_occurence_file ]] && [[ $latest_occurence ]]; then

                # Reads last occurence from the file, has to be done in this way due to how bash works with quotation marks within the file
                last_occurence=$(< $last_occurence_file)

                # If the latest and last occurence are different, prints an alert message according to the passed argument
                # is being done with "eval echo" to be able to print both strings and outputs of commands as one.
                if [[ "$last_occurence" != "$latest_occurence" ]]; then
                        alert_message=$(eval echo "$3")
                        logprint "$alert_prefix $alert_message"
                fi
        fi

        # Overwrites the file of the last occurence with the output of the latest occurence
        echo "$latest_occurence" > $last_occurence_file
}

# Checks whether too many errors have recently been written into the log
check_errors ()
{
        number_of_errors=$(tail -n 100 $log | grep -iE '"s":"(E|W|F)"' | grep -ivE "atlasCliLocalDevCluster|Dropping all pooled|Different user name was supplied to saslSupp
rtedMechs|fsync" | wc -l)
        if [[ $number_of_errors -gt 3 ]]; then
                logprint "$alert_prefix has some errors logged. Please contact DBAmongo."
        fi
}

check_low_severity_errors ()
{
        categories="auth ssl sync storage electability"

        auth_errors=$(tail -n 100 $log | grep -iE 'authentication failed|sasl.*(failed|error)' | wc -l)
        ssl_errors=$(tail -n 100 $log | grep -iE 'ended during ssl handshake|SSL peer certificate validation failed' | wc -l)
        sync_errors=$(tail -n 100 $log | grep -iE 'could not find member to sync from|no sync source available|sync source candidate.*blacklist' | wc -l)
        storage_errors=$(tail -n 100 $log | grep -iE 'wt cache.*dirty|page fault' | wc -l)
        electability_errors=$(tail -n 100 $log | grep -iE 'no electable primary found|not electable|not running for primary' | wc -l)

        for category in $categories
        do
                if [[ ${!category}_errors -gt 3 ]]; then
                        logprint "$alert_prefix has multiple $category errors. Please contact DBAmongo."
                fi
        done
}

check_certificate_date ()
{
        certs=$(ls /mongodb/certificate/*.pem)
        for cert in $certs; do
                certinfo=$(openssl x509 -enddate -noout -in $cert | cut -d'=' -f2)
                ttl=$((($(date -d "${certinfo}" +%s) - $(date  +%s))/86400))
                if [[ $ttl -le 14 ]]; then
                        logprint "$alert_prefix has one or more certificates expiring in the next 14 days."
                fi
                return
        done
}


check_clock_sync() {
    local sync_status
    sync_status=$(timedatectl status 2>/dev/null \
        | awk -F': +' '/System clock synchronized/ {print $2}')

    if [[ "$sync_status" == "yes" ]]; then
        :
    elif [[ "$sync_status" == "no" ]]; then
        logprint "$alert_prefix System clock is NOT synchronized with the organization clock!"
        echo "Please verify NTP configuration and connectivity."
    else
        logprint "$alert_prefix Unable  determine  synchronization status!"
    fi
}


[root@linx108883a5n scripts]#





