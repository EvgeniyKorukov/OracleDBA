--Step through, find mutex and latch info:
SELECT s.sql_hash_value, l.name, s.sid
FROM V$SESSION s, V$LATCHHOLDER l
WHERE s.sid = l.sid;


select * from v$latchholder;


select * from V$MUTEX_SLEEP_HISTORY
order by sleep_timestamp desc;


select * from v$sql
where hash_value=$hash_value