####################################################
# Script to Show Previous & Current Running SQL STMT
# Author:       Mahmmoud ADEL        	#   #     #
# Created:      24-01-11 	      # # # #   ###
# Modified:	24-12-13	    #   #   # #   # 
#		Customized the script to run on
#		various environments.
#
####################################################

#############
# Description:
#############
echo
echo "======================================================"
echo "This script Shows Previous & Current Running SQL STMT."
echo "======================================================"
echo
sleep 1

# Variables:
echo "Please Enter the Unix Process ID:"
echo "================================="
while read "SPID"
 do
	case "${SPID}" in
	"") echo;echo "Please Enter the Unix Process ID:"
		 echo "=================================";;
	*) export SPID;break ;;
	esac
 done

#############################
# Getting ORACLE_SID:
#############################
CHK1=`ps -ef| grep ${SPID} | grep -v grep | grep LOCAL`

	if [ -z "${CHK1}" ]
	 then
	  echo "This Script Is Not Designed For Such Proccess!"
	  echo "This Script Works With Oracle Sessions PIDs Having (LOCAL=YES) or (LOCAL=NO) attribute."
	  exit
	fi

ORACLE_SID=`ps -ef | grep ${SPID} | grep -v grep | awk '{print $(NF-1)}'| sed -e 's/oracle//g' | grep -v sed | grep -v "s///g"`

	if [ -z "${ORACLE_SID}" ]
	 then
	  echo "Can Not Obtain A Valid ORACLE_SID, Please check the process ID you have entered and try again."
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

###############################################
# SQLPLUS: Show Previous/Current SQL Statement:
###############################################

# SQL Script:
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col USERNAME for a20
col PROGRAM for a25
col MODULE for a25
col TERMINAL for a15
col "Previous SQL" for a140
col "Current SQL" for a140

select instance_name from v\$instance;
Prompt

Prompt Previous SQL Statement:
prompt -----------------------

select s.USERNAME,s.sid,s.serial#,s.terminal,s.program,s.module,q.SQL_FULLTEXT "Previous SQL" from v\$process p,v\$session s ,v\$sql q where p.spid=$SPID and p.addr = s.paddr and q.sql_id=s.PREV_SQL_ID;

prompt
Prompt Current SQL Statement:
prompt ---------------------

select s.USERNAME,s.sid,s.serial#,s.terminal,s.program,s.module,q.SQL_FULLTEXT "Current SQL" from v\$process p,v\$session s ,v\$sql q where p.spid=$SPID and p.addr = s.paddr and q.sql_id=s.sql_id;
EOF
###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
