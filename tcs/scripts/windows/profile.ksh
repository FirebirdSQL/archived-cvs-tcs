
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

export TZ=PDT
#This file is executed by KornShells started either from login, or via
# "sh -L".  It contains local initialization commands for TCS test setup.
#
#Set this to = the protocol of the client--so NP must be Client because
#We are always going remote.  Only local should be set to Server
export SETTING=Server
#export SETTING=Client

#Named Pipe
#export WHERE_GSEC=//intelX/$TCSDRIVE/interbase
#export CLIENT_TESTBED=//intelX/$TCSDRIVE/testbed
#export WHERE_GDB=//intelX/$TCSDRIVE/testbed
#export WHERE_GDB1=//intelX/$TCSDRIVE/testbed
#export WHERE_GDB2=//intelX/$TCSDRIVE/testbed
# where_gdb4 is used to gbak a file to a local dir. Make sure it is local.
#export WHERE_GDB3=$TCSDRIVE/testbed
#export REMOTE_DIR11=$TCSDRIVE/testbed/remote
#export REMOTE_DIR=$TCSDRIVE/testbed
#export WHERE_GDB_EXTERNAL=$TCSDRIVE/testbed
#export SERVICE_MGR=//intelX/service_mgr

#TCP/IP
#export WHERE_GSEC=intelX:$TCSDRIVE/interbase
#export CLIENT_TESTBED=intelX:$TCSDRIVE/testbed
#export WHERE_GDB=intelX:$TCSDRIVE/testbed
#export WHERE_GDB1=intelX:$TCSDRIVE/testbed
#export WHERE_GDB2=intelX:$TCSDRIVE/testbed
# where_gdb4 is used to gbak a file to a local dir. Make sure it is local.
#export WHERE_GDB3=$TCSDRIVE/testbed
#export REMOTE_DIR11=$TCSDRIVE/testbed/remote
#export REMOTE_DIR=$TCSDRIVE/testbed
#export WHERE_GDB_EXTERNAL=$TCSDRIVE/testbed
#export SERVICE_MGR=intelX:service_mgr

#local 
export WHERE_GSEC=$TCSDRIVE/interbase
export CLIENT_TESTBED=$TCSDRIVE/testbed
export WHERE_GDB=$TCSDRIVE/testbed
export WHERE_GDB1=$TCSDRIVE/testbed
export WHERE_GDB2=$TCSDRIVE/testbed
# where_gdb4 is used to gbak a file to a local dir. Make sure it is local.
export WHERE_GDB3=$TCSDRIVE/testbed
export REMOTE_DIR11=$TCSDRIVE/testbed/remote
export REMOTE_DIR=$TCSDRIVE/testbed
export WHERE_GDB_EXTERNAL=$TCSDRIVE/testbed
#Interbase installation directory
export INTERBASE=$TCSDRIVE/interbase
#this syntax does not work due to bug in tcs
export SERVICE_MGR=service_mgr
