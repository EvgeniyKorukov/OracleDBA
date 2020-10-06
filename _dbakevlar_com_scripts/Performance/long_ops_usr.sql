--Long Running Operations, Can be detailed to SID(s)
select opname "Description", round(totalwork/60/60) "Minutes Spent", round(time_remaining/60/60) "Minutes Left", sid
from v$session_longops
--where sid in (695)--,830,685,613,761,572,566,812,630,833,838,663,813,773,775,705)
where time_remaining>0
order by time_remaining desc