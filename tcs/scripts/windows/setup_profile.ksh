
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
        echo  ""
        echo "Your newly created testbed/profile.ksh:"
        echo
        cat profile.ksh ;;     
esac


cp /testbed/profile.ksh /testbed/keep/profile.ksh


echo
echo "NOTE: You must exit this shell and open a new shell to read your new environment"
echo ""
echo "NOTE: You must run tcsexpand after you open your new shell."
echo ""

