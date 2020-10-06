--Check Full Scans in DB
COLUMN user_process FORMAT A20 HEADING "Username(Process ID)"
COLUMN short_scans FORMAT 999,999,999 HEADING "Short Scans"
COLUMN long_scans FORMAT 999,999,999 HEADING "Long Scans"
COLUMN blocks_retrieved FORMAT 999,999,999 HEADING "Blocks Retrieved"
COLUMN avr_scan_blocks FORMAT 999,999,999.99 HEADING "Avr Scan (blocks)"
SELECT SS.username || '(' || se.sid || ') ' AS user_process,
Sum( Decode(name, 'table scans (short tables)', value) ) AS short_scans,
Sum( Decode(name, 'table scans (long tables)', value) ) AS long_scans,
Sum( Decode(name, 'table scan blocks gotten', value) ) AS block_retrieved,
(Sum( Decode(name, 'table scan blocks gotten', value) ) - (Sum( Decode(name, 'table scans (short tables)', value) ) * 5)),
Sum( Decode(name, 'table scans (long tables)', value) ) AS avr_scan_blocks
FROM v$session SS,
v$sesstat SE,
v$statname SN
WHERE SE.statistic# = SN.statistic#
AND (name Like '%table scans (short tables)%'
OR
name Like '%table scans (long tables)%'
OR
name Like '%table scan blocks gotten%')
AND SE.sid = SS.sid
AND SS.username IS NOT NULL
GROUP BY SS.username || '(' || SE.sid || ') '
HAVING Sum( Decode(name, 'table scans (long tables)', value) ) <> 0
ORDER BY long_scans DESC;