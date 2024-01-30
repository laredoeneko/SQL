###################################################
# This script shows the FAILED LOGIN ATTEMPTS.
# To be run by ORACLE user		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	25-02-2013	    #   #   # #   # 
#
###################################################

#############
# Description:
#############
echo
echo "=================================================================="
echo "This script shows the FAILED LOGIN ATTEMPTS in the last n of days."
echo "=================================================================="
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
    echo "Select the Instance You Want To Run this script against:"
    echo "-------------------------------------------------------"
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
# SQLPLUS Section:
###########################
# PROMPT FOR VARIABLES:
######################

echo "How many days back you want to show FAILED LOGIN ATTEMPTS to the Database? [Default 1]"
while read NUM_DAYS
        do
                case $NUM_DAYS in
                  # NO VALUE PROVIDED:
                  "") NUM_DAYS=1;echo;echo "Retreiving FAILED LOGIN ATTEMPTS data in the last 24 Hours ... [Please Wait]";break ;;
                  # A NON NUMERIC VALUE PROVIDED:
                  *[!0-9]*) echo "Please enter a Valid NUMERIC Value:" ;;
                  *) echo;echo "Retreiving the FAILED LOGIN ATTEMPTS in the last [${NUM_DAYS}] Days ... [Please Wait]";break ;;
                esac
        done

# Execution of SQL Statement:
############################

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize 157
col OS_USERNAME for a15
col USERNAME for a15
col TERMINAL for a15
col ACTION_NAME for a20
col TIMESTAMP for a21
col USERHOST for a21
select /*+ parallel 2 */ to_char (EXTENDED_TIMESTAMP,'DD-MON-YYYY HH24:MI:SS') TIMESTAMP,OS_USERNAME,USERNAME,TERMINAL,USERHOST,ACTION_NAME
from DBA_AUDIT_SESSION
where returncode = 1017
and timestamp > (sysdate -$NUM_DAYS)
order by 1;
EOF

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
