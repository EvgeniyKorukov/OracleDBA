#!/bin/ksh
######################################################################
# Name:         stdby_init.sh
# Type:         korn-shell script
# Date:         28Mar01
# Author:       Tim Gorman, Evergreen Database Technologies, Inc.
#
######################################################################
# Description:
#
#       This script is used for initializing a standby database using
#	Oracle9i software or above.  Please note that RMAN command
#	DUPLICATE TARGET DATABASE ... FOR STANDBY is used...
#
######################################################################
# Modifications:
#	TGorman	28mar01	adapted from earlier scripts
#	TGorman	20dec05 adapted from earlier script which uses old
#			"hot-backup" methods to initialize...
######################################################################
_Pgm=stdby_init
export PATH=/opt/bin:/usr/bin:/usr/local/bin:${PATH}
#   
#----------------------------------------------------------------------------
# Define a korn-shell function to handle error messages...
#----------------------------------------------------------------------------
_Echo() ### ...define shell-function "_Echo()"...
{
if [[ "$1" = "failure" ]]
then
        if [ -r ${HOME}/.dbapage ]
        then    
                sed '/^#/d' ${HOME}/.dbapage |
                while read _PageRcpt
                do
                        date | mailx -s "`hostname`: ${_Pgm} $1" ${_PageRcpt}
                done
        fi
fi
if [ -r ${HOME}/.dbamail ]
then
        sed '/^#/d' ${HOME}/.dbamail |
        while read _EmailRcpt
        do
                echo "$2" | mailx -s "`hostname`: ${_Pgm} $1" ${_EmailRcpt}
        done
else
        echo "`hostname`: ${_Pgm} $1\n\n$2\n"
fi
}               ### ...end of definition of shell-function "_Echo()"...
#
#------------------------------------------------------------------------------
# If just testing, then set the variables "_RmanTESTING", "_SqlTESTING", and
# "_ShTESTING" to the values of "### ", "prompt ", and "echo " respectively...
#------------------------------------------------------------------------------
###_RmanTESTING="### "
###_SqlTESTING="prompt "
###_ShTESTING="echo "
_RmanTESTING=""
_SqlTESTING=""
_ShTESTING=""
#
#------------------------------------------------------------------------------
# Check command-line parameters...
#------------------------------------------------------------------------------
if (( $# != 3 ))
then
	echo "Usage: \"$0 <primary-TNS-string> <primary-ORACLE_SID> <stdby-ORACLE_SID>\"; aborting..."
	exit 1
fi
_PriTnsString=$1
_PriOraSID=$2
_StdbyOraSID=$3
#
#-----------------------------------------------------------------------------
# Set up connection information to both PRIMARY and STANDBY databases...
#-----------------------------------------------------------------------------
if [ ! -r ~/.orapwd ]	# ...validate that ".orapwd" file exists...
then
	_Echo failure "Cannot read \"~/.orapwd\" file; aborting..."
	exit 1
fi
_PriUnPwd=`grep "@${_PriTnsString}$" ~/.orapwd | grep -i "^system/"`
if [ -z ${_PriUnPwd} ]	# ...validate that password for SYSTEM was found...
then
	_Echo failure "Cannot find password for SYSTEM on \"${_PriTnsString}\"; aborting..."
	exit 1
fi
#
#-----------------------------------------------------------------------------
# Check to see if the STANDBY database is local.  Since the STANDBY instance
# is running in mount mode, we must use CONNECT INTERNAL...
#-----------------------------------------------------------------------------
if [ ! -x /usr/local/bin/dbhome ]
then
	echo "Script \"/usr/local/bin/dbhome\" not found; aborting..."
	exit
fi
/usr/local/bin/dbhome ${_StdbyOraSID} > /dev/null 2>&1
if (( $? != 0 ))
then
	echo "\"${_StdbyOraSID}\" is not local to this host; aborting..."
	exit
fi
if [ ! -x /usr/local/bin/oraenv ]
then
	echo "Script \"/usr/local/bin/oraenv\" not found; aborting..."
	exit
fi
#
#------------------------------------------------------------------------------
# Set UNIX environments for accessing the STANDBY Oracle database...
#------------------------------------------------------------------------------
export ORACLE_SID=${_StdbyOraSID}
export ORAENV_ASK=NO
. /usr/local/bin/oraenv > /dev/null 2>&1
if (( $? != 0 ))
then
	_Echo failure "\". /usr/local/bin/oraenv\" for \"${_StdbyOraSID}\" failed; aborting..."
	exit 1
fi
#
#------------------------------------------------------------------------------
# Validate important Oracle-related environment variable settings and the
# existence of the directories to which they refer...
#------------------------------------------------------------------------------
if [[ "${ORACLE_SID}" = "" ]]
then
	_Echo failure "Env var \"${ORACLE_SID}\" not set by \"oraenv\" script; aborting..."
	exit 1
fi
if [[ "${ORACLE_HOME}" = "" ]]
then
	_Echo failure "Env var \"${ORACLE_HOME}\" not set by \"oraenv\" script; aborting..."
	exit 1
fi
if [ ! -d ${ORACLE_HOME} ]
then
	_Echo failure "Directory \"${ORACLE_HOME}\" not found; aborting..."
	exit 1
fi
if [ ! -d ${ORACLE_HOME}/bin ]
then
	_Echo failure "Directory \"${ORACLE_HOME}/bin\" not found; aborting..."
	exit 1
fi
if [ ! -x ${ORACLE_HOME}/bin/tnsping ]
then
	_Echo failure "Executable \"${ORACLE_HOME}/bin/tnsping\" not found; aborting..."
	exit 1
fi
if [ ! -x ${ORACLE_HOME}/bin/sqlplus ]
then
	_Echo failure "Executable \"${ORACLE_HOME}/bin/sqlplus\" not found; aborting..."
	exit 1
fi
if [ ! -x ${ORACLE_HOME}/bin/rman ]
then
	_Echo failure "Executable \"${ORACLE_HOME}/bin/rman\" not found; aborting..."
	exit 1
fi
if [[ "${ORACLE_BASE}" = "" ]]
then
	_Echo failure "Env var \"${ORACLE_BASE}\" not set by \"oraenv\" script; aborting..."
	exit 1
fi
if [ ! -d ${ORACLE_BASE} ]
then
	_Echo failure "Directory \"${ORACLE_BASE}\" not found; aborting..."
	exit 1
fi
if [ ! -d ${ORACLE_BASE}/admin ]
then
	_Echo failure "Directory \"${ORACLE_BASE}/admin\" not found; aborting..."
	exit 1
fi
if [ ! -d ${ORACLE_BASE}/admin/${ORACLE_SID} ]
then
	_Echo failure "Directory \"${ORACLE_BASE}/admin/${ORACLE_SID}\" not found; aborting..."
	exit 1
fi
if [ ! -d ${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc ]
then
	_Echo failure "Directory \"${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc\" not found; aborting..."
	exit 1
fi
#
#------------------------------------------------------------------------------
# If the standby database is already running, then shut it down.  Use SHUTDOWN
# ABORT because we're going to blow it away and re-initialize, anyway...
#------------------------------------------------------------------------------
${ORACLE_HOME}/bin/sqlplus -s /nolog << __EOF_RESTART_STDBY__ ###> /dev/null 2>&1
whenever oserror exit 1
whenever sqlerror exit 2
column exit_status new_value V_EXIT_STATUS noprint
connect / as sysdba
${_SqlTESTING}shutdown abort
${_SqlTESTING}startup nomount
select	decode(count(*), 0, '3','0') exit_status
from	v\$parameter
where	name = 'db_file_name_convert'
and	value like '%/oradata/${_PriOraSID}%'
and	value like '%/oradata/${_StdbyOraSID}%';
select	decode(count(*), 0, '3','0') exit_status
from	v\$parameter
where	name = 'log_file_name_convert'
and	value like '%/oradata/${_PriOraSID}%'
and	value like '%/oradata/${_StdbyOraSID}%';
exit &&V_EXIT_STATUS
__EOF_RESTART_STDBY__
case $? in
	1)	_Echo failure "SQL*Plus failed to connect to \"${_StdbyOraSID}\"; aborting..."
		exit 1 ;;
	2)	_Echo failure "SQL*Plus failed to execute SQL properly on \"${_StdbyOraSID}\"; aborting..."
		exit 1 ;;
	3)	if [[ "${_PriOraSID}" != "${_StdbyOraSID}" ]]
		then
			_Echo failure "Parameter \"db_file_name_convert\" not set or does not contain string \"*/oradata/${_PriOraSID}*\" or \"*/oradata/${_StdbyOraSID}*\"; aborting..."
			exit 1
		fi ;;
	4)	if [[ "${_PriOraSID}" != "${_StdbyOraSID}" ]]
		then
			_Echo failure "Parameter \"log_file_name_convert\" not set or does not contain string \"*/oradata/${_PriOraSID}*\" or \"*/oradata/${_StdbyOraSID}*\"; aborting..."
			exit 1
		fi ;;
	*)	;;
esac
#
#------------------------------------------------------------------------------
# Make sure that the "primary" connect string works...
#------------------------------------------------------------------------------
${ORACLE_HOME}/bin/tnsping ${_PriTnsString} > /dev/null 2>&1
if (( $? != 0 ))
then
	_Echo failure "\"tnsping ${_PriTnsString}\" failed; aborting..."
	exit 1
fi
#
#------------------------------------------------------------------------------
# Make sure that the TNS connect string for the primary matches the ORACLE_SID
# value also.  Also, determine if the primary database is in ARCHIVELOG mode
# or not...
#------------------------------------------------------------------------------
${ORACLE_HOME}/bin/sqlplus -s /nolog <<__EOF_TNSCHK__ ###> /dev/null 2>&1
whenever oserror exit 1
whenever sqlerror exit 2
set echo on feedback on timing on
connect ${_PriUnPwd} as sysdba
column exit_status new_value V_EXIT_STATUS noprint
select	decode(count(*), 0, '3','0') exit_status
from	v\$instance
where	instance_name = '${_PriOraSID}';
select	decode(count(*), 0, '4','0') exit_status
from	v\$database
where	log_mode = 'ARCHIVELOG';
exit &&V_EXIT_STATUS
__EOF_TNSCHK__
case $? in
	1)	_Echo failure "SQL*Plus failed to connect to \"${_PriTnsString}\"; aborting..."
		exit 1 ;;
	2)	_Echo failure "SQL*Plus failed to execute SQL properly on \"${_PriTnsString}\"; aborting..."
		exit 1 ;;
	3)	_Echo failure "Connect information in \"~/.orapwd\" is not correct for the \"${_PriOraSID}\" database; aborting..."
		exit 1 ;;
	4)	_Echo failure "Database \"${_PriOraSID}\" not in ARCHIVELOG mode; aborting..."
		exit 1 ;;
	*)	;;
esac
#
#------------------------------------------------------------------------------
# Make sure that the "primary" connect string works...
#------------------------------------------------------------------------------
${ORACLE_HOME}/bin/tnsping ${_PriTnsString} > /dev/null 2>&1
if (( $? != 0 ))
then
	_Echo failure "\"tnsping ${_PriTnsString}\" failed; aborting..."
	exit 1
fi
#
#------------------------------------------------------------------------------
# Make sure that the TNS connect string for the primary matches the ORACLE_SID
# value also.  Also, determine if the primary database is in ARCHIVELOG mode
# or not...
#------------------------------------------------------------------------------
${ORACLE_HOME}/bin/sqlplus -s /nolog <<__EOF_TNSCHK__ ###> /dev/null 2>&1
whenever oserror exit 1
whenever sqlerror exit 2
connect ${_PriUnPwd} as sysdba
column exit_status new_value V_EXIT_STATUS noprint
select	decode(count(*), 0, '3','0') exit_status
from	v\$instance
where	instance_name = '${_PriOraSID}';
select	decode(count(*), 0, '4','0') exit_status
from	v\$database
where	log_mode = 'ARCHIVELOG';
exit &&V_EXIT_STATUS
__EOF_TNSCHK__
case $? in
	1)	_Echo failure "SQL*Plus failed to connect to \"${_PriTnsString}\"; aborting..."
		exit 1 ;;
	2)	_Echo failure "SQL*Plus failed to execute SQL properly on \"${_PriTnsString}\"; aborting..."
		exit 1 ;;
	3)	_Echo failure "TNS string \"${_PriTnsString}\" did not connect to \"${_PriOraSID}\"; aborting..."
		exit 1 ;;
	4)	_Echo failure "Primary database \"${_PriTnsString}\" is not in ARCHIVELOG mode; aborting..."
		exit 1 ;;
	*)	;;
esac
#
#------------------------------------------------------------------------------
# Ask the user some important questions, and give them the chance to cancel out...
#------------------------------------------------------------------------------
echo ""
echo "================================================================================"
echo "Please ensure that a full RMAN backup of the \"primary\" database"
echo "\"${_PriTnsString}\" is available on this server for the \"standby\" database"
echo "\"${ORACLE_SID}\"?"
echo ""
echo "Please ensure that the directory in which these RMAN backupsets reside is the"
echo "default RMAN backup location for \"${ORACLE_SID}\"?"
echo ""
echo "Also, please ensure that these RMAN backupsets include a recent RMAN \"BACKUP"
echo "CURRENT CONTROLFILE FOR STANDBY\"?"
echo ""
echo "If all three of these conditions are TRUE, then please proceed by pressing ENTER."
echo ""
echo "If one of these conditions are NOT TRUE, then please cancel by entering CTRL-C,"
echo "correct the situation, and then restart..."
echo "================================================================================"
echo "Please Respond=> \c"
read _Response
echo ""
#
#------------------------------------------------------------------------------
# Set "LOCK" file so that the "stdby_*.sh" monitoring scripts don't go bonkers
# for the next 12 hours.  After 12 hours, they will remove this file and then
# proceed to go bonkers if this process hasn't resumed by then...
#------------------------------------------------------------------------------
_LockFile=${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc/stdby_init.lock
_TimeStamp="`date '+%y%m%d%H%M%S'`"
rm -f ${_LockFile} > /dev/null 2>&1
echo "Locked At ${_TimeStamp} by $0" > ${_LockFile}
if (( $? != 0 ))
then
	_Echo failure "Unable to create \"lock\" file (${_LockFile}); aborting..."
	rm -f ${_LockFile}
	exit 1
fi
#
echo "starting RMAN \"duplicate target database to \"${_StdbyOraSID}\" at `date`..."
#
#------------------------------------------------------------------------------
# Add the following clause to the RMAN "duplicate" command depending on whether
#  the ORACLE_SIDs are different...
#------------------------------------------------------------------------------
if [[ "${_PriOraSID}" = "${_StdbyOraSID}" ]]
then
	_ToDBClause="nofilenamecheck";
else
	_ToDBClause="to ${_StdbyOraSID}";
fi
#
#------------------------------------------------------------------------------
# Duplicate the "target" database (a.k.a. "primary") to the local "standby"
# database...
#------------------------------------------------------------------------------
${ORACLE_HOME}/bin/rman nocatalog << __EOF_RMANDUP__
connect target ${_PriUnPwd}
connect auxiliary /
${_RmanTESTING}duplicate target database for standby dorecover ${_ToDBClause};
exit
__EOF_RMANDUP__
if (( $? != 0 ))
then
	_Echo failure "RMAN failed; aborting..."
	rm -f ${_LockFile}
	exit 1
fi
#
echo "completed RMAN \"duplicate target database to \"${_StdbyOraSID}\" at `date`..."
#
#------------------------------------------------------------------------------
# Startup, mount, and open the standby database...
#------------------------------------------------------------------------------
${ORACLE_HOME}/bin/sqlplus -s /nolog <<__EOF_STDBY__ ###> /dev/null 2>&1
whenever oserror exit failure
set echo on feedback on timing on autorecovery on
connect / as sysdba
REM ${_SqlTESTING}alter database recover standby database;
set echo off
prompt 
prompt Do not be concerned by an ORA-00308 error -- it is normal ONLY for the last
prompt archived redo log file requested...
prompt 
whenever sqlerror exit failure
set echo on feedback on timing on
${_SqlTESTING}alter database open read only;
select count(*) test_count_of_DBA_DATA_FILES from dba_data_files;
${_SqlTESTING}alter database close;
exit success
__EOF_STDBY__
if (( $? != 0 ))
then
	_Echo failure "STARTUP/TEST STANDBY DATABASE failed; aborting `date`..."
	rm -f ${_LockFile}
	exit 1
fi
#
#------------------------------------------------------------------------------
# ...done!
#------------------------------------------------------------------------------
rm -f ${_LockFile}
exit 0
