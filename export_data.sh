###################################################
# EXPORT DATABASE | SCHEMA | TABLE.
# To be run by ORACLE user		
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      03-02-2014          #   #   # #   #
#					
#
###################################################

#############
# Description:
#############
echo
echo "=============================================="
echo "This script EXPORTS DATABASE | SCHEMA | TABLE."
echo "=============================================="
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
    echo "Select the Instance You Want To Run this Script Against:"
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
# EXPORTING Section:
###########################
# PROMPT FOR VARIABLES:
######################
DUMPDATE=`date +%m-%d-%y`
PASSHALF=`date '+%s'`

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

echo "WHERE TO SAVE THE EXPORT FILE [DUMPFILE]? [ENTER THE FULL PATH]"
echo "========================================"
while read LOC1
do
        if [ ! -d ${LOC1} ]; then
		echo
                echo "ERROR: THE LOCATION YOU HAVE PROVIDED IS NOT EXIST | WRITABLE !"
		echo
                echo "Please Enter the location where you want keep the EXPORT FILE [DUMPFILE]: [ENTER THE FULL PATH]"
                echo "========================================================================"
	elif [ -z ${LOC1} ]; then
	        echo
                echo "ERROR: THE LOCATION YOU HAVE PROVIDED IS NOT EXIST | WRITABLE !"
                echo
                echo "Please Enter the location where you want keep the EXPORT FILE [DUMPFILE]: [ENTER FULL PATH]"
                echo "========================================================================"
	else
		break
	fi
done


#########################
# EXPORT DATABASE SECTION:
#########################
echo
echo "Do you want to EXPORT FULL DATABASE? [Y|N] [Y] [N TO EXPORT SCHEMA|TABLE]"
echo "==================================="
while read ANS
 do
	         case $ANS in
                 ""|y|Y|yes|YES|Yes) echo;echo "EXPORT FULL DATABASE MODE ...";sleep 1
		 echo;echo "WHICH EXPORT UTILITY YOU WANT TO USE: [1) DATAPUMP [EXPDP]]"
		 echo "===================================="
		 echo "1) DATAPUMP [EXPDP]"
		 echo "2) LEGACY EXPORT [EXP]"
		 while read EXP_TOOL
			do
			case $EXP_TOOL in
			""|"1"|"DATAPUMP"|"datapump"|"DATAPUMP [EXPDP]"|"[EXPDP]"|"EXPDP"|"expdp")
cd ${LOC1}
SPOOLFILE2=AFTER_IMPORT_DATABASE_${ORACLE_SID}.sql
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT CREATE USER DBA_BUNDLEEXP7 FOR THE SAKE OF THE EXPORT (WILL BE DROPPED AFTER THE EXPORT) ...
CREATE USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
ALTER USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
GRANT DBA TO DBA_BUNDLEEXP7;
-- The following privileges to workaround Bug 6392040:
GRANT EXECUTE ON SYS.DBMS_DEFER_IMPORT_INTERNAL TO DBA_BUNDLEEXP7;
GRANT EXECUTE ON SYS.DBMS_EXPORT_EXTENSION TO DBA_BUNDLEEXP7;
PROMPT
PROMPT CREATING DIRECTORY EXPORT_FILES_DBA_BUNDLE POINTING TO $LOC1 ...
CREATE OR REPLACE DIRECTORY EXPORT_FILES_DBA_BUNDLE AS '$LOC1';
PROMPT
PROMPT CREATING AFTER DATABASE IMPORT SCRIPT ...
PROMPT
SET PAGES 0 TERMOUT OFF LINESIZE 157 ECHO OFF FEEDBACK OFF
SPOOL $SPOOLFILE2
SELECT 'PROMPT ' FROM DUAL;
SELECT 'PROMPT COMPILING DATABASE INVALID OBJECTS ...' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT 'PROMPT ' FROM DUAL;
SELECT 'PROMPT THE FOLLOWING TRIGGERS ARE OWNED BY SYS SCHEMA AND MAY BE NOT ALL OF THEM ARE EXIST AFTER THE IMPORT' FROM DUAL;
SELECT 'PROMPT YOU MAY CONSIDER CREATING THE NON EXIST TRIGGERS IF YOU NEED SO:' FROM DUAL;
SELECT 'PROMPT ***************************************************************' FROM DUAL;
SELECT 'PROMPT '||TRIGGER_TYPE||' TRIGGER:  '||TRIGGER_NAME FROM DBA_TRIGGERS WHERE OWNER=UPPER('SYS') ORDER BY 1;
SELECT 'PROMPT ' FROM DUAL;
SELECT 'PROMPT ARE THESE DIRECTORIES POINTING TO THE RIGHT PATHS? ' FROM DUAL;
SELECT 'PROMPT ************************************************** ' FROM DUAL;
COL DIRECTORY FOR A50
COL DIRECTORY_PATH FOR A100
SELECT 'PROMPT '||OWNER||'.'||DIRECTORY_NAME||':  '||DIRECTORY_PATH FROM DBA_DIRECTORIES;
SELECT 'PROMPT ' FROM DUAL;
SPOOL OFF
EOF
echo
echo "EXPORTING DATABASE $ORACLE_SID [USING DATAPUMP] ..."
sleep 1
${ORACLE_HOME}/bin/expdp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" REUSE_DUMPFILES=Y COMPRESSION=ALL FULL=y DIRECTORY=EXPORT_FILES_DBA_BUNDLE DUMPFILE=FULL_EXPORT_${ORACLE_SID}_${DUMPDATE}.dmp LOGFILE=FULL_EXPORT_${ORACLE_SID}_${DUMPDATE}.log

# Export METADATA ONLY: <using Legacy EXP because it's more reliable than EXPDP in exporting DDLs>
echo;echo "CREATING A FILE CONTAINS ALL CREATION [DDL] STATEMENT OF ALL USERS|OBJECTS ...";sleep 1
${ORACLE_HOME}/bin/exp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" FULL=y ROWS=N STATISTICS=NONE FILE=${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.dmp log=${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.log

# Removing Extra Bad characters: [DUMP REFINING]
/usr/bin/strings ${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.dmp > ${LOC1}/${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc

# Dropping user DBA_BUNDLEEXP7:
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT
PROMPT DROPPING THE EXPORTER USER DBA_BUNDLEEXP7 (SAFELY) ...
DROP USER DBA_BUNDLEEXP7;
EOF

echo
echo "*****************"
echo "IMPORT GUIDELINES:"
echo "*****************"
echo "AFTER IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE2"
echo " => THAT SCRIPT INCLUDES (HINTS FOR TRIGGERS NAME OWNED BY SYS) + COMPILING INVALID OBJECTS, WHICH WILL NOT BE CREATED BY THE IMPORT PROCESS."
echo 
echo "*********************"
echo "EXPORT FILES LOCATION:"
echo "*********************"
echo "*****************************************************************"
echo "FULL Database EXPORT (DATA+METADATA) FILE: ${LOC1}/FULL_EXPORT_${ORACLE_SID}_${DUMPDATE}.dmp"
echo "Database METADATA DUMP LOCATION <IMPORTABLE with [exp utility]>: ${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.dmp"
echo "Database METADATA Script LOCATION <READABLE | Cannot be Imported>: ${LOC1}/${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc"
echo "*****************************************************************"
			echo; exit ;;
			"2"|"LEGACY EXPORT"|"LEGACY"|"EXPORT"|"LEGACY EXPORT [EXP]"|"EXP"|"[EXP]"|"exp"|"legacy export"|"legacy"|"export")
echo
echo "EXPORTING DATABASE $ORACLE_SID [USING LEGACY EXP] ..."
sleep 1
cd ${LOC1}
SPOOLFILE2=AFTER_IMPORT_DATABASE_${ORACLE_SID}.sql
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT CREATE USER DBA_BUNDLEEXP7 FOR THE SAKE OF THE EXPORT (WILL BE DROPPED AFTER THE EXPORT) ...
CREATE USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
ALTER USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
GRANT EXP_FULL_DATABASE TO DBA_BUNDLEEXP7;
-- The following privileges to workaround Bug 6392040:
GRANT EXECUTE ON SYS.DBMS_DEFER_IMPORT_INTERNAL TO DBA_BUNDLEEXP7;
GRANT EXECUTE ON SYS.DBMS_EXPORT_EXTENSION TO DBA_BUNDLEEXP7;
PROMPT
PROMPT CREATING AFTER DATABASE IMPORT SCRIPT ...
PROMPT
SET PAGES 0 TERMOUT OFF LINESIZE 157 ECHO OFF FEEDBACK OFF
SPOOL $SPOOLFILE2
SELECT 'PROMPT COMPILING DATABASE INVALID OBJECTS ...' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT 'PROMPT ' FROM DUAL;
SELECT 'PROMPT THE FOLLOWING TRIGGERS ARE OWNED BY SYS SCHEMA AND MAY BE NOT ALL OF THEM ARE EXIST AFTER THE IMPORT' FROM DUAL;
SELECT 'PROMPT YOU MAY CONSIDER CREATING THE NON EXIST TRIGGERS IF YOU NEED SO:' FROM DUAL;
SELECT 'PROMPT ***************************************************************' FROM DUAL;
SELECT 'PROMPT '||TRIGGER_TYPE||' TRIGGER:  '||TRIGGER_NAME FROM DBA_TRIGGERS WHERE OWNER=UPPER('SYS') ORDER BY 1;
SELECT 'PROMPT ARE THESE DIRECTORIES POINTING TO THE RIGHT PATHS? ' FROM DUAL;
COL DIRECTORY FOR A50
COL DIRECTORY_PATH FOR A100
SELECT 'PROMPT '||OWNER||'.'||DIRECTORY_NAME||':  '||DIRECTORY_PATH FROM DBA_DIRECTORIES;
SPOOL OFF
EOF

${ORACLE_HOME}/bin/exp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" FULL=y DIRECT=y CONSISTENT=y STATISTICS=NONE FEEDBACK=1000 FILE=${LOC1}/FULL_EXPORT_${ORACLE_SID}_${DUMPDATE}.dmp log=${LOC1}/FULL_EXPORT_${ORACLE_SID}_${DUMPDATE}.log
# Export METADATA ONLY: <using Legacy EXP because it's more reliable than EXPDP in exporting DDLs>
echo
echo "CREATING A FILE CONTAINS ALL CREATION [DDL] STATEMENT OF ALL USERS|OBJECTS ..."
sleep 1
${ORACLE_HOME}/bin/exp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" FULL=y ROWS=N STATISTICS=NONE FILE=${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.dmp log=${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.log
# Removing Extra Bad characters: [DUMP REFINING]
/usr/bin/strings ${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.dmp > ${LOC1}/${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc

# DRPOPPING USER DBA_BUNDLEEXP7:
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT
PROMPT DROPPING THE EXPORTER USER DBA_BUNDLEEXP7 (SAFELY) ...
DROP USER DBA_BUNDLEEXP7;
EOF

echo
echo "*****************"
echo "IMPORT GUIDELINES:"
echo "*****************"
echo "AFTER IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE2"
echo " => THAT SCRIPT INCLUDES (HINTS FOR TRIGGERS NAME OWNED BY SYS) + COMPILING INVALID OBJECTS, WHICH WILL NOT BE CREATED BY THE IMPORT PROCESS."
echo 
echo
echo "*********************"
echo "EXPORT FILES LOCATION:"
echo "*********************"
echo "*****************************************************************"
echo "FULL Database EXPORT (DATA+METADATA) FILE: ${LOC1}/FULL_EXPORT_${ORACLE_SID}_${DUMPDATE}.dmp"
echo "Database METADATA DUMP LOCATION <IMPORTABLE with [exp utility]>: ${LOC1}/${ORACLE_SID}_METADATA_${DUMPDATE}.dmp"
echo "Database METADATA Script LOCATION <READABLE | Cannot be Imported>: ${LOC1}/${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc"
echo "*****************************************************************"
                        echo; exit ;;
			*) echo "Please Enter a VALID Answer [1|2] [1]"; echo "=================================" ;;
			esac
			done
		 ;;
		 n|N|no|NO|No) echo; echo "EXPORT SCHEMA MODE ...";echo;sleep 1; break ;;
                 *) echo "Please enter a VALID answer [Y|N]"; echo "=================================" ;;
                esac
 done

#######################
# EXPORT SCHEMA SECTION:
#######################

echo "Do you want to EXPORT a SCHEMA? [Y|N] [Y] [N If you want to EXPORT TABLE]"
echo "=============================="
while read ANS2
 do
	         case $ANS2 in
                 ""|y|Y|yes|YES|Yes)
		 echo; echo "Please Enter the SCHEMA NAME:"
		       echo "============================"
		 while read SCHEMA_NAME
		  do
		        if [ -z ${SCHEMA_NAME} ]
		         then
		          echo
		          echo "Enter the SCHEMA NAME:"
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

		 echo;echo "WHICH EXPORT UTILITY YOU WANT TO USE: [1) DATAPUMP [EXPDP]]"
		 echo "===================================="
		 echo "1) DATAPUMP [EXPDP]"
		 echo "2) LEGACY EXPORT [EXP]"
		 while read EXP_TOOL
			do
			case $EXP_TOOL in
			""|"1"|"DATAPUMP"|"datapump"|"DATAPUMP [EXPDP]"|"[EXPDP]"|"EXPDP"|"expdp")
cd ${LOC1}
SPOOLFILE1=BEFORE_IMPORT_SCHEMA_$SCHEMA_NAME.sql
SPOOLFILE2=AFTER_IMPORT_SCHEMA_$SCHEMA_NAME.sql

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT CREATE USER DBA_BUNDLEEXP7 FOR THE SAKE OF THE EXPORT (WILL BE DROPPED AFTER THE EXPORT) ...
CREATE USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
ALTER USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
GRANT DBA TO DBA_BUNDLEEXP7;
-- The following privileges to workaround Bug 6392040:
GRANT EXECUTE ON SYS.DBMS_DEFER_IMPORT_INTERNAL TO DBA_BUNDLEEXP7;
GRANT EXECUTE ON SYS.DBMS_EXPORT_EXTENSION TO DBA_BUNDLEEXP7;
PROMPT
PROMPT CREATING DIRECTORY EXPORT_FILES_DBA_BUNDLE POINTING TO $LOC1 ...
CREATE OR REPLACE DIRECTORY EXPORT_FILES_DBA_BUNDLE AS '$LOC1';
PROMPT
PROMPT CREATING BEFORE SCHEMA IMPORT SCRIPT ...
PROMPT
SET PAGES 0 TERMOUT OFF LINESIZE 157 ECHO OFF FEEDBACK OFF
SPOOL $SPOOLFILE1
SELECT 'CREATE USER ' || u.username ||' IDENTIFIED ' ||' BY VALUES ''' || c.password || ''' DEFAULT TABLESPACE ' || u.default_tablespace ||' TEMPORARY TABLESPACE ' || u.temporary_tablespace ||' PROFILE ' || u.profile || case when account_status= 'OPEN' then ';' else ' Account LOCK;' end "--Creation Statement"
FROM dba_users u,user$ c where u.username=c.name and u.username=upper('$SCHEMA_NAME')
UNION
SELECT 'CREATE ROLE '||GRANTED_ROLE||';' FROM DBA_ROLE_PRIVS WHERE GRANTEE=UPPER('$SCHEMA_NAME')
UNION
select 'GRANT '||GRANTED_ROLE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted Roles"
from dba_role_privs where grantee= upper('$SCHEMA_NAME')
UNION
select 'GRANT '||PRIVILEGE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted System Privileges"
from dba_sys_privs where grantee= upper('$SCHEMA_NAME')
UNION
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||case when GRANTABLE='YES' then ' WITH GRANT OPTION;' else ';' end "Granted Object Privileges" from DBA_TAB_PRIVS where GRANTEE=upper('$SCHEMA_NAME');
SPOOL OFF
PROMPT CREATING AFTER SCHEMA IMPORT SCRIPT ...
PROMPT
SPOOL $SPOOLFILE2
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||case when GRANTABLE='YES' then ' WITH GRANT OPTION;' else ';' end "Granted Object Privileges" from DBA_TAB_PRIVS where OWNER=upper('$SCHEMA_NAME')
UNION
SELECT 'CREATE PUBLIC SYNONYM '||SYNONYM_NAME||' FOR '||TABLE_OWNER||'.'||TABLE_NAME||';' FROM DBA_SYNONYMS WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND OWNER=UPPER('PUBLIC');
PROMPT
SELECT 'PROMPT COMPILING DATABASE INVALID OBJECTS ...' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT 'PROMPT ' FROM DUAL;
SELECT 'PROMPT THE FOLLOWING TRIGGERS ARE OWNED BY OTHER USERS BUT ARE DEPENDING ON SCHEMA $SCHEMA_NAME OBJECTS' FROM DUAL;
SELECT 'PROMPT YOU MAY CONSIDER TO CREATE THEM AFTER THE SCHEMA IMPORT IF YOU NEED SO:' FROM DUAL;
SELECT 'PROMPT **********************************************************************' FROM DUAL;
SELECT 'PROMPT '||TRIGGER_TYPE||' TRIGGER:  '||OWNER||'.'||TRIGGER_NAME||'   =>ON TABLE:  '||TABLE_OWNER||'.'||TABLE_NAME FROM DBA_TRIGGERS WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND OWNER <> UPPER('$SCHEMA_NAME') ORDER BY 1;
SPOOL OFF
EOF
echo
echo "EXPORTING SCHEMA ${SCHEMA_NAME} [USING DATAPUMP] ..."
sleep 1
${ORACLE_HOME}/bin/expdp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" REUSE_DUMPFILES=Y COMPRESSION=ALL SCHEMAS=${SCHEMA_NAME} DIRECTORY=EXPORT_FILES_DBA_BUNDLE DUMPFILE=EXPORT_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp LOGFILE=EXPORT_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.log

# Export METADATA ONLY: <using Legacy EXP because it's more reliable than EXPDP in exporting DDLs>
echo
echo "CREATING A FILE CONTAINS ALL CREATION [DDL] STATEMENTS OF ALL OBJECTS ..."
sleep 1
${ORACLE_HOME}/bin/exp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" OWNER=${SCHEMA_NAME} ROWS=N STATISTICS=NONE FILE=${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.dmp log=${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.log

# Removing Extra Bad characters: [DUMP REFINING]
/usr/bin/strings ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.dmp > ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc

# DRPOPPING USER DBA_BUNDLEEXP7:
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT
PROMPT DROPPING THE EXPORTER USER DBA_BUNDLEEXP7 (SAFELY) ...
DROP USER DBA_BUNDLEEXP7;
EOF

echo
echo "*****************"
echo "IMPORT GUIDELINES:"
echo "*****************"
echo "BEFORE IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE1"
echo " => THAT SCRIPT INCLUDES (USER|ROLES|GRANTED PRIVILEGES CREATION STATEMENTS), WHICH WILL NOT BE CREATED BY THE IMPORT PROCESS."
echo 
echo "AFTER IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE2"
echo " => THAT SCRIPT INCLUDES (PUBLIC SYNONYMS DDLS|PRIVILEGES GRANTED TO OTHERS|HINTS FOR TRIGGERS OWNED BY OTHERS AND DEPENDANT ON $SCHEMA_NAME OBJECTS)"
echo "    + COMPILING INVALID OBJECTS, SUCH STUFF WILL NOT BE CARRIED OUT BY THE IMPORT PROCESS."
echo
echo
echo "*********************"
echo "EXPORT FILES LOCATION:"
echo "*********************"
echo "*******************************************"
echo "SCHEMA EXPORT (DATA+METADATA) file Location: ${LOC1}/EXPORT_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp"
echo "SCHEMA METADATA ONLY Script LOCATION <IMPORTABLE (Can be Imported using [exp utility]>: ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.dmp"
echo "SCHEMA METADATA ONLY Script LOCATION <READABLE (CANNOT be Imported)>: ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc"
echo "*******************************************"
			echo; exit ;;
			"2"|"LEGACY EXPORT"|"LEGACY"|"EXPORT"|"LEGACY EXPORT [EXP]"|"EXP"|"[EXP]"|"exp"|"legacy export"|"legacy"|"export")
cd ${LOC1}
SPOOLFILE1=BEFORE_IMPORT_SCHEMA_$SCHEMA_NAME.sql
SPOOLFILE2=AFTER_IMPORT_SCHEMA_$SCHEMA_NAME.sql

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT CREATE USER DBA_BUNDLEEXP7 FOR THE SAKE OF THE EXPORT (WILL BE DROPPED AFTER THE EXPORT) ...
CREATE USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
ALTER USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
GRANT EXP_FULL_DATABASE TO DBA_BUNDLEEXP7;
-- The following privileges to workaround Bug 6392040:
GRANT EXECUTE ON SYS.DBMS_DEFER_IMPORT_INTERNAL TO DBA_BUNDLEEXP7;
GRANT EXECUTE ON SYS.DBMS_EXPORT_EXTENSION TO DBA_BUNDLEEXP7;
PROMPT
PROMPT CREATING BEFORE SCHEMA IMPORT SCRIPT ...
PROMPT
SET PAGES 0 TERMOUT OFF LINESIZE 157 ECHO OFF FEEDBACK OFF
SPOOL $SPOOLFILE1
SELECT 'CREATE USER ' || u.username ||' IDENTIFIED ' ||' BY VALUES ''' || c.password || ''' DEFAULT TABLESPACE ' || u.default_tablespace ||' TEMPORARY TABLESPACE ' || u.temporary_tablespace ||' PROFILE ' || u.profile || case when account_status= 'OPEN' then ';' else ' Account LOCK;' end "--Creation Statement"
FROM dba_users u,user$ c where u.username=c.name and u.username=upper('$SCHEMA_NAME')
UNION
SELECT 'CREATE ROLE '||GRANTED_ROLE||';' FROM DBA_ROLE_PRIVS WHERE GRANTEE=UPPER('$SCHEMA_NAME')
UNION
select 'GRANT '||GRANTED_ROLE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted Roles"
from dba_role_privs where grantee= upper('$SCHEMA_NAME')
UNION
select 'GRANT '||PRIVILEGE||' TO '||GRANTEE|| case when ADMIN_OPTION='YES' then ' WITH ADMIN OPTION;' else ';' end "Granted System Privileges"
from dba_sys_privs where grantee= upper('$SCHEMA_NAME')
UNION
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||case when GRANTABLE='YES' then ' WITH GRANT OPTION;' else ';' end "Granted Object Privileges" from DBA_TAB_PRIVS where GRANTEE=upper('$SCHEMA_NAME');
SPOOL OFF
PROMPT CREATING AFTER SCHEMA IMPORT SCRIPT ...
PROMPT
SPOOL $SPOOLFILE2
select 'GRANT '||PRIVILEGE||' ON '||OWNER||'.'||TABLE_NAME||' TO '||GRANTEE||case when GRANTABLE='YES' then ' WITH GRANT OPTION;' else ';' end "Granted Object Privileges" from DBA_TAB_PRIVS where OWNER=upper('$SCHEMA_NAME')
UNION
SELECT 'CREATE PUBLIC SYNONYM '||SYNONYM_NAME||' FOR '||TABLE_OWNER||'.'||TABLE_NAME||';' FROM DBA_SYNONYMS WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND OWNER=UPPER('PUBLIC');
PROMPT
SELECT 'PROMPT COMPILING DATABASE INVALID OBJECTS ...' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT '@?/rdbms/admin/utlrp' FROM DUAL;
SELECT 'PROMPT ' FROM DUAL;
SELECT 'PROMPT THE FOLLOWING TRIGGERS ARE OWNED BY OTHER USERS BUT ARE DEPENDING ON SCHEMA $SCHEMA_NAME OBJECTS' FROM DUAL;
SELECT 'PROMPT YOU MAY CONSIDER TO CREATE THEM AFTER THE SCHEMA IMPORT IF YOU NEED SO:' FROM DUAL;
SELECT 'PROMPT **********************************************************************' FROM DUAL;
SELECT 'PROMPT '||TRIGGER_TYPE||' TRIGGER:  '||OWNER||'.'||TRIGGER_NAME||'   =>ON TABLE:  '||TABLE_OWNER||'.'||TABLE_NAME FROM DBA_TRIGGERS WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND OWNER <> UPPER('$SCHEMA_NAME') ORDER BY 1;
SPOOL OFF
EOF
echo
echo "EXPORTING SCHEMA ${SCHEMA_NAME} [USING LEGACY EXP] ..."
sleep 1
${ORACLE_HOME}/bin/exp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" OWNER=${SCHEMA_NAME} DIRECT=y CONSISTENT=y STATISTICS=NONE FEEDBACK=1000 FILE=${LOC1}/EXPORT_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp log=${LOC1}/EXPORT_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.log

# Export METADATA ONLY: <using Legacy EXP because it's more reliable than EXPDP in exporting DDLs>
echo
echo "CREATING A FILE CONTAINS ALL CREATION [DDL] STATEMENT OF ALL USERS|OBJECTS ..."
sleep 1
${ORACLE_HOME}/bin/exp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" OWNER=${SCHEMA_NAME} ROWS=N STATISTICS=NONE FILE=${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.dmp log=${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.log

# Removing Extra Bad characters: [DUMP REFINING]
/usr/bin/strings ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.dmp > ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc

# DRPOPPING USER DBA_BUNDLEEXP7:
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT
PROMPT DROPPING THE EXPORTER USER DBA_BUNDLEEXP7 (SAFELY) ...
DROP USER DBA_BUNDLEEXP7;
EOF

echo
echo 
echo "*****************"
echo "IMPORT GUIDELINES:"
echo "*****************"
echo "BEFORE IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE1"
echo " => THAT SCRIPT INCLUDES (USER|ROLES|GRANTED PRIVILEGES CREATION STATEMENTS), WHICH WILL NOT BE CREATED BY THE IMPORT PROCESS."
echo             
echo "AFTER IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE2"
echo " => THAT SCRIPT INCLUDES (PUBLIC SYNONYMS DDLS|PRIVILEGES GRANTED TO OTHERS|HINTS FOR TRIGGERS OWNED BY OTHERS AND DEPENDANT ON $SCHEMA_NAME OBJECTS)"
echo "    + COMPILING INVALID OBJECTS, SUCH STUFF WILL NOT BE CARRIED OUT BY THE IMPORT PROCESS."
echo
echo
echo "*********************"
echo "EXPORT FILES LOCATION:"
echo "*********************"
echo "*******************************************"
echo "SCHEMA EXPORT (DATA+METADATA) file Location: ${LOC1}/EXPORT_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp"
echo "SCHEMA METADATA ONLY Script LOCATION <IMPORTABLE (Can be Imported using [exp utility]>: ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_${DUMPDATE}.dmp"
echo "SCHEMA METADATA ONLY Script LOCATION <READABLE (CANNOT be Imported)>: ${LOC1}/${SCHEMA_NAME}_${ORACLE_SID}_METADATA_REFINED_${DUMPDATE}.trc"
echo "*******************************************"
                        echo; exit ;;
			esac
			done
		 ;;
                 n|N|no|NO|No) echo; echo "EXPORT TABLE MODE ...";echo;sleep 1; break ;;
                 *) echo "Please enter a VALID answer [Y|N]" ;;
                esac
                done


######################
# EXPORT TABLE SECTION:
######################

echo "Please Enter the TABLE OWNER:"
echo "============================"
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
echo "Please Enter the TABLE NAME:"
echo "==========================="
while read TABLE_NAME
do      
                        if [ -z ${TABLE_NAME} ]
                         then
                          echo
                          echo "Enter the TABLE NAME:"
                          echo "===================="
                         else
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER=upper('$SCHEMA_NAME') AND TABLE_NAME=upper('$TABLE_NAME');
EOF
)
                VAL22=`echo $VAL11| awk '{print $NF}'`
                                if [ ${VAL22} -eq 0 ]
                                 then
                                  echo
                                  echo "ERROR: TABLE $TABLE_NAME IS NOT EXIST ON SCHEMA [$SCHEMA_NAME] !"
                                  echo; echo "Enter the TABLE NAME:"
                                  echo "===================="
                                 else
                                  break
                                fi
                        fi
done    


echo
echo "WHICH EXPORT UTILITY YOU WANT TO USE: [1) DATAPUMP [EXPDP]]"
echo "===================================="
echo "1) DATAPUMP [EXPDP]"
echo "2) LEGACY EXPORT [EXP]"
while read EXP_TOOL
do
	case $EXP_TOOL in
	""|"1"|"DATAPUMP"|"datapump"|"DATAPUMP [EXPDP]"|"[EXPDP]"|"EXPDP"|"expdp")

cd ${LOC1}
SPOOLFILE2=AFTER_IMPORT_TABLE_${SCHEMA_NAME}.${TABLE_NAME}.sql

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT CREATE USER DBA_BUNDLEEXP7 FOR THE SAKE OF THE EXPORT (WILL BE DROPPED AFTER THE EXPORT) ...
CREATE USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
ALTER USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
GRANT DBA TO DBA_BUNDLEEXP7;
-- The following privileges to workaround Bug 6392040:
GRANT EXECUTE ON SYS.DBMS_DEFER_IMPORT_INTERNAL TO DBA_BUNDLEEXP7;
GRANT EXECUTE ON SYS.DBMS_EXPORT_EXTENSION TO DBA_BUNDLEEXP7;
PROMPT CREATING DIRECTORY EXPORT_FILES_DBA_BUNDLE POINTING TO $LOC1 ...
CREATE OR REPLACE DIRECTORY EXPORT_FILES_DBA_BUNDLE AS '$LOC1';
PROMPT
PROMPT CREATING AFTER TABLE IMPORT SCRIPT ...
PROMPT
SET PAGES 0 TERMOUT OFF LINESIZE 157 ECHO OFF FEEDBACK OFF
SPOOL $SPOOLFILE2
SELECT 'CREATE SYNONYM '||OWNER||'.'||SYNONYM_NAME||' FOR '||TABLE_OWNER||'.'||TABLE_NAME||';' FROM DBA_SYNONYMS
WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND TABLE_NAME=UPPER('$TABLE_NAME') AND OWNER <> UPPER('PUBLIC')
UNION
SELECT 'CREATE PUBLIC SYNONYM '||SYNONYM_NAME||' FOR '||TABLE_OWNER||'.'||TABLE_NAME||';' FROM DBA_SYNONYMS
WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND TABLE_NAME=UPPER('$TABLE_NAME') AND OWNER=UPPER('PUBLIC');
SPOOL OFF
EOF

echo
echo "EXPORTING TABLE [${SCHEMA_NAME}.${TABLE_NAME}] USING DATAPUMP ..."
sleep 1
${ORACLE_HOME}/bin/expdp DBA_BUNDLEEXP7/"bundle_${PASSHALF}"  REUSE_DUMPFILES=Y COMPRESSION=ALL TABLES=${SCHEMA_NAME}.${TABLE_NAME} DIRECTORY=EXPORT_FILES_DBA_BUNDLE DUMPFILE=EXPORT_${TABLE_NAME}_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp LOGFILE=EXPORT_${TABLE_NAME}_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.log

# DRPOPPING USER DBA_BUNDLEEXP7:
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT
PROMPT DROPPING THE EXPORTER USER DBA_BUNDLEEXP7 (SAFELY) ...
DROP USER DBA_BUNDLEEXP7;
EOF

echo
echo "*****************"
echo "IMPORT GUIDELINES:"
echo "*****************"
echo "AFTER IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE2"
echo " => THAT SCRIPT INCLUDES (PRIVATE & PUBLIC SYNONYMS DDLS) WHICH WILL NOT BE CREATED BY THE IMPORT PROCESS."
echo
echo
echo "*********************"
echo "EXPORT FILES LOCATION:"
echo "*********************"
echo "****************************************************"
echo "TABLE [${SCHEMA_NAME}.${TABLE_NAME}] EXPORT file Location: ${LOC1}/EXPORT_${TABLE_NAME}_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp"
echo "****************************************************"
	echo; exit ;;
	"2"|"LEGACY EXPORT"|"LEGACY"|"EXPORT"|"LEGACY EXPORT [EXP]"|"EXP"|"[EXP]"|"exp"|"legacy export"|"legacy"|"export")

cd ${LOC1}
SPOOLFILE2=AFTER_IMPORT_TABLE_${SCHEMA_NAME}.${TABLE_NAME}.sql

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT CREATE USER DBA_BUNDLEEXP7 FOR THE SAKE OF THE EXPORT (WILL BE DROPPED AFTER THE EXPORT) ...
CREATE USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
ALTER USER DBA_BUNDLEEXP7 IDENTIFIED BY "bundle_$PASSHALF";
GRANT EXP_FULL_DATABASE TO DBA_BUNDLEEXP7;
-- The following privileges to workaround Bug 6392040:
GRANT EXECUTE ON SYS.DBMS_DEFER_IMPORT_INTERNAL TO DBA_BUNDLEEXP7;
GRANT EXECUTE ON SYS.DBMS_EXPORT_EXTENSION TO DBA_BUNDLEEXP7;
PROMPT
PROMPT CREATING AFTER TABLE IMPORT SCRIPT ...
PROMPT
SET PAGES 0 LINESIZE 157 ECHO OFF FEEDBACK OFF TERMOUT OFF
SPOOL $SPOOLFILE2
SELECT 'CREATE SYNONYM '||OWNER||'.'||SYNONYM_NAME||' FOR '||TABLE_OWNER||'.'||TABLE_NAME||';' FROM DBA_SYNONYMS
WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND TABLE_NAME=UPPER('$TABLE_NAME') AND OWNER <> UPPER('PUBLIC')
UNION
SELECT 'CREATE PUBLIC SYNONYM '||SYNONYM_NAME||' FOR '||TABLE_OWNER||'.'||TABLE_NAME||';' FROM DBA_SYNONYMS
WHERE TABLE_OWNER=UPPER('$SCHEMA_NAME') AND TABLE_NAME=UPPER('$TABLE_NAME') AND OWNER=UPPER('PUBLIC');
SPOOL OFF
EOF

echo
echo "EXPORTING TABLE [${SCHEMA_NAME}.${TABLE_NAME}] USING LEGACY EXP ..."
sleep 1
${ORACLE_HOME}/bin/exp DBA_BUNDLEEXP7/"bundle_${PASSHALF}" TABLES=${SCHEMA_NAME}.${TABLE_NAME} DIRECT=y CONSISTENT=y STATISTICS=NONE FEEDBACK=1000 FILE=${LOC1}/EXPORT_${TABLE_NAME}_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp log=${LOC1}/EXPORT_${TABLE_NAME}_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.log

# DRPOPPING USER DBA_BUNDLEEXP7:
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
PROMPT
PROMPT DROPPING THE EXPORTER USER DBA_BUNDLEEXP7 (SAFELY) ...
DROP USER DBA_BUNDLEEXP7;
EOF

echo
echo "*****************"
echo "IMPORT GUIDELINES:"
echo "*****************"
echo "AFTER IMPORTING THE DUMPFILE IT'S RECOMMENDED TO RUN THIS SQL SCRIPT: ${LOC1}/$SPOOLFILE2"
echo " => THAT SCRIPT INCLUDES (PRIVATE & PUBLIC SYNONYMS DDLS) WHICH WILL NOT BE CREATED BY THE IMPORT PROCESS."
echo
echo
echo "*********************"
echo "EXPORT FILES LOCATION:"
echo "*********************"
echo "************************************************"
echo "TABLE [${SCHEMA_NAME}.${TABLE_NAME}] EXPORT file Location: ${LOC1}/EXPORT_${TABLE_NAME}_${SCHEMA_NAME}_${ORACLE_SID}_${DUMPDATE}.dmp"
echo "************************************************"
        echo; exit ;;
	esac
done
	;;
        n|N|no|NO|No) echo; echo "NO OPTIONS REMAINING !";echo "SCRIPT TERMINATED.";echo ;;
        *) echo "Please enter a VALID answer [Y|N]" ;;
        esac
        done

###############
# END OF SCRIPT
###############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# Please visit my blog: http://dba-tips.blogspot.com
# THE MORE EASY THE SCRIPT FOR THE END USER, THE MORE PAIN THE PROGRAMMER WILL GET. My Wisdom for the day !
