rem The contents of this file are subject to the InterBase Public License
rem Version 1.0 (the "License"); you may not use this file except in
rem compliance with the License.
rem     
rem You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
rem
rem Software distributed under the License is distributed on an "AS IS"
rem basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
rem the License for the specific language governing rights and limitations
rem under the License.  The Original Code was created by Inprise
rem Corporation and its predecessors.
rem
rem Portions created by Inprise Corporation are Copyright (C) Inprise
rem Corporation. All Rights Reserved.
rem 
rem Contributor(s): ______________________________________.
@echo off
nmake clean
cd ..\diffs
nmake clean
nmake -a do_diffs.obj
copy do_diffs.obj ..\tcs\do_diffs.obj
cd ..\tcs
echo Creating GTCS.GDB
gdef ..\dbs\gtcs.gdl
echo Creating LTCS.GDB
gdef ..\dbs\ltcs.gdl
nmake -a tcs.exe
echo Dropping GTCS.GDB
drop_gdb gtcs.gdb
echo Dropping LTCS.GDB
drop_gdb ltcs.gdb
copy .\ms_obj\bin\tcs.exe d:\gds\bin
