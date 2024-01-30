################################################
# Checking Tablespaces Size	  
#				  #   #     #
# Author:	Mahmmoud ADEL	 # # # # #####
# Created:	18-12-13	#   #   # #   #  
#
#
################################################

#############
# Description:
#############
echo
echo "====================================================="
echo "This script Checks the TABLESPACES Size on a database ..."
echo "====================================================="
echo
sleep 1

################################################
# Database Selection Section:
################################################

## Count DB Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|grep -v ASM|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g"|wc -l )

## If there is ONLY one DB set it as default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|grep -v ASM|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

## If there are more than one DB ASK the user to select:
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

## If there is no DBs are running Exit with msg:
else
  echo No Database Running !
  exit
fi

# Exit if the user selected a Non Listed Number:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "You've Entered An INVALID ORACLE_SID"
          exit
        fi

# Locate the oratab file & Set ORACLE_HOME [Linux & Sun]
##########################################
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

## If oratab is not found, grap ORACLE_HOME from the user's profile:
else
  echo 'oratab file is not found !'
  ORACLE_HOME=`grep 'ORACLE_HOME=\/' $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
fi

## If ORACLE_HOME is EMPTY, extract it from Oracle User Profile:
if [ -z "$ORACLE_HOME" ]
 then
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|grep -v ASM|awk '{print $1}'`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'`
  if [ -f $USR_ORA_HOME/.bash_profile ]   # Linux Bash Profile
   then 
   ORACLE_HOME=`grep 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'`

  elif [ -f $USR_ORA_HOME/.profile ]      # Sun Profile
   then
   ORACLE_HOME=`grep 'ORACLE_HOME=\/' $USR_ORA_HOME/.profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'`

  else
   ORACLE_HOME=`grep 'ORACLE_HOME=\/' /etc/bashrc | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'`
  fi
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

################################################
# Script Body Section:
################################################
$ORACLE_HOME/bin/sqlplus -s /nolog << EOF
connect / as sysdba
set pages 100
set line 100
column tablespace format A20
column "MAXSIZE MB" format 999999
column s format 999999999 heading 'Allocated MB'
column f format 999999999 heading 'Free MB'
column o format 999999999 heading 'Used MB'
column bused format 999.99 heading '%Used'
compute sum of s on report
compute sum of f on report
compute sum of o on report
break on report
select a.tablespace_name tablespace,bb.MAXSIZE/1024/1024 "MAXSIZE MB",sbytes/1024/1024 s,fbytes/1024/1024 f,
(sbytes - fbytes)/1024/1024 o, ext,
round(((sbytes - fbytes) / sbytes) * 100,2) bused
from (select tablespace_name,sum(bytes) sbytes from dba_data_files group by tablespace_name ) a,
     (select tablespace_name,sum(bytes) fbytes,count(*) ext from dba_free_space group by tablespace_name) b,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_data_files group by tablespace_name) bb
--where a.tablespace_name in (select tablespace_name from dba_tablespaces)
where a.tablespace_name = b.tablespace_name (+)
and a.tablespace_name = bb.tablespace_name
and round(((sbytes - fbytes) / sbytes) * 100,2) > 0
UNION ALL
select c.tablespace_name tablespace,dd.MAXSIZE/1024/1024 MAXSIZE_GB,sbytes/1024/1024 s,fbytes/1024/1024 f,
(sbytes - fbytes)/1024/1024 obytes, ext,
round(((sbytes - fbytes) / sbytes) * 100,2) bused
from (select tablespace_name,sum(bytes) sbytes
      from dba_temp_files group by tablespace_name having tablespace_name in (select tablespace_name from dba_tablespaces)) c,
     (select tablespace_name,sum(bytes_free) fbytes,count(*) ext from v\$temp_space_header group by tablespace_name) d,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_temp_files group by tablespace_name) dd
--where c.tablespace_name in (select tablespace_name from dba_tablespaces)
where c.tablespace_name = d.tablespace_name (+)
and c.tablespace_name = dd.tablespace_name
order by tablespace;

set feedback off
set pages 0
-- 100% used tablespaces will not appear in dba_free_space, The following is to eliminate this BUG:
select 'ALARM: TABLESPACE '||tablespace_name||' IS 100% FULL !' from dba_data_files minus select 'ALARM: TABLESPACE '||tablespace_name||' IS 100% FULL !' from dba_free_space;
prompt 
EOF

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# PLEASE VISIT MY BLOG: http://dba-tips.blogspot.com
