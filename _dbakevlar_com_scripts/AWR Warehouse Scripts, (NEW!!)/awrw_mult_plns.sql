select
  SQL_ID
, PLAN_HASH_VALUE
, sum(EXECUTIONS_DELTA) EXECUTIONS
, sum(ROWS_PROCESSED_DELTA) CROWS
, trunc(sum(CPU_TIME_DELTA)/1000000/60) CPU_MINS
, trunc(sum(ELAPSED_TIME_DELTA)/1000000/60)  ELA_MINS
from DBA_HIST_SQLSTAT S, DBSNMP.CAW_DBID_MAPPING M
where LOWER(M.TARGET_NAME) = '&dbname'
and M.NEW_DBID = S.DBID
and S.SQL_ID in ('&sqlid')
group by SQL_ID , PLAN_HASH_VALUE
order by SQL_ID, CPU_MINS;