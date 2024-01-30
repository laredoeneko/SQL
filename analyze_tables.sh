###################################################
# This script gathers object stats using ANALYZE..
# To be run by ORACLE user		
#					
# Author:	ABD-ELGAWAD OTHMAN    
# Modified:	Mahmmoud ADEL
#		29-01-2014
#		Script Environment Globalization.
#
###################################################

#############
# Description:
#############
echo
echo "======================================================="
echo "This script Gathers object stats using ANALYZE command."
echo "======================================================="
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
# SQLPLUS Section:
###########################
# PROMPT FOR VARIABLES:
######################
echo
echo "Please Enter the location where you want keep staging script: [Default is: ${USR_ORA_HOME}]"
echo "============================================================"
read LOC1
	if [ -z ${LOC1} ]; then
	 LOC1=${USR_ORA_HOME}
         echo "Location has been set to: [${LOC1}]"
	fi
        if [ ! -d ${LOC1} ]; then
         echo "The location you entered is NOT EXIST."
         echo "Location has been set to: ${USR_ORA_HOME}"
	 echo ""
         LOC1=${USR_ORA_HOME}
        fi

cd ${LOC1}
echo
echo "Enter the SCHEMA NAME you want to ANALYZE it's tables:"
echo "====================================================="
while read SCHEMA_NAME
 do
        if [ -z ${SCHEMA_NAME} ]
         then
          echo
          echo "Enter the SCHEMA NAME:"
          echo "====================="
         else
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('$SCHEMA_NAME');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                if [ ${VAL22} -eq 0 ]
                 then
                  echo
                  echo "ERROR: USER [${SCHEMA_NAME}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
                  echo; echo "Enter the SCHEMA NAME:"
                  echo "====================="
                 else
                  break
                fi
        fi
 done

# Execution of SQL Statement:
############################

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
SET LINESIZE 157
SET PAGESIZE 5000
SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF
spool analyze.sql

select 'spool analyze.log' from dual
/ 
select 'Analyze table '||owner||'.'||table_name||' compute statistics  for table for all indexes for all indexed columns;'
from dba_tables
where owner =upper('$SCHEMA_NAME')
/
select  'Analyze table '||table_owner||'.' ||
table_name||' partition ('||partition_name || ') COMPUTE STATISTICS for table  for all local indexes for all indexed columns; '
from dba_tab_partitions
where table_owner =upper('$SCHEMA_NAME')
/
select 'spool off' from dual
/
select 'exit' from dual
/
spool off
EOF

	if [ -f ${LOC1}/analyze.sql ]
	 then 
	  echo ""
	  echo "Do you want to ANALYZE ALL ${SCHEMA_NAME} TABLES? [Y|N] [Y]"
	  echo "================================================"
 	  while read ANS
 		do
         		case $ANS in
                 	""|y|Y|yes|YES|Yes) echo; echo "START ANAYLZING TABLES ...";sleep 1
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
@analyze.sql
EOF
			echo "The LOGFILE Location: ${LOC1}/analyze.log";echo
			break ;;
                 	n|N|no|NO|No) echo;echo "To ANALYZE Tables for Schema ${SCHEMA_NAME} run script: ${LOC1}/analyze.sql";exit;break ;;
                 	*) echo "Please enter a VALID answer [Y|N]" ;;
         		esac
 		done
	 else
	  echo "ANALYZE script ${LOC1}/analyze.sql is NOT EXIST !"
	fi

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
