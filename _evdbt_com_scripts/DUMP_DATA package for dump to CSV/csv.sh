#!/bin/ksh
#
_Dir=/csv/cdnpd
_TS=STR_FT_ROLL_60M023889Z
_OWN=CDN_DSL
_TAB=STREAMING_FACT_ROLLUP_60MIN
#
/usr/bin/perl csv.pl ${_TS} ${_OWN} ${_TAB} > ${_Dir}/${_TS}.csv 2> ${_Dir}/${_TS}.err
if (( $? == 0 ))
then
	_Status=completed
	integer _RtnStatus=0
else
	_Status=failed
	integer _RtnStatus=1
fi
echo "Dump \"${_TS}\" to CSV ${_Status}" | mailx -s "csv.sh ${_TS} ${_Status}" tim.gorman@level3.com
exit ${_RtnStatus}
