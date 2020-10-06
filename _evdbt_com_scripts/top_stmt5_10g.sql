/**********************************************************************
 * File:	top_stmt5_10g.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:	21-Mar-2008
 *
 * Description:
 *	DDL script to create the TOP_STMT5 stored procedure, which
 *	reads from AWR tables instead of STATSPACK tables, as the
 *	TOP_STMT4 procedure did...
 *
 *	This version of TOP_STMT5 is intended to used with Oracle10g.
 *
 * Modifications:
 *	TGorman	17mar04	adapted from previous TOP_STMTx procedures...
 *	TGorman 02may04	corrected bug in LAG() OVER clause
 *	TGorman 10aug04	corrected bug in query on STATS$SYSSTAT and
 *			removed unnecessary PARTITION BY DBID,
 *			INSTANCE_NUMBER phrases from queries using
 *			LAG () analytic functions
 *	TGorman	17sep04	improved efficiency of cursor "get_top_stmts"
 *			by joining STATS$SQL_SUMMARY and STATS$SNAPSHOT
 *			in the inner-most in-line view subquery
 *	TGorman	21sep04	added display of EXPLAIN PLAN information from
 *			STATS$SQL_PLAN and STATS$SQL_PLAN_USAGE
 *	TGorman	17oct05	adapted for Oracle10g
 *	TGorman	21mar08	adapted for AWR in Oracle10g
 *********************************************************************/
set echo on feedback on timing on

spool top_stmt5_10g

create or replace procedure top_stmt5
(
	in_start_date in date,
	in_nbr_days in number,
	in_top_count in integer default 10,
	in_instance_nbr in number DEFAULT NULL,
	in_max_disk_reads in integer default 10000,
	in_max_buffer_gets in integer default 100000
) is
	--
	cursor get_top_stmts(in_dr in integer, in_bg in integer,
			     in_dbid in integer, in_inst_nbr in integer,
			     in_begin_time in timestamp, in_end_time in timestamp)
	is
	select	 sq.sql_id,
		 sq.module,
		 st.command_type,
		 sum(sq.disk_reads_delta) disk_reads,
		 sum(sq.buffer_gets_delta) buffer_gets,
		 sum(sq.cpu_time_delta)/1000000 cpu_time,
		 sum(sq.elapsed_time_delta)/1000000 elapsed_time,
		 sum(sq.executions_delta) executions,
		 (1 - (sum(sq.disk_reads_delta) / sum(sq.buffer_gets_delta)))*100 bchr,
		 sum(sq.disk_reads_delta) / sum(sq.executions_delta) dr_per_exe,
		 sum(sq.buffer_gets_delta) / sum(sq.executions_delta) bg_per_exe,
		 sum(sq.cpu_time_delta)/1000000 / sum(sq.executions_delta) cpu_per_exe,
		 sum(sq.elapsed_time_delta)/1000000 / sum(sq.executions_delta) ela_per_exe,
		 ((sum(sq.disk_reads_delta)*100)+sum(sq.buffer_gets_delta))/100 factor
	from	 dba_hist_sqltext		st,
		 dba_hist_sqlstat		sq,
		 dba_hist_snapshot		ss
	where	 ss.dbid = in_dbid
	and	 ss.instance_number = nvl(in_inst_nbr, ss.instance_number)
	and	 ss.begin_interval_time between in_begin_time and in_end_time
	and	 sq.dbid = ss.dbid
	and	 sq.instance_number = ss.instance_number
	and	 sq.snap_id = ss.snap_id
	and	 st.sql_id = sq.sql_id
	group by sq.sql_id,
		 sq.module,
		 st.command_type
	having	 (sum(sq.disk_reads_delta) > in_dr
	  or	  sum(sq.buffer_gets_delta) > in_bg)
	and	 sum(sq.buffer_gets_delta) > 0
	and	 sum(sq.executions_delta) > 0
	order by factor desc;
	--
	cursor get_sql_plan(in_dbid in number,
			    in_sql_id in varchar2,
			    in_begin_time in timestamp,
			    in_end_time in timestamp)
	is
	select	distinct plan_hash_value, timestamp
	from	dba_hist_sql_plan
	where	dbid = in_dbid
	and	sql_id = in_sql_id
	and	timestamp between in_begin_time and in_end_time
	order by 2;
	--
	v_text_lines		integer;
	v_sql_text		clob;
	v_sql_text_len		integer;
	n			integer;
	v_tot_logr		integer;
	v_tot_phyr		integer;
	v_sql_tot_cnt		integer := 0;
	v_sql_tot_dr		integer := 0;
	v_sql_tot_bg		integer := 0;
	v_sql_tot_cpu		integer := 0;
	v_sql_tot_ela		integer := 0;
	v_plsql_tot_cnt		integer := 0;
	v_plsql_tot_dr		integer := 0;
	v_plsql_tot_bg		integer := 0;
	v_plsql_tot_cpu		integer := 0;
	v_plsql_tot_ela		integer := 0;
	v_dbid			integer;
	v_instance_nbr		integer;
	v_begin_snapshot	timestamp;
	v_end_snapshot		timestamp;
	v_nbr_snapshots		integer;
	v_nbr_instances		integer;
	v_plan_id		integer;
	--
	v_errcontext		varchar2(100);
	v_errmsg		varchar2(512);
	v_save_module		varchar2(48);
	v_save_action		varchar2(32);
	--
begin
--
dbms_application_info.read_module(v_save_module, v_save_action);
v_errcontext := 'query dba_hist_database_instance';
dbms_application_info.set_module('TOP_STMT5', v_errcontext);
select	h.dbid, decode(in_instance_nbr, null, null, i.instance_number), count(distinct i.instance_number)
into	v_dbid, v_instance_nbr, v_nbr_instances
from	dba_hist_database_instance	h,
	gv$instance			i
where	h.instance_number = i.instance_number
and	i.instance_number = nvl(in_instance_nbr, i.instance_number)
group by h.dbid, decode(in_instance_nbr, null, null, i.instance_number);
--
v_errcontext := 'query dba_hist_snapshot';
dbms_application_info.set_action(v_errcontext);
select	min(begin_interval_time),
	max(end_interval_time),
	count(*)
into	v_begin_snapshot,
	v_end_snapshot,
	v_nbr_snapshots
from	dba_hist_snapshot
where	begin_interval_time between in_start_date and (in_start_date + in_nbr_days)
and	dbid = v_dbid
and	instance_number = nvl(v_instance_nbr, instance_number);
--
v_errcontext := 'query dba_hist_sysstat';
dbms_application_info.set_action(v_errcontext);
select	sum(cg.value_delta+dbg.value_delta),
	sum(p.value_delta)
into	v_tot_logr,
	v_tot_phyr
from	(select dbid, instance_number, snap_id,
		decode(greatest(value, lag(value,1,0) over (partition by dbid, instance_number order by snap_id)),
		       value, value - lag(value,1,0) over (partition by dbid, instance_number order by snap_id),
		       value) value_delta
	 from	dba_hist_sysstat
	 where	stat_name = 'consistent gets')		cg,
	(select dbid, instance_number, snap_id,
		decode(greatest(value, lag(value,1,0) over (partition by dbid, instance_number order by snap_id)),
		       value, value - lag(value,1,0) over (partition by dbid, instance_number order by snap_id),
		       value) value_delta
	 from	dba_hist_sysstat
	 where	stat_name = 'db block gets')		dbg,
	(select dbid, instance_number, snap_id,
		decode(greatest(value, lag(value,1,0) over (partition by dbid, instance_number order by snap_id)),
		       value, value - lag(value,1,0) over (partition by dbid, instance_number order by snap_id),
		       value) value_delta
	 from	dba_hist_sysstat
	 where	stat_name = 'physical reads')		p,
	dba_hist_snapshot				s
where	s.begin_interval_time between in_start_date and (in_start_date + in_nbr_days)
and	s.dbid = v_dbid
and	s.instance_number = nvl(v_instance_nbr, s.instance_number)
and	cg.snap_id = s.snap_id
and	cg.dbid = s.dbid
and	cg.instance_number = s.instance_number
and	dbg.snap_id = s.snap_id
and	dbg.dbid = s.dbid
and	dbg.instance_number = s.instance_number
and	p.snap_id = s.snap_id
and	p.dbid = s.dbid
and	p.instance_number = s.instance_number;
--
v_errcontext := 'open/fetch get_top_stmts';
dbms_application_info.set_action(v_errcontext);
for a in get_top_stmts(in_max_disk_reads, in_max_buffer_gets,
		       v_dbid, v_instance_nbr,
		       v_begin_snapshot, v_end_snapshot) loop
	--
	if get_top_stmts%rowcount > in_top_count then
		--
		exit;
		--
	end if;
	--
	v_errcontext := 'put_line formfeed';
	dbms_application_info.set_action(v_errcontext);
	if get_top_stmts%rowcount > 1 then
		--
		dbms_output.put_line(chr(12));
		--
	end if;
	--
	v_errcontext := 'put_line statement header';
	dbms_application_info.set_action(v_errcontext);
	dbms_output.put_line(rpad('Beginning Snap Time: ',30) ||
			to_char(v_begin_snapshot, 'MM/DD/YY HH24:MI:SS') ||
			lpad('Page ' ||
			     to_char(get_top_stmts%rowcount,'990'),60));
	dbms_output.put_line(rpad('Ending Snap Time : ',30) ||
			to_char(v_end_snapshot, 'MM/DD/YY HH24:MI:SS') ||
			lpad('Nbr of Snapshots: ' ||
			     to_char(v_nbr_snapshots,'990'),60));
	dbms_output.put_line(rpad('Date of Report : ',30) ||
			to_char(sysdate, 'MM/DD/YY HH24:MI:SS') ||
			lpad('Nbr of Instances: ' ||
			     to_char(v_nbr_instances,'990'),60));
	dbms_output.put_line(rpad('Total Logical Reads: ', 23) ||
			to_char(v_tot_logr,'999,999,999,999,999,990') ||
			lpad('Total Physical Reads: ' ||
			to_char(v_tot_phyr,'999,999,999,999,999,990'), 60));
	dbms_output.put_line('.');
	--
	if a.module is not null then
		v_errcontext := 'display module';
		dbms_output.put_line('Module: "' || a.module || '"');
		dbms_output.put_line('.');
	end if;
	--
	dbms_output.put_line('SQL Statement Text (SQL ID=' || a.sql_id || ')');
	dbms_output.put_line('-------------------------------' || rpad('-', length(trim(to_char(a.sql_id))), '-') || '-');
	--
	v_errcontext := 'get sql_text from dba_hist_sqltext';
	dbms_application_info.set_action(v_errcontext);
	select	sql_text,
		dbms_lob.getlength(sql_text) len
	into	v_sql_text,
		v_sql_text_len
	from	dba_hist_sqltext
	where	sql_id = a.sql_id;
	v_text_lines := 1;
	n := 1;
	while n < v_sql_text_len loop
		--
		dbms_output.put_line(rpad(to_char(v_text_lines),6) ||
			replace(dbms_lob.substr(v_sql_text, 100, n),chr(10),null));
		n := n + 100;
		v_text_lines := v_text_lines + 1;
		--
		v_errcontext := 'fetch/close get_text';
		--
	end loop;
	--
	v_errcontext := 'put_line statement totals';
	dbms_application_info.set_action(v_errcontext);
	dbms_output.put_line('.');
	dbms_output.put_line(':' ||
				lpad('Disk ',16) ||
				lpad('Buffer',16) ||
				lpad('Cache Hit',10) ||
				lpad(' ',11) ||
				lpad('DR Per',12) ||
				lpad('BG Per',12) ||
				lpad('CPU Per',15) ||
				lpad('Ela Per',15));
	dbms_output.put_line(':' ||
				lpad('Reads',16) ||
				lpad('Gets',16) ||
				lpad('Ratio',10) ||
				lpad('Runs',11) ||
				lpad('Run',12) ||
				lpad('Run',12) ||
				lpad('Run',15) ||
				lpad('Run',15));
	dbms_output.put_line(':' ||
				lpad('-----',16) ||
				lpad('------',16) ||
				lpad('---------',10) ||
				lpad('----',11) ||
				lpad('------',12) ||
				lpad('------',12) ||
				lpad('------',15) ||
				lpad('------',15));
	dbms_output.put_line(':' ||
		lpad(ltrim(to_char(a.disk_reads,'999,999,999,990')),16) ||
		lpad(ltrim(to_char(a.buffer_gets,'999,999,999,990')),16) ||
		lpad(ltrim(to_char(a.bchr,'990.00')||'%'),10) ||
		lpad(ltrim(to_char(a.executions,'99,999,990')),11) ||
		lpad(ltrim(to_char(a.dr_per_exe,'999,999,990')),12) ||
		lpad(ltrim(to_char(a.bg_per_exe,'999,999,990')),12) ||
		lpad(ltrim(to_char(a.cpu_per_exe,'999,999,990.00')),15) ||
		lpad(ltrim(to_char(a.ela_per_exe,'999,999,990.00')),15));
	dbms_output.put_line(':' ||
		lpad('('||ltrim(to_char(round((a.disk_reads/v_tot_phyr)*100,3),
				   '990.000'))||'%)',16) ||
		lpad('('||ltrim(to_char(round((a.buffer_gets/v_tot_logr)*100,3),
				   '990.000'))||'%)',16));
	--
	v_errcontext := 'open/fetch get_sql_plan';
	dbms_application_info.set_action(v_errcontext);
	for p in get_sql_plan(v_dbid, a.sql_id, v_begin_snapshot, v_end_snapshot) loop
		--
		v_text_lines := 0;
		v_errcontext := 'open/fetch get_xplan';
		dbms_application_info.set_action(v_errcontext);
		for s in (select plan_table_output
			  from	 table(dbms_xplan.display_awr(a.sql_id, p.plan_hash_value, v_dbid, 'ALL'))) loop
			--
			if s.plan_table_output like 'Plan hash value: %' then
				v_text_lines := 1;
			end if;
			--
			if v_text_lines = 1 then
				dbms_output.put_line('.');
				dbms_output.put_line('.  SQL execution plan from "'||
					to_char(p.timestamp,'MM/DD/YY HH24:MI:SS') || '"');
			end if;
			--
			if v_text_lines >= 1 then
				dbms_output.put_line(s.plan_table_output);
				v_text_lines := v_text_lines + 1;
			end if;
			--
		end loop;
		--
		v_errcontext := 'fetch/close get_sql_plan';
		--
	end loop;
	--
	if a.command_type = 47 then
		--
		v_plsql_tot_cnt := v_plsql_tot_cnt + 1;
		v_plsql_tot_dr := v_plsql_tot_dr + a.disk_reads;
		v_plsql_tot_bg := v_plsql_tot_bg + a.buffer_gets;
		v_plsql_tot_cpu := v_plsql_tot_cpu + a.cpu_time;
		v_plsql_tot_ela := v_plsql_tot_ela + a.elapsed_time;
		--
	else
		--
		v_sql_tot_cnt := v_sql_tot_cnt + 1;
		v_sql_tot_dr := v_sql_tot_dr + a.disk_reads;
		v_sql_tot_bg := v_sql_tot_bg + a.buffer_gets;
		v_sql_tot_cpu := v_sql_tot_cpu + a.cpu_time;
		v_sql_tot_ela := v_sql_tot_ela + a.elapsed_time;
		--
	end if;
	--
	v_errcontext := 'fetch/close get_top_stmt';
	dbms_application_info.set_action(v_errcontext);
	--
end loop;
--
if v_sql_tot_cnt > 0 then
	--
	v_errcontext := 'put_line SQL cumulative totals';
	dbms_application_info.set_action(v_errcontext);
	dbms_output.put_line('.');
	dbms_output.put_line('.');
	dbms_output.put_line(': =============================================================================');
	dbms_output.put_line(':');
	dbms_output.put_line(': >>> CUMULATIVE TOTALS FOR '||v_sql_tot_cnt||' "TOP ' || in_top_count || '" SQL STATEMENTS <<<');
	dbms_output.put_line(':');
	dbms_output.put_line(':' ||
		lpad('Disk ',16) ||
		lpad('Buffer',20) ||
		lpad('Cache Hit',10) ||
		lpad('CPU',20) ||
		lpad('Elapsed',20));
	dbms_output.put_line(':' ||
		lpad('Reads',16) ||
		lpad('Gets',20) ||
		lpad('Ratio',10) ||
		lpad('Time',20) ||
		lpad('Time',20));
	dbms_output.put_line(':' ||
		lpad('-----',16) ||
		lpad('------',20) ||
		lpad('---------',10) ||
		lpad('---------',20) ||
		lpad('---------',20));
	dbms_output.put_line(':' ||
		lpad(ltrim(to_char(v_sql_tot_dr,'999,999,999,990')),16) ||
		lpad(ltrim(to_char(v_sql_tot_bg,'999,999,999,999,990')),20) ||
		lpad(ltrim(to_char((1 - (v_sql_tot_dr/v_sql_tot_bg))*100,'990.00')||'%'),10) ||
		lpad(ltrim(to_char(v_sql_tot_cpu,'999,999,999,999,990')),20) ||
		lpad(ltrim(to_char(v_sql_tot_ela,'999,999,999,999,990')),20));
	dbms_output.put_line(':' ||
		lpad('('||ltrim(to_char(round((v_sql_tot_dr/v_tot_phyr)*100,3),
			   	'990.000'))||'%)',16) ||
		lpad('('||ltrim(to_char(round((v_sql_tot_bg/v_tot_logr)*100,3),
			   	'990.000'))||'%)',20));
	--
end if;
--
if v_plsql_tot_cnt > 0 then
	--
	v_errcontext := 'put_line PLSQL cumulative totals';
	dbms_application_info.set_action(v_errcontext);
	dbms_output.put_line('.');
	dbms_output.put_line('.');
	dbms_output.put_line(': =============================================================================');
	dbms_output.put_line(':');
	dbms_output.put_line(': >>> CUMULATIVE TOTALS FOR '||v_plsql_tot_cnt||' "TOP '||in_top_count||'" PL/SQL STATEMENTS <<<');
	dbms_output.put_line(':');
	dbms_output.put_line(':' ||
		lpad('Disk ',20) ||
		lpad('Buffer',20) ||
		lpad('Cache Hit',10) ||
		lpad('CPU',20) ||
		lpad('Elapsed',20));
	dbms_output.put_line(':' ||
		lpad('Reads',16) ||
		lpad('Gets',20) ||
		lpad('Ratio',10) ||
		lpad('Time',20) ||
		lpad('Time',20));
	dbms_output.put_line(':' ||
		lpad('-----',20) ||
		lpad('------',20) ||
		lpad('---------',10) ||
		lpad('---------',20) ||
		lpad('---------',20));
	dbms_output.put_line(':' ||
		lpad(ltrim(to_char(v_plsql_tot_dr,'999,999,999,999,990')),20) ||
		lpad(ltrim(to_char(v_plsql_tot_bg,'999,999,999,999,990')),20) ||
		lpad(ltrim(to_char((1 - (v_plsql_tot_dr/v_plsql_tot_bg))*100,'990.00')||'%'),10) ||
		lpad(ltrim(to_char(v_plsql_tot_cpu,'999,999,999,999,990')),20) ||
		lpad(ltrim(to_char(v_plsql_tot_ela,'999,999,999,999,990')),20));
	dbms_output.put_line(':' ||
		lpad('('||ltrim(to_char(round((v_plsql_tot_dr/v_tot_phyr)*100,3),
			   	'990.000'))||'%)',20) ||
		lpad('('||ltrim(to_char(round((v_plsql_tot_bg/v_tot_logr)*100,3),
			   	'990.000'))||'%)',20));
	--
end if;
--
rollback;
--
dbms_application_info.set_module(v_save_module, v_save_action);
--
exception
	when others then
		v_errmsg := sqlerrm;
		dbms_application_info.set_module(v_save_module, v_save_action);
		rollback;
		raise_application_error(-20000, v_errcontext || ': ' || v_errmsg);
end top_stmt5;
/
show errors
spool off
