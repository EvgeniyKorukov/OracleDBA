 --high-var-sql.sql
--undefine days_back
select
   sub1.sql_id,
   round( avg(sub1.seconds_per_hour) ) as avg_seconds_per_hour,
   round( variance(sub1.seconds_per_hour)/avg(sub1.seconds_per_hour) ) as var_over_mean,
   count(*) as ct
from
   ( -- sub1
     select
        snap_id,
        sql_id,
        elapsed_time_delta/1000000 as seconds_per_hour
     from
        dba_hist_snapshot natural join dba_hist_sqlstat
     where
        -- look at recent history only
        begin_interval_time > sysdate - &&days_back;
     and
        -- must have executions to be interesting
        executions_delta > 0
   ) sub1
group by 
   sub1.sql_id
having 
   -- only queries that consume 10 seconds per hour on the average
   avg(sub1.seconds_per_hour) > 10
and 
   -- only queries that run 50% of the time
   -- assumes hourly snapshots too
   count(*) > ( &&days_back * 24) * 0.50
order by
   3
;
--undefine days_back