-- gets basic DBA_HIST_SQLSTAT data for a single sql_id
-- assumes that each AWR snap is one-hour (used in names, not math)
column BEGIN_HOUR format a16

select
   snap_id,
   to_char(begin_interval_time,'YYYY-MM-DD HH24:MI') as begin_hour,
   executions_delta as execs_per_hour,
   buffer_gets_delta as gets_per_hour,
   round(buffer_gets_delta/executions_delta) as gets_per_exec,
   round(elapsed_time_delta/1000000) as seconds_per_hour
from
   dba_hist_snapshot natural join dba_hist_sqlstat
where
   begin_interval_time between to_date('&start_hour', 'YYYY-MM-DD HH24:MI')
                           and to_date('&end_hour',   'YYYY-MM-DD HH24:MI')
and
   sql_id = '&sql_id'
and
   executions_delta > 0
order by
   snap_id
;

