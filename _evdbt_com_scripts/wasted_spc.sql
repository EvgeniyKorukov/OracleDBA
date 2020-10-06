/**********************************************************************
 * File:	wasted_spc.sql
 * Type:	SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:	26-Aug 2011
 *
 * Description:
 *      SQL*Plus script to use cost-based optimizer (CBO) statistics to
 *      calculate whether a table consists of 25% or more "wasted" space,
 *      making it a good candidate for the Oracle10g ALTER TABLE ...
 *      SHRINK SPACE command.
 *
 *      The script uses the following assumptions...
 *	- does not include tables in the SYS, SYSTEM, or OUTLN schemas
 *	- does not include tables which do not have CBO stats gathered
 *	- does not include tables less than 5Mb in size
 *	- does not include tables estimated less than 25% "wasted"
 *
 *      Because there are several restrictions on the ALTER TABLE ...
 *      SHRINK SPACE command, the script also detects whether the table
 *      is likely to run afoul of those restrictions or not...
 *
 *	- owner (schema) and name of the table
 *	- Mb allocated to the segment
 *	- Mb underneath the HWM
 *	- estimated Mb used
 *	- estimated Mb wasted
 *	- percentage wasted
 *	-- Is the table an IOT?
 *	-- Is the table part of a table-cluster?
 *	-- Is the table compressed?
 *	-- Does the table reside in a tablespace that is NOT
 *	   "auto" segment space managed?
 *	-- Does the table reside in a tablespace in READ ONLY or OFFLINE status?
 *	-- Is "row movement" not enabled?
 *	-- Any LONG columns on the table?
 *	-- Any bitmap-join indexes on the table?
 *	-- Any function-based indexes on the table?
 *
 *      If any of the last nine (9) questions above can be answered "yes",
 *      then the table might not be able to be shrunk using the ALTER
 *      TABLE ... SHRINK SPACE command.
 *
 *      If any of the nine (9) restrictions above might be relevant, or if
 *      the table has not had statistics gathered in the past 90 days,
 *      then the last column of the report will have an arrow icon
 *      (i.e. "<==") to indicate that there may be a problem with employing
 *	the ALTER TABLE ... SHRINK SPACE command.
 *
 * Modifications:
 *      TGorman 26aug11 adapted from report produced by Manish Garg
 *********************************************************************/
clear breaks computes
break on owner skip 1 on report
compute sum of alloc_mb on owner
compute sum of alloc_mb on report
compute sum of hwm_mb on owner
compute sum of hwm_mb on report
compute sum of estd_used_mb on owner
compute sum of estd_used_mb on report
compute sum of estd_wasted_mb on owner
compute sum of estd_wasted_mb on report
compute count of warn on report
compute count of table_name on report
set echo off feedback off timing off pagesize 1000 linesize 200 trimout on trimspool on tab off verify off
col owner format a20 heading "Owner"
col name format a40 heading "Table Name [:partition [:sub-partition] ]"
col alloc_mb format 999,990 heading "Alloc|Mb"
col hwm_mb format 999,990 heading "HWM|Mb"
col estd_used_mb format 999,990 heading "Est'd|Used|Mb"
col estd_wasted_mb format 999,990 heading "Est'd|Wasted|Mb"
col pct_wasted format 990.00 heading "Est'd|%|Wasted"
col iot format a3 heading ">--||IOT"
col clus format a4 heading "----||Clus"
col cmpr format a4 heading "----||Cmpr"
col assm format a4 heading "----||ASSM"
col status format a9 heading "-Possible||TS Status"
col row_movement format a8 heading "Restrict||Row Move?"
col cnt_longs format 990 heading "ions|#|Long"
col cnt_bji format 990 heading "----|#|BJI"
col cnt_fbi format 990 heading "----|#|FBI"
col last_analyzed format a9 heading "--------<|Last|Analyzed"
col warn format a9 heading "Check for|Restrctns"
col cmd format a195
spool wasted_spc
select  owner,
	name,
	alloc_mb,
	hwm_mb,
	estd_used_mb,
	estd_wasted_mb,
	(estd_wasted_mb/decode(hwm_mb,0,1,hwm_mb))*100 pct_wasted,
	iot,
	clus,
	cmpr,
	assm,
	status,
	row_movement,
	cnt_longs,
	cnt_bji,
	cnt_fbi,
	to_char(last_analyzed, 'DD-MON-YY') last_analyzed,
	case    when    iot <> 'NO' or clus <> 'NO' or cmpr <> 'NO' or assm <> 'YES' or
			cnt_longs > 0 or cnt_bji > 0 or cnt_fbi > 0 or
			(sysdate - last_analyzed) > 90 or status <> 'ONLINE' or
			row_movement = 'DISABLED'
		then '<=='
	end warn
from    (select t.owner,
		t.table_name name,
		(s.blocks*ts.block_size)/1048576 alloc_mb,
		(t.blocks*ts.block_size)/1048576 hwm_mb,
		((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len))/1048576 estd_used_mb,
		((t.blocks*ts.block_size)-((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len)))/1048576 estd_wasted_mb,
		decode(t.iot_name,NULL,'NO','YES') iot,
		decode(t.cluster_name,NULL,'NO','YES') clus,
		decode(t.compression,'ENABLED','YES','NO') cmpr,
		decode(ts.segment_space_management,'AUTO','YES','NO') assm,
		ts.status,
		t.row_movement,
		t.last_analyzed,
		(select count(*)
		 from   dba_tab_columns
		 where  owner = t.owner
		 and    table_name = t.table_name
		 and    data_type = 'LONG') cnt_longs,
		(select count(*)
		 from   dba_indexes
		 where  table_owner = t.owner
		 and    table_name = t.table_name
		 and    index_type like '%BITMAP%'
		 and	join_index = 'YES') cnt_bji,
		(select count(*)
		 from   dba_indexes
		 where  table_owner = t.owner
		 and    table_name = t.table_name
		 and    index_type like '%FUNCTION-BASED%') cnt_fbi
	 from   dba_tables t,
		dba_segments s,
		dba_tablespaces ts
	 where  t.owner not in ('SYS','SYSTEM','OUTLN')
	 and    t.blocks is not null
	 and    t.partitioned = 'NO'
	 and    ts.tablespace_name = t.tablespace_name
	 and    ts.contents = 'PERMANENT'
	 and    ((t.blocks*ts.block_size)/1048576) > 5
	 and    s.owner = t.owner
	 and    s.segment_name = t.table_name
	 and    s.segment_type = 'TABLE'
	 union all
	 select t.table_owner owner,
		t.table_name || ':' || t.partition_name name,
		(s.blocks*ts.block_size)/1048576 alloc_mb,
		(t.blocks*ts.block_size)/1048576 hwm_mb,
		((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len))/1048576 estd_used_mb,
		((t.blocks*ts.block_size)-((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len)))/1048576 estd_wasted_mb,
		decode(t2.iot_name,NULL,'NO','YES') iot,
		'NO' clus,
		decode(t.compression,'ENABLED','YES','NO') cmpr,
		decode(ts.segment_space_management,'AUTO','YES','NO') assm,
		ts.status,
		t2.row_movement,
		t.last_analyzed,
		(select count(*)
		 from   dba_tab_columns
		 where  owner = t.table_owner
		 and    table_name = t.table_name
		 and    data_type = 'LONG') cnt_longs,
		(select count(*)
		 from   dba_indexes
		 where  table_owner = t.table_owner
		 and    table_name = t.table_name
		 and    index_type like '%BITMAP%'
		 and	join_index = 'YES') cnt_bji,
		(select count(*)
		 from   dba_indexes
		 where  table_owner = t.table_owner
		 and    table_name = t.table_name
		 and    index_type like '%FUNCTION-BASED%') cnt_fbi
	 from   dba_tab_partitions t,
		dba_tables t2,
		dba_segments s,
		dba_tablespaces ts
	 where  t.table_owner not in ('SYS','SYSTEM','OUTLN')
	 and    t.blocks is not null
	 and    t.subpartition_count = 0
	 and    ts.tablespace_name = t.tablespace_name
	 and    ts.contents = 'PERMANENT'
	 and    ((t.blocks*ts.block_size)/1048576) > 5
	 and    s.owner = t.table_owner
	 and    s.segment_name = t.table_name
	 and    s.partition_name = t.partition_name
	 and    s.segment_type = 'TABLE PARTITION'
	 and    t2.owner = t.table_owner
	 and    t2.table_name = t.table_name
	 union all
	 select t.table_owner owner,
		t.table_name || ':' || t.partition_name || ':' || t.subpartition_name name,
		(s.blocks*ts.block_size)/1048576 alloc_mb,
		(t.blocks*ts.block_size)/1048576 hwm_mb,
		((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len))/1048576 estd_used_mb,
		((t.blocks*ts.block_size)-((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len)))/1048576 estd_wasted_mb,
		decode(t2.iot_name,NULL,'NO','YES') iot,
		'NO' clus,
		decode(t.compression,'ENABLED','YES','NO') cmpr,
		decode(ts.segment_space_management,'AUTO','YES','NO') assm,
		ts.status,
		t2.row_movement,
		t.last_analyzed,
		(select count(*)
		 from   dba_tab_columns
		 where  owner = t.table_owner
		 and    table_name = t.table_name
		 and    data_type = 'LONG') cnt_longs,
		(select count(*)
		 from   dba_indexes
		 where  table_owner = t.table_owner
		 and    table_name = t.table_name
		 and    index_type like '%BITMAP%'
		 and	join_index = 'YES') cnt_bji,
		(select count(*)
		 from   dba_indexes
		 where  table_owner = t.table_owner
		 and    table_name = t.table_name
		 and    index_type like '%FUNCTION-BASED%') cnt_fbi
	 from   dba_tab_subpartitions t,
		dba_tables t2,
		dba_segments s,
		dba_tablespaces ts
	 where  t.table_owner not in ('SYS','SYSTEM','OUTLN')
	 and    t.blocks is not null
	 and    ts.tablespace_name = t.tablespace_name
	 and    ts.contents = 'PERMANENT'
	 and    ((t.blocks*ts.block_size)/1048576) > 5
	 and    s.owner = t.table_owner
	 and    s.segment_name = t.table_name
	 and    s.partition_name = t.subpartition_name
	 and    s.segment_type = 'TABLE SUBPARTITION'
	 and    t2.owner = t.table_owner
	 and    t2.table_name = t.table_name)
where   (estd_wasted_mb/decode(hwm_mb,0,1,hwm_mb))*100 >= 25
order by 1, 2;
spool off

clear breaks computes
set pagesize 0
spool run_table_shrinks.sql
prompt set echo on feedback on timing on
prompt spool run_table_shrinks
prompt 
select	decode(row_movement, 'ENABLED','','alter table '||owner||'.'||name||' enable row movement;'||chr(10))||
	'alter table '||owner||'.'||name||' shrink space;' cmd
from	(select	owner,
		name,
		alloc_mb,
		hwm_mb,
		estd_used_mb,
		estd_wasted_mb,
		(estd_wasted_mb/decode(hwm_mb,0,1,hwm_mb))*100 pct_wasted,
		iot,
		clus,
		cmpr,
		assm,
		status,
		row_movement,
		cnt_longs,
		cnt_bji,
		cnt_fbi,
		to_char(last_analyzed, 'DD-MON-YY') last_analyzed,
		case    when    iot <> 'NO' or clus <> 'NO' or cmpr <> 'NO' or assm <> 'YES' or
				cnt_longs > 0 or cnt_bji > 0 or cnt_fbi > 0 or
				(sysdate - last_analyzed) > 90 or status <> 'ONLINE'
			then '<=='
		end warn
	 from   (select t.owner,
			t.table_name name,
			(s.blocks*ts.block_size)/1048576 alloc_mb,
			(t.blocks*ts.block_size)/1048576 hwm_mb,
			((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len))/1048576 estd_used_mb,
			((t.blocks*ts.block_size)-((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len)))/1048576 estd_wasted_mb,
			decode(t.iot_name,NULL,'NO','YES') iot,
			decode(t.cluster_name,NULL,'NO','YES') clus,
			decode(t.compression,'ENABLED','YES','NO') cmpr,
			decode(ts.segment_space_management,'AUTO','YES','NO') assm,
			ts.status,
			t.row_movement,
			t.last_analyzed,
			(select count(*)
			 from   dba_tab_columns
			 where  owner = t.owner
			 and    table_name = t.table_name
			 and    data_type = 'LONG') cnt_longs,
			(select count(*)
			 from   dba_indexes
			 where  table_owner = t.owner
			 and    table_name = t.table_name
			 and    index_type like '%BITMAP%'
			 and	join_index = 'YES') cnt_bji,
			(select count(*)
			 from   dba_indexes
			 where  table_owner = t.owner
			 and    table_name = t.table_name
			 and    index_type like '%FUNCTION-BASED%') cnt_fbi
		 from   dba_tables t,
			dba_segments s,
			dba_tablespaces ts
		 where  t.owner not in ('SYS','SYSTEM','OUTLN')
		 and    t.blocks is not null
		 and    t.partitioned = 'NO'
		 and    ts.tablespace_name = t.tablespace_name
		 and    ts.contents = 'PERMANENT'
		 and    ((t.blocks*ts.block_size)/1048576) > 5
		 and    s.owner = t.owner
		 and    s.segment_name = t.table_name
		 and    s.segment_type = 'TABLE'
		 union all
		 select t.table_owner owner,
			t.table_name || ' modify partition ' || t.partition_name name,
			(s.blocks*ts.block_size)/1048576 alloc_mb,
			(t.blocks*ts.block_size)/1048576 hwm_mb,
			((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len))/1048576 estd_used_mb,
			((t.blocks*ts.block_size)-((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len)))/1048576 estd_wasted_mb,
			decode(t2.iot_name,NULL,'NO','YES') iot,
			'NO' clus,
			decode(t.compression,'ENABLED','YES','NO') cmpr,
			decode(ts.segment_space_management,'AUTO','YES','NO') assm,
			ts.status,
			t2.row_movement,
			t.last_analyzed,
			(select count(*)
			 from   dba_tab_columns
			 where  owner = t.table_owner
			 and    table_name = t.table_name
			 and    data_type = 'LONG') cnt_longs,
			(select count(*)
			 from   dba_indexes
			 where  table_owner = t.table_owner
			 and    table_name = t.table_name
			 and    index_type like '%BITMAP%'
			 and	join_index = 'YES') cnt_bji,
			(select count(*)
			 from   dba_indexes
			 where  table_owner = t.table_owner
			 and    table_name = t.table_name
			 and    index_type like '%FUNCTION-BASED%') cnt_fbi
		 from   dba_tab_partitions t,
			dba_tables t2,
			dba_segments s,
			dba_tablespaces ts
		 where  t.table_owner not in ('SYS','SYSTEM','OUTLN')
		 and    t.blocks is not null
		 and    t.subpartition_count = 0
		 and    ts.tablespace_name = t.tablespace_name
		 and    ts.contents = 'PERMANENT'
		 and    ((t.blocks*ts.block_size)/1048576) > 5
		 and    s.owner = t.table_owner
		 and    s.segment_name = t.table_name
		 and    s.partition_name = t.partition_name
		 and    s.segment_type = 'TABLE PARTITION'
		 and    t2.owner = t.table_owner
		 and    t2.table_name = t.table_name
		 union all
		 select t.table_owner owner,
			t.table_name || ' modify subpartition ' || t.subpartition_name name,
			(s.blocks*ts.block_size)/1048576 alloc_mb,
			(t.blocks*ts.block_size)/1048576 hwm_mb,
			((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len))/1048576 estd_used_mb,
			((t.blocks*ts.block_size)-((t.blocks*172)+(t.blocks*t.ini_trans*32)+(t.num_rows*t.avg_row_len)))/1048576 estd_wasted_mb,
			decode(t2.iot_name,NULL,'NO','YES') iot,
			'NO' clus,
			decode(t.compression,'ENABLED','YES','NO') cmpr,
			decode(ts.segment_space_management,'AUTO','YES','NO') assm,
			ts.status,
			t2.row_movement,
			t.last_analyzed,
			(select count(*)
			 from   dba_tab_columns
			 where  owner = t.table_owner
			 and    table_name = t.table_name
			 and    data_type = 'LONG') cnt_longs,
			(select count(*)
			 from   dba_indexes
			 where  table_owner = t.table_owner
			 and    table_name = t.table_name
			 and    index_type like '%BITMAP%'
			 and	join_index = 'YES') cnt_bji,
			(select count(*)
			 from   dba_indexes
			 where  table_owner = t.table_owner
			 and    table_name = t.table_name
			 and    index_type like '%FUNCTION-BASED%') cnt_fbi
		 from   dba_tab_subpartitions t,
			dba_tables t2,
			dba_segments s,
			dba_tablespaces ts
		 where  t.table_owner not in ('SYS','SYSTEM','OUTLN')
		 and    t.blocks is not null
		 and    ts.tablespace_name = t.tablespace_name
		 and    ts.contents = 'PERMANENT'
		 and    ((t.blocks*ts.block_size)/1048576) > 5
		 and    s.owner = t.table_owner
		 and    s.segment_name = t.table_name
		 and    s.partition_name = t.subpartition_name
		 and    s.segment_type = 'TABLE SUBPARTITION'
		 and    t2.owner = t.table_owner
		 and    t2.table_name = t.table_name)
	 where  (estd_wasted_mb/decode(hwm_mb,0,1,hwm_mb))*100 >= 25)
where	warn is null
order by 1;
prompt 
prompt spool off
prompt set echo off feedback 6 timing off
spool off
set feedback 6 pagesize 100 linesize 130 tab on verify on
