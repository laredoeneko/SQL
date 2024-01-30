###################################################
# Script to Check Scheduled Jobs.	#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	02-02-10	    #   #   # #   # 
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
echo "=============================================="
echo "This script Checks ALL database Scheduled Jobs ..."
echo "=============================================="
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

#################################
# SQLPLUS: Check Scheduled Jobs:
#################################
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 157
PROMPT DBMS_JOBS:
PROMPT -----------

select job,schema_user,failures,LAST_DATE LAST_RUN,NEXT_DATE NEXT_RUN from dba_jobs;

PROMPT 
PROMPT DBMS_SCHEDULER:
PROMPT ----------------

col OWNER for a10
col STATE for a11
col FAILURE_COUNT for 999 heading 'Fail'
col LAST_START_DATE for a40
select OWNER,JOB_NAME,ENABLED,STATE,FAILURE_COUNT,to_char(LAST_START_DATE,'DD-Mon-YYYY hh24:mi:ss')LAST_RUN,to_char(NEXT_RUN_DATE,'DD-Mon-YYYY hh24:mi:ss')NEXT_RUN from dba_scheduler_jobs order by ENABLED,STATE;
EOF

echo "Enter the JOB_NAME/ID to get it's details:"
echo "========================================="
read JOB_NAME
# Exit if No Input:
	if [ -z "${JOB_NAME}" ]
	 then
	  exit
	fi

# Check if the variable is Number query DBMS_JOBS:
	if [ -z "${JOB_NAME##[0-9]*}" ]
	 then
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
col what for a157
Select what from dba_jobs where job='$JOB_NAME';
EOF

# If variable is Characters query dba_scheduler_jobs:

	else
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
Select COMMENTS,JOB_ACTION from dba_scheduler_jobs where JOB_NAME='$JOB_NAME';
EOF
	fi
###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
