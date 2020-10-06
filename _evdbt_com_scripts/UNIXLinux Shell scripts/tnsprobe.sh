#!/bin/ksh
#============================================================================
# Name:	 tnsprobe.sh
# Type:	 UNIX "korn" shell script
# Author:       Tim Gorman (Evergreen Database Technologies, Inc)
# Date:	 31Mar00
#
# Description:
#       Probes all ports between 1025 and 65536 seeking any active TNS
#       Listeners...
#
# Modifications:
#============================================================================
export PATH=/usr/sbin:/usr/bin:/bin:${PATH}:.
_Prog=tnsprobe
#
#----------------------------------------------------------------------------
# Verify that a hostname was entered...
#----------------------------------------------------------------------------
if (( $# != 1 ))
then
	echo
	echo "	Usage: \"${0} <hostname>\"; aborting..."
	echo
	exit 1
fi
_Host=$1
#
#----------------------------------------------------------------------------
# Verify proper syntax for call to "ping", by operating-system...
#----------------------------------------------------------------------------
case "`uname`" in
	AIX|Darwin|Linux)	_PingArgs="-c 1 ${_Host}" ;;
	HP-UX)			_PingArgs="${_Host} -n 1" ;;
	Solaris|SunOS)		_PingArgs="${_Host} 1" ;;
	*) echo "This script does not know how to call \"ping\" on `uname`..."
esac
#
#----------------------------------------------------------------------------
# Verify that the hostname is valid using the "ping" command...
#----------------------------------------------------------------------------
ping ${_PingArgs} > /dev/null 2>&1
if (( $? != 0 ))
then
	echo
	echo "	\"ping ${_PingArgs}\" failed; aborting..."
	echo
	exit 1
fi
#
#----------------------------------------------------------------------------
# Verify that the ORACLE_HOME environment variable has been set...
#----------------------------------------------------------------------------
if [[ "${ORACLE_HOME}" = "" ]]
then
	echo
	echo "	ORACLE_HOME not set; aborting..."
	echo
	exit 1
fi
#
#----------------------------------------------------------------------------
# Verify that the "tnsping" and "lsnrctl" executables can be executed...
#----------------------------------------------------------------------------
if [ ! -x ${ORACLE_HOME}/bin/tnsping ]
then
	echo
	echo "	\"ORACLE_HOME/bin/tnsping\" not found; aborting..."
	echo
	exit 1
fi
#
if [ ! -x ${ORACLE_HOME}/bin/lsnrctl ]
then
	echo
	echo "	\"ORACLE_HOME/bin/lsnrctl\" not found; aborting..."
	echo
	exit 1
fi
#
#----------------------------------------------------------------------------
# Change current environment within this shell script to make the new
# temporary TNS_ADMIN directory current...
#----------------------------------------------------------------------------
export TNS_ADMIN=./.test_${_Prog}_${$}
echo
echo "Setting TNS_ADMIN=${TNS_ADMIN} for duration of run..."
echo
_OsnFile=${TNS_ADMIN}/sqlnet.ora
_CfgFile=${TNS_ADMIN}/listener.ora
_NamFile=${TNS_ADMIN}/tnsnames.ora
_RptFile=${TNS_ADMIN}/${Prog}.out
_TmpFile1=${TNS_ADMIN}/${Prog}1_$$.tmp
_TmpFile2=${TNS_ADMIN}/${Prog}2_$$.tmp
#
#----------------------------------------------------------------------------
# Create a temporary TNS_ADMIN directory and make it private...
#----------------------------------------------------------------------------
mkdir ${TNS_ADMIN}
if (( $? != 0 ))
then
	echo
	echo "	\"mkdir ${TNS_ADMIN}\" failed; aborting..."
	echo
	exit 1
fi
chmod 700 ${TNS_ADMIN}
if (( $? != 0 ))
then
	echo
	echo "	\"chmod 700 ${TNS_ADMIN}\" failed; aborting..."
	echo
	exit 1
fi
echo "names.directory_path=(tnsnames)" > ${_OsnFile}
if (( $? != 0 ))
then
	echo
	echo "	\"echo names.directory_path=(tnsnames) > ${_OsnFile}\" failed; aborting..."
	echo
	exit 1
fi
#
#----------------------------------------------------------------------------
# Start probing ports, starting at port 1024, through port 65535...
#----------------------------------------------------------------------------
integer _Port=1024
echo "\nstarting at port ${_Port}..."
###while (( ${_Port} <= 65535 ))
while (( ${_Port} <= 9999 ))
do
	#
	#--------------------------------------------------------------------
	# Create a TNS Address string...
	#--------------------------------------------------------------------
	_TnsAddress="(ADDRESS=(PROTOCOL=TCP)(HOST=${_Host})(PORT=${_Port}))"
	#
	#--------------------------------------------------------------------
	# Use the Oracle "tnsping" program to see if the port is active...
	#--------------------------------------------------------------------
	${ORACLE_HOME}/bin/tnsping ${_TnsAddress} > /dev/null 2>&1
	if (( $? == 0 ))
	then
		echo "Oracle TNS Listener detected on \"${_Host}\" at port ${_Port}"
		echo "T_${_Port}=(DESCRIPTION=${_TnsAddress})" >> ${_CfgFile}
		#
		#--------------------------------------------------------------------
		# Attempt to use the passworded "services" command on the found
		# TNS Listener.  If it succeeds, then there is no password...
		#--------------------------------------------------------------------
		lsnrctl services t_${_Port} > ${_TmpFile1} 2>&1
		#
		#--------------------------------------------------------------------
		#--------------------------------------------------------------------
		grep "TNS-01189" ${_TmpFile1} > /dev/null 2>&1
		if (( $? == 0 ))
		then
			echo "TNS Listener on \"${_Host}\" on port ${_Port} using local OS authentication (default since 10gR1); continuing..."
		else
			#
			echo "TNS Listener on \"${_Host}\" on port ${_Port} *NOT* using local OS authentication..."
			#
			#--------------------------------------------------------------------
			# Using output from the "services" command, try to parse out the
			# database instance information in order to append onto the new
			# temporary listener configuration file...
			#--------------------------------------------------------------------
			_ListenerPassworded=false
			grep "handler(s) for this service..." ${_TmpFile1} | \
				awk '{print $2}' | sed 's/"//g' | sed 's/,//g' | \
				grep -v "PLSExtProc" | \
				sort -u | \
			while read _Sid
			do
				if [[ "${_ListenerPassworded}" = "false" ]]
				then
					echo "TNS Listener on \"${_Host}\" on port ${_Port} not passworded."
				fi
				_ListenerPassworded=true
				echo "T_${_Port}_${_Sid}=(DESCRIPTION=${_TnsAddress}(CONNECT_DATA=(SID=${_Sid})))" >> ${_NamFile}
				echo "Calling \"oraprobe.sh T_${_Port}_${_Sid} ${TNS_ADMIN}\"..."
				oraprobe.sh T_${_Port}_${_Sid} ${TNS_ADMIN}
			done
			if [[ "${_ListenerPassworded}" = "false" ]]
			then
				echo "TNS Listener on \"${_Host}\" on port ${_Port} is apparently passworded."
			fi
			#
		fi
	fi
	#
	#--------------------------------------------------------------------
	# Go to the next port...
	#--------------------------------------------------------------------
	integer _Port=${_Port}+1
	integer _Remainder=${_Port}%100
	if (( ${_Remainder} == 0 ))
	then
		echo "...port ${_Port}..."
	fi
	#
done
#
rm -rf ${TNS_ADMIN}
exit 0
