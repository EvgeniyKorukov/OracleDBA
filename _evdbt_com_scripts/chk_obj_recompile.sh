#!/bin/ksh
#============================================================================
# File:		chk_obj_recompile.sh
# Type:		UNIX korn-shell script
# Author:	Tim Gorman (Evergreen Database Technologies, Inc)
# Date:		25Apr02
#
# Description:
#
#	Check the specified database to determine whether:
#
#	1. Any database objects are invalid...
#
# Exit statuses:
#	0	normal succesful completion
#	1	ORACLE_SID not specified - user error
#	2	Cannot connect using "CONNECT / AS SYSDBA"
#	3	SQL*Plus failed to create "spool" file for report
#	4	SQL*Plus failed while generating report
#	5	Something is invalidated - check report!!
#
# Modifications:
#============================================================================
_Pgm=chk_obj_recompile.sh
#
#----------------------------------------------------------------------------
# Korn-shell function to be called multiple times in the script...
#----------------------------------------------------------------------------
notify_via_email() # ...use email to notify people...
{
	if [ ! -r ~/.notify_via_email ]
	then
		echo "...generating default \"~/.notify_via_email\" file..."
		echo root > ~/.notify_via_email
		echo oracle >> ~/.notify_via_email
	fi
	_EmailList=`cat ~/.notify_via_email`
	for _Email in "${_EmailList}"
	do
		echo "${_ErrMsg}" | mailx -s "${_Pgm} ${_OraSid}" ${_Email}
	done
} # ...end of shell function "notify_via_email"...
#
#----------------------------------------------------------------------------
# Verify that the ORACLE_SID has been specified on the UNIX command-line...
#----------------------------------------------------------------------------
if (( $# != 1 ))
then
	exit 1 > /dev/null 2>&1
fi
_OraSid=$1
#
#----------------------------------------------------------------------------
# Verify that the database instance specified is "up"...
#----------------------------------------------------------------------------
_Up=`ps -eaf | grep ora_pmon_${_OraSid} | grep -v grep | awk '{print $NF}'`
if [[ "${_Up}" = "" ]]
then
	exit 0 > /dev/null 2>&1
fi
#
#----------------------------------------------------------------------------
# Verify that the ORACLE_SID is registered in the ORATAB file...
#----------------------------------------------------------------------------
/usr/local/bin/dbhome ${_OraSid} > /dev/null 2>&1
if (( $? != 0 ))
then
	echo "${_Pgm}: \"${_OraSid}\" not local to this host; aborting..."
	exit 1
fi
#
#----------------------------------------------------------------------------
# Set the Oracle environment variables for this database instance...
#----------------------------------------------------------------------------
export ORACLE_SID=${_OraSid}
export ORAENV_ASK=NO
. /usr/local/bin/oraenv > /dev/null 2>&1
unset ORAENV_ASK
#
#----------------------------------------------------------------------------
# Connect via SQL*Plus and product the report...
#----------------------------------------------------------------------------
sqlplus -s /nolog << __EOF__ > /dev/null 2>&1
whenever oserror exit 2
whenever sqlerror exit 2
connect / as sysdba
whenever oserror exit 3
whenever sqlerror exit 4
set echo off feedb off timi off pau off pages 0 lines 500 trimsp on
spool /tmp/chk_obj_recompile_${ORACLE_SID}.lst
select	chr(9) || 'alter ' || decode(object_type,
			   'PACKAGE BODY', 'PACKAGE',
			   'TYPE BODY', 'TYPE',
			   object_type) ||
	' "' || owner || '"."' || object_name || '" compile' ||
	decode(object_type,
		'PACKAGE BODY', ' body;',
		'TYPE BODY', ' body;',
		';') cmd
from	dba_objects
where	status = 'INVALID';
exit success
__EOF__
#
#----------------------------------------------------------------------------
# If SQL*Plus exited with a failure status, then exit the script also...
#----------------------------------------------------------------------------
_Rtn=$?
if (( ${_Rtn} != 0 ))
then
	case "${_Rtn}" in
		2) _ErrMsg="${_Pgm}: Cannot connect using \"CONNECT / AS SYSDBA\"";;
		3) _ErrMsg="${_Pgm}: spool of report failed";;
		4) _ErrMsg="${_Pgm}: query in report failed" ;;
	esac
	notify_via_email
	exit ${_Rtn} > /dev/null 2>&1
fi
#
#----------------------------------------------------------------------------
# If the report contains anything, then notify the authorities!
#----------------------------------------------------------------------------
if [ -s /tmp/chk_obj_recompile_${ORACLE_SID}.lst ]
then
	_ErrMsg="${_Pgm} - some objects are invalid:\n\n`cat /tmp/chk_obj_recompile_${ORACLE_SID}.lst`"
	_ErrMsg="${_ErrMsg}\n\nYou may want to investigate how they were invalidated by checking DBA_DEPENDENCIES"
	_ErrMsg="${_ErrMsg}\nand then checking DBA_OBJECTS for LAST_DDL_TIME on dependent objects..."
	_ErrMsg="${_ErrMsg}\n\nScript \"gen_recompile.sql\" can help also..."
	notify_via_email
	rm -f /tmp/chk_obj_recompile_${ORACLE_SID}.lst
	exit 5 > /dev/null 2>&1
else
	rm -f /tmp/chk_obj_recompile_${ORACLE_SID}.lst
fi
#
#----------------------------------------------------------------------------
# Return the exit status from SQL*Plus...
#----------------------------------------------------------------------------
exit 0 > /dev/null 2>&1
