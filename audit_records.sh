###################################################
# This script shows AUDIT records for a user.
# To be run by ORACLE user		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	25-04-2013	    #   #   # #   # 
#
###################################################

#############################
# Listing Available Instances:
#############################

echo
echo "=================================================================="
echo "This Script Retreives AUDIT data for a user if auditing is enabled."
echo "=================================================================="
echo
sleep 1
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
    echo "Select the Instance You Want To Run this script Against:"
    echo "-------------------------------------------------------"
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


###########################
# SQLPLUS Section:
###########################
# PROMPT FOR VARIABLES:
######################

echo
echo "Enter The DB USERNAME:"
echo "====================="
while read DB_USERNAME
        do
                case $DB_USERNAME in
                  # NO VALUE PROVIDED:
                  "") USERNAME_COND=$DB_USERNAME;echo "RETREIVING ALL USERS AUDIT DATA";break ;;
                  *) USERNAME_COND="USERNAME=upper('$DB_USERNAME') and";break ;;
                esac
        done

echo
echo "How [MANY DAYS BACK] you want to retrieve AUDIT data? [Default 1]"
echo "====================================================="
echo "OR: If you want to retrieve AUDIT data on a [SPECIFIC DATE] Enter the DATE in this FORMAT [DD-MM-YYYY] e.g. 25-01-2011"
echo "==  =================================================================================================="
while read NUM_DAYS
        do
                case $NUM_DAYS in
		  # User PROVIDED a NON NUMERIC value:
		  *[!0-9]*) echo;echo "Retreiving AUDIT data for User [${DB_USERNAME}] on [${NUM_DAYS}] ..."
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize 157
col OS_USERNAME for a15
col USERNAME for a15
col EXTENDED_TIMESTAMP for a36
col OWNER for a10
col OBJ_NAME for a25
col USERHOST for a21
col ACTION_NAME for a25
col ACTION_OWNER_OBJECT for a55
select extended_timestamp,OS_USERNAME,USERNAME,USERHOST,ACTION_NAME||'  '||OWNER||' . '||OBJ_NAME ACTION_OWNER_OBJECT
from dba_audit_trail
where $USERNAME_COND
ACTION_NAME not like 'LOGO%'
and TRUNC(extended_timestamp) = TO_DATE('$NUM_DAYS','DD-MM-YYYY') order by EXTENDED_TIMESTAMP;
EOF
exit
		     break ;;
                  # NO VALUE PROVIDED:
                  "") NUM_DAYS=1;echo;echo "Retreiving AUDIT data in the last 24 Hours ... [Please Wait]";break ;;
                  # A NUMERIC VALUE PROVIDED:
                  *) echo;echo "Retreiving AUDIT data in the last ${NUM_DAYS} Days ... [Please Wait]";break ;;
                esac
        done

# Execution of SQL Statement:
############################

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize 157
col OS_USERNAME for a15
col USERNAME for a15
col EXTENDED_TIMESTAMP for a36
col OWNER for a10
col OBJ_NAME for a25
col USERHOST for a21
col ACTION_NAME for a25
col ACTION_OWNER_OBJECT for a55
select extended_timestamp,OS_USERNAME,USERNAME,USERHOST,ACTION_NAME||'  '||OWNER||' . '||OBJ_NAME ACTION_OWNER_OBJECT
from dba_audit_trail 
where $USERNAME_COND
ACTION_NAME not like 'LOGO%' 
and timestamp > SYSDATE-$NUM_DAYS order by EXTENDED_TIMESTAMP;
EOF

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
