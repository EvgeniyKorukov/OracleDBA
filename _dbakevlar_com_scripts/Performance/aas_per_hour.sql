--column sample_hour format a16
select
   to_char(round(sub1.sample_time, 'HH24'), 'YYYY-MM-DD HH24:MI') as sample_hour,
   round(avg(sub1.on_cpu),1) as cpu_avg,
   round(avg(sub1.waiting),1) as wait_avg,
   round(avg(sub1.active_sessions),1) as act_avg,
   round( (variance(sub1.active_sessions)/avg(sub1.active_sessions)),1) as act_var_mean
from
   ( -- sub1: one row per second, the resolution of SAMPLE_TIME
     select
        sample_id,
        sample_time,
        sum(decode(session_state, 'ON CPU', 1, 0))  as on_cpu,
        sum(decode(session_state, 'WAITING', 1, 0)) as waiting,
        count(*) as active_sessions
     from
        dba_hist_active_sess_history
     where
        sample_time > sysdate - (&hours/24)
     group by
        sample_id,
        sample_time
   ) sub1
group by
   round(sub1.sample_time, 'HH24')
order by
   round(sub1.sample_time, 'HH24')
;

