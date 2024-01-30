###################################################
# Script to unlock locked users		#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	24-12-11	    #   #   # #   # 
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
echo "=========================================="
echo "This script UNLOCKS locked database users."
echo "=========================================="
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
# SQLPLUS: Unlock An Oracle User:
#################################
# Variables
echo 
echo Please enter the Username:
echo "========================="
read USERNAME
echo "Searching ..."
sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col USERNAME for a35
col account_status for a23
select username,account_status,profile,LOCK_DATE,EXPIRY_DATE from dba_users where username like upper ('%$USERNAME%');
/*
DECLARE
CURSOR c1 IS
select username,account_status,profile,LOCK_DATE,EXPIRY_DATE from dba_users where username like upper ('%$USERNAME%') and account_status!='OPEN';
BEGIN
FOR u IN c1 LOOP
--dbms_output.put_line('SQL:');
dbms_output.put_line('ALTER USER '||u.username||' ACCOUNT UNLOCK;');
end loop;
end;
/
*/
--select 'ALTER USER '||username||' ACCOUNT UNLOCK;' UNLOCK_ACCOUNT from dba_users where username like upper ('%$USERNAME%') and account_status not in ('OPEN','EXPIRED(GRACE)');
EOF

# Unlock Execution part:
echo 
echo Please Confirm The Username you want to Unlock: [${USERNAME}]
echo "=============================================="
while read USERNAME2
 do
        if [ -z ${USERNAME2} ]
         then
          USERNAME2=${USERNAME}
          echo Unlocking User: \"${USERNAME}\"
          sleep 1
	  break
         else
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('$USERNAME2');
EOF
)
VAL22=`echo $VAL11| awk '{print $NF}'`
                if [ ${VAL22} -eq 0 ]
                 then
                  echo
                  echo "ERROR: USER [${USERNAME2}] IS NOT EXIST ON DATABASE [$ORACLE_SID] !"
                  echo; echo "Enter the Username you want to UNLOCK:"
                        echo "====================================="
                 else
                  break
                fi
        fi
 done
VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
ALTER user $USERNAME2 ACCOUNT UNLOCK;
EOF
)
VAL2=`echo $VAL1| grep "User altered"`
		if [ -z "${VAL2}" ]
		 then
		  echo User \"${USERNAME2}\" Is Not Exist!
		  exit
		else
		  echo
		  echo User ${USERNAME2} Unlocked Successfully.
		  echo
		  echo "Enter a New Password for User [${USERNAME2}]: <To Skip Press [Ctrl+c]>"
		  echo "============================="
		  read PASS1

	if [ -z $PASS1 ]
	then
	 # Setting new password:
	 PASSHALF=`date '+%s'`
	 echo The Password will be RESET to: ${USERNAME2}\#${PASSHALF}
	 sleep 1
	 PASS1=${USERNAME2}\#${PASSHALF}
	fi

VAL3=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
Alter user $USERNAME2 identified by "$PASS1";
EOF
)
VAL4=`echo $VAL3| grep "User altered"`
                if [ -z "${VAL4}" ]
                 then
		  echo 
                  echo Password Failed to Reset!
		  echo $VAL3 | perl -lpe'$_ = reverse' | cut -c-53 | perl -lpe'$_ = reverse'
                  exit
                 else
                  echo 
                  echo The Password For User \"${USERNAME2}\" Has Been Reset Successfully.

		fi
	        fi
###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
