###################################################
# Script to check invalid objects	
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	24-08-11	    #   #   # #   # 
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
echo "====================================================="
echo "This script Checks ALL INVALID OBJECTS on a database."
echo "====================================================="
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

####################
# VARIABLES:
####################
LOC1=${USR_ORA_HOME}
cd ${LOC1}

#################################
# SQLPLUS: Check Invalid Objects
#################################
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' <<EOF
set pages 0
SET LINESIZE 157
SET PAGESIZE 5000
SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF
spool FIX_INVALID_OBJ.sql
select 'alter package '||owner||'.'||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type like '%PACKAGE%' union 
select 'alter type '||owner||'.'||object_name||' compile specification;' from dba_objects where status <> 'VALID' and object_type like '%TYPE%'union
select 'alter '||object_type||' '||owner||'.'||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type not in ('PACKAGE','PACKAGE BODY','SYNONYM','TYPE','TYPE BODY') union
select 'alter public synonym '||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type ='SYNONYM';
spool off
select 'Invalid Objects#: '||count(distinct (owner||object_name)) a from dba_objects where status <> 'VALID';
EOF

# Check if the fix script is exist:
        if [ -f ${LOC1}/FIX_INVALID_OBJ.sql ]
         then
          echo;echo "Do you want to FIX THOSE INVALID Objects? [Y|N] [Y]"
               echo "========================================"
          while read ANS
                do
                        case $ANS in
                        ""|y|Y|yes|YES|Yes) echo;echo "START COMPILING INVALID OBJECTS ...";sleep 1
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set heading off
@FIX_INVALID_OBJ.sql
@FIX_INVALID_OBJ.sql
PROMPT
PROMPT List of remaining INVALID Objects ...
PROMPT ---------------------------------

PROMPT
select 'alter PACKAGE '||owner||'.'||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type like '%PACKAGE%' union
select 'alter TYPE '||owner||'.'||object_name||' compile specification;' from dba_objects where status <> 'VALID' and object_type like '%TYPE%'union
select 'alter '||object_type||' '||owner||'.'||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type not in ('PACKAGE','PACKAGE BODY','SYNONYM','TYPE','TYPE BODY') union
select 'alter public synonym '||object_name||' compile;' from dba_objects where status <> 'VALID' and object_type ='SYNONYM';
select 'Invalid Objects#: '||count(distinct (owner||object_name)) a from dba_objects where status <> 'VALID';
EOF
                        break ;;
                        n|N|no|NO|No) echo;echo "Later To FIX the invalid objects:"
				      echo "run script: ${LOC1}/FIX_INVALID_OBJ.sql"
				      echo "OR run: @?/rdbms/admin/utlrp.sql"
				      echo;exit;break ;;
                        *) echo "Please enter a VALID answer [Y|N]" ;;
                        esac
                done
        fi
###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
