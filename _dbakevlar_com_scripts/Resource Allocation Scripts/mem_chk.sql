--SGA Roundup
SELECT
name, ROUND(SUM(bytes/1024/1024)) MB FROM V$SGASTAT
GROUP
BY ROLLUP(name)
order
by MB desc;