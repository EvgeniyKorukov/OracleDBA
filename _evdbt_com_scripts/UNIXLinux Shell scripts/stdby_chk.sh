#!/bin/ksh
#=============================================================================
# Name:         stdby_chk.sh
# Type:         korn-shell script
# Author:       Tim Gorman (Evergreen Database Technologies, Inc)
# Date:         10Apr00
#
# Description:
#	Korn-shell script intended to be run from the UNIX "cron" utility in
#	order to check to see whether the STANDBY database is more than two
#	archived redo log files behind the PRIMARY...
#
# Assumptions:
#	This script expects to be executed under the UNIX "cron" utility as the
#	UNIX account owning the Oracle software, so that it can connect
#	"/ as SYSDBA".
#
#	This script relies on the standard "oraenv" shell script supplied with
#	a standard Oracle RDBMS distribution.  If you use some other method for
#	setting up the necessary Oracle environment variables such as ORACLE_SID
#	and ORACLE_HOME, then this script will need to be modified accordingly.
#
#	Also, this script expects an environment variable named ORACLE_BASE to
#	be set up in the "oraenv" script, and it also expects a directory
#	structure like the following:
#
#		$ORACLE_BASE/
#			admin/
#				$ORACLE_SID/
#					adhoc/
#					adump/
#					bdump/
#					cdump/
#					pfile/
#					udump/
#
#	This script uses the "adhoc" subdirectory in which to create some
#	files used for locking.  All other directory locations are extracted
#	from the database.
#
# Notifications and alerts:
#	This script will send all messages to "standard output", which is
#	typically emailed to the calling user by the UNIX "cron" utility.
#
#	Alternatively, this script is also designed to expect the presence of
#	one or two text files, each containing a list of email addresses, one
#	per line.  Both text files are expected in the $HOME directory of the
#	Oracle software owner, and they are named:
#
#		.dbamail	List of email addresses for DBAs to receive
#				longer, more complete error messages, warnings,
#				and informational messages
#		.dbapage	List of email addresses (intended for text msgs)
#				for short messages only in the event of serious
#				failure
#
# Modifications:
#	TGorman	10apr00
#
#=============================================================================
_Pgm=stdby_chk
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
#-----------------------------------------------------------------------------
# Validate the number of command-line parameters...
#-----------------------------------------------------------------------------
if (( $# != 2 ))
then
	echo "Usage: \"$0 <primary-TNS-string> <standby-ORACLE_SID>\"; aborting..."
	exit 1
fi
#
_PriOraSid=$1
_StdbyOraSid=$2
#
#-----------------------------------------------------------------------------
# Set up connection information to both PRIMARY and STANDBY databases...
#-----------------------------------------------------------------------------
if [ ! -r ~/.orapwd ]	# ...validate that ".orapwd" file exists...
then
	_Echo failure "Cannot read \"~/.orapwd\" file; aborting..."
	exit 2
fi
_PriUnPwd=`grep "@${_PriOraSid}$" ~/.orapwd | grep -i "system/"`
if [ -z ${_PriUnPwd} ]	# ...validate that password for SYSTEM was found...
then
	_Echo failure "Cannot find password for SYSTEM on ${_PriOraSid}; aborting..."
	exit 3
fi
#
#-----------------------------------------------------------------------------
# Check to see if the STANDBY database is local.  Since the STANDBY instance
# is running in mount mode, we must use CONNECT INTERNAL...
#-----------------------------------------------------------------------------
dbhome ${_StdbyOraSid} > /dev/null 2>&1
if (( $? != 0 ))
then
	_Echo failure "\"${_StdbyOraSid}\" is not local to this host; aborting..."
	exit 4
fi
#
#-----------------------------------------------------------------------------
# If the instance isn't up and running, then just exit quietly...
#-----------------------------------------------------------------------------
if [ -z "`ps -eaf | grep ora_pmon_${_StdbyOraSid} | grep -v grep`" ]
then
	exit 0
fi
#
#-----------------------------------------------------------------------------
# Set up Oracle environment variables...
#-----------------------------------------------------------------------------
export ORACLE_SID=${_StdbyOraSid}
export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1
unset ORAENV_ASK
#
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
if [[ "${ORACLE_BASE}" = "" ]]
then
	_Echo failure "ORACLE_BASE not set"
	exit 1
fi
if [ ! -d ${ORACLE_BASE}/admin ]
then
	_Echo failure "Directory \"${ORACLE_BASE}/admin\" not found"
	exit 1
fi
#
#-----------------------------------------------------------------------------
# Check to see if the STANDBY is being refreshed at the present time...
#-----------------------------------------------------------------------------
_LockFile=${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc/stdby_init.lock
_LockedTime="`awk '{print $3}' ${_LockFile} 2> /dev/null`"
if [[ "${_LockedTime}" = "" ]] # ...if not found, then use current time...
then
	_LockedTime="`date '+%y%m%d%H%M%S'`"
fi
#
#-----------------------------------------------------------------------------
# If the STANDBY instance has been locked for refresh
#-----------------------------------------------------------------------------
sqlplus -s /nolog << __EOF__ > /dev/null 2>&1
whenever oserror exit failure
whenever sqlerror exit 1
connect ${_PriUnPwd}
whenever sqlerror exit 2
column table_name new_value V_TABLE_NAME
select	'dual' table_name
from	dual
where	sysdate - to_date('${_LockedTime}','RRMMDDHH24MISS') <= (1/2);
select dummy from &&V_TABLE_NAME ;
exit success
__EOF__
integer _Rtn=$?
if (( ${_Rtn} == 2 ))
then
	_Echo failure "\"${_StdbyOraSid}\" locked for REFRESH for > 12 hours"
	rm -f ${_LockFile}
	exit 5
else
	if (( ${_Rtn} != 0 ))
	then
		_Echo failure "SQL*Plus on ${_PriOraSid} failed"
		rm -f ${_LockFile}
		exit 5
	fi
fi
#
#-----------------------------------------------------------------------------
# Use SQL*Plus to query the MAX(SEQUENCE#) from both databases V$LOG_HISTORY
# view.  If the STANDBY appears to be falling behind, then yell and scream...
#-----------------------------------------------------------------------------
_OutFile=/tmp/stdby_chk_$$.out
sqlplus -s /nolog << __EOF__ > ${_OutFile} 2>&1
whenever oserror exit 99
connect / as sysdba
set verify off

whenever sqlerror exit 6
col logseq_on_standby new_value V_STDBY_LOGSEQ
select  /*+ rule */ max(h.sequence#) logseq_on_standby
from    v\$log_history  h,
        v\$parameter    p
where   h.thread#       = to_number(decode(p.value,'0',1,p.value))
and     p.name          = 'thread';

col filecnt new_value V_STDBY_FILECNT
select	count(*) filecnt
from	v\$datafile;

whenever sqlerror exit 7
connect ${_PriUnPwd}

whenever sqlerror exit 8
col logseq_on_primary new_value V_PRIMARY_LOGSEQ
select  /*+ rule */ max(h.sequence#) logseq_on_primary
from    sys.v_\$log_history     h,
        sys.v_\$parameter       p
where   h.thread#       = to_number(decode(p.value,'0',1,p.value))
and     p.name          = 'thread';

col filecnt new_value V_PRIMARY_FILECNT
select	count(*) filecnt
from	v\$datafile;

whenever sqlerror exit 9
begin
        if &&V_STDBY_LOGSEQ < &&V_PRIMARY_LOGSEQ - 2 then
		--
		if &&V_PRIMARY_FILECNT > &&V_STDBY_FILECNT then
			--
                	raise_application_error(-20001,
				'${_StdbyOraSid} is falling behind;  datafile(s) were added to PRIMARY');
			--
		elsif &&V_PRIMARY_FILECNT < &&V_STDBY_FILECNT then
			--
                	raise_application_error(-20002,
				'${_StdbyOraSid} is falling behind;  datafile(s) were dropped from PRIMARY');
			--
		else
			--
                	raise_application_error(-20000,
				'${_StdbyOraSid} is falling behind.');
			--
		end if;
		--
        end if;
end;
/
exit success
__EOF__
#
#-----------------------------------------------------------------------------
# Based on error code from SQL*Plus, compose an error message...
#-----------------------------------------------------------------------------
integer _Rtn=$?
case ${_Rtn} in
        0)      rm -f ${_OutFile} ;; # ...everything is OK!
        6)      _Echo failure "Query of V\$LOG_HISTORY on STANDBY failed\n\n`cat ${_OutFile}`\n" ;;
        7)      _Echo failure "unable to connect to PRIMARY" ;;
        8)      _Echo failure "Query of V\$LOG_HISTORY on PRIMARY failed\n\n`cat ${_OutFile}`\n" ;;
        9)      _Echo failure "STANDBY is falling behind PRIMARY\n\n`cat ${_OutFile}`\n" ;;
        *)      _Echo failure "SQL*Plus failed\n\n`cat ${_OutFile}`\n" ;;
esac
rm -f ${_OutFile}
#
#-----------------------------------------------------------------------------
# Done!
#-----------------------------------------------------------------------------
exit 0
