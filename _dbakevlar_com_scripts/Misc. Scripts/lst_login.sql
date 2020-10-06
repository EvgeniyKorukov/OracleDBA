--Last Login
select username, count(*) "SESSIONS", trunc(last_call_et/3600) "IDLE_HOURS", module
from v$session
group by username, trunc(last_call_et/3600), module
order by 4, 3, 1;
select osuser, program, count(program) "Active Count"
from v$session
where program not like '%$program%'
and (status = 'ACTIVE'
or last_call_et < 900)
group by osuser, program