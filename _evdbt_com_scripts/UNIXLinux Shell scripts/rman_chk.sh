#!/bin/ksh
#############################################################################
# File:		rman_chk.sh     
# Type:		UNIX korn-shell script
# Author:	Tim Gorman (Evergreen Database Technologies, Inc)
# Date:		14Feb03
# 
# Description:
#   
#	Report on recoverability of databases using RMAN_CHK package...
#
# Modifications:
#	TGorman	20dec2013	added customizations for COA
#############################################################################
#
#----------------------------------------------------------------------------
# Set up basic shell environment...
#----------------------------------------------------------------------------
if [ -f ~/.bashrc ]; then
        . ~/.bashrc > /dev/null 2>&1
fi
export PATH=$PATH:/usr/bin:/usr/local/bin
unset USERNAME
#
#----------------------------------------------------------------------------
# Setup script-specific shell variables...
#----------------------------------------------------------------------------
_Pgm=rman_chk
_LBin=/usr/local/bin
_WorkDir="`dirname $0`"
_TStamp="`date '+%Y%m%d_%H%M%S'`"
_PgmLogFile="${_WorkDir}/${_Pgm}.log"
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"
_CoaAppDir=/coa/applications/epage	# TGorman 20dec2013
#
#----------------------------------------------------------------------------
# Initialize program variables...
#----------------------------------------------------------------------------
_OraSid="<unknown>"
_LogFile=/tmp/${_Pgm}_${$}.tmp
_HostName="`hostname`"
_WhoAmI="`whoami`"
integer _ExitStatus=0
#
#----------------------------------------------------------------------------
# Create a shell function for error message handling...
#----------------------------------------------------------------------------
_Echo() ### ...define shell-function "_Echo()"...
{
	#--------------------------------------------------------------------
	# If "REPORT_MODE" is TRUE, then simply output all messages to
	# standard output.  Otherwise, email messages to the email addresses
	# listed in the ".dbapage" and ".dbamail" files...
	#--------------------------------------------------------------------
	_ReportMode=${REPORT_MODE:="FALSE"}
	if [[ "${_ReportMode}" = "TRUE" ]]
	then
		#
		echo "${_WhoAmI}@${_HostName} [${_OraSid}]: ${_Pgm}.sh $1\n\n$2\n"
		#
	else
		#
		#------------------------------------------------------------
		# if the message type is "failure", then send a brief alert
		# to the addresses listed in the file "$HOME/.dbapage"...
		#------------------------------------------------------------
		if [[ "$1" = "failure" ]]
		then
			#
###			if [ -r ${HOME}/.dbapage ]     # TGorman 20dec2013
			if [ -r ${_CoaAppDir}/epage.user ]
			then
###				sed '/^#/d' ${HOME}/.dbapage | \    # TGorman 20dec2013
				grep -v '^#' ${_CoaAppDir}/epage.user | grep -v '^$' | awk '{print $2}' | \
				while read _PageRcpt
				do
					_Subj="${_WhoAmI}@${_HostName} [${_OraSid}]: ${_Pgm}.sh $1 - check email"
					date | mailx -s "${_Subj}" ${_PageRcpt}
				done
			fi
			#
			echo "`date`: ${_WhoAmI}@${_HostName} [${_OraSid}]: ${_Pgm}.sh $1" >> ${_PgmLogFile}
			#
		fi
		#
		#------------------------------------------------------------
		# email the messages to the addresses listed in the file
		# "$HOME/.dbamail"...
		#------------------------------------------------------------
###		if [ -r ${HOME}/.dbamail ]   # TGorman 20dec2013
		if [ -r ${_CoaAppDir}/email.group -a -r ${_CoaAppDir}/email.user ]
		then
			#
###			sed '/^#/d' ${HOME}/.dbamail | \  # TGorman 20dec2013
			grep "^`grep '^dba' ${_CoaAppDir}/email.group | sed 's/dba //' | sed 's/ /\n/g'`" ${_CoaAppDir}/email.user | awk '{print $2}' | \
			while read _EmailRcpt
			do
				_Subj="${_WhoAmI}@${_HostName} [${_OraSid}]: ${_Pgm}.sh $1"
				echo "$2" | mailx -s "${_Subj}" ${_EmailRcpt}
			done
			#
		else
			#
			echo "${_WhoAmI}@${_HostName} [${_OraSid}]: ${_Pgm}.sh $1\n\n$2\n"
			#
		fi
		#
	fi
}	### ...end of definition of shell-function "_Echo()"...
#
#----------------------------------------------------------------------------
# Validate command-line parameters...
#----------------------------------------------------------------------------
case $# in
	1)	_OraSid=$1
		_RqstdPIT="sysdate-(1/4)"
		;;
	2)	_OraSid=$1
		_RqstdPIT="$2"
		;;
	*)	_Echo warning "Usage: \"${_Pgm} ORACLE_SID [requested-PIT]\"; aborting..."
        	exit 2 > /dev/null 2>&1
		;;
esac
#
#----------------------------------------------------------------------------
# Verify that the ORACLE_SID is registered in the ORATAB file...
#----------------------------------------------------------------------------
if [ ! -d ${_LBin} ]
then
	_Echo warning "Directory \"${_LBin}\" not found; aborting..."
	exit 2 > /dev/null 2>&1
fi
if [ ! -x ${_LBin}/dbhome ]
then
	_Echo warning "Script \"${_LBin}/dbhome\" not found; aborting..."
	exit 2 > /dev/null 2>&1
fi
if [ ! -x ${_LBin}/oraenv ]
then
	_Echo warning "Script \"${_LBin}/oraenv\" not found; aborting..."
	exit 2 > /dev/null 2>&1
fi
${_LBin}/dbhome ${_OraSid} > /dev/null 2>&1
if (( $? != 0 ))
then
        _Echo warning "\"${_OraSid}\" not local to this host; aborting..."
        exit 2 > /dev/null 2>&1
fi
#
#----------------------------------------------------------------------------
# Set Oracle environment variables...
#----------------------------------------------------------------------------
export ORACLE_SID=${_OraSid}
export ORAENV_ASK=NO
. ${_LBin}/oraenv > /dev/null 2>&1
if (( $? != 0 ))
then
	_Echo warning "oraenv failed; aborting..."
	exit 1 > /dev/null 2>&1
fi
unset ORAENV_ASK
#
#----------------------------------------------------------------------------
# Verify the setting of environment variables...
#----------------------------------------------------------------------------
if [[ "${ORACLE_SID}" = "" ]]
then
        _Echo warning "ORACLE_SID not set; aborting..."
        exit 1 > /dev/null 2>&1
fi
if [[ "${ORACLE_HOME}" = "" ]]
then
        _Echo warning "ORACLE_HOME not set; aborting..."
        exit 1 > /dev/null 2>&1
fi
if [ ! -d ${ORACLE_HOME} ]
then
	_Echo warning "Directory \"${ORACLE_HOME}\" not found; aborting..."
	exit 4 > /dev/null 2>&1
fi
if [ ! -d ${ORACLE_HOME}/bin ]
then
	_Echo warning "Directory \"${ORACLE_HOME}/bin\" not found; aborting..."
	exit 4 > /dev/null 2>&1
fi
if [ ! -x ${ORACLE_HOME}/bin/sqlplus ]
then
	_Echo warning "Executable \"${ORACLE_HOME}/bin/sqlplus\" not found; aborting..."
	exit 4 > /dev/null 2>&1
fi      
if [ ! -x ${ORACLE_HOME}/bin/rman ]
then
	_Echo warning "Executable \"${ORACLE_HOME}/bin/rman\" not found; aborting..."
	exit 4 > /dev/null 2>&1
fi      
#
#----------------------------------------------------------------------------
# Check to be sure that the database is running...
#----------------------------------------------------------------------------
if [[ "`ps -eaf | grep ora_pmon_${_OraSid} | grep -v grep`" = "" ]]
then
	#
	#--------------------------------------------------------------------
	# Log the execution of the script, limit the logfile to 300 lines...
	#--------------------------------------------------------------------
	echo "`date`: ${_WhoAmI}@${_HostName} [${_OraSid}]: ${_Pgm}.sh DB-DOWN" >> ${_PgmLogFile}
	tail -300 ${_PgmLogFile} > /tmp/${_Pgm}_temp_$$.tmp
	mv /tmp/${_Pgm}_temp_$$.tmp ${_PgmLogFile}
	exit 0
fi
#
#----------------------------------------------------------------------------
# Perform RMAN crosschecks...
#----------------------------------------------------------------------------
###$ORACLE_HOME/bin/rman target=/ nocatalog << __EOF_RMAN__ > ${_LogFile} 2>&1
###crosscheck backup of database;
###crosscheck backup of archivelog all;
###crosscheck backup of controlfile;
###exit
###__EOF_RMAN__
####
###if [[ "~`grep 'RMAN-' ${_LogFile}`~" != "~~" ]]
###then
###        _Echo failure "RMAN failed:\n\n`cat ${_LogFile}`"
###        integer _ExitStatus=1
###fi
###rm -f ${_LogFile}

#
#----------------------------------------------------------------------------
# Execute packaged procedure RMAN_CHK.RECOVERABILITY...
#----------------------------------------------------------------------------
${ORACLE_HOME}/bin/sqlplus /nolog > /dev/null 2>&1 << __EOF_SQLP__
connect / as sysdba

whenever oserror exit failure
whenever sqlerror exit failure

set echo off feedback off timing off

variable b1 varchar2(30)
variable b2 varchar2(30)
variable b3 varchar2(30)

col hostname format a22
col orasid format a8
col sysdate heading "Current|Date-time" format a20
col most_recent_bkup heading "Point-in-time|recoverable|from backed-up|archivelogs" format a20
col most_recent_rcvy heading "Point-in-time|recoverable|from backed-up|and non-backed-up|archivelogs" format a20
col bkup_type heading "Backup Type:|INCONSISTENT=hot backup|CONSISTENT=cold backup" format a30

alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';

spool ${_LogFile}
prompt RMAN_CHK.RECOVERABILITY for "${ORACLE_SID}", requested point-in-time is "${_RqstdPIT}"...
set echo on feedback on timing off pause off pages 100 lines 130 trimout on trimspool on serveroutput on size 1000000

alter system switch logfile;
whenever sqlerror continue
alter system archive log all;
whenever sqlerror exit failure

exec rman_chk.recoverability(${_RqstdPIT}, :b1, :b2, :b3, TRUE)

select	'${_HostName}' hostname,
	'${ORACLE_SID}' orasid,
	sysdate,
	:b1 most_recent_bkup,
	:b2 most_recent_rcvy,
	:b3 bkup_type
from	dual;

exit success
__EOF_SQLP__
#
if (( $? != 0 ))
then
        _Echo failure "SQL*Plus calling RMAN_CHK.RECOVERABILITY failed:\n\n`cat ${_LogFile}`"
        integer _ExitStatus=1
fi
rm -f ${_LogFile}
#
#----------------------------------------------------------------------------
# Log completion, and trim log to last 300 lines...
#----------------------------------------------------------------------------
if (( ${_ExitStatus} == 0 ))
then
	echo "`date`: `whoami`@`hostname` [${_OraSid}]: ${_Pgm} OK" >> ${_PgmLogFile}
	tail -300 ${_PgmLogFile} > /tmp/${_Pgm}_temp_$$.tmp
	mv /tmp/${_Pgm}_temp_$$.tmp ${_PgmLogFile}
fi
#
#----------------------------------------------------------------------------
# Done...
#----------------------------------------------------------------------------
exit ${_ExitStatus}
