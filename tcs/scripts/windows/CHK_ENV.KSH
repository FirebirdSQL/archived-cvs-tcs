
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

############################################
# chk_env.ksh
#
# Description: A simple Shell script that accepts no arguments.
#              This script checks and displays Environment variables
#              It prints out a warning if something is incorrect or not set.
#
#############################################

# A Shell function that accepts two (2) arguments
#  1 - A message to be printed.
#  2 - The second argument is either TRUE or FALSE.
#      This allows to terminate the script if the error is fatal
display_message()
{
  if [ $2 = "TRUE" ]
  then
    echo Fatal: $1;
    echo
    exit 1;
  else
    echo
    echo Warning: $1;
    echo
  fi
}

echo
echo Checking your test setup...
echo

if [ -z "$TCSDRIVE" ]; then
   echo "FATAL ERROR:  environment variable \$TCSDRIVE"
   echo ""
   exit 0
fi



# CLIENT_TESTBED is present ?
[ -z "$CLIENT_TESTBED" ] && display_message "CLIENT_TESTBED is not set" "TRUE"

echo CLIENT_TESTBED is: $CLIENT_TESTBED

[ -z "$SETTING" ] && display_message "SETTING is not set" "TRUE"

echo SETTING is: $SETTING

[ $SETTING != "Client" -a $SETTING != "Server" ] && display_message "SETTING is incorrect" "FALSE"

if [ -z "$WHERE_GSEC" ]
then
   display_message "WHERE_GSEC is not set. Set it."  "FALSE"
else
  echo WHERE_GSEC is: $WHERE_GSEC
fi

npipe=`echo $CLIENT_TESTBED | cut -f 1,2 -d "/" -`
spx=`echo $CLIENT_TESTBED | cut -f 1 -d "@" -`
server=`echo $CLIENT_TESTBED | cut -b 2 - `

if [ ! "$server" = ":" ]
then
  
[ $SETTING != "Client" ] && display_message "SETTING could not be Server" "TRUE"

    if [ $npipe = "/" ]
    then
      server=`echo $CLIENT_TESTBED | cut -f 3 -d "/" - `
      echo 'Server running on:' ${server}' via NAMED PIPES.'
      remote_path=`echo $CLIENT_TESTBED | cut -f 4,5 -d "/" - `
    else
      if [ $spx != $CLIENT_TESTBED ]
      then
        server=$spx
        echo 'Server running on:' ${server}' via SPX/IPX'
        remote_path=`echo $CLIENT_TESTBED | cut -f 2 -d "@" -`
      else
        server=`echo $CLIENT_TESTBED | cut -f 1 -d ":" - `
        echo 'Server running on:' ${server}' via TCP/IP.'
        remote_path=`echo $CLIENT_TESTBED | cut -f 2,3 -d ":" -`
      fi
    fi
   
else
[ $SETTING != "Server" ] && display_message "SETTING could not be Server" "TRUE"

    server=`uname -n`
    echo 'Server running on ' $server ' via IPC.'
    remote_path=$CLIENT_TESTBED
fi 

echo
echo Your setup looks fine
echo
echo

tests="`egrep '^(r|rs|rms) ' tcsrun.input`"
if [ -z "$tests" ]; then
  echo "WARNING: No Tests Are Set To Run..."
else
  echo "The following tests are set to run:"
  egrep '^(r |\*|rs |rms )' tcsrun.input 
fi

echo ""
echo ""


exit 0
