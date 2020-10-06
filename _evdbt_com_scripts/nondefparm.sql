/**********************************************************************
 * File:	nondefparm.sql
 * Type:	SQL*Plus script
 * Author:	Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:	30-Jun-98
 *
 * Description:
 *	Report against the X$ tables which displays information about
 *	documented and un-documented "init.ora" parameters, similar
 *	to the Server Manager SHOW PARAMETER command.
 *
 * Modifications:
 *	TGorman 26mar04	added more columns from V$PARAMETER
 *********************************************************************/
set pagesize 100 linesize 130 trimout on trimspool on
col parameter format a50 word_wrapped heading "Parameter"
col description format a20 word_wrapped heading "Description"
col dflt format a5 word_wrapped heading "Syst|At|Dflt?"
col is_ses_modifiable format a5 heading "Is|Sess|Mod?"
col is_sys_modifiable format a9 heading "Is|Syst|Mod?"
col is_modified format a10 heading "Is|Mod?"
col is_adjusted format a5 heading "Is|Adj?"
select	rpad(i.ksppinm, 35) || ' = ' || v.ksppstvl parameter,
	i.ksppdesc description,
	v.ksppstdf dflt,
	decode(bitand(i.ksppiflg/256,1),1,'TRUE','FALSE') is_ses_modifiable,
	decode(bitand(i.ksppiflg/65536,3),1,'IMMEDIATE',2,'DEFERRED',3,'IMMEDIATE','FALSE') is_sys_modifiable,
	decode(bitand(v.ksppstvf,7),1,'MODIFIED',4,'SYSTEM_MOD','FALSE') is_modified,
	decode(bitand(v.ksppstvf,2),2,'TRUE','FALSE') is_adjusted
from	x$ksppi		i,
	x$ksppcv	v
where	v.indx = i.indx
and	v.inst_id = i.inst_id
and	(v.ksppstdf = 'FALSE'
    or	 bitand(v.ksppstvf,7) in (1,4)
    or	 bitand(v.ksppstvf,2) = 2)
order by i.ksppinm

spool nondefparm
/
spool off
