--Check execution in Memory
select OWNER,
NAME||' - '||TYPE object,
EXECUTIONS
from v$db_object_cache
where EXECUTIONS > 100
and type in ('PACKAGE','PACKAGE BODY','FUNCTION','PROCEDURE')
and owner='&&SCHEMA'
order by EXECUTIONS desc
/