
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

bindir='getconf _CS_PATH'
#!$BINDIR/sh
unset BINDIR
#
#----------------------------------------------------------------------------
#
# FILENAME:	tcsrun.sh
# MODULE:	
#
# DESCRIPTION:	This file is the template script for running TCS.  It will
#		redirect STDIN and pass a file of commands into TCS.
#
#----------------------------------------------------------------------------
# START TCS SETUP PHASE
#
clear
# determine if tcs is going to be testing the latest server through named pipes
# tcp/ip and spx_ipx

if [ ! "$SETTING" = "Client" ] && [ ! "$SETTING" = "Server" ]
then
  # this machine is going to be used for testing server access on a peer-to-peer network
  
  # get the access method from the directory name.  This is assuming that you will be 
  # correct directory for the protocol being tested.

  protocol=`echo $SETTING | cut -f 2 -d ":" -`
  machine=`echo $SETTING | cut -f 1 -d ":" -`
  case $protocol in
    ipc) echo 'Protocol '$protocol' needs to be started from the TESTBED directory.  Exiting.'
         rm -f tcsrun.temp*
	 exit 1 ;;
    tcp_ip) export CLIENT_TESTBED=$machine':$TCSDRIVE/tcs/'$protocol'/'$COMPUTERNAME ;;
    npipes) export CLIENT_TESTBED='//'$machine'/$TCSDRIVE/tcs/'$protocol'/'$COMPUTERNAME ;;
    spx_ipx) export CLIENT_TESTBED='@'$machine'/$TCSDRIVE/tcs/'$protocol'/'$COMPUTERNAME ;;
    *) echo 'Protocol '$protocol' not supported.  Exiting.'
       rm -f tcsrun.temp*
       exit 1 ;;
  esac
  echo 'Setting up TCS.'
  echo 'Server being use$TCSDRIVE '$machine
  echo 'Protocol being teste$TCSDRIVE '$protocol
 
  remote_path=$TCSDRIVE/testbed

# The  Setting is either Sever or Client
else
  echo 'Setting up TCS.'
  echo 'Area being tested' "$TCSDRIVE $SETTING"

# the second character will be : if its a drive which means that you are testing the
# server since no server name was given (we don't have any 1 character server names)
 
  npipe=`echo $CLIENT_TESTBED | cut -f 1,2 -d "/" -`
  spx=`echo $CLIENT_TESTBED | cut -f 1 -d "@" -`
  server=`echo $CLIENT_TESTBED | cut -b 2 - `
  if [ ! "$server" = ":" ]
  then
    if [ $npipe = "/" ]
    then
      server=`echo $CLIENT_TESTBED | cut -f 3 -d "/" - `
      echo 'Server running on:' ${server}' via NAMED PIPES.'
      remote_path=`echo $CLIENT_TESTBED | cut -f 4,5 -d "/" - `
      protocol=npipes
    else
      if [ $spx != $CLIENT_TESTBED ]
      then
        server=$spx
        echo 'Server running on:' ${server}' via SPX/IPX'
        remote_path=`echo $CLIENT_TESTBED | cut -f 2 -d "@" -`
        protocol=spx_ipx
      else
        server=`echo $CLIENT_TESTBED | cut -f 1 -d ":" - `
        echo 'Server running on:' ${server}' via TCP/IP.'
        remote_path=`echo $CLIENT_TESTBED | cut -f 2,3 -d ":" -`
        protocol=tcpip
      fi
    fi
  else
    server=`uname -n`
    echo 'Server running on ' $server ' via IPC.'
    remote_path=$CLIENT_TESTBED
    protocol=ipc
  fi 

fi

#  Check to see that a tcsrun.input file exists
#

if [ ! -f "tcsrun.input" ]
then
   echo "tcsrun.input file does not exist..."
   rm -f tcsrun.temp*
   exit 1 
fi
#
#  Get rid of all the comments in the tcsrun.input file
#
grep -v '^#' tcsrun.input > tcsrun.temp0

#
#  Find out the number of iteration we need to go
#
maxloop=1

while [ `grep -c "\$CONFIG$maxloop:" tcsrun.temp0` -gt 0 ]
do
  maxloop=`expr $maxloop + 1`
done

#
#  Error if there is no $CONFIG in the tcsrun.input file
#
if [ $maxloop -eq 1 ]
then
   echo "No \$CONFIG line found in the tcsrun.input file"
   rm -f tcsrun.temp*
   exit 1
fi

# TCS SETUP PHASE COMPLETE
#----------------------------------------------------------------------------
# START TCS TEST PHASE
#
rm -f tcsrun.temp*

loop=1
while [ $loop -lt $maxloop ]
do
#
#  PARSE thru the tcsrun.input file gathering all the needed information
#
   grep -v '^#' tcsrun.input > tcsrun.temp0

   grep "\$CONFIG$loop:" tcsrun.temp0 > tcsrun.temp1

   grep -v "FILE" tcsrun.temp1 | grep -v "SHELL" | grep -v "srn" | sed -e "s/\$CONFIG$loop://" > .tcs_config
   
   case $SETTING in
     Client) rm -f tcsrun.temp3

       # Set WHERE_GDB* which are always the same as CLIENT_TETSBED
	  echo 'WHERE_GDB='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB' >> tcsrun.temp3
	  echo 'WHERE_GDB1='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB1' >> tcsrun.temp3
	  echo 'WHERE_GDB2='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB2' >> tcsrun.temp3
	  echo 'WHERE_GDB3='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB3' >> tcsrun.temp3

        # Set up GSEC properly

        # Rely on sys env since we do not know where exactly
        # Interbase is on a remote machine.
          echo 'WHERE_GSEC=${WHERE_GSEC}' >> tcsrun.temp3
          echo 'export WHERE_GSEC' >> tcsrun.temp3

          echo 'REMOTE_DIR11='${remote_path} >> tcsrun.temp3
	  echo 'export REMOTE_DIR11' >> tcsrun.temp3

	  echo 'WHERE_GDB_EXTERNAL='$remote_path >> tcsrun.temp3
	  echo 'export WHERE_GDB_EXTERNAL' >> tcsrun.temp3 
   
          echo 'REMOTE_DIR='${remote_path} >> tcsrun.temp3
	  echo 'export REMOTE_DIR' >> tcsrun.temp3

      ;;

      Server)
          grep "SHELL" tcsrun.temp1 | sed -e "s/\$CONFIG$loop://" -e "s/SHELL//" > tcsrun.temp3

  	  echo 'REMOTE_DIR='$CLIENT_TESTBED >> tcsrun.temp3
          echo 'export REMOTE_DIR' >> tcsrun.temp3

          echo 'WHERE_GSEC='${WHERE_GSEC} >> tcsrun.temp3
          echo 'export WHERE_GSEC' >> tcsrun.temp3
       ;;

   # Neither server nor client
      *) rm -f tcsrun.temp3
	  echo 'WHERE_GDB='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB' >> tcsrun.temp3

	  echo 'WHERE_GDB1='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB1' >> tcsrun.temp3

	  echo 'WHERE_GDB2='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB2' >> tcsrun.temp3

	  echo 'WHERE_GDB3='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export WHERE_GDB3' >> tcsrun.temp3

	  echo 'REMOTE_DIR11='$CLIENT_TESTBED >> tcsrun.temp3
	  echo 'export REMOTE_DIR11' >> tcsrun.temp3

          echo 'WHERE_GDB_EXTERNAL=$TCSDRIVE/tcs/'$protocol'/'$COMPUTERNAME >> tcsrun.temp3
          echo 'export WHERE_GDB_EXTERNAL' >> tcsrun.temp3

	  echo 'REMOTE_DIR=$TCSDRIVE/tcs/'$protocol'/'$COMPUTERNAME >> tcsrun.temp3
          echo 'export REMOTE_DIR' >> tcsrun.temp3

          echo 'WHERE_GSEC=$TCSDRIVE/interbase' >> tcsrun.temp3
          echo 'export WHERE_GSEC'  >> tcsrun.temp3 
      ;;
          
   esac

# Set up the environment
#   . ./tcsrun.temp3

# reset the suffix on the log file to correspond with the access method.
   if [ "$SETTING" = "Server" ] || [ "$SETTING" = "Client" ]
   then
     file=`grep "FILE" tcsrun.temp1 | awk '{print $3}'`
   else
     file=$protocol
   fi

   grep -v "\$CONFIG" tcsrun.temp0 > tcsrun.temp2

#
#  Move the LOG file if it already exists
#
   if [ -f "$file" ]
   then
     num=1
     while [ -f "$file.$num" ]
     do
       num=`expr $num + 1`
     done
     mv "$file" "$file.$num"
   fi

   # the line below doesn't seem to do anything
   if [ ! "$PROCESSOR_ARCHITECTURE" = "PPC" ]
   then
     convtool -f tcsrun.temp3 -v $WHERE_GDB/
   fi

   # Find out the versions of interbase
   # get the server and client versions if running under win nt or
   # win 95

cat << EOF > tcsrun.temp300
create database "${WHERE_GDB}/XXXX.gdb";
show  version;
drop database;
quit;
EOF

   isql -i tcsrun.temp300 > tcsrun.temp4 2>&1
   if [ `grep -c "remote server" tcsrun.temp4` -gt 0 ]
   then
           # Get client information
      server_version=`grep "remote server" tcsrun.temp4 | awk '{print $6" "$7}'`
      client_version=`grep "remote interface" tcsrun.temp4 | awk '{print $6" "$7}'`
   else
           # Get server information
      server_version=`grep "access method" tcsrun.temp4 | awk '{print $6" "$7}'`
      client_version=`grep "access method" tcsrun.temp4 | awk '{print $6" "$7}'`
   fi

# if both the Client_version and the Server_version are null, then the initial isql connect
# failed so abort tcsrun.ksh with an error

if [ ! "$client_version" ] && [ ! "$server_version" ]
then
  case $SETTING in
   Server) echo 'Could not make a connection to the server.  Make sure that it is active.' ;;
   Client) echo 'The client library could not connect to the server: '$server'.'
           echo 'Make sure the server is running and listening on the desired protocol.' ;;
   *) echo 'Could not connect to the specified server on '$SETTING 
      echo 'Make sure that all the directories exist and the server is listening via '$protocol'.';;
  esac
  rm -f tcsrun.temp*
  exit 1
fi
# echo the server and client information to the screen
echo 'Server Version: '$server_version
echo 'Client Version: '$client_version

#
#  Echo the Header to the LOG file
#
# Get the OS Information and store it in a file that will not be deleted at the
# end of the run since uname only returns part of the information when called more
# than one time.

  echo '==============================================================================='> $file
     echo 'Test run date:    '`date`                  >>$file
     echo 'Platform/Node/OS: '`uname -a`              >>$file
     echo 'Test engineer:    '$LOGNAME                >>$file
     echo 'InterBase Server Version: '$server_version >>$file   
     echo 'InterBase Client Version: '$client_version >>$file
  echo '===============================================================================\r'>> $file
#
#  Run tcs
#
    start tail -f $file
    echo 'Starting TCS on '`date`
    tcs -m -d"test-dbs/nt_ltcs.gdb" -g"test-dbs/gtcs.gdb"< tcsrun.temp2 >> $file 2>&1
#
#  Echo the end of the LOG file
#
   echo '\n==============================================================================='>> $file
   echo 'Test End date:     '`date` >>$file
   echo '==============================================================================='>> $file
#
#  Get rid of the temp files
#
   rm -f tcsrun.temp*
   loop=`expr $loop + 1`
       
done
#
# TCS TEST PHASE COMPLETE
#----------------------------------------------------------------------------

# print summary information

local_tests=`grep -c "Running local" ${file}`
global_tests=`grep -c "Running global" ${file}`

tt=`expr $local_tests + $global_tests`          #total tests run
ft=`grep -c "\*\*\* failed" ${file}`    #total failed tests
rt=`grep -c "only" ${file}`		#total read-only tests

echo 'Finished TCS on '`date`
echo '====================================' >> $file
echo 'Summary Information:' >> ${file} 
echo 'Number of tests run       : '$tt  >> $file
echo 'Number of failed tests    : '$ft  >> $file
echo 'Number of read-only tests : '$rt  >> $file
echo '===================================='
echo 'Summary Information:'
echo 'Number of tests run       : '$tt
echo 'Number of failed tests    : '$ft
echo 'Number of read-only tests : '$rt

if [ $tt -gt 0 ]
then
  echo 'Percent of tests passed   : '`echo '2 k '$tt' '$ft' - '$tt' / 100 * p' | dc` >> $file
  echo 'Percent of tests passed   : '`echo '2 k '$tt' '$ft' - '$tt' / 100 * p' | dc`
else
  echo 'Percent of tests passed   : No Tests Run' >> $file
  echo 'Percent of tests passed   : No Tests Run'
fi
echo '\n==================================\n' >> $file
echo '\n==================================\n'

# save the logfile 
root_dir=$PWD
log_ext=`date +%b%d_%H.%M%.%S`
logname="$file.$log_ext.log"
cp $root_dir/$file $logname
