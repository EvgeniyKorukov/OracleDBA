#!/bin/ksh
#============================================================================
# Name:         oraprobe.sh
# Type:         UNIX "korn" shell script
# Author:       Tim Gorman (Evergreen Database Technologies, Inc)
# Date:         29Mar00
#
# Description:
#       Probes the database at the given TNS alias to find out if any
#	Oracle accounts are passworded in "guess-able" fashion...
#
# Modifications:
#============================================================================
_Prog=oraprobe
#
#----------------------------------------------------------------------------
# Verify that a hostname was entered...
#----------------------------------------------------------------------------
if (( $# != 1 && $# != 2 ))
then
        echo
        echo "\tUsage: \"${0} <TNS-alias> [ TNS_ADMIN-dir ]\"; aborting..."
        echo
        exit 1
fi
_TnsAlias=$1
_TnsAdmin=$2
#
#----------------------------------------------------------------------------
# Verify that the ORACLE_HOME environment variable has been set...
#----------------------------------------------------------------------------
if [[ "~${ORACLE_HOME}~" = "~~" ]]
then
        echo
        echo "\tORACLE_HOME not set; aborting..."
        echo
        exit 1
fi
#
#----------------------------------------------------------------------------
# Verify that the "tnsping" executables can be executed...
#----------------------------------------------------------------------------
if [ ! -x ${ORACLE_HOME}/bin/tnsping ]
then
        echo
        echo "\t\"ORACLE_HOME/bin/tnsping\" not found; aborting..."
        echo
        exit 1
fi
#
#----------------------------------------------------------------------------
# Verify the existence of a "TNS_ADMIN" directory and "TNSNAMES" file...
#----------------------------------------------------------------------------
if [[ "~${_TnsAdmin}~" != "~~" ]]	# if TNS_ADMIN specified on cmd-line
then
	export TNS_ADMIN=${_TnsAdmin}
fi
#
if [[ "~${TNS_ADMIN}~" = "~~" ]]	# if TNS_ADMIN is still not set
then
	export TNS_ADMIN=${ORACLE_HOME}/network/admin
fi
#
if [ ! -d ${TNS_ADMIN} ]
then
	echo
	echo "TNS_ADMIN directory \"${TNS_ADMIN}\" not found; aborting..."
	echo
	exit 1
fi
#
if [ ! -f ${TNS_ADMIN}/tnsnames.ora ]
then
	echo
	echo "TNSNAMES file \"${TNS_ADMIN}/tnsnames.ora\" not found; aborting..."
	echo
	exit 1
fi
#
echo "Using \"tnsnames.ora\" file in \"${TNS_ADMIN}\" directory..."
#
#----------------------------------------------------------------------------
# Verify that _TnsAlias is a valid TNS connect string...
#----------------------------------------------------------------------------
${ORACLE_HOME}/bin/tnsping ${_TnsAlias} > /dev/null 2>&1
if (( $? != 0 ))
then
        echo
        echo "\t\"tnsping ${_TnsAlias}\" failed; aborting..."
        echo
        exit 1
fi
#
#----------------------------------------------------------------------------
# Create three "temporary files" for later use...
#----------------------------------------------------------------------------
_TmpFile1=/tmp/.oraprobe_${$}_1.tmp
_TmpFile2=/tmp/.oraprobe_${$}_2.tmp
_TmpFile3=/tmp/.oraprobe_${$}_3.tmp
rm -f ${_TmpFile1} ${_TmpFile2} ${_TmpFile3}
#
#----------------------------------------------------------------------------
# Create the first (basic) list of "username/password" combinations to use...
#----------------------------------------------------------------------------
echo "connect sys/change_on_install@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/sys@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/manager@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/manag3r@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/oracle@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/oracl3@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racle@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racl3@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/oracle8@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/oracle9@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/oracle8i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/oracle9i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racle8@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racle9@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racle8i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racle9i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racl38@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racl39@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racl38i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/0racl39i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sys/change_on_install@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/sys@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/manager@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/manag3r@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/oracle@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/oracl3@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racle@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racl3@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/oracle8@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/oracle9@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/oracle8i@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/oracle9i@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racle8@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racle9@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racle8i@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racle9i@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racl38@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racl39@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racl38i@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect sys/0racl39i@${_TnsAlias} as sysdba" >> ${_TmpFile1}
echo "connect system/system@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/manager@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/manag3r@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/oracle@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/oracl3@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racle@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racl3@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/oracle8@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/oracle9@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/oracle8i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/oracle9i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racle8@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racle9@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racle8i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racle9i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racl38@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racl39@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racl38i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect system/0racl39i@${_TnsAlias}" >> ${_TmpFile1}
echo "connect dbsnmp/dbsnmp@${_TnsAlias}" >> ${_TmpFile1}
echo "connect outln/outln@${_TnsAlias}" >> ${_TmpFile1}
echo "connect mdsys/mdsys@${_TnsAlias}" >> ${_TmpFile1}
echo "connect ordsys/ordsys@${_TnsAlias}" >> ${_TmpFile1}
echo "connect ordplugins/ordplugins@${_TnsAlias}" >> ${_TmpFile1}
echo "connect perfstat/perfstat@${_TnsAlias}" >> ${_TmpFile1}
echo "connect tracesvr/trace@${_TnsAlias}" >> ${_TmpFile1}
echo "connect demo/demo@${_TnsAlias}" >> ${_TmpFile1}
echo "connect names/names@${_TnsAlias}" >> ${_TmpFile1}
echo "connect sysadm/sysadm@${_TnsAlias}" >> ${_TmpFile1}
echo "connect ctxsys/ctxsys@${_TnsAlias}" >> ${_TmpFile1}
echo "connect ctxdemo/ctxdemo@${_TnsAlias}" >> ${_TmpFile1}
echo "connect mtssys/mtssys@${_TnsAlias}" >> ${_TmpFile1}
echo "connect scott/tiger@${_TnsAlias}" >> ${_TmpFile1}
echo "connect adams/wood@${_TnsAlias}" >> ${_TmpFile1}
echo "connect jones/steel@${_TnsAlias}" >> ${_TmpFile1}
echo "connect clark/cloth@${_TnsAlias}" >> ${_TmpFile1}
echo "connect blake/paper@${_TnsAlias}" >> ${_TmpFile1}
echo "connect applsys/fnd@${_TnsAlias}" >> ${_TmpFile1}
echo "connect apps/apps@${_TnsAlias}" >> ${_TmpFile1}
chmod 600 ${_TmpFile1}
#
#----------------------------------------------------------------------------
# Append SELECT ... FROM DUAL after each CONNECT command to verify whether
# the connection was successful.  Also, append a SELECT from the ALL_USERS
# view for use if the connection is successful to attempt to get a list of
# other usernames, for a second round of attempted logins...
#----------------------------------------------------------------------------
echo "whenever oserror continue" >> ${_TmpFile2}
chmod 600 ${_TmpFile2}
echo "whenever sqlerror continue" >> ${_TmpFile2}
echo "set echo off feedb off pages 0 pau off timi off time off trimo on" >> ${_TmpFile2}
while read _UnPwd
do
        #
        #--------------------------------------------------------------------
        # Append SELECT statements after each CONNECT attempt...
        #--------------------------------------------------------------------
	echo "${_UnPwd}" >> ${_TmpFile2}
	echo "select '${_UnPwd} is valid' from dual;" >> ${_TmpFile2}
	echo "select '::connect '||lower(username)||'/'||lower(username)||'@${_TnsAlias}' from all_users;" >> ${_TmpFile2}
	#
done < ${_TmpFile1}
echo "exit" >> ${_TmpFile2}
#
#----------------------------------------------------------------------------
# Run the generated script and save the output...
#----------------------------------------------------------------------------
sqlplus -s /nolog << __EOF__ > ${_TmpFile1}
start ${_TmpFile2}
__EOF__
#
#----------------------------------------------------------------------------
# For any successful connection attempts, extract all of the generated
# connection attempts produced from the ALL_USERS view, to make a second
# round of login attempts...
#----------------------------------------------------------------------------
echo "whenever oserror continue" > ${_TmpFile2}
chmod 600 ${_TmpFile2}
echo "whenever sqlerror continue" >> ${_TmpFile2}
echo "set echo off feedb off pages 0 pau off timi off time off trimo on" >> ${_TmpFile2}
grep "::connect " ${_TmpFile1} | \
	sed 's/::connect /connect /' | \
while read _UnPwd
do
        #
        #--------------------------------------------------------------------
        # Append a SELECT ... FROM DUAL to identify successful login attempts...
        #--------------------------------------------------------------------
	echo "${_UnPwd}" >> ${_TmpFile2}
	echo "select '${_UnPwd} is valid' from dual;" >> ${_TmpFile2}
	#
done
echo "exit" >> ${_TmpFile2}
#
#----------------------------------------------------------------------------
# Run the second generated SQL*Plus script and save the output...
#----------------------------------------------------------------------------
sqlplus -s /nolog << __EOF__ > ${_TmpFile3}
start ${_TmpFile2}
__EOF__
#
#----------------------------------------------------------------------------
# Extract all of the successful login attmempts from the spooled output of
# the first and second sets of login attempts...
#----------------------------------------------------------------------------
grep -h "is valid" ${_TmpFile1} ${_TmpFile3} | sort -u
rm -f ${_TmpFile1} ${_TmpFile2} ${_TmpFile3}
#
#----------------------------------------------------------------------------
# done
#----------------------------------------------------------------------------
exit 0


