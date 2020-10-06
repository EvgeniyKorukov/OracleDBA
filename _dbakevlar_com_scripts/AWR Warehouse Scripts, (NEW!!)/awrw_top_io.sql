select * from
(
SELECT /*+LEADING(x h) USE_NL(h)*/
       h.sql_id
,      SUM(10) ash_secs
FROM   dba_hist_snapshot x
,      dba_hist_active_sess_history h
,      dbsnmp.caw_dbid_mapping m
WHERE  LOWER(m.target_name) = '&dbname'
AND    x.dbid = m.new_dbid
AND    h.dbid = x.dbid
AND    x.begin_interval_time > sysdate -&days_bk
AND    h.SNAP_id = X.SNAP_id
AND    h.instance_number = x.instance_number
AND    h.event in  ('db file sequential read','db file scattered read')
GROUP BY h.sql_id
ORDER BY ash_secs desc)
where rownum <= &num_rows;
