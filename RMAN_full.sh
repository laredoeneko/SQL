###################################################
# This script Take RMAN Backup of a database.		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	24-09-11	    #   #   # #   # 
# Modified:	31-12-13	     
#		Customized the script to run on
#		various environments.
#
#
#
###################################################

#############
# Description:
#############
echo
echo "=================================================="
echo "This script Take a RMAN FULL Backup of a database."
echo "=================================================="
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
    echo Select the ORACLE_SID you want to BACKUP:
    echo ----------------------------------------
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

#################################
# RMAN: Script Creation:
#################################
# Variables
echo 
echo Please enter the Backup Location:
echo "================================"
while read BKPLOC1
	do
		/bin/mkdir -p ${BKPLOC1}/RMANBKP_${ORACLE_SID}/`date '+%F'`
		BKPLOC=${BKPLOC1}/RMANBKP_${ORACLE_SID}/`date '+%F'`

		if [ ! -d "${BKPLOC}" ]; then
        	 echo "Provided Backup Location is NOT Exist/Writable !"
		 echo
	         echo "Please Provide a VALID Backup Location."
		else
		 break
        	fi
	done

echo "--------------------------------------------"
echo "COMPRESSED BACKUP will allocate SMALL space"
echo "but it's slightly SLOWER than NORMAL BACKUP."
echo "--------------------------------------------"
echo
echo "Do you want a COMPRESSED BACKUP? [Y|N]: [Y]"
echo "================================"
while read COMPRESSED
	do
		case $COMPRESSED in  
		  ""|y|Y|yes|YES|Yes) COMPRESSED=" AS COMPRESSED BACKUPSET "; echo "COMPRESSED BACKUP ENABLED.";break ;; 
		  n|N|no|NO|No) COMPRESSED="";break ;; 
		  *) echo "Please enter a VALID answer [Y|N]" ;;
		esac
	done

RMANSCRIPT=${BKPLOC}/RMAN_FULL_${ORACLE_SID}.rman
RMANLOG=${BKPLOC}/rmanlog.`date '+%a'`

echo "run {" > ${RMANSCRIPT}
echo "allocate channel c1 type disk;" >> ${RMANSCRIPT}
echo "allocate channel c2 type disk;" >> ${RMANSCRIPT}
echo "allocate channel c3 type disk;" >> ${RMANSCRIPT}
echo "allocate channel c4 type disk;" >> ${RMANSCRIPT}
echo "CHANGE ARCHIVELOG ALL CROSSCHECK;" >> ${RMANSCRIPT}
echo "DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;" >> ${RMANSCRIPT}
echo "SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';" >> ${RMANSCRIPT}
echo "BACKUP ${COMPRESSED} INCREMENTAL LEVEL=0 FORMAT '$BKPLOC/%d_%t_%s_%p' TAG='FULLBKP'" >> ${RMANSCRIPT}
echo "FILESPERSET 100 DATABASE PLUS ARCHIVELOG;" >> ${RMANSCRIPT}
echo "BACKUP FORMAT '${BKPLOC}/%d_%t_%s_%p' TAG='CONTROL_BKP' CURRENT CONTROLFILE;" >> ${RMANSCRIPT}
echo "SQL \"ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''$BKPLOC/ctrl.trc'' REUSE\";" >> ${RMANSCRIPT}
echo "SQL \"CREATE PFILE=''$BKPLOC/init$ORACLE_SID.ora'' FROM SPFILE\";" >> ${RMANSCRIPT}
echo "release channel c1;" >> ${RMANSCRIPT}
echo "release channel c2;" >> ${RMANSCRIPT}
echo "release channel c3;" >> ${RMANSCRIPT}
echo "release channel c4;" >> ${RMANSCRIPT}
echo "}" >> ${RMANSCRIPT}
echo "RMAN BACKUP SCRIPT CREATED."
echo 
sleep 1
echo "Backup Location is: ${BKPLOC}"
echo
sleep 1
echo "Starting up the RMAN Backup Job ..."
echo
sleep 1
$ORACLE_HOME/bin/rman target / cmdfile=${RMANSCRIPT}
echo
echo "Backup Job is DONE."
echo
echo "Backup Location is: ${BKPLOC}"
echo "Check the LOGFILE: ${RMANLOG}"
echo

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# PLEASE VISIT MY BLOG: http://dba-tips.blogspot.com
