#!/bin/ksh
#============================================================================
#  File:	oramem.sql
#  Type:	UNIX/Linux korn-shell script
#  Date:	28-Jun 2002, 31-Mar 2016
#  Author:	Delphix
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
#  Copyright (c) 2016 by Delphix. All rights reserved.
# 
#  Description:
#
#	This shell script utilizes the "pmap -x" command to total up the
#	total amount of virtual memory used by all of the Oracle server
#	processes (both "background" and "foreground") belonging to the
#	Oracle database instance specified by the ORACLE_SID environment
#	variable..
#
#  Usage:
#
#	oramem.sh [ -v ]
#
#	where:
#		-v	Verbose mode, displays detailed information about each
#			foreground and background process in the Oracle database
#			instance.
#
#			Without this optional parameter, only summary
#			information for the entire Oracle database instance
#			is displayed.
#
# Modifications:
#	TGorman 28jun02	written for Solaris 2.8
#	TGorman 31mar16 updated for Linux and rejunvenated for Delphix
#============================================================================
#
#----------------------------------------------------------------------------
# Qualify on OS platform name...
#----------------------------------------------------------------------------
case `uname` in
	Linux)	_osName="Linux"
		;;
	SunOS)	_osName="SunOS)"
		;;
	*)	echo "OS platform \"`uname`\" not supported; aborting..."
		exit 1
		;;
esac
#
#----------------------------------------------------------------------------
# Validate command-line parameters...
#----------------------------------------------------------------------------
_Prog=oramem.sh
if (( $# > 1 ))
then
	echo ""
	echo "Usage: \"${_Prog} [ verbose ]\"; aborting..."
	echo ""
	exit 1
fi
#
#----------------------------------------------------------------------------
# If a command-line parameter is specified, then put the script into
# "verbose" mode...
#----------------------------------------------------------------------------
if (( $# == 1 ))
then
	_VerboseFlag=TRUE
else
	_VerboseFlag=FALSE
fi
#
#----------------------------------------------------------------------------
# Verify that the ORACLE_SID environment variable is set...
#----------------------------------------------------------------------------
if [[ "${ORACLE_SID}" = "" ]]
then
	echo "ORACLE_SID not set; aborting..."
	exit 1
fi
#
#----------------------------------------------------------------------------
# Create a name for a "temporary" scratch file...
#----------------------------------------------------------------------------
_TmpFile=/tmp/${_Prog}_$$.tmp
_TmpFile2=/tmp/${_Prog}2_$$.tmp
#
#----------------------------------------------------------------------------
# Using the UNIX "ps", "sed", and "awk" commands, retrieve VM and RSS
# information for this database instance's processes, saving the information
# to the "scratch" file...
#----------------------------------------------------------------------------
ps -eo fname,pid,args | \
	sed '1d' | \
	awk '{ \
		if ($1 == "oracle") \
		{ \
			if (substr($3,1,6)=="oracle") \
			{ \
				printf("%s %s\n", substr($3,7,10), $0); \
			} \
			else \
			{ \
				printf("%s %s\n", substr($3,10,10), $0); \
			} \
		} \
	     }' > ${_TmpFile}
#
#----------------------------------------------------------------------------
# Use OS platform-specific commands to determine total RAM and swap...
#----------------------------------------------------------------------------
case "${_osName}" in
	Linux)
		integer _SwapUsedMb=`free -m | grep '^Swap:' | awk '{print $3}'`
		integer _SwapFreeMb=`free -m | grep '^Swap:' | awk '{print $4}'`
		integer _TotRAM=`free -m | grep '^Mem:' | awk '{print $2}`
		;;
	SunOS)
		integer _SwapUsedKb=`swap -s | awk '{print $9}' | sed 's/k//'`
		_SwapUsedMb=`echo ${_SwapUsedKb} | awk '{printf("%0.02f\n", $1 / 1024)}'`
		integer _SwapFreeKb=`swap -s | awk '{print $11}' | sed 's/k//'`
		_SwapFreeMb=`echo ${_SwapFreeKb} | awk '{printf("%0.02f\n", $1 / 1024)}'`
		integer _TotRAM=`prtconf | grep "Mem" | awk '{print $3}`
		;;
esac
echo ""
echo "Total RAM on this server = ${_TotRAM}Mb, Swap = ${_SwapUsedMb}Mb used, ${_SwapFreeMb}Mb free"
#
#----------------------------------------------------------------------------
# Display header if printing in "verbose mode"...
#----------------------------------------------------------------------------
if [[ "${_VerboseFlag}" = "TRUE" ]]
then
	echo ""
	echo "     Detail for each foreground/background process in the Oracle instance \"${ORACLE_SID}\"..."
	echo ""
	echo "PID Command Txt(MB) Shm(MB) Priv(MB) All(MB)" | \
		awk '{printf("%10s%25s%15s%15s%15s%15s\n",$1,$2,$3,$4,$5,$6)}'
	echo "=== ======= ======= ======= ======== =======" | \
		awk '{printf("%10s%25s%15s%15s%15s%15s\n",$1,$2,$3,$4,$5,$6)}'
fi
#
#----------------------------------------------------------------------------
# ...retrieve the process information from the "scratch" file and save it
# into "korn-shell" arrays...
#----------------------------------------------------------------------------
integer _MaxSHR=0
integer _MaxSHM=0
integer _MaxTXT=0
integer _TotPRV=0
integer _BG=0
integer _FG=0
while read _SID _EXE _PID _ARGV0 _ARGVn
do
	#
	if [[ "${ORACLE_SID}" = "${_SID}" ]]
	then
		if [[ "`echo ${_ARGV0} | grep oracle${ORACLE_SID}`" = "" ]]
		then
			integer _BG=${_BG}+1
		else
			integer _FG=${_FG}+1
		fi
		#
###echo "_PID=${_PID}, _ARGV0=\"${_ARGV0}\""
		pmap -x ${_PID} > ${_TmpFile2} 2>&1
		if (( $? != 0 ))
		then
			echo "warning: \"pmap -x ${_PID}\" failed..."
		fi
		#
		# 02-APR-2003  Ty Haeber
		#
		#  Some systems may have more than one shared segment; therefore, I had to
		#  add some logic to sum this field.
		#
		###integer _SGA=`grep shmid ${_TmpFile2} | awk '{print $5}'`
		###integer _SGA=`grep shmid ${_TmpFile2} | awk '{ s += $5 } END {print s}'`
		###integer _SHR=`grep 'total Kb' ${_TmpFile2} | awk '{print $5}'`
		###integer _PRV=`grep 'total Kb' ${_TmpFile2} | awk '{print $6}'`
		###integer _SHR=${_SHR}+${_SGA}
		###integer _PRV=${_PRV}-${_SGA}
		#
		# 19-MAR-2004	Tim Gorman
		#
		# Calculated a different way, by isolating heap and stack and subtracting that from the total...
		#
		integer _SHM=`grep -i shm ${_TmpFile2} | awk '{i+=$2}END{print i}'`
		integer _HEAP=`grep -i heap ${_TmpFile2} | awk '{i+=$2}END{print i}'`
		integer _ANON=`grep -i anon ${_TmpFile2} | awk '{i+=$2}END{print i}'`
		integer _STACK=`grep -i stack ${_TmpFile2} | awk '{i+=$2}END{print i}'`
		integer _PRV=${_HEAP}+${_STACK}+${_ANON}
		integer _ALL=`grep -i 'total Kb' ${_TmpFile2} | awk '{print $3}'`
		integer _SHR=${_ALL}-${_PRV}
		integer _TXT=${_SHR}-${_SHM}
		#
		if (( ${_SHR} > ${_MaxSHR} ))
		then
			integer _MaxSHR=${_SHR}
		fi
		if (( ${_SHM} > ${_MaxSHM} ))
		then
			integer _MaxSHM=${_SHM}
		fi
		if (( ${_TXT} > ${_MaxTXT} ))
		then
			integer _MaxTXT=${_TXT}
		fi
		integer _TotPRV=${_TotPRV}+${_PRV}
###echo "	(_STACK[${_STACK}] + _HEAP[${_HEAP}] + _ANON[${_ANON}]) = PRV[${_PRV}], (CumTotal=${_TotPRV})"
###echo "	(_TXT[${_TXT}] + _SHM[${_SHM}]) = _SHR[${_SHR}]"
###echo "	_ALL=${_ALL}, _SHR=${_SHR}, _PRV=${_PRV}, _TotPRV=${_TotPRV}"
		if [[ "${_VerboseFlag}" = "TRUE" ]]
		then
			_MbTXT=`echo ${_TXT} | awk '{printf("%0.02f\n", $1 / 1024)}'`
			_MbSHM=`echo ${_SHM} | awk '{printf("%0.02f\n", $1 / 1024)}'`
			_MbPRV=`echo ${_PRV} | awk '{printf("%0.02f\n", $1 / 1024)}'`
			_MbALL=`echo ${_ALL} | awk '{printf("%0.02f\n", $1 / 1024)}'`
			echo "${_PID} ${_ARGV0} ${_MbTXT} ${_MbSHM} ${_MbPRV} ${_MbALL}" | \
				awk '{printf("%10s%25s%15s%15s%15s%15s\n",$1,$2,$3,$4,$5,$6)}'
		fi
	fi
	#
done < ${_TmpFile}
rm -f ${_TmpFile} ${_TmpFile2}
#
#----------------------------------------------------------------------------
# Display totals...
#----------------------------------------------------------------------------
integer _TotMEM=${_MaxSHR}+${_TotPRV}
_MbMaxTXT=`echo ${_MaxTXT} | awk '{printf("%0.02f\n", $1 / 1024)}'`
_MbMaxSHM=`echo ${_MaxSHM} | awk '{printf("%0.02f\n", $1 / 1024)}'`
_MbMaxSHR=`echo ${_MaxSHR} | awk '{printf("%0.02f\n", $1 / 1024)}'`
_MbTotPRV=`echo ${_TotPRV} | awk '{printf("%0.02f\n", $1 / 1024)}'`
_MbTotMEM=`echo ${_TotMEM} | awk '{printf("%0.02f\n", $1 / 1024)}'`
echo ""
echo "Summary info for all processes in the Oracle instance \"${ORACLE_SID}\"..."
echo ""
echo "#Procs #Procs Max Max Sum" | \
	awk '{printf("%10s%10s%15s%15s%15s\n",$1,$2,$3,$4,$5)}'
echo "Foregrnd Backgrnd Txt(MB) SHM(MB) Priv(MB) Total(MB)" | \
	awk '{printf("%10s%10s%15s%15s%15s%15s\n",$1,$2,$3,$4,$5,$6)}'
echo "======== ======== ======= ======= ======== =========" | \
	awk '{printf("%10s%10s%15s%15s%15s%15s\n",$1,$2,$3,$4,$5,$6)}'
echo "${_FG} ${_BG} ${_MbMaxTXT} ${_MbMaxSHM} ${_MbTotPRV} ${_MbTotMEM}" | \
	awk '{printf("%10s%10s%15s%15s%15s%15s\n",$1,$2,$3,$4,$5,$6)}'
echo ""
#
#----------------------------------------------------------------------------
# Done!
#----------------------------------------------------------------------------
exit 0
