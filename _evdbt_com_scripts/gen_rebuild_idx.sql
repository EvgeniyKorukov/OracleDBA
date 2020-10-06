/**********************************************************************
 * File:        gen_rebuild_idx.sql
 * Type:        SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:        29-Mar-2002
 *
 * Description:
 *      SQL*Plus script to generate another SQL*Plus script to rebuild
 *	any indexes, index partitions, or index sub-partitions which
 *	are in an UNUSABLE state.  Intended for Oracle8i and above...
 *      etc) in summary.
 *
 * Modifications:
 *********************************************************************/
set echo off feedback off timing off verify off
set pagesize 0 linesize 500 trimspool on trimout on

select	'alter index "'||owner||'"."'||index_name||
		'" rebuild nologging compute statistics;' cmd
from	dba_indexes
where	status = 'UNUSABLE'
union
select	'alter index "'||index_owner||'"."'||index_name||
		'" rebuild partition "'||partition_name||
		'" nologging compute statistics;' cmd
from	dba_ind_partitions
where	status = 'UNUSABLE'
union
select	'alter index "'||index_owner||'"."'||index_name||
		'" rebuild subpartition "'||subpartition_name||';' cmd
from	dba_ind_subpartitions
where	status = 'UNUSABLE'
order by 1

spool run_rebuild_idx.sql
prompt set echo on feedback on timing on
prompt
prompt spool run_rebuild_idx
prompt
/
prompt
prompt spool off
spool off

REM start run_rebuild_idx
