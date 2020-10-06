set echo on feedback on timing on pages 100 lines 130
set serveroutput on size 1000000
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';

col sysdate heading "Current|Date-time"
col pitr_bkup heading "Point-in-time|recoverable|from backed-up|archivelogs" format a20
col pitr_beyond_bkup heading "Point-in-time|recoverable|from backed-up|and non-backed-up|archivelogs" format a20
col bkup_type heading "Backup Type:|INCONSISTENT=hot backup|CONSISTENT=cold backup" format a20

spool rman_chk_test

variable b1 varchar2(30)
variable b2 varchar2(30)
variable b3 varchar2(30)

exec system.rman_chk.recoverability(1, sysdate-1, :b1, :b2, :b3, TRUE)

select	sysdate, :b1 pitr_bkup, :b2 pitr_beyond_bkup, :b3 bkup_type from dual;

spool off
