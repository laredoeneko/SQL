###################################################
# Database COLD Backup Script.	
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	22-12-13	    #   #   # #   #  
# Modified:	23-12-13
#		Handled non exist logs (first run)
#
###################################################

#############
# Description:
#############
echo
echo "==============================================="
echo "This script Takes a COLD BACKUP for a database."
echo "==============================================="
echo
sleep 1

#############################
# Listing Available Databases:
#############################

# Count Instance Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|grep -v ASM|wc -l )

# Exit if No DBs are running:
if [ $INS_COUNT -eq 0 ]
 then
   echo No Database Running !
   exit
fi

# If there is ONLY one DB set it as default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|grep -v ASM|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo Select the ORACLE_SID:
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|grep -v ASM|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
          echo Selected Instance:
          echo
          echo "********"
          echo $DB_ID
          echo "********"
          echo
          break
         else
          export ORACLE_SID=${REPLY}
          break
        fi
     done

fi
# Exit if the user selected a Non Listed Number:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "You've Entered An INVALID ORACLE_SID"
          exit
        fi

###########################
# Getting ORACLE_HOME
###########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|grep -v ASM|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

## If OS is Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi

## If oratab is not exist, or ORACLE_SID not added to oratab, find ORACLE_HOME in user's profile:
if [ -z "${ORACLE_HOME}" ]
 then
  ORACLE_HOME=`grep 'ORACLE_HOME=\/' $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
fi

##########################################
# Exit if the user is not the Oracle Owner:
##########################################
CURR_USER=`whoami`
        if [ ${ORA_USER} != ${CURR_USER} ]; then
          echo ""
          echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
          echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
          echo "Script Terminated!"
          exit
        fi

##################################
# Creating Backup & Restore Script:
##################################
echo "Enter the Backup location: [Full Path]"
while read LOC1
        do
                /bin/mkdir -p ${LOC1}/COLDBACKUP_${ORACLE_SID}/`date '+%F'`
                LOC2=${LOC1}/COLDBACKUP_${ORACLE_SID}/`date '+%F'`

                if [ ! -d "${LOC2}" ]; then
                 echo "Provided Backup Location is NOT Exist/Writable !"
                 echo
                 echo "Please Provide a VALID Backup Location."
                else
		 echo
		 sleep 1
		 echo "Backup Location Validated."
		 echo
                 break
                fi
        done
BKPSCRIPT=${LOC2}/Cold_Backup.sh
RSTSCRIPT=${LOC2}/Restore_Cold_Backup.sh
BKPSCRIPTLOG=${LOC2}/Cold_Backup.log
RSTSCRIPTLOG=${LOC2}/Restore_Cold_Backup.log

# Creating the Cold Backup script:
echo
echo "Creating Cold Backup and Cold Restore Scripts ..."
sleep 1
cd ${LOC2}
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 
set termout off echo off feedback off;
spool Cold_Backup.sh
PROMPT echo "Shutting Down Database $ORACLE_SID ... [Ctrl+c to CANCEL]"
PROMPT echo "[5]"
PROMPT sleep 1
PROMPT echo "[4]"
PROMPT sleep 1
PROMPT echo "[3]"
PROMPT sleep 1
PROMPT echo "[2]"
PROMPT sleep 1
PROMPT echo "[1]"
PROMPT sleep 1
PROMPT echo "SHUTTING DOWN NOW ..."
PROMPT sleep 3
PROMPT echo ""
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT shutdown immediate;
PROMPT EOF
PROMPT echo "Database SHUTDOWN SUCCESFULLY."
PROMPT sleep 1
PROMPT echo "Starting DB FILES copy ..."
PROMPT echo "Keep this session OPEN, Once the COLD BACKUP is DONE, it will return you back to the PROMPT."
PROMPT sleep 1
PROMPT
select 'cp -vpf '||name||' $LOC2' from v\$controlfile
union
select 'cp -vpf '||name||' $LOC2'  from v\$datafile
union
select 'cp -vpf '||member||' $LOC2'  from v\$logfile;
PROMPT echo "Please Note that TEMP DATAFILES have NOT been Backed up."
PROMPT echo "Database Cold Backup is DONE."
PROMPT echo "You can STARTUP Database $ORACLE_SID."
spool off
EOF
chmod 700 ${BKPSCRIPT}
# Creating the Restore Script:
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 termout off echo off feedback off;
spool Restore_Cold_Backup.sh
PROMPT echo ""
PROMPT echo "Restoring Database $ORACLE_SID from Cold Backup ..."
PROMPT sleep 1
PROMPT echo ""
PROMPT echo "ARE YOU SURE YOU WANT TO RESTORE DATABASE $ORACLE_SID ? [Y|N] [N]"
PROMPT while read ANS
PROMPT 	do
PROMPT		case \$ANS in
PROMPT                  y|Y|yes|YES|Yes) echo "RESTORATION PROCEDURE STARTED ...";break ;;;
PROMPT                  ""|n|N|no|NO|No) echo "Script Terminated.";exit;break ;;;
PROMPT                  *) echo "Please enter a VALID answer [Y|N]" ;;;
PROMPT          esac
PROMPT 	done
PROMPT ORACLE_SID=$ORACLE_SID
PROMPT export ORACLE_SID
PROMPT echo "Shutting Down Database $ORACLE_SID ... [Ctrl+c to CANCEL]"
PROMPT echo "[5]"
PROMPT sleep 1
PROMPT echo "[4]"
PROMPT sleep 1
PROMPT echo "[3]"
PROMPT sleep 1
PROMPT echo "[2]"
PROMPT sleep 1
PROMPT echo "[1]"
PROMPT sleep 1
PROMPT echo "SHUTTING DOWN NOW ..."
PROMPT sleep 3
PROMPT echo ""
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT shutdown immediate;
PROMPT EOF
PROMPT 
PROMPT echo "Restoration Job Started ..."
PROMPT echo ""
select 'cp -vpf $LOC2/'||SUBSTR(name, INSTR(name,'/', -1,1)+1)||'  '||name from v\$controlfile
union
select 'cp -vpf $LOC2/'||SUBSTR(name, INSTR(name,'/', -1,1)+1)||'  '||name from v\$datafile
union
select 'cp -vpf $LOC2/'||SUBSTR(member, INSTR(member,'/', -1,1)+1)||'  '||member from v\$logfile;
PROMPT ${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
PROMPT startup
PROMPT PROMPT
PROMPT PROMPT Adding TEMPFILES TO TEMPORARY TABLSEPACES...
select 'ALTER DATABASE TEMPFILE '''||file_name||''' DROP;' from dba_temp_files;
select 'ALTER TABLESPACE '||tablespace_name||' ADD TEMPFILE '''||file_name||''' REUSE;' from dba_temp_files;
PROMPT EOF
PROMPT echo "Database $ORACLE_SID Restored Successfully."
PROMPT echo "Database $ORACLE_SID is UP."
spool off
EOF

chmod 700 ${RSTSCRIPT}

	if [ ! -f "${BKPSCRIPT}" ]; then
	  echo ""
	  echo "Backup & Restore Scripts CANNOT be Created."
	  echo "The Script Failed to run Cold Backup job !"
	  echo "Please check the Backup Location permissions."
	  exit
	fi
	
echo "--------------------------------------------------------"
echo "Backup & Restore Scripts have been Created Successfully."
echo
echo
sleep 1

##############################
# Executing Cold Backup Script:
##############################
# Checking if more than one instance is running: [RAC]
echo "Checking Other OPEN instances [RAC]."
sleep 1
VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set heading off echo off feedback off termout off
select count(*) from gv\$instance;
EOF
)
VAL2=`echo $VAL1 | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
                if [ "${VAL2}" -gt 1 ]
                 then
                  echo
		  echo "WARNING:"
		  echo "-------"
                  echo "Please SHUTDOWN ALL other RAC INSTANCES EXCEPT the one on the CURRENT Node."
		  echo "Then Re-run This Script Again."
                  echo ""
                  exit
                fi
echo
echo "VERIFIED: Only ONE INSTANCE is RUNNING for Database [${ORACLE_SID}]."
echo
sleep 1
echo "Running "Cold Backup" Script:"
sleep 1
echo "ARE YOU SURE YOU WANT TO SHUTDOWN DATABASE [${ORACLE_SID}] AND START THE COLD BACKUP JOB? [Y|N] [N]"
while read ANS
 do
         case $ANS in
                 y|Y|yes|YES|Yes) echo "RESTORATION PROCEDURE STARTED ...";break ;;
                 ""|n|N|no|NO|No) echo "Script Terminated.";exit;break ;;
                 *) echo "Please enter a VALID answer [Y|N]" ;;
         esac
 done

echo "Database [${ORACLE_SID}] Will SHUTDOWN within [5 Seconds] ... [To CANCEL press [Ctrl+c]]"
echo "[5]"
sleep 1
echo "[4]"
sleep 1
echo "[3]"
sleep 1
echo "[2]"
sleep 1
echo "[1]"
sleep 1
echo ""
echo "Shutting Down Database [${ORACLE_SID}] ..."
echo "Backup Files will be Copied Under: [${LOC2}] ..."
echo "DON'T CLOSE THIS SESSION, Once the script FINISH it will ASK you to STARTUP the Database."
sleep 1
. ${BKPSCRIPT} > ${BKPSCRIPTLOG}

echo ""
echo "The COLD BACKUP Completed Successfully."
echo "Please Note that TEMPORARY DATAFILES are NOT Backed up."
sleep 2
echo
echo "Do You Want to STARTUP Database [${ORACLE_SID}]? [Y|N] [Y]"
while read ANS
 do
         case $ANS in
                 ""|y|Y|yes|YES|Yes) echo "STARTING UP DATABASE [${ORACLE_SID}] ..."
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
STARTUP
EOF
echo
echo "COLD BACKUP SCRIPT IS DONE."
echo "To restore this database from the COLD BACKUP, Run Script: ${RSTSCRIPT}"
echo
break ;;
                 n|N|no|NO|No) echo;echo "Script FINISHED."
echo "To restore this database from the COLD BACKUP, Run Script: [${RSTSCRIPT}]"
exit
break ;;
                 *) echo "Please enter a VALID answer [Y|N]" ;;
         esac
 done

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# PLEASE VISIT MY BLOG: http://dba-tips.blogspot.com
