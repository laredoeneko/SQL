###################################################
# Script to Enable tracing for an Oracle Session.		
#					#   #     #
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
echo "=================================================="
echo "This script Enables tracing for an Oracle Session."
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

###########################
# Getting UDUMP Location:
###########################
VAL_DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt 
SELECT value from v\$parameter where NAME='user_dump_dest';
exit;
EOF
)
UDUMP=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
export UDUMP

#################################
# SQLPLUS: Unlock An Oracle User:
#################################
# Variables
echo "" 
echo "Please enter the Username you want to trace it's session:"
echo "========================================================"
read USERNAME
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col USERNAME for a35
col MODULE for a30
select username,module,status,sid,serial# from v\$session where username like upper ('%$USERNAME%');
EOF

# Unlock Execution part:
echo 
echo "Enter the User's session SID:"
read SESSIONID
	if [ -z "${SESSIONID}" ]
	 then
	  echo No Value Entered!
	  echo Script Terminated.
	  exit
	fi
echo "Enter the User's session SERIAL#:"
read SESSIONSERIAL
        if [ -z "${SESSIONSERIAL}" ]
         then
          echo "No Value Entered!"
          echo "Script Terminated."
          exit
        fi

VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
begin
dbms_monitor.session_trace_enable (
session_id => '$SESSIONID',
serial_num => '$SESSIONSERIAL',
waits => true,
binds => true
);
end;
/
EOF
)
VAL2=`echo $VAL1| grep "successfully completed"`
		if [ -z "${VAL2}" ]
		 then
		  echo "The Session with Provided SID & SERIAL# is NOT EXIST!"
		  echo "Script Terminated."
		  exit
		fi
echo
echo "TRACING has been ENABLED for session SID:${SESSIONID} / SERIAL#:${SESSIONSERIAL}"
TRACEFILE=`find ${UDUMP}/*_ora_*.trc -mmin -1|tail -1`
sleep 1
echo
echo "Trace File Location:"
echo "-------------------"
        if [ -z ${TRACEFILE} ]
         then
	  echo "Once the session starts doing activities, try find the TRACE FILE using this command:"
	  echo "find ${UDUMP}/*_ora_*.trc -mmin -1"
         else
          echo "Trace File is: ${TRACEFILE}"
        fi
echo
sleep 2
echo "Don't Forget to STOP the Tracing once you Finish Using Script: ~/DBA_BUNDLE1/stop_tracing.sh"
echo

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
