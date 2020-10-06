--Check Redo Size
SELECT A.*,
Round(A.NUMBER_of_LOGS*B.AVG#/1024/1024) Daily_Avg_Mb
FROM
(
SELECT
To_Char(First_Time,'YYYY-MM-DD') DAY,
Count(1) NUMBER_OF_LOGS,
Min(RECID) MIN_RECID,
Max(RECID) MAX_RECID
FROM
v$log_history
GROUP
BY To_Char(First_Time,'YYYY-MM-DD')
ORDER
BY 1 DESC
) A,
(
SELECT
Avg(BYTES) AVG#,
Count(1) NUMBER_of_LOGS,
Max(BYTES) Max_Bytes,
Min(BYTES) Min_Bytes
FROM
v$log
) B
;