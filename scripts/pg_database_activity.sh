#!/bin/bash

# Show PostgreSQL database activity, connections memory consumption and more

source ./settings.txt

# Settings
PG_LOG_LINES=15							# PostgreSQL log lines to show. 0 - disable output

#PG_LOG_DATE=$(date +%Y-%m)					# log_filename = 'postgresql-%Y-%m.log'	# log file name pattern
#PG_LOG_FILENAME=$PG_LOG_DIR/postgresql-$PG_LOG_DATE.log	# log_filename = 'postgresql-%Y-%m.log'	# log file name pattern
PG_LOG_FILENAME=`ls -t $PG_LOG_DIR/postgresql-*.log | head -n1`	# newest PostgreSQL log file in log_directory


# ------------------------------------------------

# Colors
REDLIGHT='\033[1;31m'
GREENLIGHT='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
CYANLIGHT='\033[1;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color


# ------------------------------------------------

# Client connections. Uncomment to show
pid_clients=`$PG_BIN/psql -t -c "SELECT pid FROM pg_stat_activity where backend_type='client backend' and pid<>pg_backend_pid();"`
#echo "PID| Database| Username| Application name| Client address| Backend type| Wait event type| Wait event| Memory (KB)| CPU% " > pg_database_activity_tmp.txt

total_clients_mem=0
total_clients_count=0

for pids in $pid_clients ; do
        mem=`ps -q $pids -eo rss | sed 1d`
        cpu=`ps -q $pids -eo pcpu | sed 1d`

#        pid_client_info=`$PG_BIN/psql -t -c "SELECT datname as database, usename as username, application_name, client_addr, backend_type, wait_event_type, wait_event FROM pg_stat_activity where pid=$pids;"`
#        echo "$pids|$pid_client_info|$mem| $cpu" >> pg_database_activity_tmp.txt

        total_clients_mem=$((total_clients_mem+mem))
        ((total_clients_count++))
done

total_clients_mem_mb=$((total_clients_mem/1024))


# Server connections
pid_server=`$PG_BIN/psql -t -c "SELECT pid FROM pg_stat_activity where backend_type<>'client backend' and pid<>pg_backend_pid();"`

echo "PID| Database| Username| Application name| Client address| Backend type| Wait event type| Wait event| Memory (KB)| CPU% " > pg_database_activity_tmp.txt

total_server_mem=0
total_server_count=0

for pids in $pid_server ; do

        mem=`ps -q $pids -eo rss | sed 1d`
        cpu=`ps -q $pids -eo pcpu | sed 1d`
        #mem_cpu=`ps -q $pids -eo rss,pcpu | sed 1d | sed 's/  /|/'`
        
        pid_client_info=`$PG_BIN/psql -t -c "SELECT datname as database, usename as username, application_name, client_addr, backend_type, wait_event_type, wait_event FROM pg_stat_activity where pid=$pids;"`
        echo "$pids|$pid_client_info|$mem| $cpu" >> pg_database_activity_tmp.txt

        total_server_mem=$((total_server_mem+mem))
        ((total_server_count++))
done

total_server_mem_mb=$((total_server_mem/1024))



# ------------------------------------------------

# Title (1 line)
DATE=$(date '+%d.%m.%Y %H:%M:%S')
HOST=`hostname --short`
HOSTIP=`hostname -I | xargs`
UPTIME=`uptime`
UPTIME=${UPTIME#*load average: }
IOSTAT_AWAIT=`iostat -d -x -T -g ALL | sed 1,3d | tr -s " " | cut -d " " -f 11`
IOSTAT_UTIL=`iostat -d -x -T -g ALL | sed 1,3d | tr -s " " | cut -d " " -f 15`

POSTGRES_VER=`$PG_BIN/psql -t -c "select version();" | cut -d ' ' -f 3`
POSTGRES_VER_GLOB=`echo $POSTGRES_VER | awk '{print int($0)}'`	# Round PostgreSQL version (13.1 = 13)
DB_STATUS=`$PG_BIN/psql -t -c "select pg_is_in_recovery();"`
# echo "Status: ["$DB_STATUS"]"

if [[ $DB_STATUS == " f" ]]; then
  STATUS="${GREENLIGHT}[$HOST ($HOSTIP) / PostgreSQL $POSTGRES_VER / Master]${YELLOW}"
else
  STATUS="${PURPLE}[$HOST ($HOSTIP) / PostgreSQL $POSTGRES_VER / Replica]${YELLOW}"
fi

echo -e "${YELLOW}[$DATE] $STATUS [CPU load (1/5/15 min): $UPTIME] [Disks load: util $IOSTAT_UTIL %, await $IOSTAT_AWAIT ms] ${NC}"



# Title (2 line). Disk usage & free
#PG_DATA=/postgres/13/data			# Main data directory
#PG_ARC=/postgres/13/archive			# Archive logs directory

DIR_DATA_FREE=`df -h $PG_DATA | sed 1d | grep -v used | awk '{ print $4 "\t" }' | tr -d '\t'`	# free disk space for PG_DATA
DIR_ARC_FREE=`df -h $PG_ARC | sed 1d | grep -v used | awk '{ print $4 "\t" }' | tr -d '\t'`	# free disk space for PG_ARC
DIR_BASE_SIZE=`du -sh $PG_DATA/base | awk '{print $1}'`		# Base folder size
DIR_WAL_SIZE=`du -sh $PG_DATA/pg_wal | awk '{print $1}'`	# WAL folder size
DIR_ARC_SIZE=`du -sh $PG_ARC | awk '{print $1}'`		# Archive logs folder size

echo -e "${GREENLIGHT}Disk${NC}   | ${GREENLIGHT}PGDATA:${NC} $PG_DATA / base: $DIR_BASE_SIZE / pg_wal: $DIR_WAL_SIZE / ${CYANLIGHT}disk free: $DIR_DATA_FREE${NC} | ${GREENLIGHT}Archive logs:${NC} $PG_ARC / size: $DIR_ARC_SIZE / ${CYANLIGHT}disk free: $DIR_ARC_FREE ${NC}"




# Title (3 line). Connections & memory totals
total_mem=0
total_mem=$((total_server_mem+total_clients_mem))
total_mem_mb=$((total_mem/1024))
total_count=0
total_count=$((total_clients_count+total_server_count))
echo -e "${GREENLIGHT}Memory${NC} | PostgreSQL processes ($total_count) memory consumption: $total_mem_mb MB | ${YELLOW}Clients connections ($total_clients_count) $total_clients_mem_mb MB${NC} | ${YELLOW}Server connections ($total_server_count) $total_server_mem_mb MB${NC}"
echo



# ------------------------------------------------

# Client connections. Uncomment to show
# echo
# echo -e "${GREENLIGHT}Clients connections ($total_clients_count) memory consumption: $total_clients_mem_mb MB${NC}"
# echo "--------------------------------------------------------------------------------------------------------------------------------------------"
# sort -t '|' -k9 -n pg_database_activity_tmp.txt | column -t -s '|' -o ' |'
# echo "--------------------------------------------------------------------------------------------------------------------------------------------"
# echo



# Server connections
echo -e "${GREENLIGHT}Server connections ($total_server_count) memory consumption: $total_server_mem_mb MB${NC}"
echo "---------------------------------------------------------------------------------------------------------------------------------------------------------------"

sort -t '|' -k9 -n pg_database_activity_tmp.txt | column -t -s '|' -o ' |'	# sort file by memory column, then show like table

echo "---------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo
rm pg_database_activity_tmp.txt



# Database statistics
echo -e "${GREENLIGHT}Database statistics:${NC}"
$PG_BIN/psql -c "select p.datid, p.datname, pg_size_pretty(pg_database_size(p.datname)) as size, p.numbackends as connections, p.xact_commit as commit, p.xact_rollback as rollback, p.blks_read, p.blks_hit, p.temp_files, round(p.temp_bytes/1024/1024) as temp_mb, p.deadlocks, p.checksum_failures as chksum_fail, TO_CHAR(p.checksum_last_failure, 'dd.mm.yyyy HH24:MI:SS') as chksum_f_date, TO_CHAR(p.stats_reset, 'dd.mm.yyyy') as stat_reset from pg_stat_database p, pg_database d where p.datid=d.oid and d.datistemplate = false order by p.datid;" | grep -v row



# Wait events
echo -e "${GREENLIGHT}Wait events:${NC}"
$PG_BIN/psql -c "select wait_event_type, wait_event, count(*) as connections from pg_stat_activity where wait_event_type is not null and wait_event_type <> 'Activity' group by wait_event_type, wait_event order by 3 desc;" | grep -v row



# Locks statement duration
locks_status=`$PG_BIN/psql -t -c "SELECT a.query FROM pg_locks bl JOIN pg_stat_activity a ON a.pid = bl.pid WHERE NOT bl.GRANTED;"`
if [[ ${#locks_status} >0 ]]; then
  echo -e "${YELLOW}Locks:${NC}"
  #$PG_BIN/psql -c "select d.datname, t.schemaname, t.relname as table, l.locktype, page, virtualtransaction, pid, mode, granted from pg_locks l, pg_stat_all_tables t, pg_database d where l.relation=t.relid and l.database=d.oid order by relation asc;" | grep -v row
  $PG_BIN/psql -c "SELECT a.query AS blocking_statement, EXTRACT('epoch' FROM NOW() - a.query_start) AS blocking_duration FROM pg_locks bl JOIN pg_stat_activity a ON a.pid = bl.pid WHERE NOT bl.GRANTED;" | grep -v row
  PG_LOG_LINES=$((PG_LOG_LINES-5))
fi



# Archiving status
archiving_status=`$PG_BIN/psql -t -c "select * from pg_stat_archiver;"`
if [[ ${#archiving_status} >0 ]]; then

  echo -e "${GREENLIGHT}Archiving status:${NC}"

  if [[ $DB_STATUS == " f" ]]; then
    # master
    $PG_BIN/psql -c "
    select archived_count as archived_cnt, pg_walfile_name(pg_current_wal_lsn()), last_archived_wal, TO_CHAR(last_archived_time, 'dd.mm.yyyy HH24:MI:SS') as last_archived_time, failed_count, last_failed_wal, TO_CHAR(last_failed_time, 'dd.mm.yyyy HH24:MI:SS') as last_failed_time,
    ('x'||substring(pg_walfile_name(pg_current_wal_lsn()),9,8))::bit(32)::int*256 +
    ('x'||substring(pg_walfile_name(pg_current_wal_lsn()),17))::bit(32)::int -
    ('x'||substring(last_archived_wal,9,8))::bit(32)::int*256 -
    ('x'||substring(last_archived_wal,17))::bit(32)::int as diff
    --TO_CHAR(stats_reset, 'dd.mm.yyyy') as stats_reset
    from pg_stat_archiver;" | grep -v row
  else
    # replica
    $PG_BIN/psql -c "
    select archived_count, last_archived_wal, TO_CHAR(last_archived_time, 'dd.mm.yyyy HH24:MI:SS') as last_archived_time, failed_count, last_failed_wal, TO_CHAR(last_failed_time, 'dd.mm.yyyy HH24:MI:SS') as last_failed_time, TO_CHAR(stats_reset, 'dd.mm.yyyy HH24:MI:SS') as stats_reset
    from pg_stat_archiver;" | grep -v row
  fi

  PG_LOG_LINES=$((PG_LOG_LINES-5))

fi



# Replication status
replication_status=`$PG_BIN/psql -t -c "select * from pg_stat_replication;"`
if [[ ${#replication_status} >0 ]]; then

  echo -e "${GREENLIGHT}Replication status:${NC}"
  $PG_BIN/psql -c "
  SELECT client_addr AS client_addr, usename AS username, application_name AS app_name, pid, state, sync_state AS MODE,
         (pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) / 1024)::int AS sending_lag,   -- sending_lag (network problems)
         (pg_wal_lsn_diff(sent_lsn, flush_lsn) / 1024)::int AS receiving_lag,            -- receiving_lag
         (pg_wal_lsn_diff(sent_lsn, write_lsn) / 1024)::int AS WRITE,                    -- disks problems
         (pg_wal_lsn_diff(write_lsn, flush_lsn) / 1024)::int AS FLUSH,                   -- disks problems
         (pg_wal_lsn_diff(flush_lsn, replay_lsn) / 1024)::int AS replaying_lag,          -- replaying_lag (disks/CPU problems)
         (pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn))::int / 1024 AS total_lag
  FROM pg_stat_replication;" | grep -v row
  PG_LOG_LINES=$((PG_LOG_LINES-5))

fi



# PostgreSQL system process activity progress

# PostgreSQL 9.6 and higher
progress_vacuum=`$PG_BIN/psql -t -c "select * from pg_stat_progress_vacuum;"`
if [[ ${#progress_vacuum} >0 ]]; then
  echo -e "${YELLOW}VACUUM progress:${NC}"
  $PG_BIN/psql -c "select a.query, p.datname, p.phase, p.heap_blks_total, p.heap_blks_scanned, p.heap_blks_vacuumed, p.index_vacuum_count, p.max_dead_tuples, p.num_dead_tuples from pg_stat_progress_vacuum p, pg_stat_activity a WHERE p.pid = a.pid;" | grep -v row
  PG_LOG_LINES=$((PG_LOG_LINES-5))
fi


# PostgreSQL 12 and higher: pg_stat_progress_analyze, pg_stat_progress_basebackup
if [[ $POSTGRES_VER_GLOB -ge 12 ]]; then	# >= 12

  progress_create_index=`$PG_BIN/psql -t -c "select * from pg_stat_progress_create_index;"`
  if [[ ${#progress_create_index} >0 ]]; then
    echo -e "${YELLOW}CREATE INDEX progress:${NC}"
    $PG_BIN/psql -c "SELECT a.query, p.datname, p.command, p.phase, p.lockers_total, p.lockers_done, p.blocks_total, p.blocks_done, p.tuples_total, p.tuples_done FROM pg_stat_progress_create_index p, pg_stat_activity a WHERE p.pid = a.pid;" | grep -v row
    PG_LOG_LINES=$((PG_LOG_LINES-5))
  fi

  progress_cluster=`$PG_BIN/psql -t -c "select * from pg_stat_progress_cluster;"`
  if [[ ${#progress_cluster} >0 ]]; then
    echo -e "${YELLOW}VACUUM FULL or CLUSTER progress:${NC}"
    $PG_BIN/psql -c "select a.query, p.datname, p.command, p.phase, p.heap_tuples_scanned, p.heap_tuples_written, p.index_rebuild_count from pg_stat_progress_cluster p, pg_stat_activity a WHERE p.pid = a.pid;" | grep -v row
    PG_LOG_LINES=$((PG_LOG_LINES-5))
  fi

fi


# PostgreSQL 13 and higher: pg_stat_progress_analyze, pg_stat_progress_basebackup
if [[ $POSTGRES_VER_GLOB -ge 13 ]]; then	# >= 13

  progress_analyze=`$PG_BIN/psql -t -c "select * from pg_stat_progress_analyze;"`
  if [[ ${#progress_analyze} >0 ]]; then
    echo -e "${YELLOW}ANALYZE progress:${NC}"
    $PG_BIN/psql -c "SELECT a.query, p.datname, p.phase, p.sample_blks_total, p.sample_blks_scanned, p.ext_stats_total, p.ext_stats_computed, p.child_tables_total, p.child_tables_done FROM pg_stat_progress_analyze p, pg_stat_activity a WHERE p.pid = a.pid;" | grep -v row
    PG_LOG_LINES=$((PG_LOG_LINES-5))
  fi

  progress_basebackup=`$PG_BIN/psql -t -c "select * from pg_stat_progress_basebackup;"`
  if [[ ${#progress_basebackup} >0 ]]; then
    echo -e "${YELLOW}PG_BASEBACKUP progress:${NC}"
    $PG_BIN/psql -c "SELECT a.query, p.pid, p.phase, p.backup_total, p.backup_streamed, p.tablespaces_total, p.tablespaces_streamed FROM pg_stat_progress_basebackup p, pg_stat_activity a WHERE p.pid = a.pid;" | grep -v row
    PG_LOG_LINES=$((PG_LOG_LINES-5))
  fi

fi



# show PostgreSQL log
if [[ $PG_LOG_LINES -gt 0 ]]; then
  echo -e "${GREENLIGHT}PostgreSQL log: $PG_LOG_FILENAME${NC}"
  tail --lines=$PG_LOG_LINES $PG_LOG_FILENAME
fi