###################################################
# Backup & Gather Statistics for SCHEMA|TABLE.
# To be run by ORACLE user		
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      02-02-2014          #   #   # #   #
#					
#
###################################################

#############
# Description:
#############
echo
echo "==================================================================="
echo "This script Backup & Gather Statistics for a specific SCHEMA|TABLE."
echo "==================================================================="
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
STATS_TABLE=BACKUP_STATS
STATS_OWNER=SYS
STATS_TBS=SYSTEM

VAL33=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT STATUS FROM V\$INSTANCE;
EOF
)
VAL44=`echo $VAL33| awk '{print $NF}'`
		case ${VAL44} in
		"OPEN") echo ;;
		*) echo;echo "ERROR: INSTANCE [$ORACLE_SID] IS IN STATUS: ${VAL44} !"
		   echo; echo "PLEASE OPEN THE INSTANCE [$ORACLE_SID] AND RE-RUN THIS SCRIPT.";echo; exit ;;
		esac

echo "Enter the TABLE OWNER:"
echo "====================="
while read SCHEMA_NAME
 do
        if [ -z ${SCHEMA_NAME} ]
         then
	  echo
	  echo "Enter the TABLE OWNER:"
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

echo 
echo "Enter the TABLE NAME: [BLANK VALUE MEANS GATHER THE WHOLE SCHEMA [$SCHEMA_NAME] STATS]"
echo "===================="
while read TABLE_NAME
 do
        if [ -z ${TABLE_NAME} ]
         then
          echo
          echo "ARE YOU SURE TO GATHER SCHEMA [${SCHEMA_NAME}] STATISTICS? [Y|N] [Y]"
	  while read ANS
		 do
	         case $ANS in
                 ""|y|Y|yes|YES|Yes) echo "GATHERING STATISTICS ON SCHEMA [${SCHEMA_NAME}] ..."
echo
echo "GATHER HISTOGRAMS ALONG WITH STATISTICS? [Y|N] [Y]"
echo "======================================="
while read ANS1
        do
        case $ANS1 in
        ""|y|Y|yes|YES|Yes) HISTO="FOR ALL COLUMNS SIZE SKEWONLY";HISTOMSG="(+HISTOGRAMS)"; break ;;
        n|N|no|NO|No) HISTO="FOR ALL COLUMNS SIZE 1"; break ;;
        *) echo "Please enter a VALID answer [Y|N]" ;;
        esac
        done
# Check The Existance of BACKUP STATS TABLE:
VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER=upper('$STATS_OWNER') AND TABLE_NAME=upper('$STATS_TABLE');
EOF
)
VAL2=`echo $VAL1| awk '{print $NF}'`
                if [ ${VAL2} -gt 0 ]
                 then
                  echo
                  echo "BACKUP STATS TABLE [${STATS_OWNER}.${STATS_TABLE}] IS ALREADY EXIST."
                 else
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
SET LINESIZE 157
SET PAGESIZE 5000
SET HEADING OFF
SET VERIFY OFF
PROMPT CREATING BACKUP STATS TABLE ...
BEGIN
dbms_stats.create_stat_table (
ownname => upper('$STATS_OWNER'),
tblspace => upper('$STATS_TBS'),
stattab => upper('$STATS_TABLE'));
END;
/
PROMPT
EOF
                fi
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT BACKING UP CURRENT STATISTICS OF SCHEMA [$SCHEMA_NAME] ...
BEGIN
DBMS_STATS.EXPORT_SCHEMA_STATS (
ownname => upper('$SCHEMA_NAME'),
statown => upper('$STATS_OWNER'),
stattab => upper('$STATS_TABLE'));
END;
/
PROMPT
PROMPT GATHERING STATISTICS $HISTOMSG ON SCHEMA [$SCHEMA_NAME] ...
BEGIN 
DBMS_STATS.GATHER_SCHEMA_STATS (
ownname => upper('$SCHEMA_NAME'),
METHOD_OPT => '$HISTO',
estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE);
END;
/
PROMPT
PROMPT (IN CASE THE NEW STATISTICS IS PERFORMING BAD, RESTORE BACK THE ORIGINAL STATISTICS USING THIS SQL COMMAND):
PROMPT
PROMPT EXEC DBMS_STATS.IMPORT_SCHEMA_STATS (ownname => upper('$SCHEMA_NAME'), statown => upper('$STATS_OWNER'), stattab => upper('$STATS_TABLE'));;
PROMPT
EOF
		 exit 1 ;;
		 n|N|no|NO|No) echo; echo "Enter the TABLE NAME:";echo "====================";break ;;
	         *) echo "Please enter a VALID answer [Y|N]" ;;
		esac
		done
         else
# Check The Existance of ENTERED TABLE:
VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER=upper('$SCHEMA_NAME') AND TABLE_NAME=upper('$TABLE_NAME');
EOF
)
VAL2=`echo $VAL1| awk '{print $NF}'`
                if [ ${VAL2} -eq 0 ]
                 then
                  echo
                  echo "ERROR: TABLE [${SCHEMA_NAME}.${TABLE_NAME}] IS NOT EXIST !"
		  echo;echo "Enter the TABLE NAME: [BLANK VALUE MEANS GATHER THE WHOLE SCHEMA [$SCHEMA_NAME] STATS]"
		  echo "===================="
		 else
		  break
		fi
        fi
 done

echo
echo "GATHER HISTOGRAMS ALONG WITH STATISTICS? [Y|N] [Y]"
echo "======================================="
while read ANS1
 	do
        case $ANS1 in
        ""|y|Y|yes|YES|Yes) HISTO="FOR ALL COLUMNS SIZE SKEWONLY"; HISTOMSG="(+HISTOGRAMS)";break ;;
        n|N|no|NO|No) HISTO="FOR ALL COLUMNS SIZE 1"; break ;;
        *) echo "Please enter a VALID answer [Y|N]" ;;
        esac
        done

echo
echo "GATHER STATISTICS ON ALL TABLES'S INDEXES? [Y|N] [Y]"
echo "========================================="
while read ANS2
        do
        case $ANS2 in
        ""|y|Y|yes|YES|Yes) CASCD="TRUE";CASCMSG="AND IT'S ALL INDEXES"; break ;;
        n|N|no|NO|No) CASCD="FALSE"; break ;;
        *) echo "Please enter a VALID answer [Y|N]" ;;
        esac
        done

# Execution of SQL Statement:
############################

VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER=upper('$STATS_OWNER') AND TABLE_NAME=upper('$STATS_TABLE');
EOF
)
VAL2=`echo $VAL1| awk '{print $NF}'`
                if [ ${VAL2} -gt 0 ]
                 then
                  echo
                  echo "BACKUP STATS TABLE [${STATS_OWNER}.${STATS_TABLE}] IS ALREADY EXIST."
                 else
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
SET LINESIZE 157
SET PAGESIZE 5000
SET HEADING OFF
SET VERIFY OFF
PROMPT CREATING BACKUP STATS TABLE ...
BEGIN
dbms_stats.create_stat_table (
ownname => upper('$STATS_OWNER'),
tblspace => upper('$STATS_TBS'),
stattab => upper('$STATS_TABLE'));
END;
/
PROMPT
EOF
                fi

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
SET LINESIZE 157
SET PAGESIZE 5000
SET HEADING OFF
--SET FEEDBACK OFF
--SET VERIFY OFF
PROMPT BACKING UP CURRENT STATISTICS OF TABLE [$SCHEMA_NAME.$TABLE_NAME]  ...
BEGIN
DBMS_STATS.EXPORT_TABLE_STATS (
ownname => upper('$SCHEMA_NAME'),
tabname => upper('$TABLE_NAME'),
statown => upper('$STATS_OWNER'),
stattab => upper('$STATS_TABLE'));
END;
/
PROMPT
PROMPT GATHERING STATISTICS $HISTOMSG FOR TABLE [$SCHEMA_NAME.$TABLE_NAME] $CASCMSG ...
BEGIN
DBMS_STATS.GATHER_TABLE_STATS (
ownname => upper('$SCHEMA_NAME'),
tabname => upper('$TABLE_NAME'),
cascade => $CASCD,
METHOD_OPT => '$HISTO',
estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE);
END;
/
PROMPT
PROMPT => IN CASE THE NEW STATISTICS IS PERFORMING BAD, RESTORE BACK THE ORIGINAL STATISTICS USING THIS SQL COMMAND:
PROMPT
PROMPT EXEC DBMS_STATS.IMPORT_TABLE_STATS (ownname => upper('$SCHEMA_NAME'), tabname => upper('$TABLE_NAME'), statown => upper('$STATS_OWNER'), stattab => upper('$STATS_TABLE'));;
PROMPT
EOF

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
