
Welcome to TCS - buggered if I know what it stands for but you can 
use it to test Firebird or InterBase.

This readme was done in 5min flat so apologies in advance.


BUILDING 

First you need to build the tcs programs and restore the databases
the script file buildInstall.sh describes how to do that, if you
are lucky you can run it, if not the procedure is simple and you
can get it by reading the script.

(The rest of this was written by Frank, as part of an email.  But it
helped get me started)

MOD 27-July-2001


QUICK TEST 

cd tcs/scripts

./runtcs or ./runtcs.fb2

at the prompt type in

ls
exit

Check out the file .tcs_config for config.




QUICK NOTES ON HOW TO USE

Using the test control system on Linux

cd into the directory where you have installed the TCS (TCS/tcs/scripts)

If you don't like vi and don't want to set the EDITOR variable globally,
add a line like
EDITOR=joe -nobackups
at the beginning of the runtcs script.

Start the tcs with runtcs.

You will see something like

Mit Okt 18 15:53:43 MEST 2000
record not found for user: QA_FRANK
Reading configuration file ".tcs_config"...
        Version set to:         6.0.0
        Boilerplate set to:     BP_FB
        Environment set to:     QA_FB
        Run set to:             FIREBIRD

Scanning System Environment for REMOTE variables
        REMOTE_DIR1=/home/frank/TCS/FB_test
        WHERE_GDB=/home/frank/TCS/FB_test
        REMOTE_DIR11=/home/frank/TCS/FB_test
        WHERE_GDB1=/home/frank/TCS/FB_test
        WHERE_GDB2=/home/frank/TCS/FB_test
        WHERE_GDB3=/home/frank/TCS/FB_test
        WHERE_GDB_EXTERNAL=/home/frank/TCS/FB_test
        REMOTE_DIR=/home/frank/TCS/FB_test

        Welcome to TCS: V4.16   29-Jan-1998
tcs>

At the first start there will be probably some more record not found messages.

The first test is to enter
EE QA_FB
at the tcs> prompt.

This will just return you to the tcs> prompt if your IB server has a broken BLOB_edit.
To use any of the edit functions of the TCS you will need to install a newer
server (a newer gds.so may be enough, but I don't know)

If you have a server with a working BLOB_edit function, your favorite
editor will be started and you may edit the test environment.
Don't do this now, just leave the editor.
You will be returned to the tcs> prompt.

Now you can run single tests:

tcs> r cf_isql_01

or series

tcs> rs cf_isql

or the whole suite

tcs> rms VECTOR_12HOUR

Newer firebird servers should pass the whole suite.
If there where failures you can list them with:

tcs> lf

And here is a list of all commands that are available:
	AS	add_series <series> to <meta_series> [<sequence>]
	AT	add test <test> to <series> [<sequence>]
	BR	browse for tests containing <string>
	C	commit changes

	CB	create <boiler_plate> using [<template>]
	CE	create <environment> using [<template>]
	CLT	create local <test> [<version>]
	CMS	create <meta_series> (global)
	CS	create <series>  (global, EOF to end list)
	CT	create <test> [<version>] (global)

	DAF	delete all failures for [<run>]/current run
	DF	delete failure for <test> for current run
	DI	delete initialization for <test> [<version>] (global)
	DLI	delete local initialization for <test> [<version>]
	DLT	delete local <test> [<version>]
	DT	delete <test> [<version>] (global)
	DTS	delete <test> from <series>
		(test remains in DB, all copies removed from series)
	DTM	delete timing information

	DUPGG	duplicate <test_1> <version_1> <test_2> <version_2>
		global to global
	DUPGL	duplicate <test_1> <version_1> <test_2> <version_2>
		global to local
	DUPLL	duplicate <test_1> <version_1> <test_2> <version_2>
		local to local

	E	edit <test> [<version>] (global)
	EE	edit <environment>
	EB	edit <boiler plate>
	EC	edit comment from <test> (global)
	EGI	edit global initialization of <test> [<version>]
	EL	edit local <test> [<version>]
	ELC	edit local comment from <test>
	ELI	edit local initialization of <test> [<version>]
	EMSC	edit <meta_series> comment (global)
	ESC	edit <series> comment (global)

	FTEST	find test(s) with name(s) like <string>
	FSERIES find series(s) with names(s) like <string>

	IL	local init for local/global <test> [<version>]
	IG	global init for local/global <test> [<version>]
	IS	initialize <series> [<sequence> [<version>]]
		where sequence 1-3,10 runs tests 1,2,3,10
	KILL	rollback database changes

	LB	list boiler plates
	LE	list environments
	LF	list failed tests
	LMS	list <meta_series>
	LR	list runs
	LS	list <series>
	LT	list tests [<-l>=local, <-g>=global (default)]

	MLTV	modify local <test> <version_1> to <version_2>
	MTV	modify <test> <version_1> <version_2> (global)
	MVT	move <test> <series1> <series2> [<sequence>]

	PB	print [<boiler_plate>]
	PC	print comment for <test> (search local, then global)
	PD	print differences for failure of <test>
		(search local, then global
	PE	print [<environment>]
	PF	print failure for <test> (local)
	PGR	print expected global result for <test> [<version>]
	PMS	print series in <meta_series>
	PMSC	print <meta_series> comment
	PR	print expected result for <test> [<version>] (local)
	PRN	print run setting
	PS	print tests in <series> (local if it exists, otherwise
                global)
	PSC	print <series> comment
	PT	print <test> [<version>] (search local, then global)

	R	run <test> (search local, then global)
	RS	run <series> [<sequence>] where sequence of 1-3,10
		runs tests 1,2,3,10
	RMS	run <meta_series> [starting with <sequence>]

	MKF	mark known failure for <test> (local)
	RO	set NO_RUN_FLAG for global <test> [<version>] to <value>
		0 - Run the test
		1 - Do not run the test / Bug
		2 - Do not run the test / Code not yet implemented
	ROL	set NO_RUN_FLAG for local <test> [<version>] to <value>
		0 - Run the test
		1 - Do not run the test / Bug
		2 - Do not run the test / Code not yet implemented
	SLNI	set local NO_INIT_FLAG for <test> [<version>] to <value>
		0 - Initialization is read/write
		1 - Initialization is read only
	SNI	set NO_INIT_FLAG for <test> [<version>] to <value> (global)
		0 - Initialization is read/write
		1 - Initialization is read only
	SNIS	set NO_INIT_FLAG to read only for <series>

	SB	set <boiler plate>
	SDV	set <dollar verb> to <definition>
	SE	set <environment>

	SKF	set <run name> for known failures
	SRN	set <run>

	SHOW	show <test> (versions, inits, series)
	ST	show <test> (versions, inits, series)
	PVR	print version setting
	SVR	set <version>
	VECTOR	<configuration> run tests on vectored worklist

	HELP	display [<command/dollar verb>]
	?	display [<command/dollar verb>]
	SHELL	Escape to sub-shell
	Q	Exit from TCS
	QUIT	Exit from TCS
	EXIT	Exit from TCS

TCS reserved words are ("dollar" verbs):
	ADA		  	Invokes ada compiler
	ADA_LINK		Invokes ada linker
	ADA_MKFAM		Invokes ada family manager to create a
				family
	ADA_MKLIB		Creates an ada library
	ADA_RMFAM		Invokes ada family manager to remove a
				family
	ADA_RMLIB		Removes an ada library
	ADA_SEARCH		Necessary for ada test to run on VMS
	ADA_SETLIB		Necessary for ada test to run on VMS
	API			api
	CC			cc
	CXX			Invokes c++ compiler
	CXX_LINK		Invokes c++ linker
	COB			Invokes cobol compiler
	COBOL			Invokes cobol compiler (same as above)
	COB_LINK		Invokes cobol linker
	COPY			"cp"
	CRE			"cat >"
	CREATE			"cat >"
	DEL			"rm -f"
	DELETE			"rm -f"
	DIR			"ls"
	DIRECTORY		"ls"
	DROP			"drop_gdb"
	FOR			Invokes fortran compiler
	FORTRAN			Invokes fortran compiler (same as above)
	FORTRAN_LINK		Invokes fortran linker
	GBAK			"gbak"
	GCON			"gcon"
	GCSU			"gcsu"
	GDEF			"gdef"
	GDS_CACHE_MANAGER	"gds_cache_manager"
	GFIX			"gfix"
	GJRN			"gjrn"
	GLTJ			"gltj"
	GPRE			"gpre"
	GRST			"grst"
	GSEC			"gsec"
	ISQL			"isql"
	JAVA			"java"
	JAVAC			"javac"
	LINK			Invokes unix linker(cc)
	MAKE			"make"
	PAS			Invokes pascal compiler
	PASCAL			Invokes pascal compiler (same as above)
	QLI			"qli"
	RSH			"rsh"
	RUN			Execute in the shell
	SH			"sh"
	TYPE			"cat <"


There is also more detailed documentation in tcs/doc
and you might want to check out interbase/firebird/fsg/TCS for
some additonal scripts (that is the one in the interbase tree 
not the TCS tree) 
  
