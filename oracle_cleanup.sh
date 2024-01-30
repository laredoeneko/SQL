###################################################
# This script Backup & Delete the database logs.
# To be run by ORACLE user		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	03-06-2013	    #   #   # #   # 
# Modified:	02-07-2013
#		14-01-2014	     
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
echo "==============================================="
echo "This script Backs up & Delete the database logs ..."
echo "==============================================="
echo
sleep 1

#############################
# Listing Available Instances:
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
    echo "Select the Instance You Want To Backup & Delete It's Logs:"
    echo "----------------------------------------------------------"
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|grep -v ASM|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
	if [ -z "${REPLY##[0-9]*}" ]
	 then
          export ORACLE_SID=$DB_ID
	  echo Selected Instance:
	  echo $DB_ID
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

###########################
# Getting DB_NAME:
###########################
VAL1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT name from v\$database
exit;
EOF
)
# Getting DB_NAME in Uppercase & Lowercase:
DB_NAME_UPPER=`echo $VAL1| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "$DB_NAME_UPPER" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER

# DB_NAME is Uppercase or Lowercase?:

     if [ -f $ORACLE_HOME/diagnostics/${DB_NAME_UPPER} ]
        then
                DB_NAME=$DB_NAME_UPPER
		export DB_NAME
        else
                DB_NAME=$DB_NAME_LOWER
                export DB_NAME
     fi

##########################
# Getting ORACLE_BASE:
##########################
# Get ORACLE_BASE from user's profile if not set:

if [ -z "${ORACLE_BASE}" ]
 then
   ORACLE_BASE=`grep 'ORACLE_BASE=\/' $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
   export ORACLE_BASE
fi

###########################
# Getting ALERTLOG path:
###########################
VAL_DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
BDUMP=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
export BDUMP
DUMP=`echo ${BDUMP} | sed -s 's/\/trace//g'`
export DUMP
CDUMP=${DUMP}/cdump
export CDUMP
ALERTDB=${BDUMP}/alert_${ORACLE_SID}.log
export ALERTDB

###########
# Variables: 
###########
echo ""
echo "Please Enter The Full Path of Backup Location: [/tmp]"
echo "============================================="
read LOC1
# Check if No location provided:
	if [ -z ${LOC1} ]; then
          LOC1=/tmp
          export LOC1
          echo "Database Logs Backup Will Be Saved Under: ${LOC1}"
	 else
	  export LOC1
	  echo "Database Logs Backup Will Be Saved Under: ${LOC1}"
	fi
# Check if provided location path is not exist:
        if [ ! -d ${LOC1} ]; then
	  echo ""
	  echo "Location Path \"${LOC1}\" is NOT EXIST!"
          echo "Script Terminated!"
	  exit
        fi

	
# Setting a Verifier:
echo ""
echo "Are You SURE to Backup & Remove the logs of Database \"${ORACLE_SID}\" and it's Listener: [Y|N] N"
echo "==============================================================================="
while read ANS
  do
        case $ANS in
        y|Y|yes|YES|Yes) echo;echo "Backing up & removing DB & Listener Logs ...";sleep 1;echo;break ;;
        ""|n|N|NO|no|No) echo; echo "Script Terminated !";echo; exit; break ;;
        *) echo;echo "Please enter a VALID answer [Y|N]" ;;
        esac
  done

BKP_BASE=${LOC1}
export BKP_BASE
BKP_LOC_DB=$BKP_BASE/${ORACLE_SID}_logs/`uname -n`/`date '+%b_%Y'`
export BKP_LOC_DB
DB=${DB_NAME}
export DB
INS=${ORACLE_SID}
export INS
LSNR_NAME=LISTENER_${ORACLE_SID}
export LSNR_NAME

# Creating folder holds the logs:
mkdir -p ${BKP_LOC_DB}

# Backup & Delete DB logs:
#########################
        if [ ! -d ${DUMP} ]
         then
          echo "The Parent Log Dump location cannot be Found!"
	  exit
        fi

tail -1000 ${ALERTDB} > $BKP_LOC_DB/alert_$INS.log.keep
gzip -9 $BDUMP/alert_$INS.log 
mv $BDUMP/alert_$INS.log.gz   $BKP_LOC_DB
mv $BKP_LOC_DB/alert_$INS.log.keep $BDUMP/alert_$INS.log
tar cvfP $BKP_LOC_DB/$INS-dump-logs.tar   ${DUMP}
gzip -9 $BKP_LOC_DB/$INS-dump-logs.tar 

# Delete DB logs older than 5 days:
find ${BDUMP}         -type f -mtime +5 -exec rm {} \;
find ${DUMP}/alert    -type f -mtime +5 -exec rm {} \;
find ${DUMP}/incident -type f -mtime +5 -exec rm {} \;
find ${CDUMP}         -type f -mtime +5 -exec rm {} \;

# Backup & Delete listener's logs:
#################################
LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep -i ${LSNR_NAME}|awk '{print $(NF-2)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
export LISTENER_HOME
LISTENER_NAME=`ps -ef|grep -v grep|grep tnslsnr|grep -i ${LSNR_NAME}|awk '{print $(NF-1)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
export LISTENER_NAME
TNS_ADMIN=${LISTENER_HOME}/network/admin; export TNS_ADMIN
export TNS_ADMIN
LISTENER_LOGDIR=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME} |grep "Listener Log File"| awk '{print $NF}'| sed -e 's/\/alert\/log.xml//g'`
export LISTENER_LOGDIR
LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
export LISTENER_LOG

# Determine if the listener name is in Upper/Lower case:
        if [ -f ${LISTENER_LOG} ]
         then
          # Listner_name is Uppercase:
          LISTENER_NAME=$( echo ${LISTENER_NAME} | perl -lpe'$_ = reverse' |perl -lpe'$_ = reverse' )
          LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
         else
          # Listener_name is Lowercase:
          LISTENER_NAME=$( echo "${LISTENER_NAME}" | tr -s  '[:upper:]' '[:lower:]' )
          LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
        fi

	if [ ! -d ${LISTENER_LOGDIR} ]
	 then
          echo 'Listener Logs Location Cannot be Found!'
        fi
tar cvfP $BKP_LOC_DB/${LISTENER_NAME}_trace.tar  ${LISTENER_LOGDIR}/trace
tar cvfP $BKP_LOC_DB/${LISTENER_NAME}_alert.tar  ${LISTENER_LOGDIR}/alert
gzip -9 $BKP_LOC_DB/${LISTENER_NAME}_trace.tar  $BKP_LOC_DB/${LISTENER_NAME}_alert.tar
tail -10000 ${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log > $BKP_LOC_DB/${LISTENER_NAME}.log.keep
find ${LISTENER_LOGDIR}/trace -type f -exec rm {} \;
find ${LISTENER_LOGDIR}/alert -type f -exec rm {} \;
mv $BKP_LOC_DB/${LISTENER_NAME}.log.keep   ${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log

# Backup & Delete AUDIT logs:
############################
# Getting Audit Files Location:
##############################
VAL_AUD=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='audit_file_dest';
exit;
EOF
)
AUD_LOC=`echo ${VAL_AUD} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
export AUD_LOC

        if [ ! -d ${AUD_LOC} ]
         then
          echo 'Audit Files Location Cannot be Found!'
	  exit
        fi
tar cvfP $BKP_LOC_DB/audit_files.tar ${AUD_LOC}/${ORACLE_SID}*
gzip -9 $BKP_LOC_DB/audit_files.tar

# Delete Audit logs older than 5 days
find ${AUD_LOC}/${ORACLE_SID}* -type f -mtime +5 -exec rm {} \;

echo ""
echo "The Last 5 Days Logs Have Been Kept."
echo "Oracle_cleanup Script is Done."
echo

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# PLEASE VISIT MY BLOG: http://dba-tips.blogspot.com
