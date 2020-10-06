 SELECT name, value
   FROM SYS.v_$sysstat
 WHERE NAME in ('redo buffer allocation retries',
                'redo log space wait time');
