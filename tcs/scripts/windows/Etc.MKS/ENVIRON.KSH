
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

# Create a new command history file for each KornShell.  This avoids
# history file conflicts when two or more KornShells are open
# simultaneously.  Highly recommended for DOS with Windows, OS/2 and
# Windows NT.
# if [ _$- != _${-%%*i*} ]; then . $ROOTDIR/etc/newhist.ksh; fi

# Enable Vi style in-line editor for command entry.  Uncomment to use.
#set -o vi

# Aliases to mimic the standard command interpreters and access their
# built-in commands.
alias a:="cd a:" b:="cd b:" c:="cd c:" d:="cd d:" e:="cd e:"
alias md=mkdir rd=rmdir
export SWITCHAR=${SWITCHAR:=/}	# if not already defined
for arg in cls copy del dir erase move path ren type ver verify vol
do
	alias $arg="'${COMSPEC}' ${SWITCHAR}c $arg"
done
# Change console.  Applicable only to DOS KornShells.
#if [ $(uname) = DOS ];then ctty() { exec > $1 2>&1 <&1; }; fi

# Applicable only to DOS KornShells.
# If you make a habit of stopping Vi, or otherwise using
# Terminate-And-Stay-Resident (TSR) programs that are not installed from
# $ROOTDIR/etc/inittab, then this ulimit command avoids memory conflict
# in sub-shells as well as the login shell.
# Uncomment to use; -d parameter can be adjusted downwards.
#if [ $(uname) = DOS ]; then ulimit -d 48; fi

# Here is an assortment of command line prompts.  Choose one by
# deleting or commenting-out all others.
PS1='[$PWD] '
#PS1="$ "			# a simple default prompt
#PS1="!% "			# prompt with history number
#typeset -u PS1='$PWD>'		# equivalent to command prompt $p$g
#typeset -u PS1='${PWD%%:*}>'	# equivalent to command prompt $n$g
# It might be instructive to figure out how this next prompt works.
#typeset -Z2 H M S; let SECONDS=`date '+(%H*60+%M)*60+%S'`
#PS1='${__[(H=SECONDS/3600%24)==(M=SECONDS/60%60)==(S=SECONDS%60)]-$H:$M:$S}>'
