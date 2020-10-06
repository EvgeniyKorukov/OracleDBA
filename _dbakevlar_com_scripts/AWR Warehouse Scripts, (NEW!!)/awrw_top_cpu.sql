select * from (
select
SQL_ID,
 sum(CPU_TIME_DELTA),
sum(DISK_READS_DELTA),
count(*)
from
DBA_HIST_SQLSTAT a, dba_hist_snapshot s, dbsnmp.caw_dbid_mapping m
where lower(m.target_name) = '&dbname'
and m.new_dbid = a.dbid
and a.dbid = s.dbid
and s.snap_id = a.snap_id
and s.begin_interval_time > sysdate -&days_bk
and EXTRACT(HOUR FROM S.END_INTERVAL_TIME) between &begin_hr and &end_hr
group by SQL_ID
order by sum(CPU_TIME_DELTA) desc)
where rownum <= &num_rows;
