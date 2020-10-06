--check for mview lags
set lines 128
set trimout on
column "MVIEW BEING REFRESHED" format a22
column SID format 999999
column ROWS_PROCESSES format 999,999,999
select to_char(sysdate,'hh24:mi:ss') as NOW,
SID_KNST as SID,
CURRMVOWNER_KNSTMVR || '.' || CURRMVNAME_KNSTMVR "MVIEW BEING REFRESHED",
decode( REFTYPE_KNSTMVR, 1, 'FAST', 2, 'COMPLETE', 'UNKNOWN' ) REFTYPE,
decode(GROUPSTATE_KNSTMVR, 1, 'SETUP', 2, 'INSTANTIATE', 3, 'WRAPUP', 'UNKNOWN' ) STATE,
( TOTAL_INSERTS_KNSTMVR /* INSERTS */ +
TOTAL_UPDATES_KNSTMVR /* UPDATES */ +
TOTAL_DELETES_KNSTMVR /* DELETES */ ) as ROWS_PROCESSED
from X$KNSTMVR X
WHERE type_knst=6
and exists (select 1 from v$session s
where s.sid=x.sid_knst
and s.serial#=x.serial_knst);