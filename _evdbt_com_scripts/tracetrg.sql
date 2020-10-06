/**********************************************************************
 * File:	tracetrg.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:	01Dec01
 *
 * Description:
 *	SQL*Plus script containing the DDL to create a database-level
 *	AFTER LOGON event trigger to enable SQL Trace for a specific
 *	user account only.  Very useful diagnostic tool...
 *
 * Modifications:
 * TGorman 13oct08	added GRANT and ALTER TRIGGER commands
 *********************************************************************/
set echo on feedback on timing on verify on

undef username

spool tracetrg_&&username

REM 
REM ...comment this line out if unnecessary or not desired...
REM 
grant alter session to &&username ;

REM 
REM ...create trigger TRACETRG for the user specified...
REM 
create or replace trigger &&username..tracetrg
	after logon
	on &&username..schema
begin
	execute immediate 'alter session set statistics_level = all';
	execute immediate 'alter session set timed_statistics = true';
	execute immediate 'alter session set tracefile_identifier = ''' || lower(user) || '''';
	execute immediate 'alter session set max_dump_file_size = unlimited';
	execute immediate 'alter session set events ''10046 trace name context forever, level 12''';
end tracetrg;
/
show errors

REM 
REM ...make sure to disable the trigger right away, so it doesn't get used
REM unexpectedly. When it is to be used, be sure to ENABLE it, and then
REM do NOT forget to DISABLE it again (or just DROP it) when you are done using it...
REM 
alter trigger &&username..tracetrg disable;

spool off
