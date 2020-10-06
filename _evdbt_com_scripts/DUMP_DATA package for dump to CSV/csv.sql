set feedback off
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set echo off timing off pause off verify off pagesize 0 linesize 32767 trimout on arraysize 500
select txt from table(dump_data.csv('&v_part_name','&v_owner','&v_table',100));
exit success
