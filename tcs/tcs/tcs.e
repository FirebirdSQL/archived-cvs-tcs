/*
 *	PROGRAM:	Test Control System
 *	MODULE:		tcs.e
 *	DESCRIPTION:	Main Module for test control system.
 *
 * The contents of this file are subject to the InterBase Public License
 * Version 1.0 (the "License"); you may not use this file except in
 * compliance with the License.
 *
 * You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.  The Original Code was created by Inprise
 * Corporation and its predecessors.
 *
 * Portions created by Inprise Corporation are Copyright (C) Inprise
 * Corporation. All Rights Reserved.
 *
 * Contributor(s): ______________________________________.
 */

#ifdef __BORLANDC__

/* Turn off Suspicius pointer conversion */
#pragma warn -sus

/* Possibly incorrect assigment */
#pragma warn -pia

/* Conversion may loose significant digits */
#pragma warn -sig

#pragma warn -use

#endif

#include <ctype.h>
#include <setjmp.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#ifdef WIN_NT
#include <winsock.h>
#endif	/* WIN_NT */
/* #include "source/jrd/common.h" */
#include "tcs.h"

#define MAX_RECURSION 5

#ifdef VMS
#define PATH_SEPARATER	0
#endif
#ifdef PC_PLATFORM
#define PATH_SEPARATER	'\\'
#endif
#ifdef mpexl
#define PATH_SEPARATER	0
#endif

#ifndef PATH_SEPARATER
#define PATH_SEPARATER	'/'
#endif

/* Used for recovery in the event of an emergency */

jmp_buf  JumpBuffer;

/* DB definitions */
DATABASE
    TCS = COMPILETIME FILENAME "ltcs.gdb";

DATABASE
    TCS_GLOBAL = COMPILETIME FILENAME "gtcs.gdb";

#if (defined WIN_NT || defined OS2_ONLY)

/* External declarations for NT */
extern int  PTSL_set_table(void);
extern int	list_keywords (FILE*, TEXT*);
extern int DISP_add_series (TEXT db_flag, TEXT* meta, TEXT* series, SSHORT sequence);
extern int DISP_add_test (TEXT db_flag, TEXT* series, TEXT* test, SSHORT sequence);
extern int disp_get_string (SCHAR* prompt_string, SCHAR* response_string, int length);
extern int disp_upcase (TEXT* string, TEXT* name);
extern int disp_get_answer (SCHAR* prompt_string, SCHAR* response_string, int length);
extern int disp_print_blob (SLONG* blob_id, SLONG* db_handle);

extern int EXEC_init (TEXT* string,
							 ULONG*  blob_id,
							 ULONG* db_handle,
							 USHORT sw_no_system,
							 USHORT phase,
							 int* file_count,
							 TEXT* version,
							 SSHORT global);
extern int EXEC_env (ULONG* blob_id);
extern TEST_RESULT EXEC_test (TEXT* test_name,
							  SLONG* script_id,
							  ULONG* db_handle,
							  USHORT sw_no_system,
							  USHORT phase,
							  int* file_count,
							  TEXT* version,
							  TEXT* run_name);

extern int keyword_search (TEXT* string );
extern void fix_nt_mks_lookup(void);
extern void set_script_file(void);
extern int set_ptl_lookup(TEXT* verb, TEXT* def);

/* Static declarations */
static int parse_main_options(TEXT* p);
static int parse_series_args (TEXT* start,
										SSHORT* first,
										SSHORT* second,
										SSHORT* break_flag );
static int	get_work (char* configuration,
							 char* series_name,
							 int* sequence,
							 char* boilerplate);
static int	report_results (char* configuration,
									 char* series_name,
									 int  sequence,
									 struct tr_test_results* series_results,
									 USHORT test_error);
static char *right_trim (char* string, int length);

static int set_env (TEXT* name);
static int set_config(TEXT* rfn);
static int add_series (TEXT* series, TEXT*  meta, TEXT* seq);
static int add_test (TEXT* test, TEXT* series, TEXT* seq);
static int set_boilerplate (TEXT* string);
static int browse (TEXT* string);
static int commit(void);
static int test (TEXT* string);
static int test_series (TEXT* string, TEXT* start);
static int test_meta_series (TEXT* string, TEXT* start);
static int interact (void);
static int create_bp (TEXT* name, TEXT* template);
static TEXT* make_version (TEXT* name);
static void unmake_version (TEXT* name, TEXT*  version);
static int create_env (TEXT* name, TEXT* template);
static int create_local (TEXT* string, TEXT* vers);
static int create_meta_series (TEXT* name, TEXT* swtch);
static int create_series (TEXT* name, TEXT* swtch);
static int create (TEXT* string, TEXT* vers);
static int clear (TEXT* name);
static int erase (TEXT* string);
static int delete_initialization (TEXT* t_name, TEXT* vers);
static int delete_local_initialization (TEXT* t_name, TEXT* vers);
static int delete_test (TEXT* string, TEXT* vers);
static int delete_local_test (TEXT* string, TEXT* vers);
static int delete_test_from_series (TEXT* test_string, TEXT* series_string);
static int delete_times (void);
static int duplicate_global (TEXT* name1, TEXT* vers1, TEXT* name2, TEXT* vers2);
static int duplicate_global_local (TEXT* name1, TEXT* vers1, TEXT* name2, TEXT* vers2);
static int duplicate_local (TEXT* name1, TEXT* vers1, TEXT* name2, TEXT* vers2);
static int edit (TEXT* string, TEXT* vers);
static int edit_env (TEXT* name);
static int edit_boilerplate (TEXT* string);
static int edit_comment (TEXT* string);
static int edit_global_initialization (TEXT* string, TEXT* vers);
static int edit_local (TEXT* string, TEXT* vers);
static int edit_local_comment (TEXT* string);
static int edit_local_initialization (TEXT* string, TEXT* vers);
static int edit_meta_series_comment (TEXT* name, TEXT* swtch);
static int edit_series_comment (TEXT* name, TEXT* swtch);
static int find_test_name (TEXT* string);
static int find_series_name (TEXT* string);
static int initialize_local (TEXT* string, TEXT* vers);
static int initialize_global (TEXT* string,TEXT* vers);
static int initialize_series (TEXT* string, TEXT* start, TEXT* vers);
static int rollback (void);

static int list_boilerplates (void);
static int list_environments (void);
static int list_failures (TEXT* name);
static int list_meta_series (TEXT* swtch);
static int list_runs (void);
static int list_series (TEXT* swtch);
static int list_tests (TEXT* swtch);

static int modify_test_version (TEXT* string, TEXT* vers1, TEXT* vers2);
static int move_test_series1_series2 (TEXT* test_string, TEXT* s1, TEXT* s2, TEXT* seq);
static int print_boilerplate (TEXT* string);
static int print_comment (TEXT* string);
static int diff (TEXT* string);
static int print_environment (TEXT* string);
static int failure (TEXT* string);
static int print_global_result (TEXT* string, TEXT* vers);
static int print_meta_series (TEXT* string);
static int print_meta_series_comment (TEXT* name, TEXT* swtch);
static int print_result (TEXT* string, TEXT* vers);
static int print_run (void);
static int print_series (TEXT* string);
static int print_series_comment (TEXT* name, TEXT* swtch);
static int print_test (TEXT* string, TEXT* vers);
static int mark_local_known_failure (TEXT* string);
static int mark_test (TEXT* string, TEXT* value, TEXT*  vers);
static int mark_local_test (TEXT* string, TEXT* value, TEXT* vers);
static int mark_local_init (TEXT* string, TEXT* value, TEXT*  vers);
static int mark_init (TEXT* string, TEXT* value, TEXT* vers);
static int mark_init_series (TEXT* string, TEXT* swtch);
static int set_dollar_verb (TEXT* verb, TEXT* def);
static int set_known_failures (TEXT* name);
static int set_run (TEXT* name);
static int show_test (TEXT* name);
static int print_version (void);
static int set_version (TEXT* name);
static int run_worklist (char* string);
static int list_commands (TEXT* string);
static int shell (TEXT* string);

static void CLIB_ROUTINE signal_quit(void);

#else

extern void		list_keywords();
extern struct tm	*localtime();
static TEXT	*make_version();
static void	unmake_version();

static int	add_series(), add_test(), browse(), clear(), commit(),
		clear_env(), create_bp(), create_env(),
		duplicate_global(), duplicate_global_local(),
		create(), create_local(), create_meta_series(),
		create_series(), diff(),
		delete_initialization(), delete_local_initialization(),
		delete_test(),  delete_local_test(),
		delete_test_from_series(),
		delete_times (), duplicate_local(),
		edit_comment(), edit(), edit_env(),
		edit_boilerplate(), edit_global_initialization(),
		edit_local(), edit_local_initialization(),
		edit_local_comment(), edit_meta_series_comment(),
		edit_series_comment(), erase(), failure(),
		find_test_name(), find_series_name(),
		initialize_local(), initialize_global(), initialize_series(),
		list_boilerplates(), list_commands(), list_environments(),
		list_runs(), mark_local_init(), mark_init_series(),
		list_failures(), list_series(), list_tests(), mark_init(),
		modify_test_version(), modify_local_test_version(),
		list_meta_series(), mark_local_test(), mark_test(),
		move_test_series1_series2(),
		parse_series_args(),
		print_boilerplate(), print_comment(), print_series(),
		print_environment(), print_meta_series(),
		print_meta_series_comment(), print_run(),
		print_series_comment(),
		print_test(), rollback(), print_version(),
		print_global_result(), print_result(),
		run_worklist(),
		mark_local_known_failure(),
		set_known_failures(),
		set_boilerplate(), set_config(), set_dollar_verb(),
		set_env(), shell(),
		set_run(), set_version(),
		show_test(),
		test(), test_series(),
		test_meta_series();

static char *right_trim ();
static void CLIB_ROUTINE signal_quit();

#endif

extern int		keyword_search();
static int		ms_count,ms_sequence,s_count,s_sequence,init_run,
			phase,file_count;

static struct tr_test_results {
	int	tr_test_count;
	int	tr_test_results [NUM_RESULTS];
} series_results;

static BASED_ON TCS.META_SERIES.META_SERIES_NAME ms_name;
static BASED_ON TCS.SERIES.SERIES_NAME s_name;
static BASED_ON TCS.TESTS.TEST_NAME t_name;
static BASED_ON TCS.BOILER_PLATE.BOILER_PLATE_NAME bp_name;
static BASED_ON TCS.ENV.ENV_NAME env_name;
static BASED_ON TCS.FAILURES.RUN run_name;
		 BASED_ON TCS.FAILURES.RUN known_failures_run_name;
static BASED_ON TCS.TESTS.VERSION version;
static BASED_ON TCS.TESTS.VERSION version_buffer;

static FILE	*ifile;
static SSHORT	sw_no_system;
static TEXT	prompt[128];

static TEXT	this_hostname[32] = "<unknown>";
static SSHORT	running_worklist;

#ifdef ULTRIX
#  define NO_STRDUP
#endif

#if (defined WIN_NT || defined OS2_ONLY)

USHORT 		sw_nt_mks;
USHORT 		sw_nt_bash;

#endif

USHORT		sw_timestamp_off = 0;
USHORT 		sw_ignore_init = 0;
USHORT		sw_save = 0;
USHORT		sw_quiet = 0;
USHORT		sw_times = 0;
USHORT		quit = 0;

TEXT		environment_name [20];
USHORT  	env_clear;
TEXT		boilerplate_name [32];

static USHORT	sw_version= FALSE;
USHORT		disk_io_error = FALSE;

#define RIGHT_TRIM(x) right_trim ((x), sizeof (x))


/* Some useful tables */

/* Table for the NO_RUN_FLAG options. */

static struct runflag {
	 SSHORT	option;
	 TEXT	*description;
} runflag_options [] = {
 {	0, "Run the test" },
 {	1, "Bug" },
 {	2, "Code not yet implemented" },
 {	0, NULL }
 };


/* Table for commands within TCS */

static struct cmd {
	 TEXT	*cmd_string;
	 int	(*cmd_routine)();
	 TEXT	*cmd_text;
	 SSHORT	cmd_args;
} commands [] = {
  { "AS", add_series, "add_series <series> to <meta_series> [<sequence>]", 2 },
  { "AT", add_test, "add test <test> to <series> [<sequence>]", 2},
  { "BR", browse, "browse for tests containing <string>", 1},
  {  "C", commit, "commit changes\n", 0},
  { "CB", create_bp, "create <boiler_plate> using [<template>]", 1},
  { "CE", create_env, "create <environment> using [<template>]", 1},
  {  "CLT", create_local, "create local <test> [<version>]", 1},
  {  "CMS", create_meta_series, "create <meta_series> (global)", 1},
  {  "CS", create_series, "create <series>  (global, EOF to end list)", 1},
  {  "CT", create, "create <test> [<version>] (global)\n", 1},
  {  "DAF", clear, "delete all failures for [<run>]/current run", 0},
  {  "DF", erase, "delete failure for <test> for current run", 1},
  {  "DI", delete_initialization, "delete initialization for <test> [<version>] (global)", 1},
  {  "DLI", delete_local_initialization, "delete local initialization for <test> [<version>]", 1},
  {  "DLT", delete_local_test, "delete local <test> [<version>]", 1},
  {  "DT", delete_test, "delete <test> [<version>] (global)", 1},
  {  "DTS", delete_test_from_series, "delete <test> from <series>\n\t\t\t(test remains in DB, all copies removed from series)", 2},
  {  "DTM", delete_times, "delete timing information\n", 0},
  {  "DUPGG", duplicate_global, "duplicate <test_1> <version_1> <test_2> <version_2>\n\t\t\tglobal to global", 4},
  {  "DUPGL", duplicate_global_local, "duplicate <test_1> <version_1> <test_2> <version_2>\n\t\t\tglobal to local", 4},
  {  "DUPLL", duplicate_local, "duplicate <test_1> <version_1> <test_2> <version_2>\n\t\t\tlocal to local\n", 4},
  {  "E", edit, "edit <test> [<version>] (global)", 1},
  {  "EE", edit_env, "edit <environment>", 1},
  {  "EB", edit_boilerplate, "edit <boiler plate>", 1},
  {  "EC", edit_comment, "edit comment from <test> (global)", 1},
  {  "EGI", edit_global_initialization, "edit global initialization of <test> [<version>]", 1},
  {  "EL", edit_local, "edit local <test> [<version>]", 1},
  {  "ELC", edit_local_comment, "edit local comment from <test>", 1},
  {  "ELI", edit_local_initialization, "edit local initialization of <test> [<version>]", 1},
  {  "EMSC", edit_meta_series_comment, "edit <meta_series> comment (global)",1},
  {  "ESC", edit_series_comment, "edit <series> comment (global)\n",1},
  {  "FTEST", find_test_name, "find test(s) with name(s) like <string>",1},
  {  "FSERIES", find_series_name, "find series(s) with names(s) like <string>\n",1},
  {   "IL", initialize_local, "local init for local/global <test> [<version>]", 1},
  {  "IG", initialize_global, "global init for local/global <test> [<version>]", 1},
  {  "IS", initialize_series, "initialize <series> [<sequence> [<version>]]\n\t\t\twhere sequence 1-3,10 runs tests 1,2,3,10", 1},
  {  "KILL", rollback, "rollback database changes\n", 0},
  {  "LB", list_boilerplates, "list boiler plates", 0},
  {  "LE", list_environments, "list environments", 0},
  {  "LF", list_failures, "list failed tests", 0},
  {  "LMS", list_meta_series, "list <meta_series>", 0},
  {  "LR", list_runs, "list runs", 0},
  {  "LS", list_series, "list <series>", 0},
  {  "LT", list_tests, "list tests [<-l>=local, <-g>=global (default)]\n", 0},
  {  "MLTV", modify_test_version, "modify local <test> <version_1> to <version_2>", 3},
  {  "MTV", modify_test_version, "modify <test> <version_1> <version_2> (global)", 3},
  {  "MVT", move_test_series1_series2, "move <test> <series1> <series2> [<sequence>]\n", 3},
  {  "PB", print_boilerplate, "print [<boiler_plate>]", 0},
  {  "PC", print_comment, "print comment for <test> (search local, then global)", 1},
  {  "PD", diff, "print differences for failure of <test>\n\t\t\t(search local, then global", 1},
  {  "PE", print_environment, "print [<environment>]", 0},
  {  "PF", failure, "print failure for <test> (local)", 1},
  {  "PGR", print_global_result, "print expected global result for <test> [<version>]", 1},
  {  "PMS", print_meta_series, "print series in <meta_series>", 1},
  {  "PMSC", print_meta_series_comment, "print <meta_series> comment",1},
  {  "PR", print_result, "print expected result for <test> [<version>] (local)", 1},
  {  "PRN", print_run, "print run setting", 0},
/* delete this local series ref. */
  {  "PS", print_series, "print tests in <series> (local if it exists, otherwise global)", 1},
  { "PSC", print_series_comment, "print <series> comment",1},
  { "PT", print_test, "print <test> [<version>] (search local, then global)\n", 1},
  { "R", test, "run <test> (search local, then global)", 1},
  { "RS", test_series, "run <series> [<sequence>] where sequence of 1-3,10\n\t\t\truns tests 1,2,3,10", 1},
  { "RMS", test_meta_series, "run <meta_series> [starting with <sequence>]\n", 1},
  { "MKF", mark_local_known_failure, "mark known failure for <test> (local)", 1},
  {  "RO", mark_test, "set NO_RUN_FLAG for global <test> [<version>] to <value>\n\t\t\t0 - Run the test\n\t\t\t1 - Do not run the test / Bug\n\t\t\t2 - Do not run the test / Code not yet implemented", 2},
  { "ROL", mark_local_test, "set NO_RUN_FLAG for local <test> [<version>] to <value>\n\t\t\t0 - Run the test\n\t\t\t1 - Do not run the test / Bug\n\t\t\t2 - Do not run the test / Code not yet implemented", 2},
  { "SLNI", mark_local_init, "set local NO_INIT_FLAG for <test> [<version>] to <value>\n\t\t\t0 - Initialization is read/write\n\t\t\t1 - Initialization is read only", 2},
  { "SNI", mark_init, "set NO_INIT_FLAG for <test> [<version>] to <value> (global)\n\t\t\t0 - Initialization is read/write\n\t\t\t1 - Initialization is read only", 2},
  { "SNIS", mark_init_series, "set NO_INIT_FLAG to read only for <series>\n", 1},
  { "SB", set_boilerplate, "set <boiler plate>", 1},
  { "SDV", set_dollar_verb, "set <dollar verb> to <definition>", 2},
  { "SE", set_env, "set <environment>\n", 1},
  { "SKF", set_known_failures, "set <run name> for known failures", 0},
  {  "SRN", set_run, "set <run>\n", 1},
  {  "SHOW", show_test,"show <test> (versions, inits, series)", 1},
  {  "ST", show_test,"show <test> (versions, inits, series)", 1},
  { "PVR", print_version, "print version setting", 0},
  {  "SVR", set_version, "set <version>", 1},
  { "VECTOR", run_worklist, "<configuration> run tests on vectored worklist\n", 0},
  { "HELP", list_commands, "display [<command/dollar verb>]", 0},
  { "?", list_commands, "display [<command/dollar verb>]",0},
  {  "SHELL", shell, "Escape to sub-shell", 0},
  {  "Q", NULL, "Exit from TCS", 0},
  {  "QUIT", NULL, "Exit from TCS", 0},
  {  "EXIT", NULL, "Exit from TCS", 0},
  {   NULL, NULL, NULL, 0 }
};

CLIB_ROUTINE main (argc, argv, envp)
	 int		argc;
	 char	*argv[];
	 char	*envp[];
{
/**************************************
 *
 *	m a i n
 *
 **************************************
 *
 * Functional description
 *	Main line routine.  If there are arguments, interpret them,
 *	otherwise get input from user.
 *
 **************************************/
TEXT	dbb_name[128], dbb_name2[128], *p, seq_no[10];
TEXT	 l_dpb[128], *l_dpb_end = l_dpb;
TEXT	 g_dpb[128], *g_dpb_end = g_dpb;

#ifdef WIN_NT

WORD wVersionRequested;WSADATA wsaData;
#endif

/* 	Load the defaults 	*/

strcpy (dbb_name, DBB_NAME);
strcpy (dbb_name2, DBB_NAME2);
strcpy (boilerplate_name, BOILERPLATE_NAME);
strcpy (ms_name, "none");
strcpy (s_name, "none");
strcpy (version, DEFAULT_VERSION);
strcpy (run_name, DEFAULT_RUN_NAME);
strcpy (known_failures_run_name, "");

#ifdef OLDWAY

/* This may be stubbed out if gethostname() doesn't exist on a platform,
 * it is used to identify a machine which is cooperating in a multimachine
 * tcs run.  Any resonabily unique identifier can be used as well.
 */

#ifdef WIN_NT
/*
	You must initialize Winsock before making any socket related
	calls:  ie gethostname

*/wVersionRequested = MAKEWORD( 2, 0 );

if (WSAStartup (wVersionRequested, &wsaData))
	print_error ("Unable to load Winsock\n", 0, 0,0);

	if (gethostname (this_hostname, sizeof (this_hostname)))
	{
	 int retval = WSAGetLastError();
	 switch (retval)
	 {

	 case WSAEFAULT :	 print_error (	 "The name parameter is not a valid part of the user address space, or the buffer size specified by namelen parameter is too small to hold the complete host name.\n",	  0,0,0);			break;

	case WSANOTINITIALISED :	print_error (	"A successful WSAStartup must occur before using this function.\n", 0,0,0);			break;

  case WSAENETDOWN :	 print_error ("The network subsystem has failed.\n", 0, 0, 0);			break;

  case WSAEINPROGRESS :		print_error (		"A blocking Windows Sockets 1.1 call is in progress, or the \		 service provider is still processing a callback function.\n", 0, 0, 0);			break;
	dafault:
	print_error("Unknown Winsock error has occured.\n", 0, 0, 0);
	     break;		

		}
	 strncpy (this_hostname, "<unknown>", sizeof (this_hostname));}
else

  WSACleanup ();
#else  /* Non NT */


if (gethostname (this_hostname, sizeof (this_hostname)))
	 strncpy (this_hostname, "<unknown>", sizeof (this_hostname));

#endif /* WIN_NT */

#else
{

#include <sys/utsname.h>

struct	utsname	thismachine;

if (uname (&thismachine) < 0)
	 strncpy (this_hostname, "<unknown>", sizeof (this_hostname));
else
	 strncpy (this_hostname, thismachine.nodename, sizeof (this_hostname));
}

#endif /* OLDWAY */

sw_no_system = sw_times = FALSE;
running_worklist = FALSE;
phase = 0;

/*	Initialize string translation table for words that signal	*
 *	the presence of $ which will make hp c compiler barf.		*/

PTSL_set_table ();

/* Skip over command */

argv++;

/* handle switches in the 2nd best fashion (this should be a function
   and jas has a better way to keep count of switches) */

while (--argc > 0)

{
    p = *argv++;
    if (*p++ != '-')
	continue;

/*	Parse the options... */

    switch (UPPER (*p))
    {

/*	Do options that take an argument here */

	case 'D':	/* Local Database */
	    if ( *(p+1) == '\0' && *argv != NULL )  /* If name in next arg... */
	    { 
	    	strcpy (dbb_name, *argv++);
	    	--argc;
	    }
	    else if ( *(p+1) == '\0' && *argv == NULL )
		print_error("Argument missing for '-d'",0,0,0);
	    else
		strcpy (dbb_name, (p+1));   /* Allow no spaces. */

	    if (*argv && **argv != '-')
		{
		char *l;
		*l_dpb_end++ = gds__dpb_version1;
		*l_dpb_end++ = gds__dpb_user_name;
		l = l_dpb_end++;
		*l = 0;
		for (p = *argv; *p; *l_dpb_end++ = *p++, (*l)++);
		argv++;
		argc--;
	        if (*argv && **argv != '-')
		    {
		    *l_dpb_end++ = gds__dpb_password;
		    l = l_dpb_end++;
		    *l = 0;
		    for (p = *argv; *p; *l_dpb_end++ = *p++, (*l)++);
		    argv++;
		    argc--;
		    }
		}
	    break;

	case 'G':	/* Global Database */
	    if ( *(p+1) == '\0' && *argv != NULL )  /* If name in next arg... */
	    {
	        strcpy (dbb_name2, *argv++);
	        --argc;
	    }
	    else if ( *(p+1) == '\0' && *argv == NULL )
		print_error("Argument missing for '-g'",0,0,0);
	    else
		strcpy (dbb_name2, (p+1));  /* Allow no spaces. */
	    if (*argv && **argv != '-')
		{
		char *l;
		*g_dpb_end++ = gds__dpb_version1;
		*g_dpb_end++ = gds__dpb_user_name;
		l = g_dpb_end++;
		*l = 0;
		for (p = *argv; *p; *g_dpb_end++ = *p++, (*l)++);
		argv++;
		argc--;
	        if (*argv && **argv != '-')
		    {
		    *g_dpb_end++ = gds__dpb_password;
		    l = g_dpb_end++;
		    *l = 0;
		    for (p = *argv; *p; *g_dpb_end++ = *p++, (*l)++);
		    argv++;
		    argc--;
		    }
		}
	    break;


/*	Pass off options that do not take an arg to parse_main_options() */

	case 'C':	/* Clock off  - No timestamp on series run */
	case 'I':	/* Ignore inits */

#if (defined WIN_NT || defined OS2_ONLY)
/*	NOTE:  	For NT we are adding a command line options
		to turn on MKS stuff.  This is it...	*/
	case 'M':
#endif
        case 'N':	/* No run */
	case 'Q':	/* Quiet, suppress diff */
	case 'S':	/* Save script */
        case 'T':	/* Save times */
        case 'Z':	/* Show versions */
	case 'X':	/* Show TCS command line options */
	default:
	    parse_main_options( p );
    }
}

/* Ready the databases with either the default or supplied name */

isc_attach_database ((long*) 0L, 0, GDS_VAL(dbb_name), &TCS, (short)(l_dpb_end - l_dpb), l_dpb);

isc_attach_database ((long*) 0L, 0, GDS_VAL(dbb_name2), &TCS_GLOBAL, (short)(g_dpb_end - g_dpb), g_dpb);

START_TRANSACTION;

set_config(TCS_CONFIG); 	/* Read config file */

/*	Load the Environment Variables	*/
printf("Scanning System Environment for REMOTE variables\n");
for (;*envp;envp++)
   if ( strstr(*envp, "WHERE_GDB") ||
        strstr(*envp, "REMOTE_DIR") ||
	strstr(*envp, "WHERE_URL") )
      printf("\t%s\n", *envp);

/*	If No_system flag is set then read the tcs.info file left	*
 *	by the last tcs run with the No_system option.  This file	*
 *	contains info about the test run(env, bp, test name, etc.)	*/

if (sw_no_system)

{

/*	Open the tcs.info file		*/

    if (ifile = fopen (info_file, "r"))

    {
        fscanf (ifile, "%s %d %d %s %d %d %s %s %s %d %d\n",
                        ms_name, &ms_count, &ms_sequence, s_name, &s_count, &s_sequence,
                        t_name, env_name, bp_name, &init_run, &file_count);
        fclose (ifile);

/*	Get rid of info file.	*/
	
        if (!sw_save)
            unlink (info_file);

/*	Set up TCS parameters and run the test, series or meta_series	*
 *	compare with the results left in tcs.output by user.		*/

        phase = 1;
        set_env (env_name);
        set_boilerplate (bp_name);
        (void) test (t_name);
        phase = 0;

/*	If no series, do not run	*/

        if (strcmp (s_name, "none"))

        {
            sprintf (seq_no, "%d", s_sequence + 1);
            test_series (s_name, seq_no);
        }

        s_count = s_sequence = 0;

/*	If no meta series, do not run	*/

        if (strcmp (ms_name, "none"))

        {
            sprintf (seq_no, "%d", ms_sequence + 1);
            test_meta_series (ms_name, seq_no);
        }
    }
}

printf ("\n\tWelcome to TCS:\t%s\n", TCS_VERSION);

/*	If version command line option was thrown, print the version	*
 *	of IB being used.						*/

if (sw_version)
    {
    gds__version (&TCS, NULL, NULL);
    }

/* 	Go into interaction loop for the remainder of execution		*/

if (!argc)
    while (interact())
	;

/* 	Done, so shutdown and exit	*/

COMMIT;
FINISH;
exit (FINI_OK);
}

static int add_series (series, meta, seq)
	 TEXT	*series, *meta, *seq;
{
/**************************************
 *
 *	a d d _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *	Add series to metaseries. if series doesn't exist barf
 *
 **************************************/
USHORT	count, mcount;
SSHORT   sequence;

/*	Set sequence number to integer of proper value, if no value	*
 *	is given set to negative one for now, later will convert 	*
 *	to last sequence number of series.		 		*/

sequence = (NOT_NULL (seq)?  atoi (seq):  -1);
count = mcount = 0;

/* Try to add local or global series to local metaseries */

FOR M IN TCS.META_SERIES WITH M.META_SERIES_NAME = meta
	 REDUCED TO M.META_SERIES_NAME

/*	Try to add local series to local meta series 	*/

	 FOR S IN TCS.SERIES WITH S.SERIES_NAME EQ series
		 REDUCED TO S.SERIES_NAME
	DISP_add_series ('l', meta, series, sequence);
	count++;
	 END_FOR;

/*	Try to add global series to local meta series 	*/

	 if (!count)
	FOR S IN TCS_GLOBAL.SERIES WITH S.SERIES_NAME EQ series
		 REDUCED TO S.SERIES_NAME
		 DISP_add_series ('l', meta, series, sequence);
		 count++;
	END_FOR;
	 mcount++;
END_FOR;

/* No match? Try to add local of global series to global meta series */
if (!mcount)
	 FOR M IN TCS_GLOBAL.META_SERIES WITH M.META_SERIES_NAME = meta
		  REDUCED TO M.META_SERIES_NAME

/*	Try to add local series to global meta series		*/

	FOR S IN TCS.SERIES WITH S.SERIES_NAME EQ series
		 REDUCED TO S.SERIES_NAME
		 DISP_add_series ('g', meta, series, sequence);
		 count++;
	END_FOR;

/*	Try to add global series to global meta series		*/

	if (!count)
		 FOR S IN TCS_GLOBAL.SERIES
		 WITH S.SERIES_NAME EQ series
		 REDUCED TO S.SERIES_NAME
		DISP_add_series ('g', meta, series, sequence);
		count++;
		 END_FOR;
	mcount++;
	 END_FOR;

/* 	If mcount never got incremented then could not find meta 	*
 *	series -- print error.						*/

if (!mcount)

{
	print_error ("Meta_series %s doesn't seem to exist",meta,0,0);
	return FALSE;
}

/* 	If count never got incremented then could not find series,	*
 *	print error.							*/

if (!count)

{
	print_error ("Series %s doesn't seem to exist",series,0,0);
	return FALSE;
}

return 0;
}

static int add_test (test, series, seq)
	 TEXT	*test, *series, *seq;
{
/**************************************
 *
 *	a d d _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Add test to series.  Barf if test doesn't exists.
 *      This function should only apply to the global
 *	database.  There should be NO local series.
 *
 * XXX
 *	Will fix after conferring with the group.
 *
 **************************************/
SSHORT   sequence;
TEXT	series_name [32];
USHORT	count, mcount;


/*	Set sequence number to integer of proper value, if no value	*
 *	is given set to negative one for now, later will convert 	*
 *	to last sequence number of series.		 		*/

sequence = (NOT_NULL (seq)?  atoi (seq):  -1);
count = mcount = 0;

/* Try to add local or global test to local series */

FOR M IN TCS.SERIES WITH M.SERIES_NAME = series
	 REDUCED TO M.SERIES_NAME

/*	Try to add local test to local series.	*/

	 FOR S IN TCS.TESTS  WITH S.TEST_NAME EQ test
		 REDUCED TO S.TEST_NAME
	DISP_add_test ('l', series, test, sequence);
	count++;
	 END_FOR;

/*	Since could not find local test try to add global test	*/

	 if (!count)
	FOR S IN TCS_GLOBAL.TESTS WITH S.TEST_NAME EQ test
		 REDUCED TO S.TEST_NAME
		 DISP_add_test ('l', series, test, sequence);
		 count++;
	END_FOR;
	 mcount++;
END_FOR;

/* No match? Try to add local or global test to global series */
if (!count && !mcount)
	 FOR M IN TCS_GLOBAL.SERIES WITH M.SERIES_NAME = series
		  REDUCED TO M.SERIES_NAME

/*	Try to add local test.		*/

	FOR S IN TCS.TESTS WITH S.TEST_NAME EQ test
		 REDUCED TO S.TEST_NAME
		 DISP_add_test ('g', series, test, sequence);
		 count++;
	END_FOR;

/*	Try to add global test.		*/

	if (!count)
		 FOR S IN TCS_GLOBAL.TESTS
		 WITH S.TEST_NAME EQ test
		 REDUCED TO S.TEST_NAME
		DISP_add_test ('g', series, test, sequence);
		count++;
		 END_FOR;
	mcount++;
	 END_FOR;

/* 	If mcount never got incremented then could not find series,	*
 *	print error.							*/

if (!mcount)

{
	 print_error ("Series %s doesn't seem to exist", series,0,0);
	 return FALSE;
}

/* 	If count never got incremented then could not find test ,	*
 *	print error.							*/

if (!count)

{
	 print_error ("Test %s doesn't seem to exist\n", test,0,0);
	 return FALSE;
}
	 return TRUE;
}

static int browse (string)
	 TEXT  *string;
{
/**************************************
 *
 *	b r o w s e
 *
 **************************************
 *
 * Functional description
 *	List test_names of both local
 *	and global scripts containing
 *	this string
 *
 **************************************/
SSHORT count = 0;


FOR T IN TCS.TESTS WITH T.SCRIPT.CHAR [20] CONTAINING string
	 printf ("%s %s\n", T.TEST_NAME, T.VERSION);
	 count++;
END_FOR;

FOR T IN TCS_GLOBAL.TESTS WITH T.SCRIPT.CHAR [20] CONTAINING string
	 printf ("%s %s\n", T.TEST_NAME, T.VERSION);
	 count++;
END_FOR;

if (!count)
{
	 print_error ("Could not find \"%s\" in SCRIPT of any test locally or globally", string,0,0);
	 return FALSE;
}
 return TRUE;
}

static int clear (name)
	 TEXT *name;
{
/**************************************
 *
 *	c l e a r
 *
 **************************************
 *
 * Functional description
 *	Clear out all failure records.
 *
 **************************************/

/*	Clear out all failure records  */

#ifdef TOO_DANGEROUS
/* This function was removed on 1995-February-12 David Schnepper
 * as it was too open for potential misuse
 */
	 if (NOT_NULL (name) && !strcmp (name, "ALL"))

	 {
		  FOR X IN TCS.FAILURES
			  ERASE X
		  ON_ERROR
				 print_error ("Error during erase of failures for %s",name,0,0);
		  gds__print_status (gds__status);
		  return FALSE;
		  END_ERROR;
		  END_FOR;
	 }
	 else
#endif

/*	Clear out all failure records with run name = name	*/

	 if (NOT_NULL (name))

	 {
	SSHORT count = 0;

		  FOR X IN TCS.FAILURES WITH X.RUN = name
				ERASE X
		  ON_ERROR
				 print_error ("Error during erase of failures for %s",name,0,0);
		  gds__print_status (gds__status);
		  return FALSE;
		  END_ERROR;
		 count++;
		  END_FOR;

		if (!count)
		{
		 print_error ("There are no failure records with run name = %s",name,0,0);
		 return FALSE;
		}

	 }

/*	Clear out all failure records having the current run name(run_name) */

	 else

	 {
	SSHORT count = 0;

		FOR X IN TCS.FAILURES WITH X.RUN = run_name
				ERASE X
		  ON_ERROR
				 print_error ("Error during erase of failures for %s",run_name,0,0);
		  gds__print_status (gds__status);
		  return FALSE;
		  END_ERROR;
		 count++;
		END_FOR;

		if (!count)
		{
		  print_error ("There are no failure records with run name = %s",run_name,0,0);
		  return FALSE;
		}
	 }
  return TRUE;
}

static int commit()
{
/**************************************
 *
 *	c o m m i t
 *
 **************************************
 *
 * Functional description
 *	Commit the current transaction.
 *
 **************************************/

COMMIT;
START_TRANSACTION;
return TRUE;
}

static int create_bp (name, template)
	TEXT    *name, *template;
{
/**************************************
 *
 *	c r e a t e _ b p 
 *
 **************************************
 *
 * Functional description
 *
 *         edit a new boiler plate script 
 *         use env profile as template
 *         if specified
 *
 **************************************/
SSHORT count;

count = 0;

/*	If template was specified then use it.			*/

if (NOT_NULL(template))

{

/*	Copy the specified template over to the new bp.	*/

    FOR T IN TCS.BOILER_PLATE WITH T.BOILER_PLATE_NAME = template
        STORE B IN TCS.BOILER_PLATE
        count++;
        gds__vtov (name, B.BOILER_PLATE_NAME, sizeof (B.BOILER_PLATE_NAME));
	CREATE_BLOB BTB IN B.SCRIPT
	FOR BB IN T.SCRIPT
             gds__vtov (BB.SEGMENT, BTB.SEGMENT, sizeof(BTB.SEGMENT));
	     BTB.LENGTH  = BB.LENGTH;
	     PUT_SEGMENT BTB;
	END_FOR;
	CLOSE_BLOB BTB;
       END_STORE
	    ON_ERROR
            print_error ("Error during STORE:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	    END_ERROR;
    END_FOR;

/*	Edit the new bp with name = name		*/

    FOR T IN TCS.BOILER_PLATE WITH T.BOILER_PLATE_NAME EQ name
        MODIFY T USING
            if (!BLOB_edit (&T.SCRIPT, TCS, gds__trans, name))
                return FALSE;
        END_MODIFY
	ON_ERROR
            print_error ("Modification of Boiler Plate failed:",0,0,0);
	    gds__print_status(gds__status);
	    longjmp (JumpBuffer, 1);	
	END_ERROR;
        return TRUE;
    END_FOR;
}

/*	Why we need to check count when the function returns upon 	*
 *	successful creation and edit of the new bp is beyond me.	*
 *	Create and edit the new bp.					*/

if (!count)				/* Is this check necessary? */
    STORE B IN TCS.BOILER_PLATE
        gds__vtov (name, B.BOILER_PLATE_NAME, sizeof (B.BOILER_PLATE_NAME));
        BLOB_edit (&B.SCRIPT, TCS, gds__trans, name);
    END_STORE
	 ON_ERROR
		  print_error ("Error during STORE:",0,0,0);
		  gds__print_status (gds__status);
		  return FALSE;
	 END_ERROR;
	 
  return TRUE;	 
}         

static int create_env (name, template)
   TEXT    *name, *template; 
{
/**************************************
 *
 *	c r e a t e _ e n v 
 *
 **************************************
 *
 * Functional description
 *
 *         edit a new env script 
 *         use env profile as template
 *         if specified
 *
 **************************************/
SSHORT count;

count = 0;

/*	If template was specified then use it.			*/

if (NOT_NULL(template))

{

/*	Copy the specified template over to the new env.	*/

    FOR T IN TCS.ENV WITH T.ENV_NAME = template
        STORE E IN TCS.ENV
        count++;
        gds__vtov (name, E.ENV_NAME, sizeof (E.ENV_NAME));
	CREATE_BLOB ETB IN E.PROLOG
	FOR EB IN T.PROLOG
             gds__vtov (EB.SEGMENT, ETB.SEGMENT, sizeof(ETB.SEGMENT));
	     ETB.LENGTH  = EB.LENGTH;
	     PUT_SEGMENT ETB;
	END_FOR;
	CLOSE_BLOB ETB;
       END_STORE
	    ON_ERROR
            print_error ("Error during STORE:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	    END_ERROR;
    END_FOR;

/*	Edit the new env with name = name		*/

    FOR T IN TCS.ENV WITH T.ENV_NAME EQ name
        MODIFY T USING
            if (!BLOB_edit (&T.PROLOG, TCS, gds__trans, name))
                return FALSE;
        END_MODIFY
	ON_ERROR
            print_error ("Error during MODIFY:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	END_ERROR;
        return TRUE;
    END_FOR;
    }

/*	Why we need to check count when the function returns upon 	*
 *	successful creation and edit of the new env is beyond me.	*
 *	Create and edit the new env.					*/

if (!count)
    STORE E IN TCS.ENV
        gds__vtov (name, E.ENV_NAME, sizeof (E.ENV_NAME));
        BLOB_edit (&E.PROLOG, TCS, gds__trans, name);
    END_STORE
	    ON_ERROR
            print_error ("Error during STORE:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
		 END_ERROR;

	return TRUE;
}

static int create_local (string, vers)
	TEXT    *string, *vers;
{
/**************************************
 *
 *	c r e a t e _ l o c a l
 *
 **************************************
 *
 * Functional description
 *
 *         edit a new local test 
 *
 **************************************/
TEXT *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
    return FALSE;

/*	Check to make sure the test does not already exist.		*/

FOR T IN TCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v

    print_error ("Local Test %s V%s already exists", string,*vers ? vers : version,0);
    return FALSE;

END_FOR;

/*	If the test does not already exist we made it to here, so 	*
 *	store the test(TEST_NAME,SCRIPT,VERSION).			*/

STORE T IN TCS.TESTS
    gds__vtov (string, T.TEST_NAME, sizeof (T.TEST_NAME));
    BLOB_edit (&T.SCRIPT, TCS, gds__trans, string);
    gds__vtov (v, T.VERSION, sizeof (T.VERSION));
END_STORE
   ON_ERROR
   print_error ("Error during STORE:",0,0,0);
   gds__print_status (gds__status);
	return FALSE;
	END_ERROR;

  return TRUE;
}

static int create_meta_series (name, swtch)
	TEXT  *name, *swtch;
{
/**************************************
 *
 *	c r e a t e _ m e t a _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *     loop the creation of series and accomodate
 *     storing of env
 *
 **************************************/
TEXT    buffer[20];
SSHORT   seq;

seq = 0;

/*	If a name was not entered then make them enter the name. 	*/

if (NULL_STR (name))
	disp_get_string ("Metaseries name is", name, 20);

disp_upcase (name, name);		 /* Convert to upper case */

/* 	If the switch is NULL assume Global(G), else convert to upper case */

if (NOT_NULL(swtch))
	 disp_upcase(swtch,swtch);
else
	 *swtch = 'G';

/*	If *swtch is Local(L) then create the meta series in the local	*
 *	DB.								*/

if (*swtch == 'L')
{

/* 	Check to see if the meta series already exists			*/

	 FOR S IN TCS.META_SERIES WITH S.META_SERIES_NAME = name
		 print_error ("Local series %s already exists.", name,0,0);
		 return FALSE;
	 END_FOR;

/*	Prompt for a series name and keep looping until a quit 		*
 *	is entered, adding each series name to the meta series as we go	*/

	 while (disp_get_answer("Series name", buffer, sizeof(buffer)))
    {
	STORE S IN TCS.META_SERIES USING
	    gds__vtov (name, S.META_SERIES_NAME, sizeof (S.META_SERIES_NAME));
	    gds__vtov (buffer, S.SERIES_NAME, sizeof (S.SERIES_NAME));
	    S.SEQUENCE = seq++;
	END_STORE                                 
	    ON_ERROR
            print_error ("Error during STORE:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	    END_ERROR;
	 }
}

/*	Else if Global(G) then create the meta series in the global DB.	*/

else
{

/* 	Check to see if the meta series already exists			*/

    FOR S IN TCS_GLOBAL.META_SERIES WITH S.META_SERIES_NAME = name
       print_error ("Global series %s already exists.", name,0,0);
       return FALSE;
    END_FOR;

/*	Prompt for a series name and keep looping until a quit 		*
 *	is entered, adding each series name to the meta series as we go	*/

    while (disp_get_answer("Series name", buffer, sizeof(buffer)))
    {
	STORE S IN TCS_GLOBAL.META_SERIES USING
	    gds__vtov (name, S.META_SERIES_NAME, sizeof (S.META_SERIES_NAME));
	    gds__vtov (buffer, S.SERIES_NAME, sizeof (S.SERIES_NAME));
	    S.SEQUENCE = seq++;
	END_STORE
	    ON_ERROR
            print_error ("Error during STORE:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	    END_ERROR;
	 }

}

return TRUE;
}

static int create_series (name, swtch)
	TEXT  *name, *swtch;
{
/**************************************
 *
 *	c r e a t e _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *     loop the creation of series
 *
 **************************************/
TEXT    buffer[20];
SSHORT   seq;

seq = 0;

/*	If a name was not entered then make them enter the name. 	*/

if (NULL_STR (name))
   disp_get_string ("Series name is", name, 20); 

disp_upcase (name, name);		/* Convert to upper case */

/* 	If the switch is NULL assume Global(G), else convert to upper case */

if (NOT_NULL(swtch))
    disp_upcase(swtch,swtch);
else
    *swtch = 'G';

/*	If *swtch is Local(L) then create the series in the local	*
 *	DB.								*/

if (*swtch == 'L')

{

/* 	Check to see if the series already exists			*/

    FOR S IN TCS.SERIES WITH S.SERIES_NAME = name
       print_error ("Local series %s already exists.", name,0,0);
       return FALSE;
    END_FOR;

/*	Prompt for a test name and keep looping until a quit 		*
 *	is entered, adding each test name to the series as we go	*/

    while (disp_get_answer("Test name", buffer, sizeof(buffer)))
    {
	STORE S IN TCS.SERIES USING
	    gds__vtov (name, S.SERIES_NAME, sizeof (S.SERIES_NAME));
	    gds__vtov (buffer, S.TEST_NAME, sizeof (S.TEST_NAME));
	    S.SEQUENCE = seq++;
	END_STORE
	    ON_ERROR
            print_error ("Error during STORE:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	    END_ERROR;
    }
}

/*	Else if Global(G) then create the series in the global DB.	*/

else
{ 

/*	Check to see if the series already exists in the global DB.	*/

    FOR S IN TCS_GLOBAL.SERIES WITH S.SERIES_NAME = name
       print_error ("Global series %s already exists.", name,0,0);
       return FALSE;
    END_FOR;

/*	Prompt for a test name and keep looping until a quit is 	*
 *	entered, adding each test name to the series as we go.		*/

    while (disp_get_answer("Test name", buffer, sizeof(buffer)))
    {
	STORE S IN TCS_GLOBAL.SERIES USING
	    gds__vtov (name, S.SERIES_NAME, sizeof (S.SERIES_NAME));
	    gds__vtov (buffer, S.TEST_NAME, sizeof (S.TEST_NAME));
	    S.SEQUENCE = seq++;
	END_STORE
	    ON_ERROR
            print_error ("Error during STORE:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	    END_ERROR;
    }
}
 return TRUE;
}

static int create (string, vers)
   TEXT    *string, *vers;
{
/**************************************
 *
 *	c r e a t e
 *
 **************************************
 *
 * Functional description
 *
 *         edit a new global test to be stored in the
 *         global tcs database.  Currently this is
 *         a distinct command to make implementation 
 *         real quick
 *
 **************************************/
TEXT *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
    return FALSE;

/*	Check global database to see if test already exists.	*/

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v

    print_error ("Global Test %s V%s already exists", string,*vers ? vers : version,0);
    return FALSE;

END_FOR;

/*	Create the global test.		*/

STORE T IN TCS_GLOBAL.TESTS
    gds__vtov (string, T.TEST_NAME, sizeof (T.TEST_NAME));
    BLOB_edit (&T.SCRIPT, TCS_GLOBAL, gds__trans, string);
    gds__vtov (v, T.VERSION, sizeof (T.VERSION));
END_STORE
    ON_ERROR
    print_error ("Error during STORE:",0,0,0);
    gds__print_status (gds__status);
    return FALSE;
	 END_ERROR;

  return TRUE;	 
}

static int delete_initialization (t_name, vers)
TEXT    *t_name, *vers;
{
/**************************************
*
*       d e l e t e _ i n i t i a l i z a t i o n
*
**************************************
*
* Functional description
*       Delete an initialization in the global 
*       DB for the specified test, version.
*
**************************************/
USHORT	count;
TEXT    *v;
 
/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
    return FALSE;
 
count = 0;


/* Delete the initialization--with name=t_name and version = v */

FOR T IN TCS_GLOBAL.INIT WITH T.TEST_NAME EQ t_name AND T.VERSION = v
    ERASE T
     ON_ERROR
     print_error ("Error during erase of Init",0,0,0);
     gds__print_status (gds__status);
     return FALSE;
     END_ERROR;
    count++;
END_FOR;

 if (!count)
 {
	 print_error ("%s, V%s, does not exist globally",t_name,*vers ? vers : version,0);
	 return FALSE;
 }
 return TRUE;
}

static int delete_local_initialization (t_name, vers)
TEXT    *t_name, *vers;
{
/**************************************
*
*       d e l e t e _ l o c a l _ i n i t i a l i z a t i o n
*
**************************************
*
* Functional description
*       Delete an initialization in the local
*       DB for the specified test, version.
*
**************************************/
USHORT	count;
TEXT    *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

count = 0;


/* Delete the initialization--with name=t_name and version = v */

FOR T IN TCS.INIT WITH T.TEST_NAME EQ t_name AND T.VERSION = v
    ERASE T
     ON_ERROR
     print_error ("Error during erase of Init",0,0,0);
     gds__print_status (gds__status);
     return FALSE;
     END_ERROR;
    count++;
END_FOR;

 if (!count)
 {
	 print_error ("%s, V%s, does not exist locally",t_name,*vers ? vers : version,0);
	 return FALSE;
 }
 return TRUE;
}

static int delete_local_test (string, vers)
	 TEXT	*string, *vers;
{
/**************************************
 *
 *	d e l e t e _ l o c a l _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Delete a local test.
 *
 **************************************/
TEXT	 *v;
SSHORT  count = 0;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

FOR T IN TCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v
	 ERASE T
     ON_ERROR
     print_error ("Error during erase of Test",0,0,0);
     gds__print_status (gds__status);
	  return FALSE;
	  END_ERROR;
	 count++;
END_FOR;

if (!count)
{
	 print_error ("%s, V%s, does not exist locally",string,*vers ? vers : version,0);
	 return FALSE;
}
return TRUE;
}

static int delete_test (string, vers)
    TEXT	*string, *vers;
{
/**************************************
 *
 *	d e l e t e _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Delete a global test. 
 *
 **************************************/
TEXT	  *v;
SSHORT  count = 0;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v
	 ERASE T
	  ON_ERROR
	  print_error ("Error during erase of Test",0,0,0);
	  gds__print_status (gds__status);
	  return FALSE;
	  END_ERROR;
	 count++;
END_FOR;

if (!count)
{
	 print_error ("%s, V%s, does not exist globally",string,*vers ? vers : version,0);
	 return FALSE;
}
return TRUE;
}

static int delete_test_from_series (test_string, series_string)
	 TEXT	*test_string, *series_string;
{
/******************************************************
 *
 *	d e l e t e _ t e s t _ f r o m _ s e r i e s
 *
 ******************************************************
 *
 * Functional description
 *	Delete all copies of a test from a specific global
 *	series.  This function is needed when we move a test
 *	from one series to another.  The test remains in the
 *	database, but is no longer associated with a series.
 *
 *	There should not be ANY local series.  They
 *	will have to be cleared through ISQL.
 ******************************************************/
SSHORT  count = 0;

FOR T IN TCS_GLOBAL.SERIES WITH T.SERIES_NAME EQ series_string
  AND T.TEST_NAME EQ test_string
	 ERASE T
	  ON_ERROR

	  print_error ("Error during erase of Test %s from series %s",
			test_string, series_string,0);
	  gds__print_status (gds__status);
	  return FALSE;
	  END_ERROR;
	 count++;
END_FOR;

/* Count of 0 means test was not found in this series. */
if (!count)
	 {
	print_error ("%s does not exist in series %s", test_string,
				series_string, 0);
	return FALSE;
	 }
  return TRUE;	 
}

static int delete_times ()
{
/**************************************
 *
 *	d e l e t e _ t i m e s
 *
 **************************************
 *
 * Functional description
 *	Clear out all timing information records.
 *
 **************************************/

FOR X IN TCS.TIMES
	 ERASE X
	  ON_ERROR
	  print_error ("Error during erase of times",0,0,0);
	  gds__print_status (gds__status);
	  return FALSE;
	  END_ERROR;
END_FOR;
return TRUE;
}

static int diff (string)
	 TEXT	*string;
{
/**************************************
 *
 *	d i f f
 *
 **************************************
 *
 * Functional description
 *	Print differences for failed test.
 *
 **************************************/
SSHORT   count = 0;

/*	Grab the most recent failure with name = string and 	*
 *	run equal to the current run name(run_name).  Print	*
 *	initialization information and then print the diff 	*
 *	blob(F.DIFFERENCES).					*/

FOR FIRST 1 F IN TCS.FAILURES
  CROSS I IN TCS.INIT OVER TEST_NAME
  WITH F.TEST_NAME EQ string AND F.RUN = run_name
  SORTED BY DESCENDING F.DATE
	 printf ("Test %s failed on %s:\n", string, F.DATE.CHAR [11]);
	 printf ("\tinitialized by %s \n\ton %s with boilerplate %s\n",
				I.INIT_BY, I.INIT_DATE.CHAR [11], I.BOILER_PLATE);
	 disp_print_blob (&F.DIFFERENCES, TCS);
	 count++;
END_FOR;

/*	If the initialization does not exist in the local database	*
 *	(count==0) then search the global database.  Print the 		*
 *	initialization information and then print the diff blob.	*
 *	(F.DIFFERENCES).						*/

if (!count)

{
	 FOR FIRST 1 F IN TCS.FAILURES
		WITH F.TEST_NAME EQ string AND F.RUN = run_name
		SORTED BY DESCENDING F.DATE
	count++;
	printf ("Test %s failed on %s:\n", string, F.DATE.CHAR [11]);
		  FOR FIRST 1 I IN TCS_GLOBAL.INIT WITH
	  I.TEST_NAME = F.TEST_NAME
	  AND I.VERSION <= F.VERSION
	  SORTED BY DESCENDING I.VERSION
				printf ("\tinitialized by %s \n\ton %s with boilerplate %s\n",
					 I.INIT_BY, I.INIT_DATE.CHAR [11], I.BOILER_PLATE);
	END_FOR;
	disp_print_blob (&F.DIFFERENCES, TCS);
	 END_FOR;
}
return TRUE;
}

static int duplicate_global (name1, vers1, name2, vers2)
	TEXT    *name1, *name2, *vers1, *vers2;
{
/**************************************
 *
 *	d u p l i c a t e _ g l o b a l
 *
 **************************************
 *
 * Functional description
 *
 *         Duplicate the named global
 *         test in the global tcs
 *         database as a new version.
 *
 **************************************/
BASED_ON TCS.TESTS.VERSION v1b;
BASED_ON TCS.TESTS.VERSION v2b;
TEXT *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers1)))
	 return FALSE;
gds__vtov (v, v1b, sizeof(v1b));
if ( !(v = make_version (vers2)))
	 return FALSE;
gds__vtov (v, v2b, sizeof(v2b));

/*	Hunt for global test with name = name1 and version = v1b	*	
 *	and copy info to new global test record with name = name2 and	*
 *	version = v2b.  Use gds__vtov for fields and FOR loops		*
 *	with gds__vtov statements for each segment of BLOBS.		*/	

FOR G IN TCS_GLOBAL.TESTS WITH G.TEST_NAME EQ name1 AND G.VERSION = v1b
    STORE T IN TCS_GLOBAL.TESTS USING
        if (NOT_NULL (name2))
            gds__vtov (name2, T.TEST_NAME, sizeof(T.TEST_NAME));
        else
            gds__vtov (G.TEST_NAME, T.TEST_NAME, sizeof(T.TEST_NAME));
	gds__vtov (v2b, T.VERSION, sizeof(T.VERSION));
        gds__vtov (G.CREATED_BY, T.CREATED_BY, sizeof(T.CREATED_BY));
	gds__vtov (v2b, T.VERSION, sizeof(T.VERSION));
	CREATE_BLOB TBG IN T.COMMENT;
	FOR GB IN G.COMMENT
             gds__ftof (GB.SEGMENT, sizeof(GB.SEGMENT), TBG.SEGMENT, sizeof(TBG.SEGMENT));
	     TBG.LENGTH  = GB.LENGTH;
	     PUT_SEGMENT TBG;
	END_FOR;
	CLOSE_BLOB TBG;
	CREATE_BLOB STBG IN T.SCRIPT;
	FOR SGB IN G.SCRIPT
             gds__ftof (SGB.SEGMENT, sizeof(SGB.SEGMENT), STBG.SEGMENT, sizeof(STBG.SEGMENT));
	     STBG.LENGTH  = SGB.LENGTH;
	     PUT_SEGMENT STBG;
	END_FOR;
	CLOSE_BLOB STBG;
    END_STORE

    /* Check to see if dup failed, and print gds__status if did. */

    ON_ERROR
        print_error ("Duplication of global test failed:",0,0,0);
	gds__print_status(gds__status);
	longjmp (JumpBuffer, 1);	
    END_ERROR;
END_FOR;
return TRUE;
}

static int duplicate_global_local (name1, vers1, name2, vers2)
	TEXT    *name1, *name2, *vers1, *vers2;
{
/**************************************
 *
 *	d u p l i c a t e _ g l o b a l _ l o c a l
 *
 **************************************
 *
 * Functional description
 *
 *         Duplicate the named global
 *         test in the local tcs
 *         database.
 *
 **************************************/
BASED_ON TCS.TESTS.VERSION v1b;
BASED_ON TCS.TESTS.VERSION v2b;
TEXT *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers1)))
	 return FALSE;
gds__vtov (v, v1b, sizeof(v1b));
if ( !(v = make_version (vers2)))
	 return FALSE;
gds__vtov (v, v2b, sizeof(v2b));

/*	Hunt for global test with name = name1 and version = v1b	*	
 *	and copy info to new local test record with name = name2 and	*
 *	version = v2b.  Use gds__vtov for fields and FOR loops		*
 *	with gds__vtov statements for each segment of BLOBS.		*/	

FOR G IN TCS_GLOBAL.TESTS WITH G.TEST_NAME EQ name1 AND G.VERSION = v1b
    STORE T IN TCS.TESTS USING
        if (NOT_NULL (name2))
            gds__vtov (name2, T.TEST_NAME, sizeof(T.TEST_NAME));
        else
            gds__vtov (G.TEST_NAME, T.TEST_NAME, sizeof(T.TEST_NAME));
        gds__vtov (G.CREATED_BY, T.CREATED_BY, sizeof(T.CREATED_BY));
        gds__vtov (v2b, T.VERSION, sizeof(T.VERSION));
	CREATE_BLOB TB IN T.COMMENT;
	FOR GB IN G.COMMENT
             gds__ftof (GB.SEGMENT, sizeof(GB.SEGMENT), TB.SEGMENT, sizeof(TB.SEGMENT));
	     TB.LENGTH  = GB.LENGTH;
	     PUT_SEGMENT TB;
	END_FOR;
	CLOSE_BLOB TB;
	CREATE_BLOB STB IN T.SCRIPT;
	FOR SGB IN G.SCRIPT
             gds__ftof (SGB.SEGMENT, sizeof(SGB.SEGMENT), STB.SEGMENT, sizeof(STB.SEGMENT));
	     STB.LENGTH  = SGB.LENGTH;
	     PUT_SEGMENT STB;
	END_FOR;
	CLOSE_BLOB STB;
    END_STORE

    /* Check to see if dup failed, and print gds__status if did. */

    ON_ERROR
        print_error ("Duplication of global test to local test failed:",0,0,0);
	gds__print_status(gds__status);
	longjmp (JumpBuffer, 1);	
    END_ERROR;
END_FOR;
return TRUE;
}

static int duplicate_local (name1, vers1, name2, vers2)
	TEXT    *name1, *name2, *vers1, *vers2;
{
/**************************************
 *
 *	d u p l i c a t e _ l o c a l
 *
 **************************************
 *
 * Functional description
 *
 *         Duplicate the named local
 *         test in the local tcs
 *         database as a new version.
 *
 **************************************/
BASED_ON TCS.TESTS.VERSION v1b;
BASED_ON TCS.TESTS.VERSION v2b;
TEXT *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers1)))
	 return FALSE;
gds__vtov (v, v1b, sizeof(v1b));    	/* Store version in IB variable */
if ( !(v = make_version (vers2)))
	 return FALSE;
gds__vtov (v, v2b, sizeof(v2b));	/* Store version in IB variable */

/*	Hunt for local test with name = name1 and version = v1b		*
 *	and copy info to new test record with name = name2 and		*
 *	version = v2b.  Use gds__vtov for fields and FOR loops		*
 *	with gds__vtov statements for each segment of BLOBS.		*/	

FOR G IN TCS.TESTS WITH G.TEST_NAME EQ name1 AND G.VERSION = v1b
    STORE T IN TCS.TESTS USING
        if (NOT_NULL (name2))
            gds__vtov (name2, T.TEST_NAME, sizeof(T.TEST_NAME));
        else
            gds__vtov (G.TEST_NAME, T.TEST_NAME, sizeof(T.TEST_NAME));
        gds__vtov (G.CREATED_BY, T.CREATED_BY, sizeof(T.CREATED_BY));
        gds__vtov (v2b, T.VERSION, sizeof(T.VERSION));
	CREATE_BLOB TBL IN T.COMMENT;
	FOR GB IN G.COMMENT
             gds__ftof (GB.SEGMENT, sizeof(GB.SEGMENT), TBL.SEGMENT, sizeof(TBL.SEGMENT));
	     TBL.LENGTH  = GB.LENGTH;
	     PUT_SEGMENT TBL;
	END_FOR;
	CLOSE_BLOB TBL;
	CREATE_BLOB STBL IN T.SCRIPT;
	FOR SGB IN G.SCRIPT
             gds__ftof (SGB.SEGMENT, sizeof(SGB.SEGMENT), STBL.SEGMENT, sizeof(STBL.SEGMENT));
	     STBL.LENGTH  = SGB.LENGTH;
	     PUT_SEGMENT STBL;
	END_FOR;
	CLOSE_BLOB STBL;
    END_STORE

    /* Check to see if dup failed, and print gds__status if did. */

    ON_ERROR
        print_error ("Duplication of local test failed:",0,0,0);
	gds__print_status(gds__status);
	longjmp (JumpBuffer, 1);	
    END_ERROR;
END_FOR;
return TRUE;
}

static int edit (string, vers)
	 TEXT	*string, *vers;
{
/**************************************
*
*	e d i t
*
**************************************
*
* Functional description
*	Edit or store a test script.
*       in the remote db for multi_platform use
*
**************************************/
TEXT response[4], *v;
BASED_ON TCS.TESTS.VERSION prior_version;
BASED_ON TCS.TESTS.VERSION wanted_version;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

unmake_version (wanted_version, v);

/*	Search for global test with name = string and version = v	*
 *	then call BLOB_edit to edit the test.				*/

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v
	 MODIFY T USING
		  if (!BLOB_edit (&T.SCRIPT, TCS_GLOBAL, gds__trans, string))
				return FALSE;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	return TRUE;
END_FOR;


strcpy (prior_version, "");
FOR FIRST 1 T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION < v
	 SORTED BY DESCENDING T.VERSION

	 unmake_version (prior_version, T.VERSION);

END_FOR;

if (prior_version[0])
	 {

	 sprintf (prompt, "Test %s V%s doesn't exist, but V%s does.\nDo you want to clone a new version?",
	string, wanted_version, prior_version);

	 if (!(disp_get_string (prompt, response, 4)))
		  return FALSE;
	 if ((response[0] != 'y') && (response[0] != 'Y'))
        return FALSE;

    duplicate_global (string, prior_version, "", vers);

    FOR FIRST 1 T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v
	MODIFY T USING
            if (!BLOB_edit (&T.SCRIPT, TCS_GLOBAL, gds__trans, string))
					 return FALSE;
		  END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	 END_FOR;
	 return TRUE;
	 }

/*	If made it to here then could not find test 			*/

sprintf (prompt, "Test %s V%s doesn't exist. Do you want to create it?",
	string, wanted_version);

/*	Prompt the user, and if anything but no or NULL is given the 	*
 *	call create() to create the test.				*/

if (!(disp_get_string (prompt, response, 4)))
	 return FALSE;
if ((response[0] == 'n') || (response[0] == 'N'))
	 return FALSE;

create (string, vers);
return TRUE;
}

static int edit_boilerplate (string)
    TEXT	*string;
{
/**************************************
 *
 *	e d i t _ b o i l e r p l a t e
 *
 **************************************
 *
 * Functional description
 *	Edit or store a test script.
 *
 **************************************/
TEXT response[4];

/*	Edit boilerplate with name=string 	*/

FOR T IN TCS.BOILER_PLATE WITH T.BOILER_PLATE_NAME EQ string
    MODIFY T USING
	if (!BLOB_edit (&T.SCRIPT, TCS, gds__trans, string))
		 return FALSE;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	return TRUE;
END_FOR;

/*	If made it here then could not find the boilerplate--		*
 *	did not hit the return, so allow to create.			*/

sprintf (prompt, "    Boiler plate %s doesn't exist. Do you want to create it?", string);

/*	Give prompt and if anything but no or NULL is entered call	*
 *	create_bp to create the new bp with name = string.		*/

if (!(disp_get_string (prompt, response, 4)))
	 return FALSE;
if ((response[0] == 'n') || (response[0] == 'N'))
	 return FALSE;

create_bp (string,NULL);
return TRUE;
}

static int edit_comment (string)
	 TEXT	*string;
{
/**************************************
 *
 *	e d i t _ c o m m e n t
 *
 **************************************
 *
 * Functional description
 *	Edit or store a test comment.
 *
 **************************************/

TEXT* current_version = version;

/*	Look for global test comment with name = string and edit	it. */

FOR FIRST 1 T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string
	 AND T.VERSION LE current_version
	 SORTED BY DESCENDING T.VERSION
	 MODIFY T USING
	if (!BLOB_edit (&T.COMMENT, TCS_GLOBAL, gds__trans, string))
		 return FALSE;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	return TRUE;
END_FOR;

/*	Print an error if got here */

print_error ("Test %s does not exist", string,0,0);
return FALSE;
}

static int edit_env (name)
TEXT	*name;
{
/**************************************
*
*	e d i t _ e n v
*
**************************************
*
* Functional description
*	Edit or create a test environment .
*
**************************************/
TEXT response[4];

/*	Look for env with env_name = name and call BLOB_edit	*
 *	to edit the env blob.					*/

FOR T IN TCS.ENV WITH T.ENV_NAME EQ name
	 MODIFY T USING
		  if (!BLOB_edit (&T.PROLOG, TCS, gds__trans, name))
		 return FALSE;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	return TRUE;
END_FOR;

/* 	If here then GDML was not able to find the env with name,	*
 *	so allow user to create a new one.				*/

sprintf (prompt, "    Environment %s doesn't exist. Do you want to create it?", name);

/*	Give prompt and get string, if string is anything other than	*
 *	NULL or no, then call create_env to create new env with name.	*/

if (!(disp_get_string (prompt, response, 4)))
    return FALSE;
if ((response[0] == 'n') || (response[0] == 'N'))
    return FALSE;

create_env (name,NULL);
return TRUE;
}

static int edit_global_initialization (string, vers)
TEXT 	*string, *vers;
{
/**************************************
*
*       e d i t _ g l o b a l _ i n i t i a l i z a t i o n
*
**************************************
*
* Functional description
*       Edit initialization stored in the global
*	DB for the specified test.
*
**************************************/
TEXT	*v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/* Edit the initialization--with name=string and version = v */

FOR T IN TCS_GLOBAL.INIT WITH T.TEST_NAME EQ string AND T.VERSION = v
	 MODIFY T USING
	if (!BLOB_edit (&T.OUTPUT, TCS_GLOBAL, gds__trans, string))
		 return FALSE;
	 END_MODIFY
	ON_ERROR
	  	 print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
   return TRUE;
END_FOR;

/* 	If made it to here then obviously did not hit returns	*
 *	in the GDML--could not find global init, so print 	*
 *	error string.						*/

print_error("No global init. exists for test %s V%s", string,*vers ? vers : version,0);

return FALSE;
}

static int edit_local (string, vers)
TEXT	*string, *vers;
{
/**************************************
*
*	e d i t _ l o c a l
*
**************************************
*
* Functional description
*	Edit or store a test script.
*
**************************************/
TEXT response[4], *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Call BLOB_edit (IB function) for test with name=string and	*
 *	version=v.							*/

FOR T IN TCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v
    MODIFY T USING
        if (!BLOB_edit (&T.SCRIPT, TCS, gds__trans, string))
	    return FALSE;
    END_MODIFY
	ON_ERROR
            print_error ("Error during MODIFY:",0,0,0);
	    gds__print_status (gds__status);
	    return FALSE;
	END_ERROR;
	return TRUE;
END_FOR;

/* 	If made it to here then test does not exist because return 	*
 * 	was not called.							*/

sprintf (prompt, "Test %s V%s doesn't exist. Do you want to create it?", string, *vers ? vers : version);

/*	Get the response and if anything but no or NULL, then call  	*
 *	create_local to create a local test.				*/

if (!(disp_get_string (prompt, response, 4)))
	 return FALSE;
if ((response[0] == 'n') || (response[0] == 'N'))
	 return FALSE;

create_local (string, vers);
return TRUE;
}

static int edit_local_comment (string)
	 TEXT	*string;
{
/**************************************
 *
 *	e d i t _ l o c a l _ c o m m e n t
 *
 **************************************
 *
 * Functional description
 *	Edit or store a local test comment.
 *
 **************************************/
 TEXT* current_version = version;

FOR FIRST 1 T IN TCS.TESTS WITH T.TEST_NAME EQ string
	 AND T.VERSION LE current_version
	 SORTED BY DESCENDING T.VERSION
	 MODIFY T USING
	if (!BLOB_edit (&T.COMMENT, TCS, gds__trans, string))
		 return FALSE;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	return TRUE;
END_FOR;

/*	if count was incremented--success on the modify, then		*
 *	return, else print an error.					*/

print_error ("Test %s does not exist", string,0,0);
return FALSE;
}

static int edit_local_initialization (string, vers)
TEXT    *string, *vers;
{
/**************************************
*
*       e d i t _ l o c a l _ i n i t i a l i z a t i o n
*
**************************************
*
* Functional description
*       Edit initialization stored in the local
*       DB for the specified test.
*
**************************************/
TEXT    *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/* Edit the initialization--with name=string and version = v */

FOR T IN TCS.INIT WITH T.TEST_NAME EQ string AND T.VERSION = v
	 MODIFY T USING
		  if (!BLOB_edit (&T.OUTPUT, TCS, gds__trans, string))
				return FALSE;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	 return TRUE;
END_FOR;

/*	If made it to here then the modify was not a success--		*
 *	could not find the init for name = string and version = v.	*/

print_error("No local init. exists for test %s V%s", string, *vers ? vers : version,0);

return FALSE;
}

static int edit_meta_series_comment (name, swtch)
	 TEXT        *name, *swtch;
{
/**************************************
 *
 *      e d i t _ m e t a _ s e r i e s _ c o m m e n t
 *
 **************************************
 *
 * Functional description
 *      Edit or store a series comment.
 *
 **************************************/
USHORT count;
 
count = 0;

/* Check switch to make sure is not null and convert to upcase */
 
if (NOT_NULL(swtch))
    disp_upcase (swtch, swtch);
else
    *swtch = 'G';

/* If switch is local(L) edit local meta series comment */
 
if (*swtch == 'L')

{
    FOR FIRST 1 T IN TCS.META_SERIES WITH T.META_SERIES_NAME EQ name
        FOR C IN TCS.META_SERIES_COMMENT WITH C.META_SERIES_NAME EQ name
            MODIFY C USING
                if (!BLOB_edit (&C.COMMENT, TCS, gds__trans, name))
						  return FALSE;
				END_MODIFY
		ON_ERROR
		print_error ("Error during MODIFY:",0,0,0);
		gds__print_status (gds__status);
			return FALSE;
			  END_ERROR;
				count++;
		  END_FOR;

	/* If modify failed then record does not exist, so create and  	*
	 * edit.							*/

		  if (!count)

		  {
				STORE C IN TCS.META_SERIES_COMMENT
					 gds__vtov (name, C.META_SERIES_NAME, sizeof (C.META_SERIES_NAME));
					 BLOB_edit (&C.COMMENT, TCS, gds__trans, name);
				END_STORE
			  ON_ERROR
					 print_error ("Error during STORE:",0,0,0);
			  gds__print_status (gds__status);
			  return FALSE;
			  END_ERROR;
				count++;
		  }
	 END_FOR;

/* If store/modify succeeded then exit, else print error */

	 if (count)
		  return TRUE;

	 print_error ("Meta_series %s does not exist locally", name,0,0);
}

/* If switch is global(G), then edit global meta series comment */

else

{
    FOR FIRST 1 T IN TCS_GLOBAL.META_SERIES WITH T.META_SERIES_NAME EQ name
        FOR C IN TCS_GLOBAL.META_SERIES_COMMENT WITH C.META_SERIES_NAME EQ name
            MODIFY C USING
                if (!BLOB_edit (&C.COMMENT, TCS_GLOBAL, gds__trans, name))
						  return FALSE;
				END_MODIFY
		ON_ERROR
					print_error ("Error during MODIFY:",0,0,0);
			 gds__print_status (gds__status);
			 return FALSE;
		END_ERROR;
				count++;
		  END_FOR;

	/* If modify failed then record does not exist, so create and  	*
	 * edit.							*/

		  if (!count)

		  {
				STORE C IN TCS_GLOBAL.META_SERIES_COMMENT
					 gds__vtov (name, C.META_SERIES_NAME, sizeof (C.META_SERIES_NAME));
					 BLOB_edit (&C.COMMENT, TCS_GLOBAL, gds__trans, name);
				END_STORE
			  ON_ERROR
					 print_error ("Error during STORE:",0,0,0);
			  gds__print_status (gds__status);
			  return FALSE;
			  END_ERROR;
				count++;
		  }
	 END_FOR;

/* If store/modify succeeded then exit, else print error */

	 if (count)
		  return TRUE;
	 print_error ("Meta_series %s does not exist globally", name,0,0);
}
return FALSE;
}

static int edit_series_comment (name, swtch)
	 TEXT        *name, *swtch;
{
/**************************************
 *
 *      e d i t _ s e r i e s _ c o m m e n t
 *
 **************************************
 *
 * Functional description
 *      Edit or store a series comment.
 *
 **************************************/
USHORT count;
 
count = 0;

/* Check switch to make sure is not null and convert to upcase */
 
if (NOT_NULL(swtch))
    disp_upcase (swtch, swtch);
else
    *swtch = 'G';

/* If switch is local(L) edit local series comment */
 
if (*swtch == 'L')

{
    FOR FIRST 1 T IN TCS.SERIES WITH T.SERIES_NAME EQ name 
        FOR C IN TCS.SERIES_COMMENT WITH C.SERIES_NAME EQ name
            MODIFY C USING
                if (!BLOB_edit (&C.COMMENT, TCS, gds__trans, name))
						  return FALSE;
				END_MODIFY
		ON_ERROR
				  print_error ("Error during MODIFY:",0,0,0);
		gds__print_status (gds__status);
		return FALSE;
		END_ERROR;
				count++;
		  END_FOR;

	/* If modify failed then record does not exist, so create and  	*
	 * edit.							*/

	if (!count)

	{
		 STORE C IN TCS.SERIES_COMMENT
		gds__vtov (name, C.SERIES_NAME, sizeof (C.SERIES_NAME));
		BLOB_edit (&C.COMMENT, TCS, gds__trans, name);
		 END_STORE
			  ON_ERROR
					 print_error ("Error during STORE:",0,0,0);
			  gds__print_status (gds__status);
			  return FALSE;
			  END_ERROR;
		 count++;
	}
	 END_FOR;

/* If store/modify succeeded then exit, else print error */

	 if (count)
		  return TRUE;

	 print_error ("Series %s does not exist locally", name,0,0);
}

/* If switch is global(G), then edit global series comment */

else

{
	 FOR FIRST 1 T IN TCS_GLOBAL.SERIES WITH T.SERIES_NAME EQ name
		  FOR C IN TCS_GLOBAL.SERIES_COMMENT WITH C.SERIES_NAME EQ name
				MODIFY C USING
					 if (!BLOB_edit (&C.COMMENT, TCS_GLOBAL, gds__trans, name))
						  return FALSE;
				END_MODIFY
		ON_ERROR
					print_error ("Error during MODIFY:",0,0,0);
			gds__print_status (gds__status);
			return FALSE;
		END_ERROR;
				count++;
		  END_FOR;

	/* If modify failed then record does not exist, so create and  	*
	 * edit.							*/

		  if (!count)

	{
		 STORE C IN TCS_GLOBAL.SERIES_COMMENT
			  gds__vtov (name, C.SERIES_NAME, sizeof (C.SERIES_NAME));
			  BLOB_edit (&C.COMMENT, TCS_GLOBAL, gds__trans, name);
		 END_STORE
			  ON_ERROR
					 print_error ("Error during STORE:",0,0,0);
			  gds__print_status (gds__status);
			  return FALSE;
			  END_ERROR;
		 count++;
		}

	 END_FOR;

/* If store/modify succeeded then exit, else print error */

	 if (count)
		  return TRUE;

	 print_error ("Series %s does not exist globally", name,0,0);
}
return FALSE;
}

static int erase (string)
    TEXT	*string;
{
/**************************************
 *
 *	e r a s e
 *
 **************************************
 *
 * Functional description
 *	Clear out all failure records.
 *	Where test name equals string 
 *	and run name equals the current
 *	run name.
 *
 **************************************/
SSHORT count = 0;

FOR X IN TCS.FAILURES WITH X.TEST_NAME EQ string AND X.RUN = run_name
    ERASE X
     ON_ERROR
     print_error ("Error during erase",0,0,0);
     gds__print_status (gds__status);
	  return FALSE;
	  END_ERROR;
	 count++;
END_FOR;

if (!count)
{
	 print_error ("No failure records exist for test:  %s with run name:  %s", string, run_name,0);
	 return FALSE;
}
 return TRUE;
}

static int failure (string)
	 TEXT	*string;
{
/**************************************
 *
 *	f a i l u r e
 *
 **************************************
 *
 * Functional description
 *	Print differences for failed test.
 *	Where failed test has same run_name
 *	as current run name.
 *
 *      5/16 sorted by date
 *
 **************************************/
SSHORT count = 0 ;


FOR FIRST 1 F IN TCS.FAILURES WITH F.TEST_NAME EQ string AND F.RUN = run_name
SORTED BY DESC F.DATE
	 printf ("Test %s failed on %s:\n", string, F.DATE.CHAR[11]);
	 disp_print_blob (&F.OUTPUT, TCS);
	 count++;
END_FOR;

if (!count)
{
	 print_error ("There is no failure record for %s with run name %s",string,run_name,0);
	 return FALSE;
}
 return TRUE;
}

static int find_test_name (string)
	 TEXT  *string;
{
/**************************************
 *
 *  f i n d _ t e s t _ n a m e
 *
 **************************************
 *
 * Functional description
 *  List test_names of both local
 *  and global tests whose names contain
 *  this string
 *
 **************************************/
SSHORT count = 0;


FOR T IN TCS.TESTS WITH T.TEST_NAME CONTAINING string
	 REDUCED TO T.TEST_NAME
	 printf ("%s %s (LOCAL)\n", T.TEST_NAME, T.VERSION);
	 count++;
END_FOR;

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME CONTAINING string
	 REDUCED TO T.TEST_NAME
	 printf ("%s %s\n", T.TEST_NAME, T.VERSION);
	 count++;
END_FOR;

if (!count)
{
	 print_error ("Could not find \"%s\" in TEST_NAME of any test locally or globally", string,0,0);
	 return FALSE;
}
 return TRUE;
}

static int find_series_name (string)
	 TEXT  *string;
{
/**************************************
 *
 *  f i n d _ s e r i e s _ n a m e
 *
 **************************************
 *
 * Functional description
 *  List series_names of both local
 *  and global series whose names contain
 *  this string
 *
 **************************************/
SSHORT count = 0;

FOR S IN TCS.SERIES WITH S.SERIES_NAME CONTAINING string
	 REDUCED TO S.SERIES_NAME
	 printf ("%s (LOCAL)\n", S.SERIES_NAME);
	 count++;
END_FOR;

FOR S IN TCS_GLOBAL.SERIES WITH S.SERIES_NAME CONTAINING string
	 REDUCED TO S.SERIES_NAME
	 printf ("%s\n", S.SERIES_NAME);
	 count++;
END_FOR;

if (!count)
{
	 print_error ("Could not find \"%s\" in SERIES_NAME of any test locally or globally", string,0,0);
	 return FALSE;
}
return TRUE;
}

void handle_sys_env(in_line)
		  char              *in_line;
{
/**************************************
 *
 *      h a n d l e _ s y s _ e n v
 *
 **************************************
 *
 * Functional description
 *      takes an string and looks for the pattern $(TCS:<token>).
 *      If it finds such a pattern then it looks for <token>
 *      in the system environment and does substitution,
 *      shifting the string right or left if necessary. It
 *      assumes that the string is big enough to allow any
 *      necessary shift.
 *
 **************************************/
	int             rec_count = 0,
						 sym_length = 0,
						 env_length = 0,
						 shift;
	char           *start,
						*end,
						*sys_env;
	char           *p;
	p = in_line;
	while (NULL != (start = strstr(p, "$(TCS:")))
	{

		/* Check if we are still within limits of environment *
			and if it is the first pass
		*/
		if (start < (p + env_length))
		{
			if (rec_count++ > MAX_RECURSION)
			{
				p = start+6;
				rec_count = 0;
				continue;
			}
		} else
		{
			rec_count = 0;
		}

	  /* Go to the end of $(TCS: reference */
		for (end = start;; end++)
		{
			if (*end == ' ' || *end == '\t' || *end == '\n' ||
				 *end == '\0' || *end == ')')
			  break;
		}

		/* Check if we found a termination ')' */
		if (*end != ')')
		{
			 p = start+6; /* Move p to search next $( */
			 rec_count = 0;
			 continue;
		}

		*end++ = '\0';
		sym_length = end - start;
		if (sys_env = getenv(start+6))
			env_length = strlen(sys_env);
		else
			env_length = 0;

		shift = sym_length - env_length;
		if (shift > 0)  /* Env variable is less than the reference */ 
		{
			while (*end != '\0')
			  *(end - shift - 1) = *end++;
			*(end - shift) = '\0';
		} else   /* Env variable is bigger than the reference */
		{
			while (*end) end++;
			while (end > start) *(end - shift + 1) = *end--;
		}
		if (env_length)
		   strncpy(start, sys_env, env_length);
		p = start;
	}
}


void handle_where_gdb(buffer)
	 TEXT	*buffer;
{
/**************************************
 *
 *	h a n d l e _ w h e r e _ g d b
 *
 **************************************
 *
 * Functional description
 *	Look through the line for all instances of
 *	WHERE_GDB, REMOTE_DIR, or WHERE_URL and insert the getenv()
 *	of the word in its place, shifting right or left
 *	if necessary.
 *
 **************************************/
   char  path_sep;
	char	*ptr1, *ptr2, *shift_ptr, 	*replace;
	int   len1, len2, shift, cnt;
	
	while (1)
	{
		path_sep = PATH_SEPARATER;
		/* if buffer doesn't contain an environment variable then return */
		if ( ( ptr1 = strstr( buffer, "WHERE_GDB" ) ) ||
			  ( ptr1 = strstr( buffer, "REMOTE_DIR" ) ) ||
			  ( ptr1 = strstr( buffer, "WHERE_URL" ) ) ||
			  ( ptr1 = strstr( buffer, "WHERE_GSEC" ) ) )
		 {

			/* look for the ':' if it is not there return */
			if ( ! ( ptr2 = strchr( ptr1, ':' ) ) )
				 return;

		 }
		 else
		 {
			 return;
		 }

		/* NULL the ':', get the value, put the ':' back in */
		*ptr2 = '\0';

		if ( ! (replace = getenv(ptr1)) )
		  replace = "";

		*ptr2 = ':';

		/*
		 * If no replacement from the system environment,
		 *  don't add path separater.
		 */
		if ( ! *replace )
			 path_sep = 0;

		/* If VMS is the server, path has [], don't add path separater. */
		if (strstr(replace, "["))
				  path_sep = 0;

		if ( ! path_sep ) ptr2++;

		/* move shift_ptr to the end of replace */
		for (shift_ptr = replace; *shift_ptr; shift_ptr++);

		/* skip over next word if last character was a '!' */
		if (shift_ptr[-1] == '!')
		{
			shift_ptr--;
			path_sep = 0;
			while (*ptr2 && (*ptr2 != ' ') && (*ptr2 != '\t')) ptr2++;
		}

		/* calculate length of thing to be replaced */
		len1 = ptr2 - ptr1;

		/* calculate length of the replacement */
		len2 = shift_ptr - replace;

		/* calculate the shift */
		shift = len2 - len1;

		/* if shift > 0 then right shift, else left shift */
		if (shift > 0)
		{
			while(*ptr2) ptr2++;
			for( ; ptr2 > ptr1; ptr2--) ptr2[shift] = *ptr2;

		}
		else
		{
			for( ; *ptr2; ptr2++) ptr2[shift] = *ptr2;
			ptr2[shift] = '\0';
		}

		/* put the replacement in the hole we just made */
		for(cnt = len2; cnt; cnt--) *ptr1++ = *replace++;

		/* add the path separater if it is needed */
		if (path_sep) *ptr1 = path_sep;
	}
}

static int initialize_local (string, vers)
    TEXT	*string, *vers;
{
/**************************************
 *
 *	i n i t i a l i z e _ l o c a l
 *
 **************************************
 *
 * Functional description
 *	Initialize output blob with results of script.
 *
 **************************************/
USHORT count;
TEXT *v;

/* Modify version from XXX.XXXA to XXXXXXXXXA (DB friendly format) */

if (*string == '\0')
    return FALSE;

if ( !(v = make_version (vers)))
    return FALSE;

count = 0;

/* Look for local test to initialize...*/

FOR T IN TCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v

/* Check for a value in the NO_INIT_FLAG, if NULL--INIT, else error. */

    if (T.NO_INIT_FLAG.NULL || T.NO_INIT_FLAG == 0)
        count += EXEC_init (string, &T.SCRIPT, TCS, sw_no_system, phase, &file_count, version, 0);

    	/* NO_INIT_FLAG is set to do NOT initialize. */

    else

    {
	print_error("Init. record for test %s, V%s is read only",string,*vers ? vers : version,0);
	return FALSE;
    } 
END_FOR;

/* If could not find local TEST, try global... */

if (!count)	

{
    FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v

/* Check for a value in the NO_INIT_FLAG, if NULL--INIT, else error. */

        if (T.NO_INIT_FLAG.NULL || T.NO_INIT_FLAG == 0)
    	    count += EXEC_init (string, &T.SCRIPT, TCS_GLOBAL, sw_no_system, phase, &file_count, version, 0);

	/* NO_INIT_FLAG is set to do NOT initialize. */
        else

	{
	    print_error("Init. record for test %s, V%s is read only",string,*vers ? vers : version,0);
	    return FALSE;
	}
    END_FOR;
}

/* If were able to initialize--count != 0 then print the result and exit */

if (count)

{
    print_result (string, vers);
	 return TRUE;
}

print_error ("Test \"%s\" V%s not found",string,*vers ? vers : version,0);
return FALSE; 
}

static int initialize_global (string, vers)
	 TEXT        *string, *vers;
{
/**************************************
 *
 *      i n i t i a l i z e _ g l o b a l
 *
 **************************************
 *
 * Functional description
 *      Initialize global output blob with results of script.
 *
 **************************************/
USHORT count;
TEXT *v;

/* Modify version from XXX.XXXA to XXXXXXXXXA (DB friendly format) */

if ( !(v = make_version (vers)))
    return FALSE;
 
count = 0;
 
FOR T IN TCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v

/* Check for a value in the NO_INIT_FLAG, if NULL--INIT, else error. */

    if (T.NO_INIT_FLAG.NULL || T.NO_INIT_FLAG == 0)
    	count += EXEC_init (string, &T.SCRIPT, TCS, sw_no_system, phase, &file_count, version, 1);

    	/* NO_INIT_FLAG is set to do NOT initialize. */

    else
    {
	print_error("Initialization record for test %s with V%s is read only",string,*vers ? vers : version,0);
	return FALSE;
    }

END_FOR;
 
/* If could not find local TEST, try global... */

if (!count)
FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v

/* Check for a value in the NO_INIT_FLAG, if NULL--INIT, else error. */

    if (T.NO_INIT_FLAG.NULL || T.NO_INIT_FLAG == 0)
    	count += EXEC_init (string, &T.SCRIPT, TCS_GLOBAL, sw_no_system, phase, &file_count, version, 1);

    	/* NO_INIT_FLAG is set to do NOT initialize. */

    else

    {
	print_error("Initialization record for test %s with V%s is read only",string,*vers ? vers : version,0);
	return FALSE;
    }

END_FOR;
 
/* If we're able to initialize--count != 0 then print the result and exit */

if (count)

{
    print_global_result (string, vers);
	 return TRUE;
}

print_error ("Test \"%s\" V%s not found",string,*vers ? vers : version,0);
return FALSE;
}

static int initialize_series (string, start, vers)
	 TEXT	*string, *start, *vers;
{
/**************************************
 *
 *	i n i t i a l i z e _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *	Initialize a series of tests.
 *
 **************************************/
USHORT count;
SSHORT first, second, break_flag = TRUE;
int loop = TRUE;

while( loop )

{
/*	Parse the arguments given in start and set boundaries,		*
 *	first and second, also set the break flag if we should		*
 *	stop looping.							*/
	 loop = parse_series_args( start, &first, &second, &break_flag);

/* break_flag will be set appropriately within parse_series_args. */
	 if( break_flag )
	break;

	 first--; second++;	/* Is this best? -- but increment so can use < and > */
	 count = 0;

/* 	Attempt to loop on every test that is greater than 	*
 * 	first and less than second in a local series.		*/

	 FOR S IN TCS.SERIES WITH S.SERIES_NAME EQ string
		  AND S.SEQUENCE > first AND S.SEQUENCE < second
		  SORTED BY S.SERIES_NAME, S.SEQUENCE

		  if (quit || disk_io_error)
		 break;

	/* Call initialize routine to do a test. */
		  initialize_local (strtok(S.TEST_NAME," "), vers);
		  count++;

	 END_FOR

/* If could not find local series, attempt to loop through a global series. */

	 if (!count)

	 {
		  FOR S IN TCS_GLOBAL.SERIES WITH S.SERIES_NAME EQ string
		 AND S.SEQUENCE > first AND S.SEQUENCE < second
		 SORTED BY S.SERIES_NAME, S.SEQUENCE

		 if (quit || disk_io_error)
			  break;

	/* Call initialize routine to do a test. */
		 initialize_local (strtok(S.TEST_NAME," "), vers);

		  END_FOR
	 }
}
return TRUE;
}

static int interact ()
{
/**************************************
 *
 *	i n t e r a c t
 *
 **************************************
 *
 * Functional description
 *	Read a command, parse it, execute it, and return.  If end of
 *	file, return FALSE.
 *
 **************************************/
struct cmd	*cmd;
TEXT		buffer[128], command[20], name[32], name2 [32], name3[32], name4[32], *p;
SSHORT		n, c;
void		(*prev_handler)();

setjmp (JumpBuffer);	/* Mark the place to jump back to in an emergency */
printf ("tcs> ");

/* Get command line */

p = buffer;	/*	Move in allocated memory	*/

/*	This is the tight loop, waiting for commands...	*/

while (TRUE)

{
	 c = getchar();

/*	Break on a <carriage return> or ';'	*/

	 if ((c == '\n') || (c == ';'))
	break;

/*	Abort if gets an EOF but guard against interrupted system call 	*/

	 if (c == EOF)
		  {
		  if (errno == EINTR)
				{
				errno = 0;
				continue;
				}
		  else
				return FALSE;
		  }

	 *p++ = UPPER (c);		/* Convert to up case. */
}

/* call handle_where_gdb() */
handle_where_gdb(buffer);

/* Parse into command and test/series name */

#ifndef mpexl
signal (SIGINT, signal_quit);
#if !(defined PC_PLATFORM || defined WIN_NT || defined OS2_ONLY)
signal (SIGQUIT, signal_quit);
#endif
#else
RESETCONTROL();
XCONTRAP ((int) signal_quit, (int*) &prev_handler);
#endif

quit = FALSE;
disk_io_error = FALSE;
*p = command [0] = name4 [0] = name3 [0] = name2 [0] = name [0] = 0;
n = sscanf (buffer, "%s%s%s%s%s", command, name, name2, name3, name4);

/*	If no command...n<=0 then return TRUE */

if (n <= 0)
    return TRUE;

n -= 1;		/* subtract one for the command */

/*	If not all are args full, then fill with empty string		*/

if (!strcmp (name, MISSING_ARG))
    strcpy (name, "");
if (!strcmp (name2, MISSING_ARG))
    strcpy (name2, "");
if (!strcmp (name3, MISSING_ARG))
    strcpy (name3, "");
if (!strcmp (name4, MISSING_ARG))
    strcpy (name4, "");

/* Interpret command */

for (cmd = commands; cmd->cmd_string; cmd++)
{

/*	If name of the command is
 *	the name typed at the tcs> prompt then we found a match		*/	

    if (strcmp (cmd->cmd_string, command) == 0)
    {

/*	Make sure required arguments are given
 */

	 if (n < cmd->cmd_args)
	 {
		print_error ("Command \"%s\" requires  more arguments",
		              command, 0, 0);
		return TRUE;
	 }

/*	If there is no function pointer for this command it must be QUIT
 *	Return FALSE so the command loop will quit.
 */

    if (!cmd->cmd_routine)
	    return FALSE;

/*	CALL THE FUNCTION and let it do the work.			*/

	(*cmd->cmd_routine)(name, name2, name3, name4);
	   return TRUE;
    }
}

/* If made it to here, then command was not found so print error	*/

print_error ("Invalid command, type HELP or ? for command list",0,0,0);

return TRUE;
}

static int list_boilerplates ()
{
/**************************************
 *
 *	l i s t _ b o i l e r p l a t e s
 *
 **************************************
 *
 * Functional description
 *	Print a list of the available 
 *	boiler plates.
 *
 **************************************/

printf ("Boiler plates:\n");

FOR B IN TCS.BOILER_PLATE SORTED BY B.BOILER_PLATE_NAME
    printf ("\t%s\n", B.BOILER_PLATE_NAME);
END_FOR;
return TRUE;
}

static int list_commands (string)
	 TEXT	*string;
{
/**************************************
 *
 *	l i s t _ c o m m a n d s
 *
 **************************************
 *
 * Functional description
 *	Print a list of the commands.
 *	Print a list of the keywords by
 *	calling list_keywords().
 *
 **************************************/
struct cmd	*cmd;
FILE *fp;
TEXT *buffer[40];


/* 	Search for a specific command. 		*/

if (NOT_NULL(string))

{

/*	Scan the 'commands' table for string, if not found then call	*
 *	keyword_search in trns.c to scan keyword table.			*/

	 for(cmd = commands; cmd->cmd_string && (strcmp(cmd->cmd_string,string)); cmd++)
	;

/*	If the search found the command print it, else scan keywords	*/

	 if (cmd->cmd_string)
	 {
	printf("TCS command:\n");
	printf("\t%s\t%s\n", cmd->cmd_string, cmd->cmd_text);
	return TRUE;
	 }
	 else if ( keyword_search (string) )
	return TRUE;

/*	If made it to here, then did not find command		*/

	 print_error ("No entry for %s:",string,0,0);
}

/* Remove temp file if it already exists... */

#ifdef VMS
sprintf( buffer, "DELETE  %s;*", LIST_CMDS_TMP);
#else
#if (defined WIN_NT || defined OS2_ONLY)
sprintf( buffer, "del /f %s", LIST_CMDS_TMPNT);
#else
sprintf( buffer, "rm -f %s", LIST_CMDS_TMP);
#endif
#endif
system( buffer );

/* Print the regular help page piped through more. */

#ifdef VMS
sprintf( buffer, "type/page %s", LIST_CMDS_TMP);
#else
#if (defined WIN_NT || defined OS2_ONLY)
sprintf( buffer, "more < %s", LIST_CMDS_TMP);
#else
sprintf( buffer, "more %s", LIST_CMDS_TMP);
#endif
#endif

/*	Need to open a temp file to store the help page, if success	*
 *	dump commands, and keywords to file and then system( buffer )	*/

if (fp = fopen( LIST_CMDS_TMP, "w"))

{
	 fprintf (fp, "Commands are:\n");

/*      Dump the commands to the file   */

	 for (cmd = commands; cmd->cmd_string; cmd++)
		  fprintf ( fp, "\t%s\t%s\n", cmd->cmd_string, cmd->cmd_text );

	 fprintf ( fp, "\nTCS reserved words are (\"dollar\" verbs):\n");

/*      Call list_keywords to dump the keywords and system() the        *
 *      buffer.                                                         */

	 list_keywords( fp, buffer );
}

/*	Need to open a temp file to put the help page, if we can't	*
 *	then do the help page the old way-->throw it at the screen	*/

else

{
	 print_error ("Error opening temp file for help",0,0,0);
	 printf ("Commands are:\n");

/*	Dump the commands */

	 for (cmd = commands; cmd->cmd_string; cmd++)
		  printf ("\t%s\t%s\n", cmd->cmd_string, cmd->cmd_text);

	 printf ("\nTCS reserved words are (\"dollar\" verbs):\n");

/*	Call list_keywords to dump the $ verbs		*/

	 list_keywords( fp, 0 );
}
 return FALSE;
}

static int list_environments ()
{
/**************************************
 *
 *	l i s t _ e n v i r o n m e n t s
 *
 **************************************
 *
 * Functional description
 *	Print a list of the available environments
 *
 **************************************/

printf ("Environments:\n");

FOR E IN TCS.ENV SORTED BY E.ENV_NAME
	 printf ("\t%s\n", E.ENV_NAME);
END_FOR;
return TRUE;
}

static int list_failures (name)
	 TEXT *name;
{
/**************************************
 *
 *	l i s t _ f a i l u r e s
 *
 **************************************
 *
 * Functional description
 *	Print a list of the active failures.
 *
 **************************************/


/*	If name is ALL then list all failures in the failures 		*
 *	relation.							*/

if (NOT_NULL (name) && !strcmp (name, "ALL"))

{
    printf ("Failing tests for all runs:\n");
    FOR F IN TCS.FAILURES
        printf ("%\t%s %s %s\n", F.DATE.CHAR[11], F.RUN, F.TEST_NAME);
    END_FOR;
}

/*	If name is given then print all failures for that run name.	*/

else if (NOT_NULL (name))

{
    printf ("Failing tests for run %s:\n", name);
    FOR F IN TCS.FAILURES WITH F.RUN = name
        printf ("%\t%s %s %s\n", F.DATE.CHAR[11], F.RUN, F.TEST_NAME);
    END_FOR;
}

/*	If name is NULL then print failures for the current run 	*
 *	name.								*/

else

{
    printf ("Failing tests for run %s:\n", run_name);
    FOR F IN TCS.FAILURES WITH F.RUN = run_name
        printf ("%\t%s %s %s\n", F.DATE.CHAR[11], F.RUN, F.TEST_NAME);
    END_FOR;
}
 return TRUE;
}

static int list_meta_series (swtch)
TEXT	*swtch;
{
/**************************************
 *
 *	l i s t _ m e t a _s e r i e s
 *
 **************************************
 *
 * Functional description
 *	List known meta_series names
 *
 **************************************/

/* 	Check switch to make sure is not null and convert to upcase 	*
 *	if NULL, then assume global(G).					*/

if (NOT_NULL(swtch))
	 disp_upcase(swtch,swtch);
else
	 *swtch = 'G';

/*	If local(L) then list the meta series existing in the local	*
 *	DB.								*/

if (*swtch == 'L')

{
	 printf ("Local Meta_series names are:\n");

	 FOR M IN TCS.META_SERIES REDUCED TO M.META_SERIES_NAME
		  printf ("\t%s\n", M.META_SERIES_NAME);
	 END_FOR;
}

/*	If global(G) then list the meta series existing in the global DB */

else

{
	 printf ("Global Meta_series names are:\n");

	 FOR M IN TCS_GLOBAL.META_SERIES REDUCED TO M.META_SERIES_NAME
		  printf ("\t%s\n", M.META_SERIES_NAME);
	 END_FOR;
}
return TRUE;
}

static int list_runs ()
{
/**************************************
 *
 *	l i s t _ r u n s
 *
 **************************************
 *
 * Functional description
 *	Print run names existing in
 *	the failure relation.
 *
 **************************************/

printf ("Runs:\n");

FOR F IN TCS.FAILURES REDUCED TO F.RUN
	 printf ("\t%s\n", F.RUN);
END_FOR;
return TRUE;
}

static int list_series (swtch)
TEXT	*swtch;
{
/**************************************
 *
 *	l i s t _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *	List known series names
 *
 **************************************/

/* 	Check switch to make sure is not null and convert to upcase 	*
 *	if NULL, then assume global(G).					*/

if (NOT_NULL(swtch))
	 disp_upcase(swtch,swtch);
else
	 *swtch = 'G';

/*	If local(L) then list the series existing in the local DB	*/

if (*swtch == 'L')

{
	 printf ("Local Series names are:\n");

	 FOR X IN TCS.SERIES REDUCED TO X.SERIES_NAME
		  printf ("\t%s\n", X.SERIES_NAME);
	 END_FOR;
}

/*	If global(G) then list the series existing in the global DB 	*/

else

{
	 printf ("\nGlobal Series names are:\n");

	 FOR X IN TCS_GLOBAL.SERIES REDUCED TO X.SERIES_NAME
		  printf ("\t%s\n", X.SERIES_NAME);
	 END_FOR;
}
return TRUE;
}

static int list_tests (swtch)
TEXT	*swtch;
{
/**************************************
 *
 *	l i s t _ t e s t s
 *
 **************************************
 *
 * Functional description
 *	List known test names
 *
 **************************************/

/* 	Check switch to make sure is not null and convert to upcase 	*
 *	if NULL, then assume global(G).					*/

if (NOT_NULL(swtch))
	 disp_upcase(swtch,swtch);
else
	 *swtch = 'G';

/*	If local(L) then list the test existing in the local DB	 	*/

if (*swtch == 'L')

{
	 printf ("Local Test names are:\n");

	 FOR X IN TCS.TESTS SORTED BY X.TEST_NAME
		  if (quit)
		 break;
		  printf ("\t%s\n", X.TEST_NAME);
	 END_FOR;
}

/*	If global(G) then list the test existing in the global DB 	*/

else

{
	 printf ("Global Test names are:\n");

	 FOR X IN TCS_GLOBAL.TESTS SORTED BY X.TEST_NAME
		  if (quit)
		 break;
		  printf ("\t%s\n", X.TEST_NAME);
	 END_FOR;
}
return TRUE;
}

static void unmake_version (name, version)
	 TEXT	*name, *version;
{
/**************************************
 *
 *	u n m a k e _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Convert version from MMMNNNOOOA
 *	back to human readable format of MMM.NNN.OOOA
 *
 *	See also make_version();
 *
 **************************************/
int	major, minor, third;
TEXT	letter[5];

strcpy (letter, "");
major = 0;
minor = 0;
third = 0;
sscanf (version, "%3d%3d%3d%s", &major, &minor, &third, &letter);
sprintf (name, "%d.%d.%d%s", major, minor, third, letter);
}

static TEXT *make_version (name)
	 TEXT	*name;
{
/**************************************
 *
 *	m a k e _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Convert version from MMM.NNN.OOOA to MMMNNNOOOA
 *
 *	See also unmake_version();
 *
 **************************************/
TEXT *p, *q, *s, *end;

if (!name || !*name)
    {
    strcpy (version_buffer, version);
    return version_buffer;
    }

if ( !strcmp (name, "DEFAULT"))
    {
    strcpy (version_buffer, "DEFAULT");
    return version_buffer;
    }

end = version_buffer + sizeof (version_buffer) - 1;
strcpy (version_buffer, "000000000 ");
/* Identify digits in primary version field */
s = p = name;
while (*p && *p >= '0' && *p <= '9')
    p++;
if ((p - s) > 3)
    {
    print_error ("Invalid version %s",name,0,0);
    return NULL_PTR;
    }
q = version_buffer + 3 - (p - s);
p = s;
while (*p && *p >= '0' && *p <= '9')
    {
    if (q == end)
        {
        print_error ("Invalid version %s",name,0,0);
        return NULL_PTR;
        }
    *q++ = *p++;
    }
/* Hop over the decimal point, begin second field */
if (*p == '.')
    p++;
s = p;
while (*p && *p >= '0' && *p <= '9')
    p++;
if ((p - s) > 3)
    {
    print_error ("Invalid version %s",name,0,0);
    return NULL_PTR;
    }
q = q + 3 - (p - s);
p = s;
while (*p && *p >= '0' && *p <= '9')
    {
    if (q == end)
        {
        print_error ("Invalid version %s",name,0,0);
        return NULL_PTR;
        }
    *q++ = *p++;
    }
/* Hop over the decimal point, begin third field */
if (*p == '.')
    p++;
s = p;
while (*p && *p >= '0' && *p <= '9')
    p++;
if ((p - s) > 3)
    {
    print_error ("Invalid version %s",name,0,0);
    return NULL_PTR;
    }
q = q + 3 - (p - s);
p = s;
while (*p && *p >= '0' && *p <= '9')
    {
    if (q == end)
        {
        print_error ("Invalid version %s",name,0,0);
        return NULL_PTR;
        }
    *q++ = *p++;
    }
/* End of numeric fields. There may still be an alpha character. */
while (*p && isalpha(*p) )
    {
    if (q == end)
        {
		  print_error ("Invalid version %s",name,0,0);
		  return NULL_PTR;
		  }
	 *q++ = *p++;
	 }
*q = 0;
return version_buffer;
}

static int mark_init (string, value, vers)
	 TEXT    *string, *value, *vers;
{
/**************************************
 *
 *      m a r k _ i n i t
 *
 **************************************
 *
 * Functional description
 *
 *    mark initialization as read_only
 *    set NO_INIT_FLAG
 *
 **************************************/
TEXT *v;
USHORT   count, val;
int  temp;

count = 0;
temp = val = atoi(value);

/*	If the value is NULL print an error and a description 		*
 *	of the valid values.						*/

if (! (NOT_NULL (value)))
{
	 print_error ("No value supplied",0,0,0);
	 print_error ("The following are valid values:",0,0,0);
	 fprintf (stderr, "\t\t0 - Initialization is read/write [default]\n");
	 fprintf (stderr, "\t\t1 - Initialization is read only\n");
	 (void) fflush (stderr);
	 return FALSE;
}

/*	If the value is not within the proper range print an error 	*
 *	and a description of the valid values.				*/

else if (! ((-1 < temp) && (temp < 2)))

{
	 print_error ("Invalid value",0,0,0);
	 print_error ("The following are valid values:",0,0,0);
	 fprintf (stderr, "\t\t0 - Initialization is read/write [default]\n");
	 fprintf (stderr, "\t\t1 - Initialization is read only\n");
	 (void) fflush (stderr);
	 return FALSE;
}

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Set the init flag of the global test with name=string and	*
 *	version = v.							*/

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME = string AND T.VERSION = v
	 MODIFY T USING

/*	If value is zero, set the flag to zero	*/

	 if (!val)
	 {
	T.NO_INIT_FLAG = 0;
		  T.NO_INIT_FLAG.NULL = TRUE;
	 }

/*	Else set the flag to val	*/

	 else

	 {
		  T.NO_INIT_FLAG = val;
		  T.NO_INIT_FLAG.NULL = FALSE;
	 }

	 count++;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
END_FOR;

/*	If success then return TRUE else print error.	*/

if (count)
    return TRUE;

print_error ("Test %s V%s does not exist globally, use 'CT' to create a test",string, *vers ? vers : version,0);

return FALSE;
}

static int mark_init_series (string, swtch)
    TEXT	*string, *swtch;
{
/**************************************
 *
 *      m a r k _ i n i t _ s e r i e s 
 *
 **************************************
 *
 * Functional description
 *
 *    mark initializations as read_only 
 *    for a series but NOT write/read
 *    set NO_INIT_FLAG
 *
 **************************************/
SSHORT     count = 0;

/*	If not NULL convert switch to upper case, else use global(G)	*/

if (NOT_NULL(swtch))
    disp_upcase(swtch,swtch);
else
    *swtch = 'G';

/*	For Local SERIES modify NO_INIT_FLAG for tests in series	*/

if (*swtch == 'L')

{

/*	Loop on local series with name = string		*/

    FOR S IN TCS.SERIES WITH S.SERIES_NAME EQ string
	/* Init count at top so can tell if test is local or global	*/
        count = 0;	

/*      Set flag for a local test	*/

	FOR T IN TCS.TESTS WITH T.TEST_NAME EQ S.TEST_NAME 	
	    MODIFY T USING
	      	T.NO_INIT_FLAG = 1;
		T.NO_INIT_FLAG.NULL = FALSE;
		count++;
	    END_MODIFY
		ON_ERROR
            	print_error ("Error during MODIFY:",0,0,0);
	    	gds__print_status (gds__status);
			return FALSE;
		END_ERROR;
	END_FOR;

/* 	Could not find local test so modify no_init_flag for global test */

	if (!count)

		  {

/*	Set flag for global test	*/

		 FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ S.TEST_NAME
		MODIFY T USING
			 T.NO_INIT_FLAG = 1;
			 T.NO_INIT_FLAG.NULL = FALSE;
			 count++;
		END_MODIFY
		ON_ERROR
					print_error ("Error during MODIFY:",0,0,0);
			gds__print_status (gds__status);
			return FALSE;
		END_ERROR;
	    END_FOR;

	}

    END_FOR;

/*	If count is zero then never entered series loops, so print error */

	 if (!count)
	 {
		print_error ("Series %s does not exist locally",string,0,0);
		return FALSE;
	 }
}

/*	For Global SERIES modify NO_INIT_FLAG for tests in series	*/

else

{

/*	Loop on the global series with name = string 	*/

    FOR S IN TCS_GLOBAL.SERIES WITH S.SERIES_NAME EQ string
	/* Init count at top so can tell if test is local or global	*/
        count = 0;

/* 	Modify the local test if it exists	*/

	FOR T IN TCS.TESTS WITH T.TEST_NAME EQ S.TEST_NAME 	
	    MODIFY T USING
	      	T.NO_INIT_FLAG = 1;
		T.NO_INIT_FLAG.NULL = FALSE;
		count++;
	    END_MODIFY
		ON_ERROR
            	print_error ("Error during MODIFY:",0,0,0);
	    	gds__print_status (gds__status);
			return FALSE;
		END_ERROR;
	END_FOR;

/*	Modify the global test if it exists	*/

	if (!count)

	{
		 FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ S.TEST_NAME
		MODIFY T USING
			 T.NO_INIT_FLAG = 1;
			 T.NO_INIT_FLAG.NULL = FALSE;
			 count++;
		END_MODIFY
			 ON_ERROR
						 print_error ("Error during MODIFY:",0,0,0);
				 gds__print_status (gds__status);
				 return FALSE;
					END_ERROR;
		 END_FOR;
	}

	 END_FOR;

/*	If count is zero then never enter series loops, so print error	*/

	 if (!count)
	 {
	  print_error ("Series %s does not exist globally",string,0,0);
	  return FALSE;
	 }
}

return TRUE;
}

static int mark_local_known_failure (string)
	 TEXT	*string;
{
/**************************************
 *
 *	m a r k _ l o c a l _ k n o w n _ f a i l u r e
 *
 **************************************
 *
 * Functional description
 *	Flag a failure record as "known"
 *	Where failed test has same run_name
 *	as current run name.
 *
 **************************************/
SSHORT count = 0 ;

if (NULL_STR (known_failures_run_name))
	 {
	 printf ("No current known failures run, use skf\n");
	 return FALSE;
	 }

FOR FIRST 1 F IN TCS.FAILURES WITH F.TEST_NAME EQ string AND F.RUN = run_name
SORTED BY DESC F.DATE
	 count++;

	 if (!NULL_STR (known_failures_run_name))
	{
	MODIFY F USING
		 strcpy (F.RUN, known_failures_run_name);
		  END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	}

	 STORE KF IN TCS.KNOWN_FAILURES
	strcpy (KF.TEST_NAME, F.TEST_NAME);
	/* XXX strcpy (KF.RUN, known_failures_run_name); */
	if (!F.VERSION.NULL)
		 strcpy (KF.VERSION, F.VERSION);
	else
		 strcpy (KF.VERSION, version);
	/* INIT_BY & INIT_DATE set by trigger */
	strcpy (KF.BOILER_PLATE_NAME, F.BOILER_PLATE_NAME);
	strcpy (KF.ENV_NAME, F.ENV_NAME);
		  (void) BLOB_edit (&KF.COMMENT, TCS, gds__trans, "failure.txt");

	 END_STORE
	ON_ERROR
				print_error ("Store of known failure notification failed:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
	 printf ("Test %s failed on %s: marked as known failure in run %s\n",
		string, F.DATE.CHAR[11], known_failures_run_name);
END_FOR;

if (!count)
{
	 print_error ("There is no failure record for %s with run name %s",string,run_name,0);
	 return FALSE;
}
return TRUE;
}

static int mark_local_init (string, value, vers)
	 TEXT    *string, *value, *vers;
{
/**************************************
 *
 *      m a r k _ l o c a l _ i n i t
 *
 **************************************
 *
 * Functional description
 *
 *    mark local test's initialization as read_only
 *    set NO_INIT_FLAG
 *
 **************************************/
TEXT  *v;
USHORT   count, val;
int  temp;

count = 0;
temp = val = atoi(value);

/*	If the value is NULL print an error and a description 		*
 *	of the valid values.						*/

if (! (NOT_NULL (value)))

{
	 print_error ("No value supplied",0,0,0);
	 print_error ("The following are valid values:",0,0,0);
	 fprintf (stderr, "\t\t0 - Initialization is read/write [default]\n");
	 fprintf (stderr, "\t\t1 - Initialization is read only\n");
	 (void) fflush (stderr);
	 return FALSE;
}

/*	If the value is not within the proper range print an error 	*
 *	and a description of the valid values.				*/

else if (! ((-1 < temp) && (temp < 2)))

{
	 print_error ("Invalid value",0,0,0);
	 print_error ("The following are valid values:",0,0,0);
	 fprintf (stderr, "\t\t0 - Initialization is read/write [default]\n");
	 fprintf (stderr, "\t\t1 - Initialization is read only\n");
	 (void) fflush (stderr);
	 return FALSE;
}

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Set the init flag of the global test with name=string and	*
 *	version = v.							*/

FOR T IN TCS.TESTS WITH T.TEST_NAME = string AND T.VERSION = v
	 MODIFY T USING

/*	If value is zero, set the flag to zero	*/

	 if (!val)
	 {
	T.NO_INIT_FLAG = 0;
		  T.NO_INIT_FLAG.NULL = TRUE;
	 }

/*	Else set the flag to val	*/

	 else
	 {
		  T.NO_INIT_FLAG = val;
		  T.NO_INIT_FLAG.NULL = FALSE;
	 }

	 count++;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
END_FOR;

/*	If success then return TRUE else print error.	*/

if (count)
	 return TRUE;

print_error ("Test %s V%s does not exist locally, use 'CLT' to create a test",string, *vers ? vers : version,0);

return FALSE;
}

static int mark_local_test (string, value, vers)
	 TEXT    *string, *value, *vers;
{
/**************************************
 *
 *	m a r k _ l o c a l _ t e s t
 *
 **************************************
 *
 * Functional description
 *
 *    mark test as read_only
 *    set NO_RUN_FLAG
 *
 **************************************/
struct runflag	*runflag;
TEXT response[4], *v;
USHORT	count, val;
int temp;

count = 0;
temp = val = atoi(value);

/*	If value is NULL then display options allowed for a 		*
 *	NO_RUN_FLAG and return.						*/

if (! (NOT_NULL (value)))

{
    print_error ("No value supplied",0,0,0);
    print_error ("The following are valid values:",0,0,0);
    for(runflag = runflag_options; runflag->description; runflag++)
	fprintf (stderr, "\t\t%d - %s\n", runflag->option, runflag->description);
    (void) fflush (stderr);
    return FALSE;
}

/* 	Else if the entered value is not within the proper range, 	*
 *	print acceptable values and return.				*/

else if (! ((-1 < temp) && (temp < (sizeof(runflag)-1))))
{
    print_error ("Invalid value",0,0,0);
    print_error ("The following are valid values:",0,0,0);
    for(runflag = runflag_options; runflag->description; runflag++)
	fprintf (stderr, "\t\t%d - %s\n", runflag->option, runflag->description);
    (void) fflush (stderr);
    return FALSE;
}

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Modify NO_RUN_FLAG of local test with name = string and 	*
 *	version = v							*/

FOR T IN TCS.TESTS WITH T.TEST_NAME = string AND T.VERSION = v
	 MODIFY T USING

/*	If value is zero make NO_RUN_FLAG NULL.		*/

	 if (!val)
	 {
	T.NO_RUN_FLAG = 0;
		  T.NO_RUN_FLAG.NULL = TRUE;
	 }

/*	If the value is not zero set NO_RUN_FLAG = val		*/

	 else

	 {
		  T.NO_RUN_FLAG = val;
		  T.NO_RUN_FLAG.NULL = FALSE;
	 }

	 count++;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
END_FOR;

/* 	If the test could not be found in the local DB, give the 	*
 *	option to create the test.					*/

if (!count)
{
	 sprintf (prompt, "    There is no local test %s for version %s. Do you wish to create it?", string, vers);

/*	Prompt and get response, if response is NO, return.  	*/

	 if (!(disp_get_string (prompt, response, 4)))
		  return FALSE;
	 if ((response[0] == 'n') || (response[0] == 'N'))
		  return FALSE;

/*	Create a local test with name = string and set NO_RUN_FLAG to 	*
 *	val								*/

	 STORE T IN TCS.TESTS
		  gds__vtov (string, T.TEST_NAME, sizeof (T.TEST_NAME));

/*	If the val is zero set flag to NULL		*/

		  if (!val)
		{
		 T.NO_RUN_FLAG = 0;
				T.NO_RUN_FLAG.NULL = TRUE;
	}

/*	Set the no run flag to val.			*/

		  else
		  {
				T.NO_RUN_FLAG = val;
				T.NO_RUN_FLAG.NULL = FALSE;
		  }

		  gds__vtov (v, T.VERSION, sizeof (T.VERSION));
	 END_STORE
		 ON_ERROR
				print_error ("Error during STORE:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
		 END_ERROR;
}

return TRUE;
}

static int mark_test (string, value, vers)
	 TEXT    *string, *value, *vers;
{
/**************************************
 *
 *	m a r k _ t e s t
 *
 **************************************
 *
 * Functional description
 *
 *    mark test as read_only
 *    set NO_RUN_FLAG
 **************************************/
struct runflag	*runflag;
TEXT response[4], *v;
USHORT	count, val;
int  temp;

count = 0;
temp = val = atoi(value);

/*	If value is NULL then display options allowed for a 		*
 *	NO_RUN_FLAG, and return.					*/

if (! (NOT_NULL (value)))
{
	 print_error ("No value supplied",0,0,0);
	 print_error ("The following are valid values:",0,0,0);
	 for(runflag = runflag_options; runflag->description; runflag++)
	fprintf (stderr, "\t\t%d - %s\n", runflag->option, runflag->description);
	 (void) fflush (stderr);
	 return FALSE;
}

/* 	Else if the entered value is not within the proper range, 	*
 *	print acceptable values and return.				*/

else if (! ((-1 < temp) && (temp < (sizeof(runflag)-1))))

{
	 print_error ("Invalid value",0,0,0);
	 print_error ("The following are valid values:",0,0,0);
	 for (runflag = runflag_options; runflag->description; runflag++)
	fprintf (stderr, "\t\t%d - %s\n", runflag->option, runflag->description);
	 (void) fflush (stderr);
	 return FALSE;
}

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Modify NO_RUN_FLAG of global test with name = string and 	*
 *	version = v							*/

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME = string AND T.VERSION = v
	 MODIFY T USING

/*	If value is zero make NO_RUN_FLAG NULL.		*/

	 if (!val)
	 {
	T.NO_RUN_FLAG = 0;
		  T.NO_RUN_FLAG.NULL = TRUE;
	 }

/*	If the value is not zero set NO_RUN_FLAG = val		*/

	 else

	 {
		  T.NO_RUN_FLAG = val;
		  T.NO_RUN_FLAG.NULL = FALSE;
	 }

	 count++;
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;
END_FOR;

/* 	If the test could not be found in the global DB, give the 	*
 *	option to create the test.					*/

if (!count)

{
	 sprintf (prompt, "    There is no global test %s for version %s. Do you wish to create it?", string, vers);

/*	Prompt and get response, if response is NO, return.  	*/

	 if (!(disp_get_string (prompt, response, 4)))
		  return FALSE;
	 if ((response[0] == 'n') || (response[0] == 'N'))
		  return FALSE;

/*	Create a global test with name = string and set NO_RUN_FLAG to 	*
 *	val								*/

	 STORE T IN TCS_GLOBAL.TESTS
		  gds__vtov (string, T.TEST_NAME, sizeof (T.TEST_NAME));

/*	If the val is zero set flag to NULL		*/

		  if (!val)
	{
		 T.NO_RUN_FLAG = 0;
				T.NO_RUN_FLAG.NULL = TRUE;
	}

/*	Set the no run flag to val.			*/

		  else
		  {
				T.NO_RUN_FLAG = val;
				T.NO_RUN_FLAG.NULL = FALSE;
		  }

		  gds__vtov (v, T.VERSION, sizeof (T.VERSION));
	 END_STORE
		 ON_ERROR
				print_error ("Error during STORE:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
		 END_ERROR;
}

return TRUE;
}

static int modify_local_test_version (string, vers1, vers2)
	 TEXT	*string, *vers1, *vers2;
{
/**************************************
 *
 *	m o d i f y _ l o c a l _ t e s t _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Modify version of a local test
 *
 **************************************/
USHORT	count;
TEXT *v1, *v2;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA for both versions, else abort */

if ( !(v1 = make_version (vers1)))
	 return FALSE;

if ( !(v2 = make_version (vers2)))
	 return FALSE;

count = 0;

/*	Modify the version of the local test with name = string		*/

FOR T IN TCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v1
	 MODIFY T
		  gds__vtov (v2, T.VERSION, sizeof (T.VERSION));
	 END_MODIFY
	ON_ERROR
				print_error ("Error during MODIFY:",0,0,0);
		 gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;

	 count++;

END_FOR;

/*	If count, then the modify was successful so return, else print 	*
 *	error.								*/

if (count)
	 return TRUE;

print_error ("Test %s, version %s, isn't there.", string, v1,0);
return FALSE;
}

static int modify_test_version (string, vers1, vers2)
	 TEXT	*string, *vers1, *vers2;
{
/**************************************
 *
 *	m o d i f y _ t e s t _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Modify version of a global test
 *
 **************************************/
USHORT	count;
TEXT *v1, *v2;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA for both versions, else abort */

if ( !(v1 = make_version (vers1)))
	 return FALSE;

if ( !(v2 = make_version (vers2)))
	 return FALSE;

count = 0;

/*	Modify the version of the global test with name = string	*/

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v1
    MODIFY T
        gds__vtov (v2, T.VERSION, sizeof (T.VERSION));
    END_MODIFY
	ON_ERROR
            print_error ("Error during MODIFY:",0,0,0);
	    gds__print_status (gds__status);
		 return FALSE;
	END_ERROR;

	 count++;

END_FOR;

/*	If count, then the modify was successful so return, else print 	*
 *	error.								*/

if (count)
	 return TRUE;

print_error ("Test %s, V%s, isn't there.", string, v1,0);
return FALSE;
}

static int move_test_series1_series2 (test_string, s1, s2, seq)
	 TEXT	*test_string, *s1, *s2, *seq;
{
/***********************************************************
 *
 *	m o v e _ t e s t _ s e r i e s 1 _ s e r i e s 2
 *
 ***********************************************************
 *
 * Functional description
 *	Move a test from series1 to series 2
 *	optionally assigning it a sequence.
 *	Legitimate series exist only in the
 *	global table, and test version number
 *	is not part of the relation.
 *
 ***********************************************************/

/* First add the test to series s2, passing on optional sequence.
 * On error abort so we don't delete the test from the series s1
 */

if (add_test (test_string, s2, seq) == FALSE)
    return FALSE;

/* Delete the test from series1.
 * If this fails, undo the add to series2.
 */

if (delete_test_from_series (test_string, s1) == FALSE)
    { 
    	delete_test_from_series (test_string, s2);
    	return FALSE;
	 }
return TRUE;
}

static int parse_main_options(p)
	TEXT *p;
{
/**************************************
 *
 *	p a r s e _ m a i n _ o p t i o n s
 *
 **************************************
 *
 * Functional description
 *	Parse command line switches with no arguments.
 *
 **************************************/

/* 	Scan until end of string of compacted options 			*/

while ( *p != '\0' )

{
/* 	operate on one option at a time 				*/
	
    switch (UPPER(*p))

    {
	case 'C':			/* Clock off */
	    sw_timestamp_off = TRUE;
	    printf ("\tTCS will NOT timestamp the series runs.\n");
	    break;

        case 'I':
            sw_ignore_init = TRUE;
            break;

#if (defined WIN_NT || defined OS2_ONLY)
/*	NOTE:	This switch '-m' turns on the MKS toolkit for NT.	*/
	case 'M':
	    sw_nt_mks = TRUE;
	    set_script_file();
	    fix_nt_mks_lookup();
	    printf ("\tTCS will use MKS...\n");
	    break;
#endif
 
        case 'N':
            sw_no_system = TRUE;
            break;
 
        case 'Q':
            sw_quiet = TRUE;
            break;
 
        case 'S':
            sw_save = TRUE;
            break;
 
        case 'T':
            sw_times = TRUE;
            break;
 
        case 'Z':
            sw_version = TRUE;
            break;
 
        default:
            print_error ("unrecognized switch '-%c' ignored.", (TEXT*) *p,0,0);
        case 'X':
#if (defined WIN_NT || defined OS2_ONLY)
            printf ("\nUsage:  tcs [ -d local ] [ -g global ] [ -i ] [ -m ] [ -n ] [ -q ] [ -t ]\n\t[ -z ] [ -x ]\n\n");
#else
            printf ("\nUsage:  tcs [ -d local ] [ -g global ] [ -c ] [ -i ] [ -n ] [ -q ] [ -t ]\n\t[ -z ] [ -x ]\n\n");
#endif
            printf ("\t-d\tThe name of the local database to be used.\n");
            printf ("\t-g\tThe name of the global database to be used.\n");
            printf ("\t-c\tClock off.  Do not timestamp series runs.\n");
            printf ("\t-i\tIgnore initializations.  TCS will act like all tests are\n\t\tuninitialized.\n");
#if (defined WIN_NT || defined OS2_ONLY)
	    printf ("\t-m\tTurn on MKS toolkit file handling. (This switch is only\n\t\tavailable on Windows NT and OS/2.)\n");
#endif
            printf ("\t-n\tNo system.  Allow one run of a test, series or meta-series,\n\t\tthen dump script to \"tcs.script\" and kick user to shell.\n");
	    printf ("\t\tNOTE:  No system calls are made, so TCS does not run the test.\n\t\tIf the user puts the output into a file \"tcs.output\" TCS will\n");
	    printf ("\t\tcheck the output when it is restarted.\n");
            printf ("\t-q\tQuiet.  Suppress 'diff' output from failed tests.\n");
            printf ("\t-s\tSave the script files upon exit for the last test run by TCS.\n");
            printf ("\t-t\tStore the time in seconds in the local database for each test\n\t\trun.\n");
            printf ("\t-x\tPrint this description.\n");
				printf ("\t-z\tPrint all versions of Interbase used by this TCS.\n\n");
		 break;
    }
    *p++;
}
return TRUE;
}

static int parse_series_args ( start, first, second, break_flag )
	TEXT *start;
	SSHORT *first;
	SSHORT *second;
	SSHORT *break_flag;
{
/**************************************
 *
 *	p a r s e _ s e r i e s _ a r g s 
 *
 **************************************
 *
 * Functional description
 * 	Parse the args passed to the 'rs', or 'is'
 *	commands.  (ie. rs <some series name> 1-3,5,7 )
 *	Called by test_series.
 *
 **************************************/
SSHORT range;
TEXT *previous;
static TEXT *current;

/*	Is this the first time for this series?  If it is, set current	*
 *	pointing to start.						*/

if (*break_flag == TRUE)        
    current = start;
 
*break_flag = FALSE;    /* Set this to FALSE so we don't break prematurely.  */
 
previous = current;
*second = MAX_UPPER;    /* Set the upper bound to pseudo - infinity. 	*/
*first = range = 0;     /* Set the lower bound and the range flag to zero. */

/*	Loop through the args, checking for a NULL in *current but 	*
 *	first making sure current points to something.			*/
 
while( current != NULL && *current != '\0' )             

{

/*	Encountered comma and first is still zero, ( just finished 	*
 *	parsing a range that starts at zero, or we are just parsing	*
 *	one test.							*/	

    if( *current == ',' && !(*first) )     

    {                        
        *current++ = 0;

/*	Ignore multiple commas...or junk SCHARs				*/

        if( !isdigit( *previous ) && !(*previous) ) 

        {
            previous = current;
            continue;
        }

/*	If range starts at zero then assign value to second because	*
 *	we must be done parsing the range since we hit a comma.  Else	*
 *	assign value to both second and first for one test.		*/

        if( range )         
            *second = atoi( previous );
        else
            *second = *first = atoi( previous );

        break;
    }

/*	Encountered comma and first has some value ( may be finished	*
 *	parsing a range or about to start another token )		*/

    else if( *current == ',' && *first) 

    {

/*	Assign the top of the range if the range is being processed	*/

        ( range ) && (*second = atoi( previous )); 

        *current++ = 0;               /* Zero out comma and increment c	*/ 
        break;
    }

/*	Encountered a dash, so we must be halfway through the range -- 	*
 *	assign the bottom and move on.					*/

    else if( *current == '-')          

    {
        *current = 0;

/*	Ignore an incomplete range that is not at the beginning or 	*
 *	end of a line of arguments... If previous is not holding a 	*
 *	number and current is not the first element of this token 	*/

        if( !isdigit( *previous ) && current != start ) 

        {

/*	Skip the dash and set previous to the following SCHAR.		*/	
            previous = ++current;		

/*	Set first to the max which is in second so that when we return	*
 *	to the calling function no test in the series will be called	*
 *	NOTE:  This is for the case "rs c_exam 1,-3" -- where '-3'	*
 *	should be ignored.						*/
            ( !(*first) ) && ( *first = *second );

            continue;
        }

/*	If current == start then it is implied that the range starts 	*
 *	from zero.  (rs c_exam -5, this runs 0 through 5 )		*/

        else if ( current == start )   

        {
            *first = 0;
            previous = ++current; /* Set previous to SCHAR after dash	*/
            range = TRUE;	/* Set range flag			*/
        }

/*	Anything else must be the beginning of a range, so assign	*
 *	first and set previous pointing to the SCHAR after the dash.	*/	

        else

        {
            *first = atoi( previous ); 	/* Assign bottom of range. 	*/
            previous = (current+1);			 
            range = TRUE;		/* Set range flag to true.	*/
        }
    }

/*	Ignore garbage characters by moving previous past the garbage	*/

    else if( !isdigit( *current ))     
        previous = (current+1);

    current++;	/*	Increment current for the next iteration	*/
}
 
/*	If current is NULL SCHAR then we are at the end of the line so	*
 *	if first is zero then do appropriate thing for last arg		*/

if( current != NULL && *current == '\0' && !(*first))

{

/*	If previous is NULL and previous is not the first SCHAR then	*
 *	last SCHARs are garbage so ignore by setting break_flag so	*
 *	will jump out of loop in calling function.			*/

    if ( !(*previous) && previous != start )
        *break_flag = TRUE;     

/*	If previous is NULL and previous is pointing to the starting	*
 *	character then no args were given, so exit with first and	*
 *	second set to max values -- causing all tests in series to be	*
 *	run.								*/

    else if( !(*previous) && previous == start ); 

/*	If we saw a dash ( the range flag is set ), then set second	*
 *	to the value pointed to by previous ( the range must start	*
 *	at zero )							*
 *	NOTE:  This is the case:  "rs c_exam 3-" all tests greater 	*
 *	than or equal to 3 should be run.				*/

    else if( range )           
        *second = atoi( previous );

/*	Just one test to run, only a number was given, so assign to	*
 *	first and second.						*/	

    else                        
        *second = *first = atoi( previous );

    return FALSE;
}

/*	If we are at the end of a line and first has a value ( we are	*
 *	processing a range ) then finish processing by assigning the 	*
 *	top of a range.							*/

else if( current != NULL && *current == '\0' && *first)  

{
    ( *previous != '\0' ) && ( range ) && (*second = atoi( previous ));
    return FALSE;
}

/* 	If current is not pointing to an address, exit			*/

else if ( current == NULL )
    return FALSE;
 
return TRUE;
}
	
static int print_boilerplate (string)
    TEXT	*string;
{
/**************************************
 *
 *	p r i n t _ b o i l e r p l a t e
 *
 **************************************
 *
 * Functional description
 *	Print the text of the specified boilerplate
 *      printing the default if no argument is passed.
 *      Admit it when we can't find the boilerplate named.
 *      COMMAND: PB
 *
 **************************************/
USHORT	i;

i = 0;

/*	If string is NULL then move in the name of the current		*
 *	boilerplate -- boilerplate_name, and  search for that one.	*/	

if ((!string) || (!*string))
    strcpy (string, boilerplate_name);

/*	Search to local DB for the boilerplate with name == string	*
 *	and display it.							*/

FOR B IN TCS.BOILER_PLATE WITH B.BOILER_PLATE_NAME EQ string;
    i++;
    printf ("boilerplate %s: \n", string);
    disp_print_blob (&B.SCRIPT, TCS);
END_FOR;

/*	If i was not incremented then print an error and return.	*/

if (!i)
{
	 print_error ("There is no boilerplate named %s.", string,0,0);
	 return FALSE;
}
return TRUE;
}


static int print_comment (string)
    TEXT	*string;
{
/**************************************
 *
 *	p r i n t _ c o m m e n t
 *
 **************************************
 *
 * Functional description
 *	Print a test comment.
 *
 **************************************/
USHORT	count;

count = 0;

/*	Search the local DB for the test with name == string and 	*
 *	print the comment for that test if found.			*/

FOR T IN TCS.TESTS WITH T.TEST_NAME EQ string
    disp_print_blob (&T.COMMENT, TCS);
    count++;
END_FOR;

/*	If count was incremented then test was found in local DB so	*
 *	return.								*/

if (count)
    return TRUE;

/*	Search the global DB for the test with name == string and 	*
 *	print the comment for that test if found.			*/

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string
    disp_print_blob (&T.COMMENT, TCS_GLOBAL);
    count++;
END_FOR;

if (!count)
{
	 print_error ("There is no test with name: %s",0,0,0);
	 return FALSE;
}
 return TRUE;
}

static int print_environment (string)
    TEXT	*string;
{
/**************************************
 *
 *	p r i n t _ e n v i r o n m e n t 
 *
 **************************************
 *
 * Functional description
 *	print the script of the specified environment	
 *
 **************************************/
USHORT	count = 0;	

/*	If string is NULL then move the name of the current environment	*
 *	into string.							*/

if ((!string) || (!*string))
    strcpy (string, environment_name);

/*	Search the local DB for the environment with name == string	*
 *	and print the prolog and epilog for that environment.		*/

FOR T IN TCS.ENV WITH T.ENV_NAME EQ string
    disp_print_blob (&T.prolog, TCS);
    disp_print_blob (&T.epilog, TCS);
    count++;
END_FOR;

/*	If count is greater than zero, the environment exists so return	*/

if (count) 
	 return TRUE;

/*	Print an error message because env could not be found		*/

print_error ("Environment %s isn't there.", string,0,0);
return FALSE;
}

int print_error (string, a, b, c)
	TEXT 	*string, *a, *b, *c;
{
/**************************************
 *
 *      p r i n t _ e r r o r
 *
 **************************************
 *
 * Functional description
 * 	Print an error that has occured
 *	in a standard format.
 *
 **************************************/
SCHAR buf[160];

(void) fflush (stdout);
sprintf(buf, "\n**** %s:  %s\n",TCS_NAME,string);
fprintf (stderr, buf, a, b, c);
(void) fflush (stderr);
return TRUE;
}

static int print_global_result (string, vers)
	TEXT 	*string, *vers;
{
/**************************************
 *
 *      p r i n t _ g l o b a l _ r e s u l t
 *
 **************************************
 *
 * Functional description
 *      Print 'result' of named test stored in global database.
 *      eg. result stored in field output
 *      when test was initialized
 *
 **************************************/
TEXT *v;
SSHORT count = 0 ;
static BASED_ON TCS.TESTS.VERSION i_version; 	/* human readable version */
 
/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Search the global DB for the test with name == string and 	*
 *	closest version that is less than or equal to the current	*
 *	version.  If found print the result.				*/

FOR FIRST 1 I IN TCS_GLOBAL.INIT  WITH I.TEST_NAME EQ string AND
 I.VERSION <= v SORTED BY DESCENDING I.VERSION
	 unmake_version(i_version, I.VERSION);
	 printf ("Version %s:\n", i_version);
	 printf ("Global Result:\n");
	 disp_print_blob (&I.OUTPUT, TCS_GLOBAL);
	 count++;
END_FOR;

if (!count)
{
	 print_error ("There is no global init. record for %s with version <= V%s",string,v,0);
	 return FALSE;
}
 return TRUE;
}

static int print_meta_series (string)
	 TEXT	*string;
{
/**************************************
 *
 *	p r i n t _ m e t a _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *	Print series_names of series in 
 *      in given meta_series
 *
 **************************************/
USHORT	count;

count = 0;

printf ("Series in meta_series %s:\n", string);

/*	Search the local DB for the meta series with name == string 	*
 *	and if found print all elements with name == string (i.e. all	*
 *	series in the meta series. )					*/

FOR M IN TCS.META_SERIES WITH M.META_SERIES_NAME EQ string SORTED BY M.SEQUENCE
    if (quit)
	break;
    printf ("\t%d %s\n", M.SEQUENCE, M.SERIES_NAME);
    count++;
END_FOR;

/*	If count is zero, then could not find meta series in local DB,	*
 *	search the global DB for the meta series with name == string 	*
 *	and if found print all elements with name == string (i.e. all	*
 *	series in the meta series. )					*/

if (!count)
    FOR M IN TCS_GLOBAL.META_SERIES WITH M.META_SERIES_NAME EQ string SORTED BY M.SEQUENCE
	if (quit)
	    break;
	printf ("\t%d %s\n", M.SEQUENCE, M.SERIES_NAME);
	count++;
    END_FOR;

/*	Error message would be nice here...	*/
if (!count)
{
	 print_error ("Could not find meta series %s",string,0,0);
	 return FALSE;
}
 return TRUE;
}

static int print_meta_series_comment (name, swtch)
	 TEXT        *name, *swtch;
{
/**************************************
 *
 *      p r i n t _ m e t a _ s e r i e s _ c o m m e n t
 *
 **************************************
 *
 * Functional description
 *      Print a meta_series comment.
 *
 **************************************/
USHORT   count;
 
count = 0;
 
/*	If not NULL convert switch to upper case, else use global(G)	*/

if (NOT_NULL(swtch))
    disp_upcase (swtch, swtch);
else
    *swtch = 'G';

/*	If switch  is 'L' then search the local DB for the meta series	*
 *	with name and if found print the comment for that meta series.	*/
 
if (*swtch == 'L')

{
    FOR FIRST 1 T IN TCS.META_SERIES WITH T.META_SERIES_NAME EQ name
        FOR C IN TCS.META_SERIES_COMMENT WITH C.META_SERIES_NAME EQ name
            disp_print_blob (&C.COMMENT, TCS);
            count++;
        END_FOR;

/*	If count is zero then the meta series could not be found 	*
 *	locally, so print an error message.				*/

        if (!count)

        {
            print_error ("Comment does not exist for meta_series %s, see help page\nfor 'EMSC'",name,0,0);
            return FALSE;
        }

    END_FOR;

/*	If count is not zero, then meta series was found, so return	*/

    if (count)
        return TRUE;

/*	If made it to here then meta series could not be found, print 	*
 *	error.								*/

    print_error ("Meta_series %s does not exist locally",name,0,0);
}

/*	If switch  is 'G' then search the global DB for the meta series	*
 *	with name and if found print the comment for that meta series.	*/

else

{
    FOR FIRST 1 T IN TCS_GLOBAL.META_SERIES WITH T.META_SERIES_NAME EQ name
        FOR C IN TCS_GLOBAL.META_SERIES_COMMENT WITH C.META_SERIES_NAME EQ name
            disp_print_blob (&C.COMMENT, TCS_GLOBAL);
            count++;
        END_FOR;

/*	If count is zero then the meta series could not be found 	*
 *	globally, so print an error message.				*/

        if (!count)

        {
            print_error ("Comment does not exist for meta_series %s, see help page\nfor 'EMSC'",name,0,0);
				return FALSE;
		  }

	 END_FOR;

/*	If count is not zero, then meta series was found, so return	*/

	 if (count)
		  return TRUE;

/*	If made it to here then meta series could not be found, print 	*
 *	error.								*/

	 print_error ("Meta_series %s does not exist globally",name,0,0);
}
return FALSE;
}

static int print_result (string, vers)
    TEXT	*string, *vers;
{
/**************************************
 *
 *	p r i n t _ r e s u l t
 *
 **************************************
 *
 * Functional description
 *	Print 'result' of named test stored in local database.
 *	eg. result stored in field output
 *	when test was initialized
 *
 **************************************/
TEXT *v;
SSHORT count = 0;
static BASED_ON TCS.TESTS.VERSION i_version; 	/* human readable version */

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Search Local DB for initialization record with name == string	*
 *	and version closest to, but less than or equal to the current	*
 *	version.  If found print to the screen.				*/

FOR FIRST 1 I IN TCS.INIT  WITH I.TEST_NAME EQ string AND I.VERSION <= v
  SORTED BY DESCENDING I.VERSION
	 unmake_version(i_version, I.VERSION);
	 printf ("Version %s:\n", i_version);
	 printf ("Local Result:\n");
	 disp_print_blob (&I.OUTPUT, TCS);
	 count++;
END_FOR;

if (!count)
{
	 print_error ("Could not find init. record for %s with version <= V%s",string,*vers ? vers : version,0);
	 return FALSE;
}
 return TRUE;
}

static int print_run ()
{
/**************************************
 *
 *	p r i n t _ r u n
 *
 **************************************
 *
 * Functional description
 *	print the current run name
 *
 **************************************/

printf ("Run name is %s\n", run_name);
return TRUE;
}

static int print_series (string)
    TEXT	*string;
{
/**************************************
 *
 *	p r i n t _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *	Print test_names of tests in given series
 *
 **************************************/

printf ("Tests in series %s:\n", string);
/*	Search the local DB for the series name given in string.	*
 *	If found, print each test name that exists in the series 	*
 * 	relation with that series name.					*/

FOR S IN TCS.SERIES WITH S.SERIES_NAME EQ string SORTED BY S.SEQUENCE
    if (quit)
	break;
    printf ("\t%6d %s\n", S.SEQUENCE, S.TEST_NAME);
END_FOR;

/*	Should check for success or failure...		*/

/*	Search the global DB for the series name given in string.	*
 *	If found, print each test name that exists in the series 	*
 * 	relation with that series name.					*/

FOR S IN TCS_GLOBAL.SERIES WITH S.SERIES_NAME EQ string SORTED BY S.SEQUENCE
    if (quit)
	break;
    printf ("\t%6d %s\n", S.SEQUENCE, S.TEST_NAME);
END_FOR;

/*	Should check for success or failure...		*/
 return TRUE;
}

static int print_series_comment (name, swtch)
	 TEXT        *name, *swtch;
{
/**************************************
 *
 *      p r i n t _ s e r i e s _ c o m m e n t
 *
 **************************************
 *
 * Functional description
 *      Print a series comment.
 *
 **************************************/
USHORT   count;
 
count = 0;

/*	If not NULL convert switch to upper case, else use global(G)	*/

if (NOT_NULL(swtch))
    disp_upcase (swtch, swtch);
else
    *swtch = 'G';

/*	If switch  is 'L' then search the local DB for the series	*
 *	with name and if found print the comment for that series.	*/

if (*swtch == 'L')

{
    FOR FIRST 1 T IN TCS.SERIES WITH T.SERIES_NAME EQ name 
        FOR C IN TCS.SERIES_COMMENT WITH C.SERIES_NAME EQ name
            disp_print_blob (&C.COMMENT, TCS);
            count++;
	END_FOR;

/*	If count is zero then the series could not be found locally 	*
 *	so print an error message.					*/

	if (!count)
	{
	    print_error ("Comment does not exist for series %s, see help page for 'ESC'",name,0,0);
		 return FALSE;
	}
	 END_FOR;

/*	If count is not zero, then series was found, so return	*/

	 if (count)
		  return TRUE;

/*	If made it to here then series could not be found, print 	*
 *	error.								*/

	 print_error ("Series %s does not exist locally",name,0,0);
}

/*	If switch  is 'G' then search the global DB for the series	*
 *	with name and if found print the comment for that series.	*/

else

{
	 FOR FIRST 1 T IN TCS_GLOBAL.SERIES WITH T.SERIES_NAME EQ name
		  FOR C IN TCS_GLOBAL.SERIES_COMMENT WITH C.SERIES_NAME EQ name
				disp_print_blob (&C.COMMENT, TCS_GLOBAL);
				count++;
	END_FOR;

/*	If count is zero then the series could not be found locally 	*
 *	so print an error message.					*/

	if (!count)

	{
		 print_error ("Comment does not exist for series %s, see help page for 'ESC'",name,0,0);
		 return FALSE;
	}

	 END_FOR;

/*	If count is not zero, then series was found, so return		*/

	 if (count)
		  return TRUE;

/*	If made it to here then series could not be found, print 	*
 *	error.								*/

	 print_error ("Series %s does not exist globally",name,0,0);
}
return FALSE;
}

static int print_test (string, vers)
	 TEXT	*string, *vers;
{
/**************************************
 *
 *	p r i n t _ t e s t
 *
 **************************************
 *
 * Functional description
 *	print the script of the specified test	
 *
 **************************************/
USHORT	count;
TEXT *v;
static BASED_ON TCS.TESTS.VERSION t_version; 	/* human readable version */

count = 0;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (vers)))
	 return FALSE;

/*	Search the local DB for the test with name == string and 	*
 *	version less than or equal to the current version.  If found	*
 *	print the script.						*/

FOR FIRST 1 T IN TCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION <= v
  SORTED BY DESCENDING T.VERSION
	 unmake_version (t_version, T.VERSION);
	 printf ("Local Test, Version %s:\n", t_version);
	 disp_print_blob (&T.script, TCS);
	 count++;
END_FOR;

/*	If count is zero then the test could not be found in the local 	*
 *	DB, so search the global DB.  If found print the test.		*/

if (!count)
{
	 FOR FIRST 1 T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME EQ string AND T.VERSION <= v
		SORTED BY DESCENDING T.VERSION
		  unmake_version (t_version, T.VERSION);
		  printf ("Global Test, Version %s:\n", t_version);
		  disp_print_blob (&T.script, TCS_GLOBAL);
		  count++;
	 END_FOR;
}

/*	If count is not zero then the test was found so return.		*/

if (count)
	 return TRUE;

/*	Print an error if the test could not be found.			*/

print_error ("Test %s with version <= V%s isn't there.", string, *vers ? vers : version,0);
return FALSE;
}

static int print_version ()
{
/**************************************
 *
 *	p r i n t _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	print the current version
 *
 **************************************/

static BASED_ON TCS.TESTS.VERSION ver_no; 		/* %3d.%3d.%3d%s\0 */

unmake_version(ver_no, version);
printf ("Version is %s\n", ver_no);
return TRUE;
}

static char *right_trim (string, length)
char	*string;
int	length;
{
/**************************************
 *
 *      r i g h t _ t r i m
 *
 **************************************
 *
 * Functional description
 *	Trim off all trailing spaces from a string
 *
 **************************************/
char	*p;

p = string + length - 1;
while ((p >= string) && (*p == 0 || *p == ' '))
    *p-- = 0;

return string;
}

static int rollback ()
{
/**************************************
 *
 *	r o l l b a c k
 *
 **************************************
 *
 * Functional description
 *	Rollback the current transaction.
 *
 **************************************/

ROLLBACK;
START_TRANSACTION;
return TRUE;
}




static int	get_work (configuration, series_name, sequence, boilerplate)
	 char	*configuration;
	 char	*series_name;
	 int		*sequence;
	 char	*boilerplate;
{
/**************************************
 *
 *	g e t _ w o r k
 *
 **************************************
 *
 * Functional description
 *	Check the worklist, find an unrun series, and run it.
 *
 *	This is done in it's own transaction so we can properly
 *	coordinate with the other machines that are taking work
 *	off the worklist.
 *
 **************************************/

int	got_one = FALSE;
void	*checkout_work = NULL;

START_TRANSACTION checkout_work CONSISTENCY READ_WRITE WAIT
	RESERVING TCS.worklist FOR WRITE
	 ON_ERROR
	 print_error ("Starting worklist transaction failed:",0,0,0);
	 gds__print_status (gds__status);
	 return FALSE;
	 END_ERROR;

FOR (TRANSACTION_HANDLE checkout_work)
	 FIRST 1 W IN TCS.WORKLIST
	 WITH (W.STATUS == 0 OR W.STATUS MISSING)
	  AND (W.CONFIGURATION == configuration OR W.CONFIGURATION MISSING)
	 SORTED BY W.SEQUENCE

	 got_one = TRUE;
	 strncpy (series_name, W.SERIES_NAME, sizeof (W.SERIES_NAME));
	 series_name [sizeof (W.SERIES_NAME)-1] = 0;
	 strncpy (configuration, W.CONFIGURATION, sizeof (W.CONFIGURATION));
	 series_name [sizeof (W.CONFIGURATION)-1] = 0;
	 *sequence = W.SEQUENCE;
	 if (W.BOILER_PLATE_NAME.NULL)
	{
	boilerplate [0] = 0;
	}
	 else
	{
		  strncpy (boilerplate, W.BOILER_PLATE_NAME, sizeof (W.BOILER_PLATE_NAME));
		  boilerplate [sizeof (W.BOILER_PLATE_NAME)-1] = 0;
	}

	 MODIFY W USING
	W.STATUS = 1;		/* Running */
	strcpy (W.MACHINE, this_hostname);
	strcpy (W.START_TIME.CHAR[20], "NOW");
	W.END_TIME.NULL = TRUE;
	W.PASSED = 0;
	W.FAILED = 0;
	W.FAILED_KNOWN = 0;
	W.FAILED_UNINIT = 0;
	W.SKIPPED_NOTFOUND = 0;
	W.SKIPPED_FLAGGED = 0;
	W.NOT_RUN = 0;
	 END_MODIFY
		  ON_ERROR
		  print_error ("Marking work failed:",0,0,0);
		  gds__print_status (gds__status);
		  ROLLBACK checkout_work;
		  return FALSE;
		  END_ERROR;

END_FOR
	 ON_ERROR
	 print_error ("Looking for work failed:",0,0,0);
	 gds__print_status (gds__status);
	 ROLLBACK checkout_work;
	 return FALSE;
	 END_ERROR;

COMMIT checkout_work
	 ON_ERROR
	 print_error ("Commiting worklist failed:",0,0,0);
	 gds__print_status (gds__status);
	 ROLLBACK checkout_work;
	 return FALSE;
	 END_ERROR;
return got_one;
}



static int	report_results (configuration, series_name, sequence, series_results, test_error)
	 char	*configuration;
	 char	*series_name;
	 int		sequence;
	 struct tr_test_results *series_results;
	 USHORT	test_error;
{
/**************************************
 *
 *	r e p o r t _ r e s u l t s
 *
 **************************************
 *
 * Functional description
 *	Report the result of running a test series off the worklist
 *
 **************************************/
void	*report_work = NULL;
int	found = FALSE;

START_TRANSACTION report_work READ_WRITE WAIT
	RESERVING TCS.worklist FOR WRITE
	 ON_ERROR
	 print_error ("Starting worklist transaction failed:",0,0,0);
	 gds__print_status (gds__status);
	 return FALSE;
	 END_ERROR;

FOR (TRANSACTION_HANDLE report_work)
	 FIRST 1 W IN TCS.WORKLIST
	 WITH W.SERIES_NAME == series_name AND W.SEQUENCE == sequence
	  AND W.MACHINE == this_hostname AND W.STATUS == 1
	  AND W.CONFIGURATION == configuration

	 found = TRUE;
	 MODIFY W USING
	/* If we encountered a test system error - mark the series
	 * as "not run" so some other machine can try and run it.
	 */
	if (test_error)
		 W.STATUS = 0;		/* Available to Run */
	else
		 {
		 W.STATUS = 2;		/* FINISHED */
		 strcpy (W.END_TIME.CHAR[20], "NOW");
		 }
	W.PASSED = series_results->tr_test_results [passed];
	W.FAILED = series_results->tr_test_results [failed];
	W.FAILED_KNOWN = series_results->tr_test_results [failed_known];
	W.FAILED_UNINIT = series_results->tr_test_results [failed_noinit];
	W.SKIPPED_NOTFOUND = series_results->tr_test_results [skipped_notfound];
	W.SKIPPED_FLAGGED = series_results->tr_test_results [skipped_flagged];
	W.NOT_RUN = series_results->tr_test_results [skipped];
	 END_MODIFY
		  ON_ERROR
		  print_error ("Recording work failed:",0,0,0);
		  gds__print_status (gds__status);
		  ROLLBACK report_work;
		  return FALSE;
		  END_ERROR;

END_FOR
	 ON_ERROR
	 print_error ("Reporting worklist results failed:",0,0,0);
	 gds__print_status (gds__status);
	 ROLLBACK report_work;
	 return FALSE;
	 END_ERROR;

if (!found)
	 print_error ("Unable to find worklist entry:", 0,0,0);


COMMIT report_work
	 ON_ERROR
	 print_error ("Commiting worklist results failed:",0,0,0);
	 gds__print_status (gds__status);
	 ROLLBACK report_work;
	 return FALSE;
	 END_ERROR;

  return found;
}




static int run_worklist (string)
	 char	*string;
{
/**************************************
 *
 *	r u n _ w o r k l i s t
 *
 **************************************
 *
 * Functional description
 *	Check worklist table for series to run,
 *	run them until there aren't anymore.
 *
 **************************************/

int	sequence;
BASED_ON TCS.BOILER_PLATE.BOILER_PLATE_NAME new_bp_name;
BASED_ON TCS.BOILER_PLATE.BOILER_PLATE_NAME old_bp_name;
BASED_ON TCS.FAILURES.RUN new_run_name;
BASED_ON TCS.FAILURES.RUN old_run_name;
BASED_ON TCS.WORKLIST.CONFIGURATION configuration;

running_worklist = TRUE;

/* Save old information so we can reset it when finished */

strcpy (old_bp_name, boilerplate_name);
strcpy (old_run_name, run_name);

strcpy (configuration, string);

/* Get a (series,boilerplate) to run */

while (!(disk_io_error || quit) &&
	get_work (configuration, s_name, &sequence, new_bp_name))
    {
#ifdef DEBUG
    printf ("\nGot Work: %s %s %d %s\n", configuration, s_name, sequence, new_bp_name);
    fflush (stdout);
#endif

    strncpy (new_run_name, old_run_name, sizeof (new_run_name)-1);
    strncat (new_run_name, s_name, sizeof (new_run_name)-1-strlen(new_run_name));
    set_run (new_run_name);
    clear (new_run_name);
    if (new_bp_name [0])
	set_boilerplate (new_bp_name);
    test_series (s_name, NULL);
    commit();
    report_results (configuration, s_name, sequence, &series_results, (disk_io_error || quit));
    }

set_boilerplate (old_bp_name);
set_run (old_run_name);
printf ("Work from WORKLIST completed\n");
if (*string)
    printf ("for configuration %s\n", string);
running_worklist = FALSE;
return TRUE;
}




static int set_boilerplate (string)
	 TEXT	*string;
{
/**************************************
 *
 *	s e t _ b o i l e r p l a t e
 *
 **************************************
 *
 * Functional description
 *	Set the boilerplate name.
 *
 **************************************/
USHORT	i;

i = 0;

/*	Search the local DB to see if the boilerplate with name ==	*
 *	string exists.							*/

FOR B IN TCS.BOILER_PLATE WITH B.BOILER_PLATE_NAME = string
	 i++;
END_FOR;

/*	If i is not zero then the boilerplate exists, so make it 	*
 *	current								*/

if (i)

{
	 strcpy (boilerplate_name, string);
	 return TRUE;
}

/*	The boilerplate does not exist, so print an error.		*/

	 print_error ("%s is not a boilerplate. lb to list boilerplates",string,0,0);
	 return FALSE;

}

static int set_config(rfn)
	 TEXT	*rfn;
{
/*************************************
 *
 *	s e t _ c o n f i g
 *
 *************************************
 *
 * Functional description
 *	Read SB, SE, SRN and SVR commands from
 *	the file $HOME/.tcs_config if it exists.
 *
 ************************************/
TEXT	line_buf[MAX_LINE],cmd[MAX_LINE];
FILE	*rfp;
USHORT	line_idx, cmd_idx, start;
static BASED_ON TCS.TESTS.VERSION h_version; 	/* human readable version */

/* 	Open the configuration file. 					*/

if ((rfp = fopen(rfn,"r")) == NULL)
	 return FALSE;

printf("Reading configuration file \"%s\"...\n",TCS_CONFIG);

/* 	Loop until EOF. 						*/

while (fgets(line_buf,sizeof(line_buf),rfp))

{
	 line_idx = 0;

/* 	Move past preceding spaces/tabs if any...			*/

	 while ( line_buf[line_idx] == ' ' || line_buf[line_idx] == '\t' )
	line_idx++;

/*	Is the current line a blank one?				*/

	 if ( line_buf[line_idx] == '\n' )
	continue;

	 start = line_idx;

/* 	Find out where the command modifier begins. 			*/

	 if (line_buf[start+2] == ' ')
	line_idx += 3;
	 else
	line_idx += 4;

/* 	Copy the command modifier from LINE_BUF to CMD.  Since fgets()  *
 *	was used, LINE_BUF may not be NULL terminated. 			*/

	 *cmd = 0;

/* 	Loop through SCHARs in a line					*/

	 for ( cmd_idx = 0;
	  line_buf[line_idx] != '\0' && line_buf[line_idx] != '\n';
	  line_idx++, cmd_idx )

	 {

/* 	Ignore spaces and then assign modifier.				*/

	if (( line_buf[line_idx] != ' ' ) && ( line_buf[line_idx] != '\t' ))
		 cmd[cmd_idx++] = UPPER(line_buf[line_idx]);

/* 	Ignore any tokens following second token. 			*/

	else if ( *cmd != '\0' && ( line_buf[line_idx] == ' ' ||
	 line_buf[line_idx] == '\t' ))
		 break;
	 }

	 cmd[cmd_idx] = 0;

/* 	Use the 2nd character as a key to the configuration commands 	*
 *	just read. 							*/

	 switch ( line_buf[start+1] )
	 {

/*	sb -- set boilerplate						*/

	case 'b' :
	case 'B' :
		 if ( set_boilerplate(cmd) )
		printf("\tBoilerplate set to: \t%s\n",boilerplate_name);
		 else
		print_error("Boilerplate assignment failed.",0,0,0);
		 break;

/*	sdv -- set_dollar_verb						*/

	case 'd' :
	case 'D' :
		 set_dollar_verb(cmd, (char*)0L);
		 break;

/*	se -- set environment						*/

	case 'e' :
	case 'E' :
		 if ( set_env(cmd) )
		printf("\tEnvironment set to: \t%s\n", environment_name);
		 else
		print_error("Environment assignment failed.",0,0,0);
		 break;

/*	srn -- set run							*/

	case 'r' :
	case 'R' :
		 if ( set_run(cmd) )
		printf("\tRun set to: \t\t%s\n",run_name);
		 else
		print_error("Run assignment failed.",0,0,0);
		 break;

/*	svr -- set version						*/

	case 'v' :
	case 'V' :

		 if ( set_version(cmd) )
			  {
		unmake_version(h_version, version);
		printf("\tVersion set to: \t%s\n",h_version);
		}
		 else
		print_error("Version assignment failed.",0,0,0);
		 break;

#if (defined WIN_NT || defined OS2_ONLY)
/*	MKS -- Use the mks toolkit on NT platform.			*/

	case 'k' :
	case 'K' :
		 if (!sw_nt_mks)
		{
			sw_nt_mks = TRUE;
			set_script_file();
			fix_nt_mks_lookup();
			printf("\tTCS will use MKS...\n");
		}
		break;
#endif

/* 	Unknown commands. 						*/

	default :
		 print_error("Unintelligible line ignored:  %s",line_buf,0,0);
		 break;
	 }
}

printf("\n");
fclose(rfp);
return TRUE;

}

static int set_dollar_verb (verb, def)
	 TEXT        *verb,  *def;
{
/**************************************
 *
 *      s e t _ d o l l a r _ v e r b
 *
 **************************************
 *
 * Functional description
 *      Call a function (set_ptl_lookup) in trns.c to
 *      change the ptl_lookup table.
 *
 **************************************/
TEXT    *ptr,
		  *head,
		  *tail,
		  *value;

if ( ptr = strchr(verb, '=') )

{
	 *ptr = '\0';
	 value = strdup(ptr + 1);
}
else
	 value = strdup(def);

for (head = tail = value; *head; head++, tail++)
	 if (*head == '^')
		  *tail = *(++head);
	 else
		  *tail = tolower(*head);
*tail = '\0';

if ( set_ptl_lookup(verb, value) )
	 printf("\tSuccessfully Set:\t%s = %s\n", verb, value);
else
	 printf("\tFailed to Set\t%s\n", verb);

if (ptr)
	 *ptr = '=';
  return TRUE;
}

static int set_env (name)
	 TEXT	*name;
{
/**************************************
 *
 *	s e t _ e n v
 *
 **************************************
 *
 * Functional description
 *	Try to execute the user specified environment
 *      if that succeeds, set the env name.
 *
 **************************************/
USHORT	i;

i = 0;

/*	Search local DB for environment with name			*/

FOR E IN TCS.ENV WITH E.ENV_NAME = name

/*      Convert files to new env if they exist.                         */

	 EXEC_env (&E.PROLOG);
	 i++;

END_FOR;

/*	If i then environment exists, so set current environment to 	*
 *	name								*/

if (i)

{
	 env_clear = FALSE;
	 strcpy (environment_name, name);
	 return TRUE;
}

/*	If could not find environment then print an error.		*/

	 print_error ("%s is not an environment name",name,0,0);
	 return FALSE;
}

static int set_known_failures (name)
    TEXT	*name;
{
/**************************************
 *
 *	s e t _ k n o w n _ f a i l u r e s
 *
 **************************************
 *
 * Functional description
 *	Set run name that records known failures
 *
 **************************************/

/*	If name is not NULL then make name the current run name		*/

if (NOT_NULL (name))
    {
    strcpy (known_failures_run_name, name);
    printf ("Known failures run set to %s\n", known_failures_run_name);
    return TRUE;	
    }

/*	If name is NULL then print an error and make DEFAULT the 	*
 *	current run name.						*/

strcpy (known_failures_run_name, "");
printf ("Known failures run name cleared\n");
return TRUE;
}

static int set_run (name)
	 TEXT	*name;
{
/**************************************
 *
 *	s e t _ r u n
 *
 **************************************
 *
 * Functional description
 *	Set run name
 *
 **************************************/

/*	If name is not NULL then make name the current run name		*/

if (NOT_NULL (name))

{
	 strcpy (run_name, name);
	 return TRUE;
}

/*	If name is NULL then print an error and make DEFAULT the 	*
 *	current run name.						*/

	 print_error ("No run name given, using DEFAULT",0,0,0);
	 strcpy (run_name, "DEFAULT");
	 return FALSE;
}

static int set_version (name)
    TEXT	*name;
{
/**************************************
 *
 *	s e t _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Set version
 *
 **************************************/
TEXT *v;

/* Adjust the version from XXX.XXXA to XXXXXXXXXA, else abort */

if ( !(v = make_version (name)))
    return FALSE;

/*	If conversion was successful then assign return value to 	*
 *	the current version.						*/

strcpy (version, v);
return TRUE;
}



static int show_test (name)
    TEXT	*name;
{
/**************************************
 *
 *	s h o w _ t e s t 
 *
 **************************************
 *
 * Functional description
 *	Show various useful information about a test.
 *
 *	A clone of this function is in tcs/tan.e
 *
 **************************************/

static BASED_ON TCS.TESTS.VERSION ver_no; 	/* %3d.%3d.%3d%s\0 */

struct {
    int	inits;
    int tests;
    int series;
    int failures;
} local, global;

local.inits = 0;
local.tests = 0;
local.series = 0;
local.failures = 0;
global = local;

/* Report basic info on the test: versions, creators, editors, etc */

FOR T IN TCS.TESTS WITH T.TEST_NAME = name SORTED BY DESCENDING T.VERSION
    if (local.tests == 0)
        printf (" Local test     :Editor:     :Edit date:       :Creator:   :flags:\n");
            /*  "  VVVVVVVVVVVV   BBBBBBBBBBBB DDDDDDDDDDDDDDDDD BBBBBBBBBBBB " */
    unmake_version(ver_no,T.VERSION);
    printf ("  %-12s   %-12s %-17s %-12s ",
		RIGHT_TRIM (ver_no), 
		RIGHT_TRIM (T.EDIT_BY), T.EDIT_DATE.CHAR[17],
		RIGHT_TRIM (T.CREATED_BY));
    if (T.NO_INIT_FLAG)
	printf ("(No init)");
    if (T.NO_RUN_FLAG)
	printf ("(Run only %d)", T.NO_RUN_FLAG);
    printf ("\n");
    if (!T.COMMENT.NULL)
	disp_print_blob (&T.COMMENT, TCS);
    local.tests++;
END_FOR;

FOR T IN TCS_GLOBAL.TESTS WITH T.TEST_NAME = name SORTED BY DESCENDING T.VERSION
    if (global.tests == 0)
        printf ("Global test     :Editor:     :Edit date:       :Creator:   :flags:\n");
            /*  "  VVVVVVVVVVVV   BBBBBBBBBBBB DDDDDDDDDDDDDDDDD BBBBBBBBBBBB " */
    unmake_version(ver_no,T.VERSION);
    printf ("  %-12s   %-12s %-17s %-12s ",
		RIGHT_TRIM (ver_no), 
		RIGHT_TRIM (T.EDIT_BY), T.EDIT_DATE.CHAR[17],
		RIGHT_TRIM (T.CREATED_BY));
    if (T.NO_INIT_FLAG)
	printf ("(No init)");
    if (T.NO_RUN_FLAG)
	printf ("(Run only %d)", T.NO_RUN_FLAG);
    printf ("\n");
    if (!T.COMMENT.NULL)
	disp_print_blob (&T.COMMENT, TCS_GLOBAL);
    global.tests++;
END_FOR;

if (!local.tests && !global.tests)
    printf ("Test '%s' was not found.\n", name);

printf ("\n");

/* Now report on the various init records for the test */

FOR I IN TCS.INIT WITH I.TEST_NAME = name SORTED BY DESCENDING I.VERSION
    if (local.inits == 0)
        printf (" Local init     :init by:    :init date:       :Boilerplate:\n");
            /*  "  VVVVVVVVVVVV   BBBBBBBBBBBB DDDDDDDDDDDDDDDDD BBBBBBBBBBBB" */
    unmake_version(ver_no,I.VERSION);
    printf ("  %-12s   %-12s %-17s %s\n",
		ver_no, RIGHT_TRIM (I.INIT_BY), I.INIT_DATE.CHAR[17],
		RIGHT_TRIM (I.BOILER_PLATE));
    local.inits++;
END_FOR;

FOR I IN TCS_GLOBAL.INIT WITH I.TEST_NAME = name SORTED BY DESCENDING I.VERSION
    if (global.inits == 0)
        printf ("Global init     :init by:    :init date:       :Boilerplate:\n");
            /*  "  VVVVVVVVVVVV   BBBBBBBBBBBB DDDDDDDDDDDDDDDDD BBBBBBBBBBBB" */
    unmake_version(ver_no,I.VERSION);
    printf ("  %-12s   %-12s %-17s %s\n",
		ver_no, RIGHT_TRIM (I.INIT_BY), I.INIT_DATE.CHAR[17],
		RIGHT_TRIM (I.BOILER_PLATE));
    global.inits++;
END_FOR;

if (!local.inits && !global.inits)
    printf ("Test '%s' has no local or global init records.\n", name);

printf ("\n");

/* Finally, determine which series contain the test */

FOR S IN TCS.SERIES WITH S.TEST_NAME = name SORTED BY S.SERIES_NAME, S.SEQUENCE
    if (local.series == 0)
	printf (   " Local series: ");
    else if ((local.series % 4) == 0)
	printf (",\n               ");
    else
	printf (", ");
    printf ("%s (%d)", RIGHT_TRIM (S.SERIES_NAME), S.SEQUENCE);
    local.series++;
END_FOR;
if (local.series)
    printf ("\n");

FOR S IN TCS_GLOBAL.SERIES WITH S.TEST_NAME = name SORTED BY S.SERIES_NAME, S.SEQUENCE
    if (global.series == 0)
	printf (   "Global series: ");
    else if ((global.series % 4) == 0)
	printf (",\n               ");
    else
	printf (", ");
    printf ("%s (%d)", RIGHT_TRIM (S.SERIES_NAME), S.SEQUENCE);
    global.series++;
END_FOR;
if (global.series)
    printf ("\n");

if (!local.series && !global.series)
    printf ("Test '%s' is not part of any series.\n", name);

printf ("\n");

/* And might as well dump out any failures stored for the test */

FOR F IN TCS.FAILURES WITH F.TEST_NAME = name
    SORTED BY DESCENDING F.VERSION, F.DATE
    if (local.failures == 0)
        printf (" Local fail    :date           :run_by:     :run:                :Boilerplate:\n");
            /*  " VVVVVVVVVVVV DDDDDDDDDDDDDDDDD NNNNNNNNNNNN RRRRRRRRRRRRRRRRRRRR BBBBBBBBBBBBBBBBB " */
    unmake_version(ver_no,F.VERSION);
    printf (    " %-12s %-17s %-12s %-20s %s\n",
		ver_no, F.DATE.CHAR[17], RIGHT_TRIM (F.RUN_BY),
		RIGHT_TRIM (F.RUN), RIGHT_TRIM (F.BOILER_PLATE_NAME));
    local.failures++;
END_FOR;

FOR F IN TCS_GLOBAL.FAILURES WITH F.TEST_NAME = name
    SORTED BY DESCENDING F.VERSION, F.DATE
    if (global.failures == 0)
        printf ("Global fail    :date           :run_by:     :run:                :Boilerplate:\n");
            /*  " VVVVVVVVVVVV DDDDDDDDDDDDDDDDD NNNNNNNNNNNN RRRRRRRRRRRRRRRRRRRR BBBBBBBBBBBBBBBBB " */
    unmake_version(ver_no, F.VERSION);
    printf (    " %-12s %-17s %-12s %-20s %s\n",
		ver_no, F.DATE.CHAR[17], RIGHT_TRIM (F.RUN_BY),
		RIGHT_TRIM (F.RUN), RIGHT_TRIM (F.BOILER_PLATE_NAME));
    global.failures++;
END_FOR;

if (!local.failures && !global.failures)
    printf ("Test %s has no stored failures.\n", name);

printf ("\n");

/* And might as well dump out any notes stored for the test */

FOR N IN TCS.NOTES WITH N.TEST_NAME = name AND N.NOTE NOT MISSING
    printf (" Local Note:\n");
    disp_print_blob (&N.NOTE, TCS);
END_FOR;

FOR N IN TCS_GLOBAL.NOTES WITH N.TEST_NAME = name AND N.NOTE NOT MISSING
    printf ("Global Note:\n");
    disp_print_blob (&N.NOTE, TCS_GLOBAL);
END_FOR;
return TRUE;
}


static void CLIB_ROUTINE signal_quit ()
{
/**************************************
 *
 *	s i g n a l _ q u i t
 *
 **************************************
 *
 * Functional description
 *	Handle a quit signal.
 *
 **************************************/
void	(*prev_handler)();

#ifdef mpexl
XCONTRAP (0, (int*) &prev_handler);
#endif

quit = TRUE;
}

#ifdef VMS
static shell (string)
	 TEXT	*string;
{
/**************************************
 *
 *	s h e l l
 *
 **************************************
 *
 * Functional description
 *
 **************************************/

lib$spawn();

}
#endif

#ifndef VMS
static int shell (string)
	 TEXT	*string;
{
/**************************************
 *
 *	s h e l l
 *
 **************************************
 *
 * Functional description
 *
 **************************************/
TEXT	*command,*c;

/* The command parser has uppercased the STRING, so convert to lowercase */

if (*string)
	 for ( c = string; *c; c++ )
	*c = (isupper(*c) ? tolower(*c) : *c);
command = (*string) ? string : "sh";
system (command);
return TRUE;
}
#endif



static int test (string)
    TEXT	*string;
{
/**************************************
 *
 *	t e s t
 *
 **************************************
 *
 * Functional description
 *	Compare the results of a script to the "correct" output.
 *
 **************************************/
struct runflag	*runflag = runflag_options;
USHORT		count, skip;
TEST_RESULT	result;
TEXT		test_name[33], command [128];
SLONG		clock;
struct tm	times;

series_results.tr_test_count++;
count =  0;

/*	Get current time.						*/
clock = time (NULL);
times = *localtime (&clock);

/* Print a timestamp to the log */
if (running_worklist)
    printf ("%s", asctime (&times));

/*	The first byte of test_name is used to store a symbol to	*
 *	determine which database the test is in, l=local, g=global.	*
 *	So advance test_name one byte, copy string into test_name and	*
 *	set test_name[-1] = 'l'.					*/
*test_name = 'l';
strcpy(test_name+1, string);

/* 	Execute the main file -- search for the test with name == 	*
 *	string, and version less than or equal to version.		*/

FOR FIRST 1 L IN TCS.TESTS WITH L.TEST_NAME EQ string AND
  L.VERSION <= version SORTED BY DESCENDING L.VERSION

/*	If the NO_RUN_FLAG is not set then continue to try and run the	*
 *	test.								*/

    if (L.NO_RUN_FLAG.NULL || L.NO_RUN_FLAG == 0)

    {
        skip = FALSE;

        if (!L.CATEGORY.NULL && strcmp (L.CATEGORY, "GENERIC"))

        {
            skip = TRUE;
            FOR X IN TCS.CATEGORIES WITH X.CATEGORY EQ L.CATEGORY
                skip = FALSE;
            END_FOR;
        }

        if (skip)

        {
            print_error ("Test %s, category %s skipped", string, L.CATEGORY,0);
	         series_results.tr_test_results [skipped]++;
            return 0;
        }

/*	Call the routine to really execute the test ( in exec.e )	*/

        result = EXEC_test (test_name+1, &L.SCRIPT, TCS, sw_no_system, phase, &file_count, version, run_name);
    }

/*	If the NO_RUN_FLAG is set then do not call execution routine	*
 *	to execute the test, but print out value of NO_RUN_FLAG and	*
 *	the associated meaning with that value.				*/ 

    else

    {
/*	Print the proper NO_RUN_FLAG code if there is one, else just 	*
 *	print error.					 		*/

	if (L.NO_RUN_FLAG < 2)
            print_error ("Test %s is read_only:  %d - %s", string, (TEXT*) runflag[L.NO_RUN_FLAG].option, runflag[L.NO_RUN_FLAG].description);

 	else
	    print_error ("Test %s is read_only",string,0,0);

	      series_results.tr_test_results [skipped_flagged]++;
        return 0;
        }
    count++;
END_FOR;

/*	If count is zero then test could not be found in the Local DB	*
 *	so search the Global DB and try to run.				*/

if (!count)
{ 
    *test_name = 'g';

    FOR FIRST 1 G IN TCS_GLOBAL.TESTS WITH G.TEST_NAME EQ string AND
      G.VERSION <= version SORTED BY DESCENDING G.VERSION

/*	If the NO_RUN_FLAG is set, print the value and its associated	*
 *	meaning.							*/

        if (!G.NO_RUN_FLAG.NULL && G.NO_RUN_FLAG != 0)

	{
/*	Print the proper NO_RUN_FLAG code if there is one. 		*/

	    if (G.NO_RUN_FLAG < 2)
            	print_error ("Test %s is read_only:  %d - %s", string, (TEXT*) runflag[G.NO_RUN_FLAG].option, runflag[G.NO_RUN_FLAG].description);
	    else
		print_error ("Test %s is read_only",string,0,0);

	    series_results.tr_test_results [skipped_flagged]++;
	    return 0;
	}

	skip = FALSE;

	if (!G.CATEGORY.NULL && strcmp (G.CATEGORY, "GENERIC"))
	{
	    skip = TRUE;
	    FOR X IN TCS.CATEGORIES WITH X.CATEGORY EQ G.CATEGORY
		skip = FALSE;
	    END_FOR;
	}

	if (skip)
	{
	    print_error ("Test %s, category %s skipped", string, G.CATEGORY,0);
	    series_results.tr_test_results [skipped]++;
	    return 0;
	}

/*	Call the routine to execute the test ( in exec.e )		*/

	result = EXEC_test (test_name+1, &G.SCRIPT, TCS_GLOBAL, sw_no_system, phase, &file_count, version, run_name);

        count++;
    END_FOR;
}

/*	If count is not zero then test was executed			*/

if (count)

{

/* 	If the no system flag is thrown and the test did not fail,	*
 *	then write current TCS info to info file (env,bp,run name, etc)	*/

    if (sw_no_system && (result == passed) && !phase)

    {

/*	Open the file and write the info.				*/

        if (ifile = fopen (info_file, "w"))

        {
            fprintf (ifile, "%s %d %d %s %d %d %s %s %s %d %d\n",
		ms_name, ms_count, ms_sequence, s_name, s_count, 
		s_sequence, string, environment_name, boilerplate_name, 
		init_run, file_count);

            fclose (ifile);
            COMMIT;
            FINISH;
            exit (FINI_OK);
        }

/*	Could not open the info file, so print an error.		*/

        else

        {
            print_error ("Could not open %s", info_file,0,0);
            COMMIT;
            FINISH;
            exit (FINI_ERROR);
        }

    }

/*	If the test failed and the quiet switch is not thrown, then	*
 *	print the differences between the failure and the expected	*
 *	result.								*/

    if ((result != passed) && !sw_quiet)
        diff (string);

    series_results.tr_test_results [result]++;
    return (result == passed) ? 0 : 1;
}

/*	If made it to here then test could not be found, so print error.*/
else
    {
    print_error ("Test \"%s\" with version <= V%s not found", string, version,0);

    series_results.tr_test_results [skipped_notfound]++;
    return 0;
    }
}

static int test_meta_series (string, start)
    TEXT  *string, *start;
{
/**************************************
 *
 *	t e s t _ m e t a _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *	Run through a list of series
 *                          
 **************************************/
USHORT	total;
SSHORT	first;

/*	Set first to the appropriate value depending on if start is 	*
 *	NULL or not.  If NULL, set start to zero.			*/

first = NOT_NULL (start) ? atoi (start) : 0;

first--;
total = (ms_count < 0) ? -ms_count : 0;

/*	If global variable ms_count is less than or equal to zero 	*
 *	check the local DB -- will normally be zero unless using 	*
 *	the '-n' command line option.					*/

if (ms_count <= 0)

{
    FOR M IN TCS.META_SERIES
      WITH M.META_SERIES_NAME EQ string AND M.SEQUENCE > first SORTED BY M.SEQUENCE
        total++;
        ms_count--;
        ms_sequence = M.SEQUENCE;
        strcpy (ms_name, M.META_SERIES_NAME);
	printf("Running metaseries %s",ms_name); fflush(stdout);
        test_series (M.SERIES_NAME, NULL);
    END_FOR;
}

/*	If total was not incremented, then meta series was not found 	*
 *	in the local DB so search the global DB.  If found, loop 	*
 *	and run each series in the meta series.				*/


if (!total)

{
    total = ms_count;
    FOR M IN TCS_GLOBAL.META_SERIES
    WITH M.META_SERIES_NAME EQ string AND M.SEQUENCE > first SORTED BY M.SEQUENCE
        total++;
        ms_count++;
        ms_sequence = M.SEQUENCE;
        strcpy (ms_name, M.META_SERIES_NAME);
	printf("Running metaseries %s",ms_name); fflush(stdout);
	test_series (M.SERIES_NAME, NULL);
    END_FOR;
}

/*	If total has not been incremented, then the meta series could	*
 *	not be found -- print an error.					*/

if (!total)
{
	 print_error ("Metaseries %s isn't there.", string,0,0);
	 return FALSE;
}
return TRUE;
}

static int test_series (string, start)
    TEXT  *string, *start;
{
/**************************************
 *
 *	t e s t _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *	Run a series of tests.
 *
 **************************************/
USHORT	total, count;
SSHORT	first, second, break_flag = TRUE;
int 	loop = TRUE;

struct 	tm times;
SLONG 	clock;

/* This test will set up an AUDIT system for a test series.
 * Currently it deletes existing database files so a test
 * won't fail due to pre-existing test files.
 */
if (running_worklist)
	 {
	 test ("AUDIT_INIT");
	 erase ("AUDIT_INIT");
	 }

/* Initialize the series results */

memset ((char *) &series_results, 0, sizeof (series_results));

/*	Loop for each command line argument.				*/

while( loop )

{
/*	loop will be set by parse_series_args() which will determine	*
 *	how long to keep parsing.					*/

	 loop = parse_series_args( start, &first, &second, &break_flag);

/* 	break_flag will be set appropriately within parse_series_args. 	*/

	 if ( break_flag )
	break;

/*	Increase bounds by one, so can use < and > without equal sign	*/

	 first--; second++;
	 count = 0;

/*	This is done for the '-n' TCS command line option.  s_count	*
 *	is stored in the tcs.info file.					*/

	 total = (s_count < 0) ? -s_count : 0;

/*	Normally s_count will be zero, unless -n option is thrown on	*
 *	TCS command line.  So look in local DB for series and loop	*
 *	through series for each test that is greater than first and	*
 *	less than second (determined by arguments passed in and parsed.)*/

	 if (sw_timestamp_off)
	 {
	printf("Running series %s\n", string);
	fflush (stdout);
	 }
	 else
	 {
	/* Get the current time to print out before running a series */
	clock = time (NULL);
	times = *localtime (&clock);
	printf("\nRunning series %s started on %s",string,asctime (&times));
	fflush (stdout);
	 }

	 if (s_count <= 0)

	 {
		  FOR S IN TCS.SERIES WITH S.SERIES_NAME EQ string
				AND S.SEQUENCE > first AND S.SEQUENCE < second
				SORTED BY S.SERIES_NAME, S.SEQUENCE

				if (quit || disk_io_error)
					 break;

				total++;
				s_count--;
				s_sequence = S.SEQUENCE;
				strcpy (s_name, S.SERIES_NAME);
				count = test (S.TEST_NAME);

/*	If quiet switch is not thrown and the test was run by test()	*
 *	print the differences.						*/

				if (count && !sw_quiet)
					 diff (string);

		  END_FOR;
	 }

/*	If total is zero then series was not found in local DB so seach	*
 *	global DB for series and loop through series for each test that *
 *	is greater than first and less than second ( determined by 	*
 *	arguments passed in and parsed )				*/

	 if (!total)

	 {
		  total = s_count;
		  FOR S IN TCS_GLOBAL.SERIES WITH S.SERIES_NAME EQ string
		 AND S.SEQUENCE > first AND S.SEQUENCE < second
		 SORTED BY S.SERIES_NAME, S.SEQUENCE

				if (quit || disk_io_error)
					  break;

				total++;
				s_count++;
				s_sequence = S.SEQUENCE;
				strcpy (s_name, S.SERIES_NAME);
				 count = test (S.TEST_NAME);

/*	If quiet switch is not thrown and the test was run by test()	*
 *	print the differences.						*/

				 if (count && !sw_quiet)
					 diff (string);

		  END_FOR;
		  }

/* 	If total is still zero here then series was not found in local	*
 *	or global DBs so print error.					*/

	 if (!total)
		  print_error ("Series %s isn't there.", string,0,0);

	 }

if (running_worklist)
	 {
	 /* Run a test to finish off the AUDIT, but don't include the
	  * results of this test in the series results
	  */
	 struct tr_test_results	save_results;
	 save_results = series_results;
	 test ("AUDIT_FINISH");
	 series_results = save_results;
	 }
  return TRUE;
}

#ifdef NO_STRDUP
char *strdup(text)
	 char	  *text;
{
/**************************************
 *
 *	s t r d u p
 *
 **************************************
 *
 * Functional description
 *	Allocates memory for a copy of text and
 *	copys text into the new space.
 *
 **************************************/
    int		   len;
    char	  *ptr,
		  *new;
    len = strlen(text) + 1;
    new = (char*)malloc(len * sizeof(char));
    strcpy(new, text);
    return ptr;
}
#endif
