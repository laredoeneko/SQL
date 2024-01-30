###################################################
# This script shows object's DDL statement.
# To be run by ORACLE user		
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	01-02-2013	    #   #   # #   # 
#
#
#
###################################################

#############
# Description:
#############
echo
echo "========================================="
echo "This script shows object's DDL statement."
echo "========================================="
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
# SQLPLUS Section:
###########################
# PROMPT FOR VARIABLES:
######################
echo ""
echo "Please Enter the OBJECT OWNER:"
echo "============================="
while read OBJECT_OWNER
 do
        if [ -z ${OBJECT_OWNER} ]
         then
          echo
          echo "Enter the OBJECT OWNER:"
          echo "======================"
         else
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('$OBJECT_OWNER');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                if [ ${VAL22} -eq 0 ]
                 then
                  echo
                  echo "ERROR: USER [${OBJECT_OWNER}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
                  echo; echo "Enter a VALID OBJECT OWNER:"
                        echo "=========================="
                 else
                  break
                fi
        fi
 done

echo "Please Enter the OBJECT NAME:"
echo "============================"
while read OBJECT_NAME
 do
        if [ -z ${OBJECT_NAME} ]
         then
          echo
          echo "Enter the OBJECT NAME:"
          echo "====================="
         else
VAL3=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_OBJECTS WHERE OWNER=upper('$OBJECT_OWNER') AND OBJECT_NAME=UPPER('$OBJECT_NAME');
EOF
)
VAL4=`echo $VAL3| awk '{print $NF}'`
                if [ ${VAL4} -eq 0 ]
                 then
                  echo
                  echo "ERROR: OBJECT [${OBJECT_NAME}] IS NOT EXIST UNDER SCHEMA [$OBJECT_OWNER] !"
                  echo; echo "Enter a VALID OBJECT NAME:"
                        echo "========================="
                 else
                  break
                fi
        fi
 done

# Getting The Object Type:
#########################
VAL7=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set heading off echo off feedback off
SELECT object_type from dba_objects where owner=upper('$OBJECT_OWNER') and object_name=upper('$OBJECT_NAME');
EOF
)
OBJECT_TYPE=`echo $VAL7| awk '{print $(NF)}'`

		case $OBJECT_TYPE in
                  # Correct the value of BODY to PACKAGE BODY:
                  "BODY") OBJECT_TYPE="PACKAGE";;
                esac

# Execution of SQL Statement:
############################
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 linesize 157 heading off
PROMPT RETRIEVING DDL STATEMENT FOR $OBJECT_TYPE: [$OBJECT_OWNER.$OBJECT_NAME] ...
PROMPT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
set long 10000000
col aa for a157
SELECT dbms_metadata.get_ddl(upper('$OBJECT_TYPE'),upper('$OBJECT_NAME'),upper('$OBJECT_OWNER'))||';'aa FROM dual;
EOF

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
