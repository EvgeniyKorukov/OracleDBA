--column BEGIN_HOUR format a16
select
   stat_start.snap_id,
   to_char(snap.begin_interval_time,'YYYY-MM-DD HH24:MI') as begin_hour,
   -- DB time is in units of centiseconds in DBA_HIST_SYSSTAT.VALUE
   round( (stat_end.value - stat_start.value)/100 , 0) as seconds_per_hour,
   -- also assumes hourly snapshots, hence divided by 3600
   round( (stat_end.value - stat_start.value)/(100*3600) , 1) as aas
from
   dba_hist_sysstat stat_start,
   dba_hist_sysstat stat_end,
   dba_hist_snapshot snap
where
   -- assumes the snap_id at the end of the interval is 
   -- one greater than the snap_id at teh start ofthe interval
   --
   stat_end.snap_id = stat_start.snap_id + 1
and
   -- otherwise, we join stat_end and stat_start
   -- on exact matches of the remaining PK columns
   --
   ( stat_end.dbid = stat_start.dbid
     and
     stat_end.instance_number = stat_start.instance_number
     and
     stat_end.stat_name = stat_start.stat_name
   )
and
   -- filter for the statistic we are interested in
   --
   stat_end.stat_name = 'DB time'
and
   -- join stat_start to snap on FK
   -- 
   ( stat_start.snap_id = snap.snap_id
     and
     stat_start.dbid = snap.dbid
     and
     stat_start.instance_number = snap.instance_number
   )
order by
   stat_start.snap_id
;
