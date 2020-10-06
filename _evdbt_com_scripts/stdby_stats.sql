/*******************************************************************************
 * File:	stdby_stats.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman
 * Date:	20dec12
 *
 * Description:
 *	SQL*Plus script to display statistics about the "health" of standby
 *	database destinations using MAXIMUM PERFORMANCE (i.e. ARCH) mode.
 *
 *	The report has multiple sections...
 *		1. rolling 72-hour summary by standby destination
 *		2. rolling 24-hour summary by standby destination
 *		3. daily summary of redo archives for archive destinations - by destination
 *		4. daily summary of redo archives for archive destinations - by date
 *		3. hourly summary of redo archives for archive destinations - by destination
 *		4. hourly summary of redo archives for archive destinations - by date
 *
 *	The intent is to provide a top-down report, with more detail provided within
 *	each successive section of the report.
 *
 *	Each section of the report also contains a flagged "Alert" column on the
 *	right-hand side, to alert the reader to pay attention to a particular
 *	row of data.
 *
 * Modifications:
 ******************************************************************************/
set echo off feedback off timing off pagesize 100 linesize 130 trimout on trimspool on verify off pause off
col sort0 noprint
col tm format a18 heading "Time"
col dt format a11 heading "Date"
col hr format a5 heading "Hour"
col sequence# format 99999990 heading "Sequence#"
col standby_dest format a6 heading "Stdby?"
col name format a15 heading "Name"
col mbytes format 999,990.00 heading "Avg|Mbytes|gen'd"
col arch_cnt format 999,990 heading "Avg #|Archivals|gen'd"
col arch_appld format 999,990 heading "Avg #|Archivals|applied"
col redo_secs format 999,990 heading "Avg Secs|of redo|per arch"
col arch_secs format 999,990 heading "Avg Secs|to arch"
col avg_arch_secs format 999,990 heading "Avg|Secs|to arch"
col max_arch_secs format 999,990 heading "Max|Secs|to arch"
col avg_mbps format 999,990.00 heading "Avg|Mbps|during|archival"
col max_mbps format 999,990.00 heading "Max|Mbps|during|archival"
col latest_generated format 999,999,990 heading "Secs|since|last|generated"
col latest_archived format 999,999,990 heading "Secs|since|last|archived"
col latest_applied format 999,999,990 heading "Secs|since|last|applied"
col dbname new_value V_DBNAME noprint
col alert format a5 heading "Alert"
select name dbname from v$database;
spool stdby_stats_&&V_DBNAME

clear breaks computes
ttitle center '"&&V_DBNAME" rolling 72-hour summary of redo archives for archive destinations - by destination' skip line
select	name,
	arch_cnt,
	arch_appld,
	latest_generated,
	latest_archived,
	latest_applied,
	avg_arch_secs,
	max_arch_secs,
	avg_mbps,
	max_mbps,
	case when arch_cnt > (arch_appld+1) or
		  latest_generated > 7200 or
		  latest_archived > 4800 or
		  latest_applied > 3600 then '<==' else ''
	end alert
from	(select	name,
		count(*) arch_cnt,
		sum(decode(applied,'YES',1,0)) arch_appld,
		(sysdate-max(next_time))*86400 latest_generated,
		(sysdate-max(decode(archived,'YES',next_time,null)))*86400 latest_archived,
		(sysdate-max(decode(applied,'YES',next_time,null)))*86400 latest_applied,
		avg(arch_secs) avg_arch_secs,
		max(arch_secs) max_arch_secs,
		avg(mbps) avg_mbps,
		max(mbps) max_mbps
	 from	(select	completion_time,
			next_time,
			archived,
			applied,
			name,
			(blocks*block_size)/1048576 mbytes,
			(next_time-first_time)*86400 redo_secs,
			(completion_time-next_time)*86400 arch_secs,
			decode((completion_time-next_time)*86400, 0, 0,
				((((blocks*block_size)/1048576)*8)/((completion_time-next_time)*86400))) mbps
		 from	v$archived_log
		 where	standby_dest = 'YES'
		 and	next_time >= (sysdate-3))
	 group by name
	 order by name);

clear breaks computes
ttitle center '"&&V_DBNAME" rolling 24-hour summary of redo archives for archive destinations - by destination' skip line
select	name,
	arch_cnt,
	arch_appld,
	latest_generated,
	latest_archived,
	latest_applied,
	avg_arch_secs,
	max_arch_secs,
	avg_mbps,
	max_mbps,
	case when arch_cnt > (arch_appld+1) or
		  latest_generated > 7200 or
		  latest_archived > 4800 or
		  latest_applied > 3600 then '<==' else ''
	end alert
from	(select	name,
		count(*) arch_cnt,
		sum(decode(applied,'YES',1,0)) arch_appld,
		(sysdate-max(next_time))*86400 latest_generated,
		(sysdate-max(decode(archived,'YES',next_time,null)))*86400 latest_archived,
		(sysdate-max(decode(applied,'YES',next_time,null)))*86400 latest_applied,
		avg(arch_secs) avg_arch_secs,
		max(arch_secs) max_arch_secs,
		avg(mbps) avg_mbps,
		max(mbps) max_mbps
	 from	(select	completion_time,
			next_time,
			archived,
			applied,
			name,
			(blocks*block_size)/1048576 mbytes,
			(next_time-first_time)*86400 redo_secs,
			(completion_time-next_time)*86400 arch_secs,
			decode((completion_time-next_time)*86400, 0, 0,
				((((blocks*block_size)/1048576)*8)/((completion_time-next_time)*86400))) mbps
		 from	v$archived_log
		 where	standby_dest = 'YES'
		 and	next_time >= (sysdate-1))
	group by name
	order by name);

clear breaks computes
break on dt on report
ttitle center '"&&V_DBNAME" daily summaries of redo archives for archive destinations - by date' skip line
select	dt,
	name,
	standby_dest,
	arch_cnt,
	arch_appld,
	mbytes,
	redo_secs,
	avg_arch_secs,
	max_arch_secs,
	avg_mbps,
	max_mbps,
	case when arch_cnt > (arch_appld+1) or
		  avg_arch_secs > 1800 or
		  max_arch_secs > 3600 then '<==' else ''
	end alert
from	(select	to_char(completion_time, 'YYYYMMDD') sort0,
		to_char(completion_time, 'DD-MON-YYYY') dt,
		name,
		standby_dest,
		count(*) arch_cnt,
		decode(standby_dest,'NO',to_number(null),sum(decode(applied,'YES',1,0))) arch_appld,
		avg(mbytes) mbytes,
		avg(redo_secs) redo_secs,
		avg(arch_secs) avg_arch_secs,
		max(arch_secs) max_arch_secs,
		avg(mbps) avg_mbps,
		max(mbps) max_mbps
	 from	(select	completion_time,
			applied,
			standby_dest,
			(blocks*block_size)/1048576 mbytes,
			(next_time-first_time)*86400 redo_secs,
			decode(standby_dest, 'YES', name, 'LOCAL') name,
			(completion_time-next_time)*86400 arch_secs,
			decode((completion_time-next_time)*86400, 0, 0,
				((((blocks*block_size)/1048576)*8)/((completion_time-next_time)*86400))) mbps
		 from	v$archived_log
		 where	archived = 'YES')
	 group by to_char(completion_time, 'YYYYMMDD'),
		  to_char(completion_time, 'DD-MON-YYYY'),
		  name,
		  standby_dest
	 order by sort0,
		  standby_dest,
		  name);

clear breaks computes
break on name skip 1 on standby_dest on report
ttitle center '"&&V_DBNAME" daily summaries of redo archives for archive destinations - by destination' skip line
compute avg of arch_cnt on name
compute avg of arch_appld on name
compute avg of mbytes on name
compute avg of redo_secs on name
compute avg of avg_arch_secs on name
compute max of max_arch_secs on name
compute avg of avg_mbps on name
compute max of max_mbps on name
select	name,
	standby_dest,
	dt,
	arch_cnt,
	arch_appld,
	mbytes,
	redo_secs,
	avg_arch_secs,
	max_arch_secs,
	avg_mbps,
	max_mbps,
	case when arch_cnt > (arch_appld+1) or
		  avg_arch_secs > 1800 or
		  max_arch_secs > 3600 then '<==' else ''
	end alert
from	(select	name,
		standby_dest,
		to_char(completion_time, 'YYYYMMDD') sort0,
		to_char(completion_time, 'DD-MON-YYYY') dt,
		count(*) arch_cnt,
		decode(standby_dest,'NO',to_number(null),sum(decode(applied,'YES',1,0))) arch_appld,
		avg(mbytes) mbytes,
		avg(redo_secs) redo_secs,
		avg(arch_secs) avg_arch_secs,
		max(arch_secs) max_arch_secs,
		avg(mbps) avg_mbps,
		max(mbps) max_mbps
	 from	(select	completion_time,
			applied,
			standby_dest,
			(blocks*block_size)/1048576 mbytes,
			(next_time-first_time)*86400 redo_secs,
			decode(standby_dest, 'YES', name, 'LOCAL') name,
			(completion_time-next_time)*86400 arch_secs,
			decode((completion_time-next_time)*86400, 0, 0,
				((((blocks*block_size)/1048576)*8)/((completion_time-next_time)*86400))) mbps
		 from	v$archived_log
		 where	archived = 'YES')
	 group by standby_dest,
		  name,
		  to_char(completion_time, 'YYYYMMDD'),
		  to_char(completion_time, 'DD-MON-YYYY')
	 order by standby_dest,
		  name,
		  sort0);

clear breaks computes
break on dt on hr on report
ttitle center '"&&V_DBNAME" hourly summaries of redo archives for standby destinations - by hour' skip line
select	dt,
	hr,
	name,
	arch_cnt,
	arch_appld,
	avg_arch_secs,
	max_arch_secs,
	avg_mbps,
	max_mbps,
	case when arch_cnt > (arch_appld+1) or
		  avg_arch_secs > 600 or
		  max_arch_secs > 1200 then '<==' else ''
	end alert
from	(select	to_char(completion_time, 'YYYYMMDDHH24') sort0,
		to_char(completion_time, 'DD-MON-YYYY') dt,
		to_char(completion_time, 'HH24')||':00' hr,
		name,
		count(*) arch_cnt,
		sum(decode(applied,'YES',1,0)) arch_appld,
		avg(arch_secs) avg_arch_secs,
		max(arch_secs) max_arch_secs,
		avg(mbps) avg_mbps,
		max(mbps) max_mbps
	 from	(select	completion_time,
			applied,
			(blocks*block_size)/1048576 mbytes,
			(next_time-first_time)*86400 redo_secs,
			name,
			(completion_time-next_time)*86400 arch_secs,
			decode((completion_time-next_time)*86400, 0, 0,
				((((blocks*block_size)/1048576)*8)/((completion_time-next_time)*86400))) mbps
		 from	v$archived_log
		 where	archived = 'YES'
		 and	standby_dest = 'YES')
	 group by to_char(completion_time, 'YYYYMMDDHH24'),
		  to_char(completion_time, 'DD-MON-YYYY'),
		  to_char(completion_time, 'HH24')||':00',
		  name
	 order by sort0,
		  name);

clear breaks computes
break on name skip 1 on dt on report
ttitle center '"&&V_DBNAME" hourly summaries of redo archives for standby destinations - by destination' skip line
select	name,
	dt,
	hr,
	arch_cnt,
	arch_appld,
	avg_arch_secs,
	max_arch_secs,
	avg_mbps,
	max_mbps,
	case when arch_cnt > (arch_appld+1) or
		  avg_arch_secs > 600 or
		  max_arch_secs > 1200 then '<==' else ''
	end alert
from	(select	name,
		to_char(completion_time, 'YYYYMMDDHH24') sort0,
		to_char(completion_time, 'DD-MON-YYYY') dt,
		to_char(completion_time, 'HH24')||':00' hr,
		count(*) arch_cnt,
		sum(decode(applied,'YES',1,0)) arch_appld,
		avg(arch_secs) avg_arch_secs,
		max(arch_secs) max_arch_secs,
		avg(mbps) avg_mbps,
		max(mbps) max_mbps
	 from	(select	completion_time,
			applied,
			(blocks*block_size)/1048576 mbytes,
			(next_time-first_time)*86400 redo_secs,
			name,
			(completion_time-next_time)*86400 arch_secs,
			decode((completion_time-next_time)*86400, 0, 0,
				((((blocks*block_size)/1048576)*8)/((completion_time-next_time)*86400))) mbps
		 from	v$archived_log
		 where	archived = 'YES'
		 and	standby_dest = 'YES')
	 group by name,
		  to_char(completion_time, 'YYYYMMDDHH24'),
		  to_char(completion_time, 'DD-MON-YYYY'),
		  to_char(completion_time, 'HH24')||':00'
	 order by name,
		  sort0);

spool off
clear breaks computes
ttitle off
set feedback 6 verify on
