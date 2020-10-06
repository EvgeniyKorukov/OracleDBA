#!/usr/bin/ksh
# Name: rman_bkup.ksh
# Written: 12/20/04 - KAR (cold_backup.ksh)
# ***Updated: 02/18/09 - KJP from Cold Backup to RMAN Hot backup
# Description: Generic script for RMAN hot backups of COT production
# databases
# Process: 1) Initialize RMAN Session
#          2) Clears Old Backup Files, retaining only current set
#          3) Takes hot backup of database- NO SHUTDOWN REQUIRED
#          6) Copy files to snap server with an extension
# Local drive keeps one set, Snap Server keeps 3+ sets
# Revisions: 01.04.05 - kar Added HourMinute to suffix so multiple
#                       backups per day don't overwrite each other
#            01.10.05 - KAR - Rewrote to accept SID as argument
#            03.21.05 - KAR - Temporary add of gathering file stats.
#            10.05.05 - KAR - Rewrote directory structure for Blade1
#            10.19.05 - KAR - Massive cleanup and added outfile
#            09.26.06 - KAR - Use spfile instead of pfile
#            10.03.06 - KAR - Get $O_H from /etc/oratab
#            12.01.08 - RJC - Previously using special_cold_backups.ksh.
#                       Since we are pointing backups to ap-snap5, I am
#                       modifying this script and reincorporating it.
#            02.18.09 - KJP - Copied original script and rewrote to
#                       utilize RMAN hot backup utilities so no shutdown of
#                       environment is required.
#            Execution:  ./rman_bkup.ksh $ORACLE_SID  
# set -x
#. ~/.9i
# Set Oracle variables:

. ~/.profile

################################################################################
# STANDARD - LOCAL SCRIPT VARIABLES
################################################################################
export PROGNAME=`basename $0`
export PROGROOT=`basename $0 | awk -F. '{print $1}'`
export HOSTNAME=`hostname`
echo $PROGNAME $PROGROOT $HOSTNAME

################################################################################
# STANDARD - SCRIPT PATH(S) BASED ON ENVIRONMENT PATH(S)
################################################################################
export BINPATH=${ORACLEBIN}
echo $BINPATH

################################################################################
# CUSTOM SETTINGS
################################################################################
#export DBA=oradba@cityofthornton.net
#export DBA_PG=kellyn.pedersen@vzw.blackberry.net
export ORACLE_SID=$1
export ORACLE_BASE=/ora9i/app/oracle
export ORACLE_HOME=`grep -i ^"$ORACLE_SID" /etc/oratab | awk -F: '{print $2}'`
export PATH=$PATH:${ORACLE_HOME}/bin
export UDUMP=${ORACLE_BASE}/admin/${ORACLE_SID}/udump

export rman_config=${HOME}/scripts/backup/rman/rman_config.dat
echo $rman_config
export CONF_HOME=`grep "rm_${ORACLE_SID} " $rman_config |  awk '{print $2}'`
echo $CONF_HOME
export BKUP_LOC=`grep "rm_${ORACLE_SID} " $rman_config |  awk '{print $3}'`
echo $BKUP_LOC
export EXEC_DIR=`grep "rm_${ORACLE_SID} " $rman_config |  awk '{print $4}'`
echo $EXEC_DIR
export CHANNELS=`grep "rm_${ORACLE_SID} " $rman_config |  awk '{print $5}'`
echo $CHANNELS


echo "RMAN Hot Backup for $ORACLE_SID -----------------------------------------"echo "-----------------------------------------------------------------"

export TNS_ADMIN=${ORACLE_HOME}/network/admin
echo $TNS_ADMIN
export OUTFILE=${EXEC_DIR}/logs/rman_bkup_${ORACLE_SID}.log
echo $OUTFILE
touch $OUTFILE
export ERR_LOG=${EXEC_DIR}/logs/rman_err_${ORACLE_SID}.log
echo $ERR_LOG


# Set Backup variables:

DAYS_TO_KEEP=4   # how many daily sets we want (will be 3)
#Will have to change this, RMAN backup will have specific suffix!
SFX=`date +%m%d-%H%M`   # suffix to append to backup files on snap server
#                         monthday-hourminute, needed for multiple backups a day
#SS_DIR=/orabackup/DBBackup/${ORACLE_SID}   # snap server directory for backup copies
SS_DIR=/snapshot/backup/${ORACLE_SID}   # New snap server directory for backup copies
#Renaming this variable to BKUP_LOC to utilize the RMAN commands
INIT=${ORACLE_HOME}/dbs/init${ORACLE_SID}.ora
SPFILE=${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora
OUTFILE=${EXEC_DIR}/logs/rman_bkup_${ORACLE_SID}.log

echo "Backup results for $ORACLE_SID:" >> $OUTFILE
echo "***********************************"  >> $OUTFILE


echo "Removing backup copies from $SS_DIR older than $DAYS_TO_KEEP days."  >> $OUTFILE
#find ${SS_DIR}/* -mtime +$DAYS_TO_KEEP -exec rm {} \; >> $OUTFILE
#find ${SS_DIR}/* -mtime +$DAYS_TO_KEEP -exec rm {} \;

#COPY Oracle Config Files
cp ${ORACLE_HOME}/network/admin/*.ora ${BKUP_LOC}/.
cp ${ORACLE_HOME}/dbs/init${ORACLE_SID}.ora ${BKUP_LOC}/.
cp ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora ${BKUP_LOC}/.

# Backing up database with Rman
if [ "$1" == "" ]
then
echo "RMAN- You Must Specify an Oracle SID, Exiting Script!" >> $OUTFILE
exit 1
fi

echo "Backing Up Database $ORACLE_SID -----------------------------------------" >> $OUTFILE
echo "-----------------------------------------------------------------"  >> $OUTFILE
${ORACLE_HOME}/bin/rman target=/ nocatalog <<EOF >>$OUTFILE
configure default device type to disk;
configure channel device type disk maxpiecesize 4G;
CONFIGURE CHANNEL 1 DEVICE TYPE DISK FORMAT '${BKUP_LOC}/%d_%U.bak';
CONFIGURE CHANNEL 2 DEVICE TYPE DISK FORMAT '${BKUP_LOC}/%d_%U.bak';
CONFIGURE CHANNEL 3 DEVICE TYPE DISK FORMAT '${BKUP_LOC}/%d_%U.bak';
CONFIGURE CHANNEL 4 DEVICE TYPE DISK FORMAT '${BKUP_LOC}/%d_%U.bak';
crosscheck backup;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 4 DAYS;
crosscheck archivelog all;
delete noprompt backup tag rman_nocat_${ORACLE_SID};
configure controlfile autobackup on;
configure controlfile autobackup format for device type disk to '${BKUP_LOC}/%d_%F_ctl.bak';
backup full database format '${BKUP_LOC}/%d_%U.bak' tag rman_nocat_${ORACLE_SID} plus archivelog delete input tag rman_nocat_${ORACLE_SID} ;
EOF


echo "RMan Backup List Report -------------------------------------------------" >> $OUTFILE
echo "-------------------------------------------------------------------------" >> $OUTFILE
${ORACLE_HOME}/bin/rman target=/ nocatalog <<EOF >> $OUTFILE
list recoverable backup;
EOF


echo "Searched for Errors, Sent Error Log, (if exists) and Report---------------------------" >> $OUTFILE
#Search for Errors in Backup, Email if Any Found
cat $OUTFILE | grep "RMAN-" > $ERR_LOG
if [ -s $ERR_LOG ]
then
# mailx -s "Backup Failed for $ORACLE_SID on `hostname`" $DBA_PG 
# mailx -s "Backup Failed for $ORACLE_SID on `hostname`" $DBA < $ERR_LOG
 ${COMMONBIN}/notify.ksh "$PROGNAME" "$ORACLE_SID" "SEVERE" "CRITICAL" "Backup FAILED for $ORACLE_SID"
  ${COMMONBIN}/notify.ksh "$PROGNAME" "$ORACLE_SID" "SEVERE" "INFO" "Backup FAILED for $ORACLE_SID" "$ERR_LOG"
fi

# Move Backup file to Snap Directory
echo "Copying files to $SS_DIR.  Files will have $SFX suffix." >> $OUTFILE
echo "Files backed up are:" >> $OUTFILE

for dbf in `ls $BKUP_LOC`
do
  echo "  $dbf"  >> $OUTFILE
  echo "  $dbf"
#  cp -R ${BKUP_LOC}/$dbf $SS_DIR/$dbf.$SFX
done

#Mail Standard Report to DBA Group
#   mailx -s "RMAN Report Only for $ORACLE_SID on `hostname`" $DBA < $OUTFILE
    ${COMMONBIN}/notify.ksh "$PROGNAME" "$ORACLE_SID" "REPORT ONLY" "INFO" "RMAN Report Only for $ORACLE_SID" "$OUTFILE"

#Remove Error Search File and Archive Log Files
rm -f $ERR_LOG
rm -f $OUTFILE

