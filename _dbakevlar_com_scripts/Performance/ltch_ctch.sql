--Catch Latches Check
select vs.sid, vs.username, s.sql_text, swc.wait_class, ash.P1 "File#", ash.P2 "Block#", o.owner, o.object_name
from v$session_wait_class swc, v$sql s, v$session vs, v$active_session_history ash, dba_objects o, v$latchholder l
where swc.wait_class# in (4,8)
and swc.sid=vs.sid
and vs.sid=l.sid
and s.sql_id=vs.sql_id
and vs.sql_id=ash.sql_id
and ash.current_obj#=o.data_object_id
and ash.wait_class=swc.wait_class
order by swc.time_waited desc;