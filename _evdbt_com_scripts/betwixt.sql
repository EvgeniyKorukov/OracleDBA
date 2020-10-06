/**********************************************************************
 * File:	betwixt.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:	30-July-2004
 *
 * Description:
 *	SQL*Plus script to create the BETWIXT pipelined table function.
 *	BETWIXT expects a begin-date and an end-date as parameters,
 *	and it returns all of the intervening time-intervals as
 *	specified in the third parameter, in-interval.  If in-interval
 *	is not specified, it defaults to "1" or 1 day.
 *
 *	This is useful for pivoting on date/time values.
 *
 * Modifications:
 *********************************************************************/
set echo on feedback on timing off

drop view test_betwixt_v;
drop table test_betwixt;
drop function betwixt;
drop type DtCounterTable;
drop type DtCounterType;

spool betwixt

create type DtCounterType as object (dt date);
/

create type DtCounterTable as table of DtCounterType;
/

create function betwixt(in_begin_dt in date, in_end_dt in date, in_increment in integer default 1)
	return DtCounterTable
	pipelined
is
	v_rtn		DtCounterType;
	i		integer;
begin
	--
	if in_end_dt <= in_begin_dt then
		raise_application_error(-20000, 'END_DATE must be greater than or equal to BEGIN_DATE');
	end if;
	--
	v_rtn := DtCounterType(null);	/* initialize record */
	--
	v_rtn.dt := in_begin_dt;	/* initialize return-date value */
	--
	while v_rtn.dt < in_end_dt loop
		v_rtn.dt := v_rtn.dt + in_increment;
		pipe row (v_rtn);
	end loop;
	--
	return;
	--
end betwixt;
/

alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';

select * from table(betwixt(to_date('01-JAN-03','DD-MON-RR'),to_date('11-JAN-03','DD-MON-RR')));

create table test_betwixt
(
	col1		number		not null,
	col2		varchar2(30)	not null,
	begin_date	date		not null,
	end_date	date		not null
);

declare
	v_date		date := to_date('01-JAN-2002','DD-MON-YYYY');
begin
	for i in 1..10 loop
		insert into test_betwixt
		values (i, to_char(i), v_date+i, v_date+(i+6));
		v_date := v_date + 7;
	end loop;
end;
/

select * from test_betwixt;

create view test_betwixt_v
as
select	tb.col1, tb.col2, b.dt
from	test_betwixt tb,
	table(betwixt(tb.begin_date, tb.end_date)) b;

select * from test_betwixt_v;

spool off
