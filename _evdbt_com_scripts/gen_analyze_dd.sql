/*****************************************************************************
 * File:	gen_analyze_dd.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman (Evergreen Database Technologies, Inc)
 * Date:	30may00
 *
 * Description:
 *	This script uses the technique of "SQL-generating-SQL" to query the
 *	data dictionary in order to produce a script to validate the very
 *	same data dictionary against corruption.
 *
 *	This is very useful prior to upgrading to v8.1.6 or higher, since in
 *	v8.1.6 more advanced corruption detection became default.  Since older
 *	versions of the RDBMS did not perform these consistency checks by
 *	default, frequently subtle corruptions would go undetected until after
 *	upgrade, resulting in a rather uncomfortable situation...
 *
 *	This script intended to be run by a user with DBA privileges (i.e.
 *	ability to query DBA_TABLES and DBA_CLUSTERS and possessing ANALYZE
 *	ANY privileges).
 *
 * Modifications:
 *
 ****************************************************************************/
whenever oserror exit failure
whenever sqlerror exit failure
set echo off feedb off timi off pagesi 0 linesi 500 trimspo on termout off
column type noprint
column owner noprint
column name noprint
column cmd print

select	'CLUSTER' type, owner, cluster_name name,
	'analyze cluster "' || owner || '"."' || cluster_name ||
	'" validate structure cascade;' cmd
from	dba_clusters
where	owner in ('SYS','SYSTEM','OUTLN')
union
select	'TABLE' type, owner, table_name name,
	'analyze table "' || owner || '"."' || table_name ||
	'" validate structure cascade;' cmd
from	dba_tables
where	owner in ('SYS','SYSTEM','OUTLN')
order by 1, 2, 3

spool run_analyze_dd.sql
prompt whenever oserror exit failure
prompt whenever sqlerror exit failure
prompt set echo on feedback on timing on
prompt spool run_analyze_dd
/
prompt exit success
spool off
set termout on
REM start run_analyze_dd
