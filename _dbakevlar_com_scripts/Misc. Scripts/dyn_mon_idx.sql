--Generate Index Monitoring Script
set pages 999;
set heading off;
spool run_monitor.sql
select
'alter index '||owner||'.'||index_name||' monitoring usage;'
from
dba_indexes
where
owner in ('<schema>')
;
spool off;