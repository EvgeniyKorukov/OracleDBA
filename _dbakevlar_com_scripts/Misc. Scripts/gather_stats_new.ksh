#!/usr/bin/ksh

#############################################################
#Author:  Kellyn Pot'Vin, DBAKevlar.com                     #
#This script will build stats off tables located in         #          #sys.dba_tab_modifications. Excellent choice for those that #                              #need enhancement to nightly stats job on JUST highly       #
#impacted objects.
#This parent script creates the child scripts to be used    #                                 #                                                           #
#Add Directory path, email addresses for notifications      #
#############################################################

ORACLE_SID=$1
export ORACLE_SID


#Setup, bypassing the .oraenv, but can be used in yours
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=`grep -i ^"$ORACLE_SID" /etc/oratab | awk -F: '{print $2}'`
export PATH=$PATH:${ORACLE_HOME}/bin
export EMAIL_ADD=<Enter Email Address here>

EXEC_DIR=<Insert Directory Home>
export EXEC_DIR
STATS_LOG=${EXEC_DIR}/gather_stats_dm.log
TBL_STATS=${EXEC_DIR}/tbl_stats_dm.sql
TPRT_STATS=${EXEC_DIR}/tab_part_stats_dm.sql
export STATS_LOG TBL_STATS IPRT_STATS TPRT_STATS


#Remove previous scripts which is dynamically generated.
rm -f $STATS_LOG
rm -f ${EXEC_DIR}/*stats_dm.sql
touch ${STATS_LOG}
touch ${TPRT_STATS}
touch ${IPRT_STATS}
touch ${TBL_STATS}
chmod 744 *.sql
chmod 744 *.log


#Create and Run scripts
$ORACLE_HOME/bin/sqlplus '/as sysdba' <<EOF
set head off;
set linesize 500;
set pagesize 5000;
set echo off;
set feedback off;
set serverout off;
set term off;
--Create script to gather stats on non-partitioned tables
SELECT 'Exec  DBMS_STATS.GATHER_TABLE_STATS (ownname=>'''||owner||''', tabname=>'''||table_name||''', method_opt=>'',cascade=>TRUE, DEGREE=>4);' from DBA_TABLES
WHERE OWNER ='DW_PROD'
--AND TABLE_NAME not in ('<add any tables to exclude')
AND PARTITIONED='NO';
spool ${TBL_STATS};
/
spool off;

--Create script to analyze partitions without use of DBMS_STATS package that has issues with partitioned tables.  
SELECT 'Exec  DBMS_STATS.GATHER_TABLE_STATS (ownname=>'''||table_owner||''', tabname=>'''||table_name||''',partname=>'''||partition_name||''', DEGREE=>4);' from DBA_TAB_PARTITIONS
--WHERE table_OWNER =('<insert any specific owners if desired>'
--AND table_name not like '%<enter distinct tbl name types>%'
--AND table_name not in ('<Can enter large tables that cause contention>')
--AND LAST_ANALYZED IS NULL;
spool ${TPRT_STATS};
/
spool off;

#Run Scripts
$ORACLE_HOME/bin/sqlplus '/as sysdba' <<EOF>>${STATS_LOG}
set head off;
set linesize 500;
set pagesize 5000;
set echo on;
set feedback on;
set timing on;
@${TBL_STATS};
@${TPRT_STATS};
exit
EOF
  echo|mail -s "SDTM Stats Collection for $ORACLE_SID Log" "$EMAIL_ADD" <${STATS_LOG}
