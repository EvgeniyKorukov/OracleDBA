select
 s.snap_id,
 to_char(s.begin_interval_time,'HH24:MI') "Begin Time",
 sql.executions_delta "Exec Delta",
 sql.buffer_gets_delta "Buffer Gets",
 sql.disk_reads_delta "Disk Reads",
 sql.iowait_delta "IO Waits",
sql.cpu_time_delta "CPU Time",
 sql.elapsed_time_delta "Elapsed"
 from
 dba_hist_sqlstat sql,
 dba_hist_snapshot s,
 dbsnmp.caw_dbid_mapping m
 where lower(m.target_name) = '&dbname'
 and m.new_dbid = s.dbid
 and s.dbid = sql.dbid
 and s.snap_id = sql.snap_id
 and s.begin_interval_time > sysdate -&days_bk
 and
sql.sql_id='&sqlid'
 order by "Elapsed"
 /
