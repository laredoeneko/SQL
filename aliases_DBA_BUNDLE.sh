###################################################
# Extract the DBA_BUNDLE & Set Command Alieses
# 					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	02-01-14	    #   #   # #   #  
# Modified:	13-01-14
#		Force using "." command 
#
###################################################
SRV_NAME=`uname -n`

USEDCOMM=`history|tail -1|awk '{print $2}'|egrep '(source|\.)'|grep -v '\.\/'`
        if [ -z "${USEDCOMM}" ]
         then
          echo ""
          echo "Please Use \".\" command to run this script."
          echo "e.g."
          echo ". ~/DBA_BUNDLE1/aliases_DBA_BUNDLE.sh"
          echo ""
	  exit 1
        fi

#############################
# Extract The Bundle:
#############################

# Check the existance of the TAR file:
#	if [ -f ./DBA_BUNDLE1.tar ]
#	 then
#	  echo "Extracting The DBA_BUNDLE..."
#	  tar xvf ./DBA_BUNDLE.tar
#	 else
#	  echo "The TAR file DBA_BUNDLE.tar is not exist under the current working directory !"
#	  echo "Please copy the TAR file DBA_BUNDLE.tar to the current working directory and re-run the script."
#	  exit
#	fi

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
          echo $DB_ID
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
        else
                DB_NAME=$DB_NAME_LOWER
     fi

###########################
# Getting ALERTLOG path:
###########################
DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo $DUMP | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log

##########################
# Getting ORACLE_BASE:
##########################

# Get ORACLE_BASE from user's profile if it EMPTY:

if [ -z "${ORACLE_BASE}" ]
 then
   ORACLE_BASE=`grep 'ORACLE_BASE=\/' $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
   export ORACLE_BASE
fi

# Setting the user's PROFILE variable:
        if [ -f ${USR_ORA_HOME}/.profile ]
         then
          PROFILE=${USR_ORA_HOME}/.profile
          export PROFILE
         else
          PROFILE=${USR_ORA_HOME}/.bash_profile
          export PROFILE
	fi

############################################
# Setting the Environment & Commands Alieses
############################################
if [ -f ${USR_ORA_HOME}/DBA_BUNDLE1/aliases_DBA_BUNDLE.sh ]
then
echo ""
echo "Setting Up The Commands Alieses:"

PATH=$PATH:$ORACLE_HOME/bin
export PATH
TNS_ADMIN=${ORACLE_HOME}/network/admin
export TNS_ADMIN
sed -i '/DBA_BUNDLE1/d' ${PROFILE}
echo "# DBA_BUNDLE1  ====================================================================================="  >> ${PROFILE}
echo "# DBA_BUNDLE1: The Following ALIASES Are Added By aliases_DBA_BUNDLE.sh Script [Part of DBA_BUNDLE1]:" >> ${PROFILE}
echo "# DBA_BUNDLE1  ====================================================================================="  >> ${PROFILE}
echo "ORACLE_SID=${ORACLE_SID} #DBA_BUNDLE1" >> ${PROFILE}
echo "export ORACLE_SID #DBA_BUNDLE1" >> ${PROFILE}
echo "alias l='ls' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias ll='ls -rtlh' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias lla='ls -rtlha' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias d='date' #DBA_BUNDLE1 >> Display the date." >> ${PROFILE}
echo "alias df='df -h' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias top='top -c' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias cron='crontab -e' #DBA_BUNDLE1 >> Open the crontab for editing." >> ${PROFILE}
echo "alias crol='crontab -l' #DBA_BUNDLE1 >> Display the crontab." >> ${PROFILE}
echo "alias profile='. ${PROFILE}' #DBA_BUNDLE1 >> Call the user's profile to reload Environment Variables." >> ${PROFILE}
echo "alias viprofile='vi ${PROFILE}' #DBA_BUNDLE1 >> Open the user's profile for editing." >> ${PROFILE}
echo "alias catprofile='cat ${PROFILE}' #DBA_BUNDLE1 >> Display the user's profile." >> ${PROFILE}
echo "alias vialert='vi ${ALERTDB}' #DBA_BUNDLE1 >> Open the database ALERTLOG with vi editor." >> ${PROFILE}
echo "alias logs='cd ~/Logs;ls -rtlh' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias sql='sqlplus "/ as sysdba"' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias grid='cd $GRID_HOME; ls; pwd' #DBA_BUNDLE1 >> Step you in the GRID_HOME if installed." >> ${PROFILE}
echo "alias alert='tail -100f ${ALERTDB}' #DBA_BUNDLE1 >> Tail the database ALERTLOG to monitor it on the fly." >> ${PROFILE}
echo "alias oh='cd ${ORACLE_HOME};ls;pwd' #DBA_BUNDLE1 >> Step you under ORACLE_HOME." >> ${PROFILE}
echo "alias p='ps -ef|grep pmon|grep -v grep' #DBA_BUNDLE1 >> List current RUNNING Instances." >> ${PROFILE}
echo "alias lsn='ps -ef|grep lsn|grep -v grep' #DBA_BUNDLE1 >> List current RUNNING Listeners." >> ${PROFILE}
echo "alias bdump='cd ${ALERTZ};ls -lrt|tail -10;pwd' #DBA_BUNDLE1 >> Step you under bdump dir." >> ${PROFILE}
echo "alias dbs='cd ${ORACLE_HOME}/dbs;ls -rtlh;pwd' #DBA_BUNDLE1 >> Step you under ORACLE_HOME/dbs directory." >> ${PROFILE}
echo "alias rman='cd ${ORACLE_HOME}/bin; ./rman target /' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias lis='vi ${ORACLE_HOME}/network/admin/listener.ora' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias tns='vi ${ORACLE_HOME}/network/admin/tnsnames.ora' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias pfile='vi ${ORACLE_HOME}/dbs/init${ORACLE_SID}.ora' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias aud='cd ${ORACLE_HOME}/rdbms/audit;ls -rtl|tail -200' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias network='cd ${ORACLE_HOME}/network/admin;ls -rtlh;pwd' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias spfile='vi ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora' #DBA_BUNDLE1" >> ${PROFILE}
echo "alias raclog='tail -100f $GRID_HOME/log/${SRV_NAME}/alert${SRV_NAME}.log' #DBA_BUNDLE1 >> Monitor RAC ALERTLOG on the fly." >> ${PROFILE}
echo "alias dfs='sh ${USR_ORA_HOME}/DBA_BUNDLE1/datafiles.sh' #DBA_BUNDLE1 >> List All DATAFILES on the database." >> ${PROFILE}
echo "alias datafiles='sh ${USR_ORA_HOME}/DBA_BUNDLE1/datafiles.sh' #DBA_BUNDLE1 >> List All DATAFILES on the database." >> ${PROFILE}
echo "alias invalid='sh ${USR_ORA_HOME}/DBA_BUNDLE1/invalid_objects.sh' #DBA_BUNDLE1 >> List All Invalid Objects." >> ${PROFILE}
echo "alias objects='sh ${USR_ORA_HOME}/DBA_BUNDLE1/biggest_50_objects.sh' #DBA_BUNDLE1 >> List Biggest 50 Object on the database." >> ${PROFILE}
echo "alias unlock='sh ${USR_ORA_HOME}/DBA_BUNDLE1/unlock_user.sh' #DBA_BUNDLE1 >> Unlock a specific DB User Account." >> ${PROFILE}
echo "alias sessions='sh ${USR_ORA_HOME}/DBA_BUNDLE1/all_sessions_info.sh' #DBA_BUNDLE1 >> List All current sessions on the DB." >> ${PROFILE}
echo "alias session='sh ${USR_ORA_HOME}/DBA_BUNDLE1/session_details.sh' #DBA_BUNDLE1 >> List Details of a current session." >> ${PROFILE}
echo "alias locks='sh ${USR_ORA_HOME}/DBA_BUNDLE1/db_locks.sh' #DBA_BUNDLE1 >> Show Blocking LOCKS on the database" >> ${PROFILE}
echo "alias sqlid='sh ${USR_ORA_HOME}/DBA_BUNDLE1/sql_id_details.sh' #DBA_BUNDLE1 >> Show a specific SQL Statmnt details." >> ${PROFILE}
echo "alias parm='sh ${USR_ORA_HOME}/DBA_BUNDLE1/parameter_val.sh' #DBA_BUNDLE1 >> Show the value of a Visible/Hidden DB Parameter." >> ${PROFILE}
echo "alias jobs='sh ${USR_ORA_HOME}/DBA_BUNDLE1/db_jobs.sh' #DBA_BUNDLE1 >> List All database Jobs." >> ${PROFILE}
echo "alias spid='sh ${USR_ORA_HOME}/DBA_BUNDLE1/process_info.sh' #DBA_BUNDLE1 >> Show Session details providing it's Unix PID." >> ${PROFILE}
echo "alias tbs='sh ${USR_ORA_HOME}/DBA_BUNDLE1/tablespaces.sh' #DBA_BUNDLE1 >> List All TABLESPACES on the database." >> ${PROFILE}
echo "alias tablespaces='sh ${USR_ORA_HOME}/DBA_BUNDLE1/tablespaces.sh' #DBA_BUNDLE1 >> List All TABLESPACES on the database." >> ${PROFILE}
echo "alias cleanup='sh ${USR_ORA_HOME}/DBA_BUNDLE1/oracle_cleanup.sh' #DBA_BUNDLE1 >> Backup & Clean up All DB & it's Listener LOGs." >> ${PROFILE}
echo "alias starttrace='sh ${USR_ORA_HOME}/DBA_BUNDLE1/start_tracing.sh' #DBA_BUNDLE1 >> Start TRACING an Oracle Session." >> ${PROFILE}
echo "alias tracestart='sh ${USR_ORA_HOME}/DBA_BUNDLE1/start_tracing.sh' #DBA_BUNDLE1 >> Start TRACING an Oracle Session." >> ${PROFILE}
echo "alias stoptrace='sh ${USR_ORA_HOME}/DBA_BUNDLE1/stop_tracing.sh' #DBA_BUNDLE1 >> Stop TRACING a traced Oracle Session." >> ${PROFILE}
echo "alias tracestop='sh ${USR_ORA_HOME}/DBA_BUNDLE1/stop_tracing.sh' #DBA_BUNDLE1 >> Stop TRACING a traced Oracle Session." >> ${PROFILE}
echo "alias objectddl='sh ${USR_ORA_HOME}/DBA_BUNDLE1/object_ddl.sh' #DBA_BUNDLE1 >> Generate the Creation DDL Statement for an OBJECT." >> ${PROFILE}
echo "alias userddl='sh ${USR_ORA_HOME}/DBA_BUNDLE1/user_ddl.sh' #DBA_BUNDLE1 >> Generate Full SQL Creation script for DB USER." >> ${PROFILE}
echo "alias userdetail='sh ${USR_ORA_HOME}/DBA_BUNDLE1/user_details.sh' #DBA_BUNDLE1 >> Generate Full SQL Creation script for DB USER." >> ${PROFILE}
echo "alias roleddl='sh ${USR_ORA_HOME}/DBA_BUNDLE1/role_ddl.sh' #DBA_BUNDLE1 >> Generate Full SQL Creation script for DB ROLE." >> ${PROFILE}
echo "alias roledetail='sh ${USR_ORA_HOME}/DBA_BUNDLE1/role_ddl.sh' #DBA_BUNDLE1 >> Generate Full SQL Creation script for DB ROLE." >> ${PROFILE}
echo "alias lastlogin='sh ${USR_ORA_HOME}/DBA_BUNDLE1/last_logon_report.sh' #DBA_BUNDLE1 >> Reports the last login date for ALL users on DB." >> ${PROFILE}
echo "alias failedlogin='sh ${USR_ORA_HOME}/DBA_BUNDLE1/failed_logins.sh' #DBA_BUNDLE1 >> Report last failed login attempts on the DB." >> ${PROFILE}
echo "alias archivedel='sh ${USR_ORA_HOME}/DBA_BUNDLE1/Archives_Delete.sh' #DBA_BUNDLE1 >> Delete the Archivelogs older than n number of days." >> ${PROFILE}
echo "alias analyze='sh ${USR_ORA_HOME}/DBA_BUNDLE1/analyze_tables.sh' #DBA_BUNDLE1 >> Analyze All Tables in a Schema." >> ${PROFILE}
echo "alias audit='sh ${USR_ORA_HOME}/DBA_BUNDLE1/zAngA_zAngA.sh' #DBA_BUNDLE1 >> Retreive AUDIT data for a DB user on a SPECIFIC DATE." >> ${PROFILE}
echo "alias zanga='sh ${USR_ORA_HOME}/DBA_BUNDLE1/zAngA_zAngA.sh' #DBA_BUNDLE1 >> Retreive AUDIT data for a DB user on a SPECIFIC DATE." >> ${PROFILE}
echo "alias gather='sh ${USR_ORA_HOME}/DBA_BUNDLE1/gather_stats.sh' #DBA_BUNDLE1 >> Backup & Gather Statistics for a SPECIFIC SCHEMA|TABLE." >> ${PROFILE}
echo "alias expdata='sh ${USR_ORA_HOME}/DBA_BUNDLE1/export_data.sh' #DBA_BUNDLE1 >> Export Database | SCHEMA | Table data with EXP or EXPDP." >> ${PROFILE}
echo "alias rmanfull='sh ${USR_ORA_HOME}/DBA_BUNDLE1/RMAN_full.sh' #DBA_BUNDLE1 >> Takes an RMAN FULL DATABASE BACKUP." >> ${PROFILE}


source ${PROFILE}

echo ""
echo "*******************"
echo "LIST OF ALL ALIASES:"
echo "*******************"
echo 
echo " ==============================================================="
echo "|Alias          |Usage                                          |"
echo "|===============|===============================================|"
echo "|alert          |Open the Database Alertlog with tail -f        |"
echo "|---------------|-----------------------------------------------|"
echo "|vialert        |Open the Database Alertlog with vi editor      |"
echo "|---------------|-----------------------------------------------|"
echo "|oh             |Go to ORACLE_HOME                              |"
echo "|---------------|-----------------------------------------------|"
echo "|p              |List Running Instances                         |"
echo "|---------------|-----------------------------------------------|"
echo "|lsn            |List Running Listeners                         |"
echo "|---------------|-----------------------------------------------|"
echo "|lis            |Open listener.ora file with vi editor          |"
echo "|---------------|-----------------------------------------------|"
echo "|tns            |Open tnsnames.ora file with vi editor          |"
echo "|---------------|-----------------------------------------------|"
echo "|pfile          |Open the Instance PFILE with vi editor         |"
echo "|---------------|-----------------------------------------------|"
echo "|spfile         |Open the Instance SPFILE with vi editor        |"
echo "|---------------|-----------------------------------------------|"
echo "|dbs            |Go to ORACLE_HOME/dbs                          |"
echo "|---------------|-----------------------------------------------|"
echo "|aud            |Go to ORACLE_HOME/rdbms/audit                  |"
echo "|---------------|-----------------------------------------------|"
echo "|bdump          |Go to BACKGROUND_DUMP_DEST                     |"
echo "|---------------|-----------------------------------------------|"
echo "|network        |Go to ORACLE_HOME/network/admin                |"
echo "|---------------|-----------------------------------------------|"
echo "|raclog         |Open the Clusterware Alertlog                  |"
echo "|---------------|-----------------------------------------------|"
echo "|dfs|datafiles  |List All DATAFILES on a database               |"
echo "|---------------|-----------------------------------------------|"
echo "|tbs|tablespaces|List All TABLESPACES on a database             |"
echo "|---------------|-----------------------------------------------|"
echo "|invalid        |List All Invalid Objects + Fix Statmnt         |"
echo "|---------------|-----------------------------------------------|"
echo "|objects        |List Biggest 50 Object on a database           |"
echo "|---------------|-----------------------------------------------|"
echo "|session        |List Details of a current session              |"
echo "|---------------|-----------------------------------------------|"
echo "|sessions       |List All current sessions on RAC               |"
echo "|---------------|-----------------------------------------------|"
echo "|locks          |Show Blocking LOCKS on a database              |"
echo "|---------------|-----------------------------------------------|"
echo "|unlock         |Unlock a specific DB User Account              |"
echo "|---------------|-----------------------------------------------|"
echo "|sqlid          |Show a specific SQL Statement details          |"
echo "|---------------|-----------------------------------------------|"
echo "|parm           |Show the value of a Visible/Hidden DB Parameter|"
echo "|---------------|-----------------------------------------------|"
echo "|jobs           |List All database Jobs (DBMS_JOBS + SCHEDULER) |"
echo "|---------------|-----------------------------------------------|"
echo "|spid           |Show Session details by providing it's Unix PID|"
echo "|---------------|-----------------------------------------------|"
echo "|cleanup        |Backup & Clean up All DB & it's Listener LOGs  |"
echo "|---------------|-----------------------------------------------|"
echo "|lastlogin      |Shows the last login date for ALL users on DB  |"
echo "|---------------|-----------------------------------------------|"
echo "|starttrace     |Start TRACING an Oracle Session                |"
echo "|---------------|-----------------------------------------------|"
echo "|stoptrace      |Stop TRACING a traced Oracle Session           |"
echo "|---------------|-----------------------------------------------|"
echo "|userddl        |Generate Full SQL Creation script for a DB User|"
echo "|---------------|-----------------------------------------------|"
echo "|roleddl        |Generate Full SQL Creation script for a DB ROLE|"
echo "|---------------|-----------------------------------------------|"
echo "|objectddl      |Generate Full SQL Creation script for an Object|"
echo "|---------------|-----------------------------------------------|"
echo "|failedlogin    |Report failed login attempts in the last n days|"
echo "|---------------|-----------------------------------------------|"
echo "|archivedel     |Delete Archivelogs older than n number of days |"
echo "|---------------|-----------------------------------------------|"
echo "|analyze        |Analyze All tables in a specific SCHEMA        |"
echo "|---------------|-----------------------------------------------|"
echo "|audit|zanga    |Retreive AUDIT data for a DB user              |"
echo "|---------------|-----------------------------------------------|"
echo "|gather         |Gather STATISTICS on a SCHEMA or TABLE         |"
echo "|---------------|-----------------------------------------------|"
echo "|rmanfull       |Takes an RMAN FULL DATABASE BACKUP             |"
echo "|---------------|-----------------------------------------------|"
echo "|expdata        |Export DB|SCHEMA|TABLE data using exp or expdp |"
echo " ==============================================================="	
echo ""
echo "There are some Scripts without aliases like:"
echo "*******************************************"
echo " --------------------------------------------------------------- "
echo "|dbalarm.sh     |Schedule it to run [every 5 minutes] in the    |"
echo "|               |crontab to report ORA- and TNS- that appear in |"
echo "|               |the ALERTLOG of ALL Databases & Listeners      |"
echo "|               |running on the server to your E-MAIL address:  |"
echo "|               |in line# 11 you have to replace this template: |"
echo "|               |<youremail@yourcompany.com>                    |"
echo "|               |with your E-mail Address.                      |"
echo "|---------------|-----------------------------------------------|"
echo "|SHUTDOWN_All.sh|SHUTDOWN ALL Databases and Listeners           |"
echo "|               |running on The server, I didn't alias it       |"
echo "|               |because of it's severity.                      |"
echo "|---------------|-----------------------------------------------|"
echo "|COLD_BACKUP.sh |Takes a cold backup for any database easily    |"
echo "|               |and safely, creates restore script and make it |"
echo "|               |ready for you (in case you will restore that   |"
echo "|               |cold backup later).                            |"
echo " --------------------------------------------------------------- "
echo ""
echo "***************************************"
echo "I HOPE YOU ENJOY USING THIS BUNDLE :-)"
echo "Mahmmoud ADEL"
echo "Oracle DBA"
echo "***************************************"
echo ""

else
 echo "The Bundle directory ${USR_ORA_HOME}/DBA_BUNDLE1 is not exist!"
 echo "The DBA_BUNDLE MUST be extracted under User's home: ${USR_ORA_HOME}"
 echo ""
fi

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
