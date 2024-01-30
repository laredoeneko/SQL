###################################################
# Script to get a session information	
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	03-02-11	    #   #   # #   # 
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
echo "This script Gets a datbase SESSION Information ..."
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
# SQLPLUS: Getting Session Info:
#################################
#Variables
echo Enter the Username:
echo "================="
read USERNAME
	if [ -z "${USERNAME}" ]
	 then

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set feedback off linesize 180 pages 1000
col "UNIX PID" for a8
col username for a16
col osuser for a12
col machine for a21
col module for a43
select p.spid "UNIX PID",s.USERNAME,s.OSUSER,s.MACHINE,s.MODULE,s.PREV_SQL_ID,s.SQL_ID CURR_SQL_ID
from v\$session s,v\$process p
where s.USERNAME like upper ('%$USERNAME%')
and p.addr = s.paddr
order by 2,3;
EOF
	else

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set feedback off linesize 180 pages 1000
col "UNIX PID" for a8
col username for a16
col osuser for a12
col machine for a21
col module for a43
col "Previous SQL" for a140
col "Current SQL" for a140
Prompt Previous SQL Statement:
prompt -----------------------

select p.spid "UNIX PID",s.USERNAME,s.OSUSER,s.MACHINE,s.MODULE,s.SQL_ID,s.PREV_SQL_ID,q.SQL_FULLTEXT "Previous SQL"
from v\$session s,v\$process p,v\$sql q
where s.USERNAME like upper ('%$USERNAME%')
and p.addr = s.paddr
and q.sql_id=s.PREV_SQL_ID;

prompt
Prompt Current Running SQL Statement:
prompt ------------------------------

select s.SQL_ID,q.SQL_FULLTEXT "Current SQL"
from v\$process p,v\$session s ,v\$sql q
where s.USERNAME like upper ('%$USERNAME%')
and p.addr = s.paddr 
and q.sql_id=s.sql_id;
EOF
	fi

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
