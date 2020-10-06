/**********************************************************************
 * File:        dump_data.sql 
 * Type:        SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:        24-Feb-2013
 *
 * Description:
 *      SQL*Plus script to create the PL/SQL package DUMP_DATA with the
 *	stored procedure CSV to quickly and easily dump Oracle table
 *	data to flat-file in CSV format.
 *
 *	Usage:
 *		in_tsname
 *			Name of the tablespace in which the table,
 *			partition, or subpartitions reside.  If the
 *			table is partitioned or sub-partitioned, then
 *			only those partitions/sub-partitions within
 *			the specified tablespace will be dumped
 *		in_owner
 *			Owner (schema) of the table
 *		in_table
 *			Table name
 *		in_row_limit
 *			(default: unlimited) number of rows to dump
 *		in_degree
 *			(default: 1 or noparallel) degree of parallelism
 *			to use when dumping
 *		in_array_sz
 *			(default: 1000) size of PL/SQL collection
 *			to be used during processing of data
 *
 * Modifications:
 *      TGorman 24feb13	written
 *********************************************************************/
set echo on feedback on timing on
spool dump_data

drop package dump_data;
drop type dump_data_ObjectTab;
drop type dump_data_ObjectTyp;

create type dump_data_ObjectTyp as object (txt varchar2(4000));
/
show errors

create type dump_data_ObjectTab as table of dump_data_ObjectTyp;
/

create or replace package dump_data
as
	--
	function csv(in_tsname in varchar2, in_owner in varchar2, in_table in varchar2,
		     in_row_limit in integer default 99999999999999999999,
		     in_degree in integer default 1, in_array_sz in integer default 1000)
		return dump_data_ObjectTab pipelined;
	--
end dump_data;
/
show errors

create or replace package body dump_data
as
	--
	function csv(in_tsname in varchar2, in_owner in varchar2, in_table in varchar2,
		     in_row_limit in integer default 99999999999999999999,
		     in_degree in integer default 1, in_array_sz in integer default 1000)
		return dump_data_ObjectTab
		pipelined
	is
		--
		cursor get_column_info(p_owner in varchar2, p_table in varchar2)
		is
		select	column_name,
			data_type,
			data_length,
			data_precision,
			data_scale
		from	dba_tab_columns
		where	owner = upper(p_owner)
		and	table_name = upper(p_table)
		order by column_id;
		--
		cursor get_objects(p_tsname in varchar2, p_owner in varchar2, p_table in varchar2)
		is
		select	0 partition_position,
			' from '||owner||'.'||table_name||' x' from_clause
		from	dba_tables
		where	tablespace_name = upper(p_tsname)
		and	owner = upper(p_owner)
		and	table_name = upper(p_table)
		and	partitioned = 'NO'
		union all
		select	partition_position,
			' from '||table_owner||'.'||table_name||' partition('||partition_name||') x' from_clause
		from	dba_tab_partitions
		where	tablespace_name = upper(p_tsname)
		and	table_owner = upper(p_owner)
		and	table_name = upper(p_table)
		and	subpartition_count = 0
		union all
		select	subpartition_position,
			' from '||table_owner||'.'||table_name||' subpartition('||subpartition_name||') x' from_clause
		from	dba_tab_subpartitions
		where	tablespace_name = upper(p_tsname)
		and	table_owner = upper(p_owner)
		and	table_name = upper(p_table)
		order by 1;
		--
		type t_txt	is table of varchar2(4000) index by binary_integer;
		a_txt		t_txt;
		--
		type rc		is ref cursor;
		c		rc;
		--
		o		dump_data_ObjectTyp;
		--
		v_sep_str	varchar2(30);
		v_select_clause	varchar2(32000);
		v_header_str	varchar2(32000);
		v_hdr_sep_str	varchar2(30);
		v_hint_txt	varchar2(100);
		v_rowcnt	integer := 0;
		v_start_tm	date;
		v_errctx	varchar2(1000);
		v_errmsg	varchar2(2000);
		--
	begin
		--
		o := dump_data_ObjectTyp(null);
		--
		if in_degree <= 1 then
			v_hint_txt := 'noparallel(x)';
		else
			v_hint_txt := 'full(x) parallel(x,'||in_degree||')';
		end if;
		--
		v_start_tm := sysdate;
		v_select_clause := null;
		v_sep_str := null;
		v_header_str := null;
		v_hdr_sep_str := null;
		v_errctx := 'open/fetch get_column_info';
		for c in get_column_info(in_owner, in_table) loop
			--
			if c.data_type in ('CHAR','VARCHAR2') then
				--
				v_header_str := v_header_str||v_hdr_sep_str||'"'||c.column_name||' '||c.data_type||
						'('||c.data_length||')"';
				v_select_clause := v_select_clause||v_sep_str||'''"''||replace(replace('||c.column_name||',chr(10),''''),''"'',''\"'')||''"''';
				--
			elsif c.data_type in ('DATE') then
				--
				v_header_str := v_header_str||v_hdr_sep_str||'"'||c.column_name||' '||c.data_type||'"';
				v_select_clause := v_select_clause||v_sep_str||'''"''||to_char('||c.column_name||',''YYYYMMDDHH24MISS'')||''"''';
				--
			elsif c.data_type in ('NUMBER') then
				--
				if nvl(c.data_scale, 0) > 0 then
					--
					v_header_str := v_header_str||v_hdr_sep_str||'"'||c.column_name||' NUMBER('||
						c.data_precision||','||c.data_scale||')"';
					--
				else
					--
					v_header_str := v_header_str||v_hdr_sep_str||'"'||c.column_name||' NUMBER('||
						c.data_precision||')"';
					--
				end if;
				--
				v_select_clause := v_select_clause||v_sep_str||'to_char('||c.column_name||')';
				--
			else
				--
				raise_application_error(-20001, 'column "'||c.column_name||
						'" is datatype "'||c.data_type||'": not handled');
				--
			end if;
			--
			v_sep_str := '||'',''||';
			v_hdr_sep_str := ',';
			--
			v_errctx := 'fetch/close get_column_info';
			--
		end loop;
		--
		o.txt := v_header_str;
		pipe row(o);
		--
		v_errctx := 'open/fetch get_objects';
		for x in get_objects(in_tsname, in_owner, in_table) loop
			--
			v_errctx := 'open cursor';
			dbms_output.put_line('select /*+ '||v_hint_txt||' */ '||v_select_clause||x.from_clause);
			open c for 'select /*+ '||v_hint_txt||' */ '||v_select_clause||x.from_clause;
			loop
				--
				v_errctx := 'fetch cursor';
				fetch c bulk collect into a_txt limit in_array_sz;
				if a_txt.count > 0 then
					--
					for i in a_txt.first..a_txt.last loop
						--
						o.txt := a_txt(i);
						v_rowcnt := v_rowcnt + 1;
						exit when v_rowcnt >= in_row_limit;
						pipe row(o);
						--
					end loop;
					--
				end if;
				exit when c%notfound;
				exit when v_rowcnt >= in_row_limit;
				--
			end loop;
			--
			v_errctx := 'close cursor';
			close c;
			exit when v_rowcnt >= in_row_limit;
			--
		end loop; /* end of "get_objects" loop */
		--
		if v_rowcnt > 0 then
			--
			o.txt := 'count is '||v_rowcnt||' rows in '||round((sysdate-v_start_tm)*86400,3)||' seconds';
			pipe row(o);
			--
		end if;
		--
	exception
		when others then
			v_errmsg := sqlerrm;
			raise_application_error(-20000, v_errctx || ': ' || v_errmsg);
	end csv;
	--
end dump_data;
/
show errors

spool off
set echo off feedback 6 timing off
