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

$ set verify
$ link /NOMAP/NODEBUG/NOTRACE/exe=isc_diff'p1 sys$input/opt
source:[diffs]diffs.obj
source:[diffs]do_diffs.obj
sys$library:vaxcrtlg.exe/share
interbase:[syslib]gdsshr.exe/share
psect = sys_errlist,noshr,nowrt
psect = sys_nerr,noshr,nowrt
