
# The contents of this file are subject to the InterBase Public License
# Version 1.0 (the "License"); you may not use this file except in
# compliance with the License.
#
# You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.  The Original Code was created by Inprise
# Corporation and its predecessors.
#
# Portions created by Inprise Corporation are Copyright (C) Inprise
# Corporation. All Rights Reserved.
#
# Contributor(s): ______________________________________.

#----------------------------------------------------------------------------------------
#
# FILENAME: setup_config.ksh
# DESCRIPTION:  This script creates a /testbed/profile.ksh that exports shell
#               variables needed to run a particular TCS test configuration.
#               The variables WHERE_xxx, REMOTE_DIRxxx and SERVICE_MGR are exported 
#               by /testbed/profile.ksh and are used by tcs.exe.  Variables PROTO and       
#               SERVER_OS are also exported by /testbed/profile.ksh and are used by
#               tcsrun_mlog to create TCS test log names and log directories.
#
#               The user is prompted to enter the server machine name, server operating
#               system type, server testbed directory and protocol.  The  server OS and
#               protocol are input error checked.  This script also checks that the user
#               enters the appropriate testbed directory if the protocol is ipc.
#

if [ $# -ne 1 ] 
then
  echo "You did not enter an InterBase Version number."
  echo "Exiting"
  exit 1
fi

#--------------------------------------------------------------------------------------------
# creating .tcs_config and tcsrun.input
#--------------------------------------------------------------------------------------------

newval="$1"
driveletter=`echo $TCSDRIVE | awk -F: '{ print $1 }'`

if [ $newval = "6.0" ]
     then
     echo "sb qa_v60_sdk_cb4_${driveletter}driv" > .tcs_config
     echo "svr 6.0" >> .tcs_config
     echo "se qa_v60_sdk_cb4_${driveletter}driv" >> .tcs_config
     echo "sdv run=" >> .tcs_config
     echo "sdv cc=bcc32" >> .tcs_config
     echo "sdv link=ilink32" >> .tcs_config
     echo "sdv make=make" >> .tcs_config
     echo "sdv isql=isql_d1" >> .tcs_config
     echo "sdv gpre=gpre_d1" >> .tcs_config
     
     cat tcsrun.upper > tcsrun.input
     echo "\$CONFIG1: sb qa_v60_sdk_cb4_${driveletter}driv" >> tcsrun.input
     echo "\$CONFIG1: svr 6.0" >> tcsrun.input
     echo "\$CONFIG1: se qa_v60_sdk_cb4_${driveletter}driv" >> tcsrun.input
     echo "\$CONFIG1: sdv run=" >> tcsrun.input
     echo "\$CONFIG1: sdv cc=bcc32" >> tcsrun.input
     echo "\$CONFIG1: sdv link=ilink32" >> tcsrun.input
     echo "\$CONFIG1: sdv make=make" >> tcsrun.input
     echo "\$CONFIG1: sdv isql=isql_d1" >> tcsrun.input
     echo "\$CONFIG1: sdv gpre=gpre_d1" >> tcsrun.input 
     echo "\$CONFIG1: srn QATEST" >> tcsrun.input
     cat tcsrun.lower >> tcsrun.input 


else
   echo "Invalid IB version on command line."
   exit 1
fi 

echo
echo 
echo "                   PROFILE.KSH SETUP"
echo "                  __________________"
echo
if [ -z "$TCSDRIVE" ]; then
   echo "FATAL ERROR:  environment variable \$TCSDRIVE"
   exit 0
fi
echo "You will be prompted to enter the server name, server operating system,"
echo "server testbed drive and protocol you wish to use for your next test"
echo "configuration."
echo
echo
echo "____________________________________________________________________"
echo 
echo "Server operating sytems: NT"
echo "                         W95"
echo "                         W98"
echo "                         NT-SMP"
echo
echo "Protocols:               tcp"
echo "                         np"
echo "                         ipc"
echo
echo "Server testbed drives:  $TCSDRIVE, $testbed_drive, e:, etc."
echo
echo "Server machines are named with their network names."
echo "____________________________________________________________________"
echo

echo "Enter protocol"
read protocol
echo


case $protocol in
 [nN][pP])  protocol=np ;;
 [tT][cC][pP]) protocol=tcp ;;
 [iI][pP][cC]) protocol=ipc ;;
   *) echo "You did not enter a valid protocol. Exiting."
      exit 1 ;;
esac

if [ "$protocol" = "ipc"  ]
then 
   testbed_drive=$TCSDRIVE
   server_os=`uname -s | awk -F_ '{print $NF}'`

   # Add a leading 'w' if Win95/98 for later checks.
   if [ $server_os != "NT" ]; then
      server_os="w$server_os"
   fi
fi

# Else we're not running IPC, so we need to get info from the user.


if  [ "$protocol" = "np" ] 
then
   echo "Enter server machine:"
   read server
   echo
   else if [ "$protocol" = "tcp" ]
        then
           echo "Enter server machine:"
           read server
           echo
   fi   
fi

if [ $protocol != "ipc" ]
then
echo "Enter server operating system:"
read  server_os
echo
fi

case $server_os in
 [nN][tT])  server_os=NT ;;
 [wW]95) server_os=W95 ;;
 [wW]98) server_os=W98 ;;
 95) server_os=W95 ;;
 98) server_os=W98 ;;
 [nN][tT]-[sS][mM][pP]) server_os=NT-SMP ;;
      *) echo "You did not enter a valid server operating system. Exiting."
         exit 1 ;;
esac

if [ $protocol != "ipc" ]
then
echo "Server testbed drive:"
read testbed_drive
if [ "`echo $testbed_drive | grep ':$'`" = "" ]; then
   testbed_drive="${testbed_drive}:"
fi
echo
fi


case $protocol in
   np)  echo 'export TZ=PDT' > profile.ksh
        echo 'export SETTING=Client' >> profile.ksh
        echo 'export PROTO=np' >> profile.ksh
        echo 'export SERVER_OS='$server_os >> profile.ksh
        echo 'export WHERE_GSEC=//'$server'/'$testbed_drive'/interbase' >> profile.ksh
        echo 'export CLIENT_TESTBED=//'$server'/'$testbed_drive'/testbed' >> profile.ksh
        echo 'export WHERE_GDB=//'$server'/'$testbed_drive'/testbed' >> profile.ksh 
        echo 'export WHERE_GDB1=//'$server'/'$testbed_drive'/testbed' >> profile.ksh  
        echo 'export WHERE_GDB2=//'$server'/'$testbed_drive'/testbed' >> profile.ksh 
        echo 'export WHERE_GDB3='$TCSDRIVE'/testbed' >> profile.ksh
        echo 'export WHERE_GDB4='$testbed_drive'/testbed' >> profile.ksh       
        echo 'export REMOTE_DIR11='$testbed_drive'/testbed/remote' >> profile.ksh
        echo 'export REMOTE_DIR='$testbed_drive'/testbed' >> profile.ksh
        echo 'export WHERE_GDB_EXTERNAL='$testbed_drive'/testbed' >> profile.ksh
        echo 'export WHERE_UDF='$testbed_drive'/interbase/UDF' >> profile.ksh
        echo 'export SERVICE_MGR=//'$server'/service_mgr' >> profile.ksh
	echo '# No CLASSPATH or WHERE_URL for np protocol.' >> profile.ksh
	echo '# InterClient only works for tcp.' >> profile.ksh
        echo ""
        echo "Your newly created testbed/profile.ksh:"
        echo 
        cat profile.ksh ;;

  tcp)  echo 'export TZ=PDT' > profile.ksh       
        echo 'export SETTING=Client' >> profile.ksh
        echo 'export PROTO=tcp' >> profile.ksh
        echo 'export SERVER_OS='$server_os >> profile.ksh
        echo 'export WHERE_GSEC='$server':'$testbed_drive'/interbase' >> profile.ksh
        echo 'export CLIENT_TESTBED='$server':'$testbed_drive'/testbed' >> profile.ksh
        echo 'export WHERE_GDB='$server':'$testbed_drive'/testbed' >> profile.ksh 
        echo 'export WHERE_GDB1='$server':'$testbed_drive'/testbed' >> profile.ksh  
        echo 'export WHERE_GDB2='$server':'$testbed_drive'/testbed' >> profile.ksh 
        echo 'export WHERE_GDB3='$TCSDRIVE'/testbed' >> profile.ksh
        echo 'export WHERE_GDB4='$testbed_drive'/testbed' >> profile.ksh 
        echo 'export REMOTE_DIR11='$testbed_drive'/testbed/remote' >> profile.ksh
        echo 'export REMOTE_DIR='$testbed_drive'/testbed' >> profile.ksh
        echo 'export WHERE_GDB_EXTERNAL='$testbed_drive'/testbed' >> profile.ksh
        echo 'export WHERE_UDF='$testbed_drive'/interbase/UDF' >> profile.ksh   
        echo 'export SERVICE_MGR='$server':service_mgr' >> profile.ksh
        echo 'export CLASSPATH="'$testbed_drive'/interbase/InterClient/interclient.jar;'$testbed_drive'/testbed"' >> profile.ksh
        echo 'export WHERE_URL=jdbc:interbase://'$server'/'$testbed_drive'/testbed' >> profile.ksh
        echo ""
        echo "Your newly created testbed/profile.ksh:"
        echo
        cat profile.ksh ;; 

  ipc)  echo 'export TZ=PDT' > profile.ksh
        echo 'export SETTING=Server' >> profile.ksh
        echo 'export PROTO=ipc' >> profile.ksh
        echo 'export SERVER_OS='$server_os >> profile.ksh
        echo 'export WHERE_GSEC='$testbed_drive'/interbase' >> profile.ksh
        echo 'export CLIENT_TESTBED='$testbed_drive'/testbed' >> profile.ksh
        echo 'export WHERE_GDB='$testbed_drive'/testbed' >> profile.ksh 
        echo 'export WHERE_GDB1='$testbed_drive'/testbed' >> profile.ksh  
        echo 'export WHERE_GDB2='$testbed_drive'/testbed' >> profile.ksh 
        echo 'export WHERE_GDB3='$TCSDRIVE'/testbed' >> profile.ksh
        echo 'export WHERE_GDB4='$TCSDRIVE'/testbed' >> profile.ksh 
        echo 'export REMOTE_DIR11='$TCSDRIVE'/testbed/remote' >> profile.ksh
        echo 'export REMOTE_DIR='$TCSDRIVE'/testbed' >> profile.ksh
        echo 'export WHERE_GDB_EXTERNAL='$TCSDRIVE'/testbed' >> profile.ksh
        echo 'export WHERE_UDF='$TCSDRIVE'/interbase/UDF' >> profile.ksh 
        echo 'export SERVICE_MGR=service_mgr' >> profile.ksh
	echo '# No CLASSPATH or WHERE_URL for ipc protocol.' >> profile.ksh
	echo '# InterClient only works for tcp.' >> profile.ksh
        echo  ""
        echo "Your newly created testbed/profile.ksh:"
        echo
        cat profile.ksh ;;     
esac

echo
echo "Your newly created .tcs_config: "
echo
cat .tcs_config
echo


# Allow the user to specify the tests they want to run.
echo ""
echo ""
echo "Press return to specify the tests/series/metaseries you want to run..."
read var
viw -c /rms tcsrun.input


# Save the configuration files for the user.
save_config


echo
echo "NOTE: You must exit this shell and open a new shell to read your new environment"
echo ""
echo "NOTE: You must also run tcsexpand after you open your new shell."
echo ""
