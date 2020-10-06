/*****************************************************************************
 * File:        infinite_dual.sql
 * Date:        25oct03
 * Type:	SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Description:
 *
 *	SQL*Plus script to create a view named INFINITE_DUAL, which is based
 *	on data generated from a pipelined table function named F_INFINITE_DUAL.
 *
 *	The inspiration for this function was the UNIX/BSD "yes" command, which
 *	would return either the letter "y" (or any phrase passed as a parameter)
 *	infinitely.  Since Oracle contains a DUAL table of exactly one row,
 *	then the INFINITE_DUAL view can be considered the other extreme option,
 *	a row source that returns an infinite number of rows...
 *
 * Modifications:
 * TGorman 25oct03	written as a demo of pipelined table functions
 ****************************************************************************/
set echo on feedback on timing off

drop view infinite_dual;
drop function f_infinite_dual;
drop type InfiniteDualTable;
drop type InfiniteDualType;

spool infinite_dual

create type InfiniteDualType as object (dummy number);
/

create type InfiniteDualTable as table of InfiniteDualType;
/

create function f_infinite_dual(upper_limit in number default null)
	return InfiniteDualTable
	pipelined
is
	v_rtn		InfiniteDualType;
	i		integer := 1;
begin
	--
	v_rtn := InfiniteDualType(null);
	while true loop
		v_rtn.dummy := i;
		if upper_limit is not null and i > upper_limit then
			exit;
		end if;
		i := i + 1;
		pipe row (v_rtn);
	end loop;
	--
	return;
	--
end f_infinite_dual;
/

select * from table(f_infinite_dual(10));

create view infinite_dual
as
select * from table(f_infinite_dual);

select * from infinite_dual;

spool off
