
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

#print -r Running $ROOTDIR/etc/profile.ksh >&2

# MKS Toolkit sample $ROOTDIR/etc/profile.ksh -- Modify as required.

# This file is executed by KornShells started either from login, or via
# "sh -L".  It contains global initialization commands common to all
# KornShell users and all supported operating systems.
# Operating system specific initializations for DOS, OS/2 and Windows NT
# are performed by profdos.ksh, profos2.ksh and profnt.ksh respectively.

# Turn on vi editting mode by default.
set -o vi
 
export TCSDRIVE="d:/"
export PATH="./;$TCSDRIVE/mks/mksnt;$TCSDRIVE/interbase/bin;$TCSDRIVE/borland/cbuilder4/bin;$TCSDRIVE/gds/bin;"

# Required by the default ENVIRON file provided.
# export SWITCHAR=/

# LOGNAME identifies the current user name.
export LOGNAME=${LOGNAME:=mks}

# ROOTDIR identifies the directory in which the Toolkit is installed.
# export ROOTDIR=${ROOTDIR:=$TCSDRIVE}; ROOTDIR=${ROOTDIR%/}
export ROOTDIR=$TCSDRIVE/mks

# Only define the following if they aren't defined in the OS-specific profile.

# TZ identifies the local time zone. See the timezone(5) manual page.
export TZ=${TZ:=PST}

# TMPDIR identifies the directory in which most Toolkit utilities store
# their temporary files.
export TMPDIR=${TMPDIR:=$ROOTDIR/tmp}

export HOME=$TCSDRIVE/testbed

# Set up environment file, to be processed by all shells at startup.
export ENVIRON=$TCSDRIVE/mks/etc/environ.ksh

# The following is a simple definition that will process ENVIRON in
# *all* shells.
export ENV=$ENVIRON
