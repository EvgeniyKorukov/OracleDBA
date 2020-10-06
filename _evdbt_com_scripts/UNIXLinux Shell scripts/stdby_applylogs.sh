#!/bin/ksh
#=============================================================================
# Name:         stdby_applylogs.sh
# Type:         korn-shell script
# Author:       Tim Gorman (Evergreen Database Technologies, Inc)
# Date:         29Mar01
#
# Description:
#	Korn-shell script intended to be executed from the UNIX "cron" utility
#	against the standby database.  This script should be executed as
#	frequently as necessary to apply any archived redo log files accumuated
#	from the primary database.
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
#	TGorman	29Mar01
#=============================================================================
_Pgm=stdby_appylogs
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
if (( $# != 1 ))
then
	echo "Usage: \"$0 <standby-ORACLE_SID>\"; aborting..."
	exit 1
fi
#
_StdbyOraSID=$1
#
#-----------------------------------------------------------------------------
# Check to see if the STANDBY database is local.  Since the STANDBY instance
# is running in mount mode, we must use CONNECT INTERNAL...
#-----------------------------------------------------------------------------
dbhome ${_StdbyOraSID} > /dev/null 2>&1
if (( $? != 0 ))
then
	echo "\"${_StdbyOraSID}\" is not local to this host; aborting..."
	exit
fi
#
#-----------------------------------------------------------------------------
# If the instance isn't up and running, then just exit quietly...
#-----------------------------------------------------------------------------
if [ -z "`ps -eaf | grep ora_pmon_${_StdbyOraSID} | grep -v grep`" ]
then
	exit 0
fi
#
#-----------------------------------------------------------------------------
# Set up UNIX environment variables...
#-----------------------------------------------------------------------------
export ORACLE_SID=${_StdbyOraSID}
export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1
unset ORAENV_ASK
#
#-----------------------------------------------------------------------------
# Validate that important environment variables exist...
#-----------------------------------------------------------------------------
if [[ "${ORACLE_SID}" = "" ]]
then
        _Echo warning "ORACLE_SID not set; aborting..."
        exit 1
fi
if [[ "${ORACLE_HOME}" = "" ]]
then
        _Echo warning "ORACLE_HOME not set; aborting..."
        exit 1
fi
if [[ "${LD_LIBRARY_PATH}" = "" ]]
then
        _Echo warning "LD_LIBRARY_PATH not set; aborting..."
        exit 1
fi
if [[ "${ORACLE_BASE}" = "" ]]
then
        _Echo warning "ORACLE_BASE not set; aborting..."
        exit 1
fi
#
#-----------------------------------------------------------------------------
# Validate that important directories exist...
#-----------------------------------------------------------------------------
if [ ! -d ${ORACLE_BASE} ]
then
        _Echo warning "Directory \"${ORACLE_BASE}\" not found; aborting..."
        exit 1
fi
if [ ! -d ${ORACLE_BASE}/admin ]
then
        _Echo warning "Directory \"${ORACLE_BASE}/admin\" not found; aborting..."
        exit 1
fi
if [ ! -d ${ORACLE_BASE}/admin/${ORACLE_SID} ]
then
        _Echo warning "Directory \"${ORACLE_BASE}/admin/${ORACLE_SID}\" not found; aborting..."
        exit 1
fi
if [ ! -d ${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc ]
then
        _Echo warning "Directory \"${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc\" not found; aborting..."
        exit 1
fi
#
#-----------------------------------------------------------------------------
# Check to see if the STANDBY is being refreshed at the present time.  If so,
# then just exit quietly...
#-----------------------------------------------------------------------------
_LockFile=${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc/stdby_init.lock
if [ -f ${_LockFile} ]
then
	exit 0
fi
#
#-----------------------------------------------------------------------------
# Create a shell script to compress archived redo log files...
#-----------------------------------------------------------------------------
###_CompressShellFile=/tmp/${_Pgm}_compress_${$}.sh
###echo "#!/bin/ksh" > ${_CompressShellFile}
###echo "#" >> ${_CompressShellFile}
###ls -1 /a001/oraarch/prod/prod*.log | \
###	 awk '{printf("compress %s\nif (( $? != 0 ))\nthen\n\texit 1\nfi\n",$1)}' >> ${_CompressShellFile}
###echo "#" >> ${_CompressShellFile}
###echo "exit 0" >> ${_CompressShellFile}
###chmod 755 ${_CompressShellFile}
#
#-----------------------------------------------------------------------------
# Keep only the most recent 500 lines of the log file...
#-----------------------------------------------------------------------------
_LogFile=${ORACLE_BASE}/admin/${ORACLE_SID}/adhoc/stdby_applylogs.log
_TmpFile=/tmp/stdby_applylogs_${$}.tmp
touch ${_LogFile}
tail -500 ${_LogFile} > ${_TmpFile}
mv ${_TmpFile} ${_LogFile}
#
#-----------------------------------------------------------------------------
# Use SQL*Plus to perform recovery of shipped redo log files...
#-----------------------------------------------------------------------------
echo "" >> ${_LogFile}
echo ">>> `date`: started RECOVER STANDBY DATABASE..." >> ${_LogFile}
sqlplus "/ as sysdba" << __EOF__ >> ${_LogFile} 2>&1
set autorecovery on
recover automatic standby database;
exit
__EOF__
###if (( $? != 0 ))
###then
###	_Echo failure "RECOVER AUTOMATIC STANDBY DATABASE failed.\n\n`cat ${_LogFile}`\n"
###	exit 1
###fi
echo ">>> Do not worry about an ORA-00308 error on the last" >> ${_LogFile}
echo ">>> archived redo log file applied;  that is normal..." >> ${_LogFile}
echo ">>> `date`: completed RECOVER STANDBY DATABASE..." >> ${_LogFile}
#
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
${_CompressShellFile}
if (( $? != 0 ))
then
	_Echo warning "Shell script \"${_CompressShellFile}\" failed"
	exit 1
else
	rm -f ${_CompressShellFile}
fi
#
#-----------------------------------------------------------------------------
# Complete...
#-----------------------------------------------------------------------------
exit 0
