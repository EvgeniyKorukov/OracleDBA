/**********************************************************************
 * File:        gen_recompile.sql
 * Type:        SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:        10-Oct-98
 *
 * Description:
 *      SQL*Plus script to use the technique of "SQL-generating-SQL"
 *	to generate another SQL*Plus script to recompile any invalid
 *	objects.  Then, the generated script is run...
 *
 *	Optionally, you can comment out the automatic START of the 
 *	generated script, so that you can review the generated script
 *	prior to running it...
 *
 * Modifications:
 *	TGorman	25Jul04	added SHOW ERRORS after each ALTER
 *	TGorman	30Jul04	made SHOW ERRORS conditional for MV & SNAPSHOT
 *********************************************************************/
set echo off feedb off time off timi off pages 0 lines 80 pau off verify off

select	'alter ' || decode(object_type,
			   'PACKAGE BODY', 'PACKAGE',
			   'TYPE BODY', 'TYPE',
			   object_type) ||
	' "' || owner || '"."' || object_name || '" compile' ||
	decode(object_type,
		'PACKAGE BODY', ' body;',
		'TYPE BODY', ' body;',
		';') || chr(10) ||
	decode(object_type,
		'MATERIALIZED VIEW', '',
		'SNAPSHOT', '',
			'show errors ' || object_type ||
			' ' || owner || '.' || object_name) cmd
from	all_objects
where	status = 'INVALID'

spool run_recompile.sql
prompt set echo on feedback on timing on
prompt 
prompt spool run_recompile
prompt 
/
prompt 
prompt spool off
spool off

REM start run_recompile
