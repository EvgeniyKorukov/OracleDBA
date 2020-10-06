/**********************************************************************
 * File:        cbo_stats.sql
 * Type:        SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:        29aug04
 *
 * Description:
 *	SQL*Plus script to display statistics used by the cost-
 *	based optimizer, at the global table- and index-level, as well
 *	as the partition and sub-partition levels, if they exist.
 *
 * Modifications:
 *	TGorman 07Jun13	added DBA_STAT_EXTENSION support (11.2+)
 *********************************************************************/
undef owner
undef table_name
clear breaks computes
set echo off feedback off timing off verify off recsep off
set pagesize 10000 linesize 300 trimout on trimspool on pause off arraysize 100
col avg_row_len heading "Avg|Row|Len" format 990
col num_rows heading "Nbr|Rows" format 999,999,999,990
col blocks heading "Used|Blocks" format 999,999,999,990
col sample_size heading "Sample|Size" format 999,999,999,990
col last_analyzed heading "Last|Analyzed" format a15 truncate
col index_name heading "Index Name" format a30
col partition_name heading "Partition Name" format a30
col subpartition_name heading "Subpartition Name" format a30
col blevel heading "Br|Lvl" format 90
col leaf_blocks heading "Leaf|Blocks" format 999,990
col distinct_keys heading "Distinct|Keys" format 99,999,990
col avg_leaf_blocks_per_key heading "Avg|Leaf|Blocks|Per|Key" format 999,990
col avg_data_blocks_per_key heading "Avg|Data|Blocks|Per|Key" format 999,990
col clustering_factor heading "Cluster|Factor" format 99,999,990
col column_name heading "Column Name" format a30 wrap
col num_distinct heading "Distinct|Values" format 99,999,990
col num_nulls heading "Nulls" format 99,999,990
col num_buckets heading "Buckets" format 99,999,990
col avg_col_len heading "Avg|Col|Len" format 990
col histogram heading "Histogram|Type"
col global_stats heading "Global|Stats" format a6
col user_stats heading "User|Stats" format a5
col stale_stats heading "Stale?" format a6
col stattype_locked heading "Lock?" format a5

spool cbo_stats_&&owner._&&table_name
ttitle left 'Global-level table CBO statistics for "&&owner..&&table_name"' skip 1 line
select	avg_row_len,
	num_rows,
	blocks,
	sample_size,
	to_char(last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	global_stats,
	user_stats,
	stale_stats,
	stattype_locked
from	dba_tab_statistics
where	owner = upper('&&owner')
and	table_name = upper('&&table_name')
and	object_type = 'TABLE';
ttitle left 'Partition-level table CBO statistics for "&&owner..&&table_name"' skip 1 line
select	partition_name,
	avg_row_len,
	num_rows,
	blocks,
	sample_size,
	to_char(last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	global_stats,
	user_stats,
	stale_stats,
	stattype_locked
from	dba_tab_statistics
where	owner = upper('&&owner')
and	table_name = upper('&&table_name')
and	object_type = 'PARTITION'
order by partition_position;
ttitle left 'Subpartition-level table CBO statistics for "&&owner..&&table_name"' skip 1 line
break on partition_name
select	partition_name,
	subpartition_name,
	avg_row_len,
	num_rows,
	blocks,
	sample_size,
	to_char(last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	global_stats,
	user_stats,
	stale_stats,
	stattype_locked
from	dba_tab_statistics
where	owner = upper('&&owner')
and	table_name = upper('&&table_name')
and	object_type = 'SUBPARTITION'
order by partition_position,
	 subpartition_position;
ttitle left 'Global-level index CBO statistics for "&&owner..&&table_name"' skip 1 line
select	index_name,
	blevel,
	leaf_blocks,
	distinct_keys,
	avg_leaf_blocks_per_key,
	avg_data_blocks_per_key,
	clustering_factor,
	num_rows,
	sample_size,
	to_char(last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	global_stats,
	user_stats,
	stale_stats,
	stattype_locked
from	dba_ind_statistics
where	table_owner = upper('&&owner')
and	table_name = upper('&&table_name')
and	object_type = 'INDEX'
order by index_name;
break on index_name
ttitle left 'Partition-level index CBO statistics for "&&owner..&&table_name"' skip 1 line
break on index_name
select	index_name,
	partition_name,
	blevel,
	leaf_blocks,
	distinct_keys,
	avg_leaf_blocks_per_key,
	avg_data_blocks_per_key,
	clustering_factor,
	num_rows,
	sample_size,
	to_char(last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	global_stats,
	user_stats,
	stale_stats,
	stattype_locked
from	dba_ind_statistics
where	table_owner = upper('&&owner')
and	table_name = upper('&&table_name')
and	object_type = 'PARTITION'
order by index_name,
	 partition_position;
ttitle left 'Subpartition-level index CBO statistics for "&&owner..&&table_name"' skip 1 line
break on index_name
select	index_name,
	partition_name,
	subpartition_name,
	blevel,
	leaf_blocks,
	distinct_keys,
	avg_leaf_blocks_per_key,
	avg_data_blocks_per_key,
	clustering_factor,
	num_rows,
	sample_size,
	to_char(last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	global_stats,
	user_stats,
	stale_stats,
	stattype_locked
from	dba_ind_statistics
where	table_owner = upper('&&owner')
and	table_name = upper('&&table_name')
and	object_type = 'SUBPARTITION'
order by index_name,
	 partition_position,
	 subpartition_position;
ttitle left 'Global-level column CBO statistics for "&&owner..&&table_name"' skip 1 line
select	decode(substr(s.column_name,1,7),
		'SYS_STU',	(select	dbms_lob.substr(x.extension,100,1)
				 from	all_stat_extensions x
				 where	x.owner = s.owner and x.table_name = s.table_name
				 and	x.extension_name = s.column_name),
			s.column_name) column_name,
	s.num_distinct,
	s.num_nulls,
	s.num_buckets,
	s.histogram,
	s.avg_col_len,
	s.sample_size,
	to_char(s.last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	s.global_stats,
	s.user_stats
from	dba_tab_col_statistics s
where	s.owner = upper('&&owner')
and	s.table_name = upper('&&table_name')
order by column_name;
ttitle left 'Partition-level column CBO statistics for "&&owner..&&table_name"' skip 1 line
break on partition_name
select	s.partition_name,
	decode(substr(s.column_name,1,7),
		'SYS_STU',	(select	dbms_lob.substr(x.extension,100,1)
				 from	all_stat_extensions x
				 where	x.owner = s.owner and x.table_name = s.table_name
				 and	x.extension_name = s.column_name),
			s.column_name) column_name,
	s.num_distinct,
	s.num_nulls,
	s.num_buckets,
	s.histogram,
	s.avg_col_len,
	s.sample_size,
	to_char(s.last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	s.global_stats,
	s.user_stats
from	dba_part_col_statistics s
where	s.owner = upper('&&owner')
and	s.table_name = upper('&&table_name')
order by partition_name,
	 column_name;
ttitle left 'Sub-partition-level column CBO statistics for "&&owner..&&table_name"' skip 1 line
break on subpartition_name
select	s.subpartition_name,
	decode(substr(s.column_name,1,7),
		'SYS_STU',	(select	dbms_lob.substr(x.extension,100,1)
				 from	all_stat_extensions x
				 where	x.owner = s.owner and x.table_name = s.table_name
				 and	x.extension_name = s.column_name),
			s.column_name) column_name,
	s.num_distinct,
	s.num_nulls,
	s.num_buckets,
	s.histogram,
	s.avg_col_len,
	s.sample_size,
	to_char(s.last_analyzed, 'DD-MON-YY HH24:MI') last_analyzed,
	s.global_stats,
	s.user_stats
from	dba_subpart_col_statistics s
where	s.owner = upper('&&owner')
and	s.table_name = upper('&&table_name')
order by subpartition_name,
	 column_name;
spool off
ttitle off
clear breaks computes
set linesize 130 feedback 6 verify on recsep wrap
