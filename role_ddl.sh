###################################################
# This script show the user details (Creation Stmt)		
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
echo "================================================"
echo "This script shows the user's CREATION STATEMENT."
echo "================================================"
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

###############################################
# SQLPLUS: Get the Creation statment for a ROLE:
###############################################
# Variables
echo 
echo Please enter the ROLE NAME:
echo "========================="
while read ROLE
 do
        case ${ROLE} in
          "")echo
             echo "Enter the ROLE NAME:"
             echo "===================";;
	  public|PUBLIC|Public)
SPOOL_FILE="${USR_ORA_HOME}"/"${ROLE}"_creation_stmt.log
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0
set echo off heading off feedback off
spool '$SPOOL_FILE'
select 'GRANT '||GRANTED_ROLE||' TO '||GRANTEE||';' from dba_role_privs where grantee= 'PUBLIC'
UNION
select 'GRANT '||PRIVILEGE||' TO '||GRANTEE||';' from dba_sys_privs where grantee= 'PUBLIC'
UNION
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||';' 
from DBA_TAB_PRIVS where GRANTEE='PUBLIC' and OWNER not in ('SYS','SYSTEM','WMSYS','XDB','DBSNMP','OLAPSYS','ORDSYS');
spool off
EOF
        if [ -f "${SPOOL_FILE}" ]
         then
          echo;echo "The Creation Statement has been spooled in: ${SPOOL_FILE}"
          echo
        fi
	  exit;break ;;
	  *) 
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_ROLES WHERE ROLE=upper('$ROLE');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
			case ${VAL22} in
			0) echo;echo "ERROR: ROLE [${ROLE}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
			   echo; echo "Enter the ROLE NAME:";echo "===================" ;;
			*) break;;
			esac
	  esac
 done

SPOOL_FILE="${USR_ORA_HOME}"/"${ROLE}"_creation_stmt.log
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0
set echo off heading off feedback off
spool '$SPOOL_FILE'
SELECT 'CREATE ROLE ' || ROLE ||';' FROM DBA_ROLES WHERE ROLE=UPPER('$ROLE')
UNION
select 'GRANT '||GRANTED_ROLE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted Roles"
from dba_role_privs where grantee= upper('$ROLE')
UNION
select 'GRANT '||PRIVILEGE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted System Privileges"
from dba_sys_privs where grantee= upper('$ROLE')
UNION
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||case when GRANTABLE='YES' then ' WITH GRANT OPTION;' else ';' end "Granted Object Privileges"
from DBA_TAB_PRIVS where GRANTEE=upper('$ROLE');
spool off
EOF
	if [ -f "${SPOOL_FILE}" ]
	 then
	  echo;echo "The Creation Statement has been spooled in: ${SPOOL_FILE}"
	  echo
	fi
###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
