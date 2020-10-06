/**********************************************************************
 * File:	run_top_stmt5.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:	21-Mar-2008
 *
 * Description:
 *	Script to execute the TOP_STMT5 stored procedure against
 *	the AWR repository of performance data
 *
 * Modifications:
 *	TGorman	17mar04	adapted from TOP_STMT3 procedure
 *	TGorman	21mar08	adapted from TOP_STMT4 procedure
 *********************************************************************/
set echo off feedback off timing off verify off trimout on trimspool on
undef V_INSTANCE_NBR
undef V_NBR_DAYS
undef V_LABEL
accept V_INSTANCE_NBR prompt "Please enter the instance number or just press ENTER for ALL: "
accept V_NBR_DAYS prompt "Please enter the number of days to report upon: "
set serveroutput on size 1000000 termout off pagesize 100 linesize 130
col label new_value V_LABEL noprint
select	decode('&&V_INSTANCE_NBR', '', d.name, i.instance_name) label
from	gv$instance i, v$database d
where	i.instance_number = nvl(to_number('&&V_INSTANCE_NBR'), i.instance_number);
spool top_stmt5_&&V_LABEL
execute top_stmt5( -
	in_start_date => sysdate - &&V_NBR_DAYS , -
	in_nbr_days => &&V_NBR_DAYS , -
	in_top_count => 25, -
	in_instance_nbr => to_number('&&V_INSTANCE_NBR'))
spool off
set feedback 6 termout on
ed top_stmt5_&&V_LABEL..lst
set echo off
