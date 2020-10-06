--Find source code for SQL running internally to DB, either by SQL_ID or hash
select o.owner, o.object_name, o.object_type, s.program_line#
from v$sql s, dba_objects o
where sql_id = '$SQL_ID'
--where s.hash_value=’$HASH_VALUE’
and s.program_id=o.object_id;