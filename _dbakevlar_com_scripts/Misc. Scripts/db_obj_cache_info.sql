--Info on what is in the db object_cache
select OWNER,
NAME,
DB_LINK,
NAMESPACE,
TYPE,
SHARABLE_MEM,
LOADS,
EXECUTIONS,
LOCKS,
PINS
from v$db_object_cache
where owner ='DW_PROD'
and executions <1
order by OWNER, NAME
/