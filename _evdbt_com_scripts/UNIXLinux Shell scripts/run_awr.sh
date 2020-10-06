#!/usr/bin/ksh
#==============================================================================
# File:		run_awr.sh
# Type:		korn shell script
# Author:	Tim Gorman (Evergreen Database Technologies -- www.evdbt.com)
# Date:		12sep08
#
# Description:
#	UNIX Korn-shell script to run under the UNIX "cron" utility to
#	automatically generate and email Oracle "AWR" reports in HTML and
#	Oracle "ADDM" reports in TXT against the database accessed via the specified
#	TNS connect-string, to a specified list of email addresses.
#
# Parameters:
#	Zero, one, or more parameters may be passed.  These parameters
#	are TNS connect-strings, each of which refer to entries in the
#	script's configuration file (named ".run_awr", described below).
#
#	If no parameters are specified, then the script processes all of
#	the lines in the configuration file.
#
#	For each of the parameters specified, the script will process
#	each of the corresponding lines in the configuration file.
#
#	Each TNS connect-string should be separated by whitespace.
#
# Configuration file:
#	The file ".run_awr" in the "$HOME" directory contains one or more
#	lines with the following format, three fields delimited by "commas":
#
#		TNS-connect-string : recipient-list : hrs
#
#	where:
#
#		TNS-connect-string	Oracle TNS connect-string for the db
#		recipient-list		comma-separated list of email addresses
#		hrs			"sysdate - <hrs>" is the beginning
#					time of the AWR report and "sysdate"
#					is the ending time of the AWR report
#
# Modification history:
#==============================================================================
#
#------------------------------------------------------------------------------
# Set important UNIX environment variables...
#------------------------------------------------------------------------------
export PATH=${PATH}:/usr/bin:/usr/sbin:/usr/local/bin:.
#
#------------------------------------------------------------------------------
# Verify that the Oracle environment variables and directories are set up...
#------------------------------------------------------------------------------
which oraenv > /dev/null 2>&1
if (( $? != 0 ))
then
	echo "\"which oraenv\" failed; aborting..."
	exit 1
fi
#
#------------------------------------------------------------------------------
# Set shell variables used by the shell script...
#------------------------------------------------------------------------------
_Pgm=run_awr
_RunAwrListFile=${HOME}/.run_awr
if [ ! -r ${_RunAwrListFile} ]
then
	echo "Script configuration file \"${_RunAwrListFile}\" not found; aborting..."
	exit 1
fi
#
#------------------------------------------------------------------------------
# Identify the location of the script's log file...
#------------------------------------------------------------------------------
_WorkDir=`dirname $0`
_LogFile=${_WorkDir}/${_Pgm}.log
#
#------------------------------------------------------------------------------
# ...loop through the list of database instances specified in the ".run_awr"
# list file...
#
# Entries in this file have the format:
#
#	dbname:rcpt-list:hrs
#
# where:
#	dbname		- is the TNS connect-string of the database instance
#	rcpt-list	- is a comma-separated list of email addresses
#	hrs		- is the number of hours (from the present time)
#			  marking the starting point of the AWR report
#------------------------------------------------------------------------------
grep -v "^#" ${_RunAwrListFile} | awk -F: '{print $1" "$2" "$3}' | \
while read _ListDb _ListRcpts _ListHrs
do
	#----------------------------------------------------------------------
	# If command-line parameters were specified for this script, then they
	# must be a list of databases...
	#----------------------------------------------------------------------
	if (( $# > 0 ))
	then
		#
		#---------------------------------------------------------------
		# If a list of databases was specified on the command-line of
		# this script, then find that database's entry in the ".run_awr"
		# configuration file and retrieve the list of email recipients
		# as well as the #-hrs for the AWR report...
		#---------------------------------------------------------------
		_Db=""
		_Rcpts=""
		_Hrs=""
		for _SpecifiedDb in $*
		do
			#
			if [[ "${_ListDb}" = "${_SpecifiedDb}" ]]
			then
				_Db=${_ListDb}
				_Rcpts=${_ListRcpts}
				_Hrs=${_ListHrs}
			fi
			#
		done
		#
		#---------------------------------------------------------------
		# if the listed DB is not specified on the command-line, then
		# go onto the next listed DB...
		#---------------------------------------------------------------
		if [[ "${_Db}" = "" ]]
		then
			continue
		fi
		#---------------------------------------------------------------
	else	# ...else, if no command-line parameters were specified, then
		# just use the information in the ".run_awr" configuration file...
		#---------------------------------------------------------------
		_Db=${_ListDb}
		_Rcpts=${_ListRcpts}
		_Hrs=${_ListHrs}
		#
	fi
	#
	#----------------------------------------------------------------------
	# Set up Oracle environment variables...
	#----------------------------------------------------------------------
	export ORACLE_SID=${_Db}
	export ORAENV_ASK=NO
	. oraenv > /dev/null 2>&1
	unset ORAENV_ASK
	#
	#------------------------------------------------------------------------------
	# Verify that the Oracle environment variables and directories are set up...
	#------------------------------------------------------------------------------
	if [[ "${ORACLE_HOME}" = "" ]]
	then
		echo "`date`: ORACLE_HOME not set; aborting..." | tee -a ${_LogFile}
		exit 1
	fi
	if [ ! -d ${ORACLE_HOME} ]
	then
		echo "`date`: Directory \"${ORACLE_HOME}\" not found; aborting..." | tee -a ${_LogFile}
		exit 1
	fi
	if [ ! -d ${ORACLE_HOME}/bin ]
	then
		echo "`date`: Directory \"${ORACLE_HOME}/bin\" not found; aborting..." | tee -a ${_LogFile}
		exit 1
	fi
	if [ ! -x ${ORACLE_HOME}/bin/sqlplus ]
	then
		echo "`date`: Executable \"${ORACLE_HOME}/bin/sqlplus\" not found; aborting..." | tee -a ${_LogFile}
		exit 1
	fi
	#
	#----------------------------------------------------------------------
	# Create script variables for the output files...
	#----------------------------------------------------------------------
	_TmpSpoolFile="/tmp/${_Pgm}_${_Db}.tmp"
	_AwrReportFile="/tmp/${_Pgm}_awr_${_Db}.html"
	_AddmReportFile="/tmp/${_Pgm}_addm_${_Db}.txt"
	#
	#----------------------------------------------------------------------
	# Call SQL*Plus, retrieve some database instance information, and then
	# call the AWR report as specified...
	#----------------------------------------------------------------------
	${ORACLE_HOME}/bin/sqlplus -s /nolog << __EOF__ > /dev/null 2>&1
set echo off feedback off timing off pagesize 0 linesize 8000 trimout on trimspool on verify off heading off underline on
connect / as sysdba

col dbid new_value V_DBID noprint
select	dbid from v\$database;

col instance_number new_value V_INST noprint
select	instance_number from v\$instance;

col snap_id new_value V_BID
select	min(snap_id) snap_id
from	dba_hist_snapshot
where	end_interval_time >= (sysdate-(${_Hrs}/24))
and	startup_time <= begin_interval_time
and	dbid = &&V_DBID
and	instance_number = &&V_INST;

col snap_id new_value V_EID
select	max(snap_id) snap_id
from	dba_hist_snapshot
where	dbid = &&V_DBID
and	instance_number = &&V_INST;

spool ${_TmpSpoolFile}
begin
	if '&&V_BID' is null then
		raise_application_error(-20000, 'No AWR snapshots found within the past ${_Hrs} hours');
	end if;
end;
/
select	'BEGIN='||trim(to_char(begin_interval_time, 'HH24:MI')) snap_time
from	dba_hist_snapshot
where	dbid = &&V_DBID
and	instance_number = &&V_INST
and	snap_id = &&V_BID ;
select	'END='||trim(to_char(end_interval_time, 'HH24:MI')) snap_time
from	dba_hist_snapshot
where	dbid = &&V_DBID
and	instance_number = &&V_INST
and	snap_id = &&V_EID ;
spool off

variable task_name varchar2(100)
declare
	id number;
	name varchar2(100);
	descr varchar2(500);
	v_errcontext	varchar2(100);
	v_errmsg	varchar2(2000);
BEGIN
	v_errcontext := 'setting NAME and DESCR';
	name := '';
	descr := 'ADDM run: snapshots [&&V_BID., &&V_EID.], instance &&V_INST, database id &&V_DBID';

	v_errcontext := 'dbms_advisor.create_task';
	dbms_advisor.create_task('ADDM',id,name,descr,null);

	:task_name := name;

	-- set time window
	v_errcontext := 'dbms_advisor.set_task_parameter(START_SNAPSHOT)';
	dbms_advisor.set_task_parameter(name, 'START_SNAPSHOT', &&V_BID);
	v_errcontext := 'dbms_advisor.set_task_parameter(END_SNAPSHOT)';
	dbms_advisor.set_task_parameter(name, 'END_SNAPSHOT', &&V_EID);

	-- set instance number
	v_errcontext := 'dbms_advisor.set_task_parameter(INSTANCE)';
	dbms_advisor.set_task_parameter(name, 'INSTANCE', &&V_INST);

	-- set dbid
	v_errcontext := 'dbms_advisor.set_task_parameter(DBID)';
	dbms_advisor.set_task_parameter(name, 'DB_ID', &&V_DBID);

	-- execute task
	v_errcontext := 'dbms_advisor.execute_task';
	dbms_advisor.execute_task(name);

exception
	when others then
		v_errmsg := sqlerrm;
		raise_application_error(-20000, v_errcontext || ': ' || v_errmsg);
end;
/

set long 1000000 longchunksize 1000
column get_clob format a80

select dbms_advisor.get_task_report(:task_name, 'TEXT', 'TYPICAL') from dual

spool ${_AddmReportFile}
/
spool off

set linesize 8000
column output format a7995
select output from table(dbms_workload_repository.awr_report_html(&&V_DBID, &&V_INST, &&V_BID, &&V_EID, 0))

spool ${_AwrReportFile}
/
exit success
__EOF__
	#
	#----------------------------------------------------------------------
	# Determine if the "start time" and "end time" of the AWR report was
	# spooled out...
	#----------------------------------------------------------------------
	if [ -f ${_TmpSpoolFile} ]
	then
		_BTstamp=`grep '^BEGIN=' ${_TmpSpoolFile} | awk -F= '{print $2}'`
		_ETstamp=`grep '^END=' ${_TmpSpoolFile} | awk -F= '{print $2}'`
	fi
	#
	#----------------------------------------------------------------------
	# Determine if an ADDM report failed to spool out...
	#----------------------------------------------------------------------
	if [ ! -f ${_AddmReportFile} ]
	then
		#
		for _Rcpt in `echo ${_Rcpts} | sed 's/,/ /g'`
		do
			if [ -f ${_TmpSpoolFile} ]
			then
				cat ${_TmpSpoolFile} | \
					mailx -s "Error on AWR/ADDM Report for ${_Db}" ${_Rcpt}
			else
				echo "SQL*Plus failed querying DBA_HIST_SNAPSHOT" | \
					mailx -s "Error on AWR/ADDM Report for ${_Db}" ${_Rcpt}
			fi
		done
		#
	fi
	#
	#----------------------------------------------------------------------
	# Determine if an AWR report failed to spool out...
	#----------------------------------------------------------------------
	if [ ! -f ${_AwrReportFile} ]
	then
		#
		for _Rcpt in `echo ${_Rcpts} | sed 's/,/ /g'`
		do
			if [ -f ${_TmpSpoolFile} ]
			then
				cat ${_TmpSpoolFile} | \
					mailx -s "Error on AWR/ADDM Report for ${_Db}" ${_Rcpt}
			else
				echo "SQL*Plus failed querying DBA_HIST_SNAPSHOT" | \
					mailx -s "Error on AWR/ADDM Report for ${_Db}" ${_Rcpt}
			fi
		done
		#
	fi
	#
	#----------------------------------------------------------------------
	# Send both the ADDM and AWR report to email...
	#----------------------------------------------------------------------
	for _Rcpt in `echo ${_Rcpts} | sed 's/,/ /g'`
	do
		echo "Please review the attached AWR and ADDM reports." | \
			mailx -s "AWR/ADDM Report for ${_Db} ${_BTstamp}-${_ETstamp}" -a ${_AwrReportFile} -a ${_AddmReportFile} ${_Rcpt}
	done
	#
	#----------------------------------------------------------------------
	# Clean up...
	#----------------------------------------------------------------------
#	rm -f ${_AwrReportFile} ${_TmpSpoolFile} ${_AddmReportFile}
	#
done
#
#------------------------------------------------------------------------------
# Log this execution, trim the logfile to 300 lines, and then exit...
#------------------------------------------------------------------------------
echo "`date`: ${_Pgm}.sh completed" >> ${_LogFile}
tail -300 ${_LogFile} > /tmp/${_Pgm}_log.tmp
mv /tmp/${_Pgm}_log.tmp ${_LogFile}
#
exit 0
