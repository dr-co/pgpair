#!/bin/bash

set -e

BIN=/usr/lib/postgresql/${1-11}/bin

if ! test -d $BIN; then
    echo postgresql version ${1-11} is not installed properly
    exit -1
fi

USER=${PG_USER-test}
PASSWORD=${PG_PASSWORD-test}
DATABASE=${PG_DB-test}

MASTER_PORT=${PG_MASTER_PORT-5432}
SLAVE_PORT=${PG_SLAVE_PORT-5433}

FUCKUP=yes

cleanup_fuckup() {
    set +e
    if test $FUCKUP = no; then
        return
    fi
    echo Fuckup: Stopping cluster
    for mode in master slave; do
        if test -r data-$mode/postmaster.pid; then
            $BIN/pg_ctl -D data-$mode stop
        fi
    done
    exit -1
}

if test "$(id -u)" = '0'; then
    chmod 0777 /srv
    echo exec gosu postgres bash "$BASH_SOURCE" "$@"
    exec      gosu postgres bash "$BASH_SOURCE" "$@"
fi


trap cleanup_fuckup EXIT

for mode in master slave; do
    if test -r data-$mode/postmaster.pid; then
        $BIN/pg_ctl -D data-$mode stop
    fi
done


rm -fr data-master data-slave

mkdir data-master data-slave

$BIN/initdb -U $USER --pwfile=<(echo "$PASSWORD") data-master
mkdir data-master/logs data-master/sockets


{
    echo "listen_addresses = '*'"
    echo "unix_socket_directories = 'sockets'"
    echo "port = $MASTER_PORT"
    echo "wal_level = hot_standby"
    echo "max_wal_senders = 5"
    echo "max_replication_slots = 5"
    echo "hot_standby = on"
    echo "hot_standby_feedback = on"
    echo "max_connections = 1024"

} >> data-master/postgresql.conf

{
    echo host all         all 0.0.0.0/0 md5
    echo host all         all ::1/128   md5
    echo host replication all 0.0.0.0/0 md5
    echo host replication all ::1/128 md5
} > data-master/pg_hba.conf

$BIN/pg_ctl -D data-master start

for db in $DATABASE; do
    PGHOST=localhost \
        PGPORT=$MASTER_PORT \
        PGUSER=$USER \
        PGPASSWORD=$PASSWORD \
            $BIN/createdb -U $USER \
                -O $USER \
                $db
done

$BIN/pg_ctl -D data-master stop

rsync -a data-master/ data-slave/
rm -f data-slave/*.pid

sed -Ei "s/^port = $MASTER_PORT/port = $SLAVE_PORT/" data-slave/postgresql.conf

{
    echo "standby_mode = 'on'"
    echo "primary_conninfo = 'postgresql://$USER:$PASSWORD@localhost:$MASTER_PORT'"
} > data-slave/recovery.conf

$BIN/pg_ctl -D data-master start
$BIN/pg_ctl -D data-slave start

#PGPASSWORD=$PASSWORD PGUSER=$USER psql -h localhost -p $MASTER_PORT $DATABASE
while sleep 10; do
    echo -n .
done

$BIN/pg_ctl -D data-slave  stop
$BIN/pg_ctl -D data-master  stop

FUCKUP=no
