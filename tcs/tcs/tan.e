/*
 *	PROGRAM:	TCS Analysis Tool
 *	MODULE:		tan.e
 *	DESCRIPTION:	Remote TCS analysis tool
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
 * $Log$
 */

#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <sys/stat.h>
/* seems these are needed to compile */
#include <gds.h>
#include "common.h"
#include "time.h"

#ifdef VERSION_33
/* This causes compile error on Version 4.0 */
#include "../jrd/gds.h"
#endif

#define DEFAULT_VERSION		"000000000"
#define DEFAULT_RUN_NAME	"DEFAULT"
#define NOT_NULL(s)		((s) && *(s))
#define TAN_CONFIG		".tan_config"
#define MAX_LINE		80

#ifndef SIGQUIT
#define SIGQUIT		SIGINT
#endif

#ifdef WIN_NT
#define BLOB_TEXT_LOAD	BLOB_text_load
#define BLOB_TEXT_DUMP	BLOB_text_dump
#endif

#ifndef BLOB_TEXT_LOAD
#define BLOB_TEXT_LOAD	BLOB_load
#endif

#ifndef BLOB_TEXT_DUMP
#define BLOB_TEXT_DUMP	BLOB_dump
#endif


DATABASE
    DB = COMPILETIME FILENAME "rollup.gdb";

DATABASE
    GTCS = COMPILETIME FILENAME "gtcs.gdb";

DATABASE
    LTCS = COMPILETIME FILENAME "ltcs.gdb";

static TEXT	*make_version();
static		print_differences(), set_test(), set_platform(), 
		list_commands(), list_platforms(), print_test(), 
		print_result(), print_failure(),
		rollup(), zap(), list_failures(), list_failures_only(), 
		commit_trans(), set_reference(), compare(), status(), 
		delete_failure(), repeat(), rollback_trans(), compare_zap(), 
		compare_init(), edit_note(), print_note(), next_test(), 
		disp_version(), print_local_test(), compare_test(), 
		delete_local_init(),
		delete_local_test(), print_zap_delete(), edit_local_test(), 
		edit_test(), activate_platform(), deactivate_platform(), 
		set_vms(), print_run(), print_version(), print_ref_version(), 
		set_known_failures(),
		set_run(), set_ref_version(), set_version(),
		modify_test_version(), modify_init_version(), 
		modify_local_test_version(), print_meta_series(),
		print_series(), set_config(), compare_failures(),
		list_ref_failures(), full_diff(),
#ifdef DBS_SPECIAL
		resolve_failures(),
#endif
		mark_known_failure(),
		toggle_global_mode(),
		toggle_local_mode(),
		show_test(),
		interprete_command(),
		list_runs(),
		zap_local(),
		zap_global();

static		list_categories(), add_category(), delete_category(), 
		modify_test_category(), print_category();

static char *right_trim ();
#define RIGHT_TRIM(x) right_trim ((x), sizeof (x))

static void	CLIB_ROUTINE signal_quit();

static struct cmd {
    TEXT	*cmd_string;
    int		(*cmd_routine)();
    TEXT	*cmd_text;
    SSHORT	cmd_args;
} commands [] = {
    "HELP", list_commands, "Display Command list", 0,
    "AC", add_category, "Add category to platform", 1,
    "AP", activate_platform, "Activate platform", 0,
    "CI", compare_init, "Compare local/reference initialization", 0,
    "CLT", compare_test, "Compare local test", 0,
    "C", commit_trans, "Commit transaction(s)", 0,
    "CF", compare_failures, "Compare failure with reference failure", 0,
    "COMP", compare, "Compare failure to reference", 0,
    "CZD", compare_zap, "Compare, zap and delete failure", 0,
#ifdef DBS_SPECIAL
    "DBS", resolve_failures, "Special DBS command for resolving failures", 0,
#endif
    "DC", delete_category, "Delete category from platform", 0,
    "DF", delete_failure, "Delete failure record", 0,
    "DLI", delete_local_init, "Delete local init record", 0,
    "DLT", delete_local_test, "Delete local test", 0,
    "DP", deactivate_platform, "Deactivate platform", 0,
    "FD", full_diff, "Print diff'd differences for test/platform", 0,
    "GLOBAL", toggle_global_mode, "Prepare for global init records (default)", 0, 
    "LC", list_categories, "List active categories for platform", 0,
    "LF", list_failures, "List failures for platform", 0,
    "LFO", list_failures_only, "List failures for platform without dates", 0,
    "LFP", list_platforms, "List failing platforms for test", 0,
    "LOCAL", toggle_local_mode, "Prepare for local init records", 0, 
    "LRF", list_ref_failures, "List failures for reference platform", 0,
    "E", edit_test, "Edit test (please be careful)", 0,
    "EL", edit_local_test, "Edit local test definition", 0,
    "EN", edit_note, "Edit note", 0,
    "MIV", modify_init_version, "Modify initialization version", 2,
    "MKF", mark_known_failure, "Mark failure record as a known failure", 0,
    "MLTV", modify_test_version, "Modify local test version", 2,
    "MTC", modify_test_category, "Modify test category", 1,
    "MTV", modify_test_version, "Modify global test Version", 2,
    "N", next_test, "Set up next test", 0,
    "NEXT", next_test, "Set up next test", 0,
    "PC", print_category, "Print test category", 0,
    "PD", print_differences, "Print differences for test/platform", 0,
    "PF", print_failure, "Print failure for test/platform", 0,
    "PLT", print_local_test, "Print local test definition", 0,
    "PMS", print_meta_series, "Print series in meta series", 1,
    "PN", print_note, "Print note", 0,
    "PR", print_result, "Print initialization for test/platform", 0,
    "PRN", print_run, "Print Run name", 0,
    "PRV", print_ref_version, "Print Reference Version", 0,
    "PS", print_series, "Print tests in series", 1,
    "PT", print_test, "Print test definition", 0,
    "PVR", print_version, "Print Version", 0,
    "PZD", print_zap_delete, "Print, zap and delete failure", 0,
    "QUIT", NULL, "Exit tan", 0,
    "REPEAT", repeat, "Repeat a command", 1,
    "ROLLBACK", rollback_trans, "Rollback transaction(s)", 0,
    "ROLLUP", rollup, "Extract failures from all local TCS dbs", 0,
    "RUNS", list_runs, "RUNS [plat] [patt] : Report on failures in runs matching patt for platform", 0,
    "SKF", set_known_failures, "Set name of collection of known failures", 1,
    "SP", set_platform, "Set Platform name", 1,
    "SR", set_reference, "Set Reference platform", 1,
    "SRN", set_run, "Set Run name", 1,
    "SRV", set_ref_version, "Set Reference Version", 1,
    "SHOW", show_test, "Show test information", 0,
    "ST", set_test, "Set Test name", 1,
    "SVR", set_version, "Set Version", 1,
    "STAT", status, "Print current state", 0,
    "SVMS", set_vms, "Set VMS indicator", 0,
    "VER", disp_version, "Show version for platform or all platforms", 0,
    "ZAP", zap, "Reset initialization from most recent failure", 0,
     "?", list_commands, "Display Command list", 0,
    NULL, NULL, NULL, 0};

static CONST TEXT  *short_month_names[]  = { 
	    "Jan", "Feb", "Mar", 
	    "Apr", "May", "Jun", 
	    "Jul", "Aug", "Sep", 
	    "Oct", "Nov", "Dec"
	    };

typedef struct dbb {
    struct dbb	*dbb_next;
    int		*dbb_handle;
    int		*dbb_transaction;
    int		*dbb_diffs;
    int		*dbb_failure;
    int		*dbb_lf;
    int		*dbb_lfr;
    int		*dbb_lfo;
    int		*dbb_lp;
    int		*dbb_pf;
    int		*dbb_pr;
    int		*dbb_rollup;
    int		*dbb_st1;
    int		*dbb_st2;
    int		*dbb_st3;
    int		*dbb_st4;
    int		*dbb_st5;
    int		*dbb_zap1;
    int		*dbb_zap2;
    int		*dbb_zap3;
    int		*dbb_gzap1;
    int		*dbb_gzap2;
    int		*dbb_gzap3;
#ifdef DBS_SPECIAL
    int		*dbb_resolve_failure;
#endif
    int		*dbb_compare1a;
    int		*dbb_compare1b;
    int		*dbb_compare1c;
    int		*dbb_compare1d;
    int		*dbb_compare2a;
    int		*dbb_compare2b;
    int		*dbb_compare2c;
    int		*dbb_compare2d;
    int		*dbb_compare2e;
    int		*dbb_df;
    int		*dbb_plt;
    int		*dbb_dli;
    int		*dbb_dlt;
    int		*dbb_elt;
    int		*dbb_elt2;
    int		*dbb_clt;
    int		*dbb_lc;
    int		*dbb_ac;
    int		*dbb_dc;
    int		*dbb_pms;
    int		*dbb_ps;
    int		*dbb_miv;
    int		*dbb_mltv;
    int		*dbb_mkf;
    int		*dbb_mkf2;
    int		*dbb_mkf3;
    TEXT	dbb_system [12];
    TEXT	dbb_platform [12];
    TEXT	dbb_pathname [64];
} *DBB;

typedef struct test {
    struct test	*test_next;
    DBB		test_dbb;
    BASED_ON	LTCS.FAILURES.TEST_NAME	test_name;
} *TEST;

static DBB	get_database();
static UCHAR	*alloc();
static		*openblob();
static TEXT	*prompt();

static BASED_ON LTCS.FAILURES.RUN run_name;
static BASED_ON LTCS.FAILURES.RUN known_failures_run_name;
static BASED_ON LTCS.TESTS.VERSION version;
static BASED_ON LTCS.TESTS.VERSION ref_version;
static BASED_ON LTCS.TESTS.VERSION version_buffer;
static int	global_mode = TRUE;

static DBB	databases = NULL, current_platform = NULL, 
		global_tcs = NULL, reference_platform = NULL;
static int	*rollup_trans;
static TEXT	current_test [32], *db_name, *gdb_name;
static TEST	test_list, free_tests;
static USHORT	sw_roundup, sw_quit;
static USHORT	sw_vms = 0;
static FILE	*output;

main (argc, argv)
    int		argc;
    SCHAR	**argv;
{
/**************************************
 *
 *	m a i n
 *
 **************************************
 *
 * Functional description
 *	Open rollup database, and eat commands.
 *
 **************************************/
SCHAR	**end, *pathname;
int	n, error_flag;
DBB	dbb;

if (argc > 1)
    db_name = argv [1];
else
#if (defined apollo || defined WIN_NT || defined OS2_ONLY)
    db_name = "./tests/rollup.gdb";
#else
    db_name = "./tests/rollup.gdb";
#endif

strcpy (version, DEFAULT_VERSION);
strcpy (ref_version, DEFAULT_VERSION);
strcpy (run_name, DEFAULT_RUN_NAME);
strcpy (known_failures_run_name, "");

READY GDS_VAL (db_name) DB;
START_TRANSACTION rollup_trans RESERVING DB.FAILURES FOR SHARED WRITE;

set_config (TAN_CONFIG);

reset_signal();

while (interact())
    ;

COMMIT rollup_trans;
FINISH DB;

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    {
    LTCS = dbb->dbb_handle;
    COMMIT dbb->dbb_transaction;
    FINISH LTCS;
    }

if (global_tcs)
    {
    LTCS = global_tcs->dbb_handle;
    COMMIT global_tcs->dbb_transaction;
    FINISH LTCS;
    }
}

static activate_platform (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	a c t i v a t e _ p l a t f o r m
 *
 **************************************
 *
 * Functional description
 *	Activate platform.
 *
 **************************************/

return set_platform_activity (args, arg1, TRUE);
}

static add_category (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	a d d _ c a t e g o r y
 *
 **************************************
 *
 * Functional description
 *	Add category for local database.
 *
 **************************************/
TEXT	*category;
DBB	dbb;
SSHORT	count;

/* Lookup database/test */

category = (args == 2) ? arg2 : arg1;

if (!(dbb = get_database (args - 1, arg1)))
    return TRUE;

LTCS = dbb->dbb_handle;

STORE (REQUEST_HANDLE dbb->dbb_ac, TRANSACTION_HANDLE dbb->dbb_transaction)
    X IN LTCS.CATEGORIES
    strcpy (X.CATEGORY, category);
END_STORE
    ON_ERROR
	local_failure (dbb->dbb_pathname, gds__status);
	return;
    END_ERROR;


return TRUE;
}

static add_test (test_name, dbb)
    TEXT	*test_name;
    DBB		dbb;
{
/**************************************
 *
 *	a d d _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Add test to test list.
 *
 **************************************/
TEST	test, *ptr;

for (ptr = &test_list; *ptr; ptr = &(*ptr)->test_next)
    ;

if (test = free_tests)
    {
    free_tests = test->test_next;
    test->test_next = NULL;
    *ptr = test;
    }
else
    test = *ptr = (TEST) alloc (sizeof (struct test));

copy (test_name, test->test_name);
test->test_dbb = dbb;
}

static UCHAR *alloc (size)
    USHORT	size;
{
/**************************************
 *
 *	a l l o c
 *
 **************************************
 *
 * Functional description
 *	Allocate block.
 *
 **************************************/
UCHAR	*blk, *p;

blk = p = gds__alloc ((SLONG) size);
do *p++ = 0; while (--size);

return blk;
}

static clear_tests ()
{
/**************************************
 *
 *	c l e a r _ t e s t s
 *
 **************************************
 *
 * Functional description
 *	Release all tests.
 *
 **************************************/
TEST	test;

while (test = test_list)
    {
    test_list = test->test_next;
    test->test_next = free_tests;
    free_tests = test;
    }
}

static commit_db (dbb)
    DBB		dbb;
{
/**************************************
 *
 *	c o m m i t _ d b b
 *
 **************************************
 *
 * Functional description
 *	Commit a database specific transaction and start a new one.
 *
 **************************************/
int	*old_ltcs;

old_ltcs = LTCS;
LTCS = dbb->dbb_handle;
COMMIT dbb->dbb_transaction;
START_TRANSACTION dbb->dbb_transaction RESERVING LTCS.TESTS FOR SHARED READ;
LTCS = old_ltcs;
}

static commit_trans (args, arg)
    USHORT	args;
    TEXT	*arg;
{
/**************************************
 *
 *	c o m m i t _ t r a n s
 *
 **************************************
 *
 * Functional description
 *	Commit either a single platform LTCS or all databases.
 *
 **************************************/
DBB	dbb;

if (args)
    {
    if (!(dbb = get_database (args, arg)))
	return TRUE;
    commit_db (dbb);
    return;
    }

if (global_tcs && global_tcs->dbb_transaction)
    commit_db (global_tcs);

COMMIT rollup_trans;
START_TRANSACTION rollup_trans RESERVING DB.FAILURES FOR SHARED WRITE;

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    commit_db (dbb);
}

static compare (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	c o m p a r e
 *
 **************************************
 *
 * Functional description
 *	Compare a failure against a reference initialization.
 *
 **************************************/
TEXT		*test;
DBB		dbb;
GDS__QUAD	*ref_blob_id, *cmp_blob_id;

ref_blob_id = cmp_blob_id = NULL;

/* Start by getting the reference database */

if (!reference_platform)
    {
    printf ("No references database specified.  Use SR command\n");
    return FALSE;
    }

/* Now get the test blob id */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return FALSE;

/* Get target failure */

FOR (REQUEST_HANDLE dbb->dbb_compare1a, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.FAILURES WITH X.TEST_NAME EQ test AND 
	X.RUN = run_name SORTED BY DESC X.DATE
	cmp_blob_id = &X.OUTPUT;
END_FOR;

if (!cmp_blob_id)
    {
    printf ("Can't find failure for test %s on %s / %s\n", 
	test, dbb->dbb_system, dbb->dbb_platform);
    return FALSE;
    }

LTCS = reference_platform->dbb_handle;

FOR (REQUEST_HANDLE reference_platform->dbb_compare2a, 
     TRANSACTION_HANDLE reference_platform->dbb_transaction)
    FIRST 1 X IN LTCS.INIT WITH X.TEST_NAME EQ test AND 
	X.VERSION <= ref_version SORTED BY DESCENDING X.VERSION
	ref_blob_id = &X.OUTPUT;
END_FOR;

if (!ref_blob_id)
    {
    printf ("Can't find references initialization for test %s on %s / %s\n", 
	test, reference_platform->dbb_system, reference_platform->dbb_platform);
    return FALSE;
    }

fprintf(output, "Comparison of test %s, version %s on %s with version %s on %s\n",
  test, version, dbb->dbb_system, ref_version, reference_platform->dbb_system);
return compare_blobs (dbb, cmp_blob_id, reference_platform, ref_blob_id);
}

static compare_blobs (cmp_dbb, cmp_blob_id, ref_dbb, ref_blob_id)
    DBB		cmp_dbb, ref_dbb;
    GDS__QUAD	*ref_blob_id, *cmp_blob_id;
{
/**************************************
 *
 *	c o m p a r e _ b l o b s
 *
 **************************************
 *
 * Functional description
 *	Compare two blobs, print result if different, and return result.
 *
 **************************************/
int	*ref_blob, *cmp_blob, c;
USHORT	ref_length, cmp_length, result;
TEXT	ref_buffer [1024], cmp_buffer [1024], *p, *q, *test;
FILE	*file;
STATUS	status_vector1 [20], status_vector2 [20];
struct	stat	stdbuf;

/* Open both blobs */

if (!(ref_blob = openblob (ref_dbb, ref_blob_id)) ||
    !(cmp_blob = openblob (cmp_dbb, cmp_blob_id)))
    return FALSE;

/* Compare blobs bytewise */

result = FALSE;

for (;;)
    {
    gds__get_segment (status_vector1,
	    GDS_REF (ref_blob),
	    GDS_REF (ref_length),
	    sizeof (ref_buffer),
	    ref_buffer);
    gds__get_segment (status_vector2,
	    GDS_REF (cmp_blob),
	    GDS_REF (cmp_length),
	    sizeof (cmp_buffer),
	    cmp_buffer);
    if (status_vector1 [1] != status_vector2 [1])
	break;
    if (status_vector1 [1] == gds__segstr_eof)
	{
	result = TRUE;
	break;
	}
    if (ref_length != cmp_length)
	break;
    for (p = ref_buffer, q = cmp_buffer; ref_length && *p++ == *q++; --ref_length)
	;
    if (ref_length)
	break;
    }

gds__close_blob (status_vector1, GDS_REF (ref_blob));
gds__close_blob (status_vector1, GDS_REF (cmp_blob));

if (result)
    {
    fprintf (output, "*** Test %s is identical ***\n", current_test);
    return TRUE;
    }

dump_blob (ref_dbb, ref_blob_id, "foo.1");
dump_blob (cmp_dbb, cmp_blob_id, "foo.2");

system ("diff foo.1 foo.2 > foo.3");
unlink ("foo.1");
unlink ("foo.2");
stat("foo.3", &stdbuf);
if (stdbuf.st_size != 0)
    {
    fprintf (output, "-------------------\n");

    if (!(file = fopen ("foo.3", "r")))
        {
        perror ("foo.3");
        return FALSE;
        }    

    while (!sw_quit && (c = fgetc (file)) != EOF)
       putc (c, output);

    if (fclose (file) < 0)
        printf ("fclose failed.  Who cares?\n");

    unlink ("foo.3");

    fprintf (output, "-------------------\n");
    }
else
    {
    fprintf (output, "*** Test %s is identical ***\n", current_test);
    return TRUE;
    }

return FALSE;
}

static compare_failures (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	c o m p a r e _ f a i l u r e s
 *
 **************************************
 *
 * Functional description
 *	Compare a failure against a reference initialization.
 *
 **************************************/
TEXT		*test;
DBB		dbb;
GDS__QUAD	*ref_blob_id, *cmp_blob_id;

ref_blob_id = cmp_blob_id = NULL;

/* Start by getting the reference database */

if (!reference_platform)
    {
    printf ("No references database specified.  Use SR command\n");
    return FALSE;
    }

/* Now get the test blob id */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return FALSE;

/* Get target failure */

FOR (REQUEST_HANDLE dbb->dbb_compare1b, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.FAILURES WITH X.TEST_NAME EQ test AND X.RUN = run_name SORTED BY DESC X.DATE
	cmp_blob_id = &X.OUTPUT;
END_FOR;

if (!cmp_blob_id)
    {
    printf ("Can't find failure %s on %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);
    return FALSE;
    }

LTCS = reference_platform->dbb_handle;

FOR (REQUEST_HANDLE reference_platform->dbb_compare2b, 
     TRANSACTION_HANDLE reference_platform->dbb_transaction)
    FIRST 1 X IN LTCS.FAILURES WITH X.TEST_NAME EQ test AND X.RUN EQ run_name
      SORTED BY DESCENDING X.VERSION
	ref_blob_id = &X.OUTPUT;
END_FOR;

if (!ref_blob_id)
    {
    printf ("Can't find reference failure for test %s on %s / %s\n", 
	test, reference_platform->dbb_system, reference_platform->dbb_platform);
    return FALSE;
    }

return compare_blobs (dbb, cmp_blob_id, reference_platform, ref_blob_id);
}

static compare_init (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	c o m p a r e _ i n i t
 *
 **************************************
 *
 * Functional description
 *	Compare an initialization against a reference initialization.
 *
 **************************************/
TEXT		*test;
DBB		dbb;
GDS__QUAD	*ref_blob_id, *cmp_blob_id;

ref_blob_id = cmp_blob_id = NULL;

/* Start by getting the reference database */

if (!reference_platform)
    {
    printf ("No references database specified.  Use SR command\n");
    return FALSE;
    }

/* Now get the test blob id */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return FALSE;

/* Get target failure */

FOR (REQUEST_HANDLE dbb->dbb_compare1c, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.INIT WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
	cmp_blob_id = &X.OUTPUT;
END_FOR;

if (!cmp_blob_id)
    {
    printf ("Can't find init %s on %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);
    return FALSE;
    }

LTCS = reference_platform->dbb_handle;

FOR (REQUEST_HANDLE reference_platform->dbb_compare2c, 
     TRANSACTION_HANDLE reference_platform->dbb_transaction)
    FIRST 1 X IN LTCS.INIT WITH X.TEST_NAME EQ test AND X.VERSION <= ref_version
      SORTED BY DESCENDING X.VERSION
	ref_blob_id = &X.OUTPUT;
END_FOR;

if (!ref_blob_id)
    {
    printf ("Can't find reference initialization for test %s on %s / %s\n", 
	test, reference_platform->dbb_system, reference_platform->dbb_platform);
    return FALSE;
    }

return compare_blobs (dbb, cmp_blob_id, reference_platform, ref_blob_id);
}

static compare_test (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	c o m p a r e _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Compare a failure against a reference initialization.
 *
 **************************************/
TEXT		*test;
DBB		dbb;
GDS__QUAD	*ref_blob_id, *cmp_blob_id;

ref_blob_id = cmp_blob_id = NULL;

/* Start by getting the reference database */

if (!current_platform)
    {
    printf ("No platform specified.  Use SP command\n");
    return FALSE;
    }

/* Now get the test blob id */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return FALSE;

/* Get target test */

FOR (REQUEST_HANDLE dbb->dbb_clt, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.TESTS WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
	cmp_blob_id = &X.SCRIPT;
END_FOR;

if (!cmp_blob_id)
    {
    printf ("Can't find test %s on %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);
    return FALSE;
    }

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction) FIRST 1 X IN GTCS.TESTS
     WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
	ref_blob_id = &X.SCRIPT;
END_FOR;

if (!ref_blob_id)
    {
    printf ("Can't find global test %s\n", test);
    return FALSE;
    }

return compare_blobs (dbb, cmp_blob_id, global_tcs, ref_blob_id);
}

static compare_zap (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	c o m p a r e _ z a p
 *
 **************************************
 *
 * Functional description
 *	Compare, and optionally zap.
 *
 **************************************/
DBB	dbb;
TEXT	*test;

if (!reference_platform)
    {
    printf ("No reference platform\n");
    return;
    }

if (!compare (args, arg1, arg2) &&
    !yesno ("Zap and delete? "))
    return;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return FALSE;

if (sw_quit)
    return FALSE;

zap (args, arg1, arg2);
delete_failure (args, arg1, arg2);
}

static copy (from, to)
    TEXT	*from, *to;
{
/**************************************
 *
 *	c o p y
 *
 **************************************
 *
 * Functional description
 *	Copy a blank or null terminated string.
 *
 **************************************/

while (*from && *from != ' ')
   *to++ = *from++;

*to = 0;
}

static deactivate_platform (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	d e a c t i v a t e _ p l a t f o r m
 *
 **************************************
 *
 * Functional description
 *	Deactivate platform.
 *
 **************************************/

return set_platform_activity (args, arg1, FALSE);
}

static delete_category (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	d e l e t e _ c a t e g o r y
 *
 **************************************
 *
 * Functional description
 *	Delete category from local database.
 *
 **************************************/
TEXT	*category;
DBB	dbb;
SSHORT	count;

/* Lookup database/test */

category = (args == 2) ? arg2 : arg1;

if (!(dbb = get_database (args - 1, arg1)))
    return TRUE;

LTCS = dbb->dbb_handle;

FOR (REQUEST_HANDLE dbb->dbb_dc, TRANSACTION_HANDLE dbb->dbb_transaction)
    X IN LTCS.CATEGORIES WITH X.CATEGORY EQ category
    ERASE X;
END_FOR
    ON_ERROR
	local_failure (dbb->dbb_pathname, gds__status);
	return;
    END_ERROR;

return TRUE;
}

static delete_failure (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	d e l e t e _ f a i l u r e
 *
 **************************************
 *
 * Functional description
 *	Delete failure.
 *
 **************************************/
DBB	dbb;
TEXT	*test;
SSHORT	count;

/* Lookup database/test */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

LTCS = dbb->dbb_handle;
count = 0;

FOR (REQUEST_HANDLE dbb->dbb_df, TRANSACTION_HANDLE dbb->dbb_transaction)
  X IN LTCS.FAILURES WITH X.TEST_NAME EQ test AND X.RUN = run_name
    ERASE X;
    ++count;
END_FOR;

if (!count)
    printf ("No failure for test %s on %s/%s\n", test, dbb->dbb_system, dbb->dbb_platform);

return TRUE;
}

static delete_local_init (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	d e l e t e _ l o c a l _ i n i t
 *
 **************************************
 *
 * Functional description
 *	Get rid of a local test initialization result.
 *	(cloned from delete_local_test())
 *
 **************************************/
TEXT	*test;
DBB	dbb;
USHORT	count;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return;

count = 0;

FOR (REQUEST_HANDLE dbb->dbb_dli, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.INIT
     WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
    ++count;
    ERASE X
      ON_ERROR
	local_failure (dbb->dbb_pathname, gds__status);
	return;
      END_ERROR;
END_FOR
  ON_ERROR
    local_failure (dbb->dbb_pathname, gds__status);
    return;
  END_ERROR;

if (!count)
    printf ("Test %s doesn't seem to have local init\n", test);
}

static delete_local_test (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	d e l e t e _ l o c a l _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Get rid of a local test definition.
 *
 **************************************/
TEXT	*test;
DBB	dbb;
USHORT	count;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return;

count = 0;

FOR (REQUEST_HANDLE dbb->dbb_dlt, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.TESTS
     WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
    ++count;
    ERASE X;
END_FOR;

if (!count)
    printf ("Test %s doesn't seem to exist\n", test);
}


static disp_version (args, platform)
    USHORT	args;
{
/**************************************
 *
 *	d i s p _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Print version information.
 *
 **************************************/
DBB	dbb;

if (args)
    {
    if (!(dbb = get_database (args, platform)))
	return;
    printf ("%s - %s/%s\n", dbb->dbb_pathname, dbb->dbb_platform, dbb->dbb_system);
    gds__version (&dbb->dbb_handle, NULL, NULL);
    return;
    }

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    disp_version (1, dbb->dbb_system);
}

static dump_blob (dbb, blob_id, file_name)
    DBB		dbb;
    SLONG	*blob_id;
    TEXT	*file_name;
{
/**************************************
 *
 *	d u m p _ b l o b
 *
 **************************************
 *
 * Functional description
 *	Dump a blob to a file.
 *
 **************************************/
TEXT	buffer [1028], *s, *e, c;
SSHORT	length;
int	*blob;
STATUS	status_vector [20];
FILE	*file;
SSHORT	skip;

if (!(blob = openblob (dbb, blob_id)))
    return FALSE;

if (!(file = fopen (file_name, "w")))
    {
    gds__close_blob (status_vector, GDS_REF (blob));
    return FALSE;
    }

skip = 0;
while (!gds__get_segment (status_vector,
	GDS_REF (blob),
	GDS_REF (length),
	sizeof (buffer),
	buffer))
    {
    buffer [length] = 0;
    if (!sw_vms)
        if ((buffer[0] == 'c') && (buffer[1] == 'c') && (buffer[2] == ' '))
	    continue;
	else
	    fputs (buffer, file);
    else
	{
        if (skip)
            {
            if (buffer[0] == '$')
                skip = 0;
            }
        else
            {
            s = buffer;
            if (*s++ == '$')
                {
                while ((*s == ' ') || (*s == '\t'))
                    s++;
                e = s;
                while ((*e != ' ') && (*s != '\t') && *e)
                    e++;
                c = *e;
                *e = 0;
                if (!strcmp (s, "create"))
                    skip = 1;
                else if (!strcmp (s, "link"))
                    skip = 1;
                else if (!strcmp (s, "gdef"))
                    skip = 1;
                *e = c;
                if (skip)
                    {
                    fputs (buffer, file);
                    }
                }
            }
        if (!skip)
            {
            s = buffer;
            if ((buffer[0] == 'Q') && (buffer[1] == 'L') &&
                (buffer[2] == 'I') && (buffer[3] == '>') && (buffer[4] == ' '))
                s += 5;
            if ((buffer[0] == 'C') && (buffer[1] == 'O') &&
                (buffer[2] == 'N') && (buffer[3] == '>') && (buffer[4] == ' '))
                s += 5;
            fputs (s, file);
            }
        }
    }

gds__close_blob (status_vector, GDS_REF (blob));

putc ('\n', file);
fclose (file);

return TRUE;    
}

static edit_local_test (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	e d i t _ l o c a l _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Edit a local test
 *
 **************************************/
TEXT	*test;
DBB	dbb;
USHORT	count;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

count = 0;

FOR (REQUEST_HANDLE dbb->dbb_elt, TRANSACTION_HANDLE dbb->dbb_transaction)
  FIRST 1 X IN LTCS.TESTS WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
    ++count;
    MODIFY X
    if (!BLOB_edit (&X.SCRIPT, dbb->dbb_handle, dbb->dbb_transaction, test))
	return;
    END_MODIFY
        ON_ERROR
        local_failure (dbb->dbb_pathname, gds__status);
        return;
	END_ERROR;
END_FOR;

if (!count)
    {
    printf ("Test %s doesn't seem to exist\n", test);
    if (!yesno ("Create it?  "))
	return;
    STORE (REQUEST_HANDLE dbb->dbb_elt2, TRANSACTION_HANDLE dbb->dbb_transaction)
      X IN LTCS.TESTS
	strcpy (X.TEST_NAME, test);
	strcpy (X.VERSION, version);
	if (!BLOB_edit (&X.SCRIPT, dbb->dbb_handle, dbb->dbb_transaction, test))
	    return;
    END_STORE
	ON_ERROR
	    local_failure (dbb->dbb_pathname, gds__status);
	END_ERROR;
    }

}


static edit_note (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	e d i t _ n o t e
 *
 **************************************
 *
 * Functional description
 *	Edit a note.
 *
 **************************************/
TEXT	*test;
USHORT	count;

get_gtcs();
test = (args) ? arg1 : current_test;

if (!test)
    {
    printf ("No current test\n");
    return;
    }

count = 0;

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction) NOTE IN GTCS.NOTES WITH NOTE.TEST_NAME EQ test
    MODIFY NOTE
    if (!BLOB_edit (&NOTE.NOTE, GTCS, global_tcs->dbb_transaction, "Note"))
	return;
    END_MODIFY
	ON_ERROR
	local_failure ("gtcs.gdb", gds__status);
	return;
	END_ERROR;
    count++;
END_FOR;

if (!count)
    STORE (TRANSACTION_HANDLE global_tcs->dbb_transaction) NT IN GTCS.NOTES 
	strcpy (NT.TEST_NAME, test);
	if (!BLOB_edit (&NT.NOTE, GTCS, global_tcs->dbb_transaction, "Note"))
	    return;
    END_STORE
	ON_ERROR
	    local_failure ("gtcs.gdb", gds__status);
	END_ERROR;

}

static edit_test (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	e d i t _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Edit a test.
 *
 **************************************/
TEXT	*test;
USHORT	count;

get_gtcs();
test = (args) ? arg1 : current_test;

if (!test)
    {
    printf ("No current test\n");
    return;
    }

count = 0;

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction) FIRST 1 T IN GTCS.TESTS
  WITH T.TEST_NAME EQ test AND T.VERSION <= version
      SORTED BY DESCENDING T.VERSION
    MODIFY T
    if (!BLOB_edit (&T.SCRIPT, GTCS, global_tcs->dbb_transaction, "Script"))
	return;
    END_MODIFY
	ON_ERROR
	local_failure ("gtcs.gdb", gds__status);
	return;
	END_ERROR;
    count++;
END_FOR;

if (!count)
    printf ("Test %s doesn't exist -- try TCS\n", test);
}

static full_diff (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	f u l l _ d i f f
 *
 **************************************
 *
 * Functional description
 *	Print differences between expected and actual results
 *	by comparing the actual init and failure blobs
 *	instead of the difference relation.
 *
 **************************************/
DBB		dbb, ref_dbb;
TEXT		*test;
GDS__QUAD	*ref_blob_id, *cmp_blob_id;

/* Lookup database/test */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

LTCS = dbb->dbb_handle;

cmp_blob_id = NULL;
FOR (REQUEST_HANDLE dbb->dbb_compare1d, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.FAILURES
       WITH X.TEST_NAME EQ test AND X.RUN = run_name SORTED BY DESC X.DATE
    cmp_blob_id = &X.OUTPUT;
END_FOR;

if (!cmp_blob_id)
    {
    printf ("No failure for test %s on %s / %s\n", 
	test, dbb->dbb_system, dbb->dbb_platform);
    return TRUE;
    }

if (global_mode)
    ref_dbb = global_tcs;
else
    ref_dbb = dbb;
LTCS = ref_dbb->dbb_handle;

ref_blob_id = NULL;
FOR (REQUEST_HANDLE ref_dbb->dbb_compare2d, TRANSACTION_HANDLE ref_dbb->dbb_transaction)
    FIRST 1 X IN LTCS.INIT WITH X.TEST_NAME EQ test AND
        X.VERSION <= version SORTED BY DESCENDING X.VERSION
    ref_blob_id = &X.OUTPUT;
END_FOR;

if (!ref_blob_id)
    {
    printf ("No initialization for test %s on %s / %s\n",
        test, ref_dbb->dbb_system, ref_dbb->dbb_platform);
    return TRUE;
    }

printf ("Differences for test %s, version %s on %s vs init from %s:\n", 
	test, version, dbb->dbb_system, ref_dbb->dbb_system);
return compare_blobs (dbb, cmp_blob_id, ref_dbb, ref_blob_id);
}

static DBB get_database (args, name)
    USHORT	args;
    TEXT	*name;
{
/**************************************
 *
 *	g e t _ d a t a b a s e
 *
 **************************************
 *
 * Functional description
 *	Find database block associated with name.  The name can be
 *	either system or platform name.
 *
 **************************************/
DBB	dbb;
TEXT	*pathname;

/* If there is no argument, there better be default database */

if (!args)
    {
    if (current_platform)
	LTCS = current_platform->dbb_handle;
     else
	printf ("No current platform\n");
    return current_platform;
    }

/* If we already know about it, fine */

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    if (!strcmp (name, dbb->dbb_system) ||
	!strcmp (name, dbb->dbb_platform))
	{
	LTCS = dbb->dbb_handle;
	return dbb;
	}

/* Look it up */

FOR (TRANSACTION_HANDLE rollup_trans) PLATFORM IN DB.PLATFORMS WITH 
	PLATFORM.SYSTEM EQ name OR 
	PLATFORM.PLATFORM EQ name
    pathname = PLATFORM.PATHNAME;
    LTCS = NULL;
    printf ("    attaching %s...\n", pathname);
    READY GDS_VAL (pathname) LTCS
	ON_ERROR
	    local_failure (pathname, "gds__attach_database");
	    return NULL;
	END_ERROR;
    dbb = (DBB) alloc (sizeof (struct dbb));
    dbb->dbb_next = databases;
    databases = dbb;
    dbb->dbb_handle = LTCS;
    copy (PLATFORM.SYSTEM, dbb->dbb_system);
    copy (PLATFORM.PLATFORM, dbb->dbb_platform);
    copy (PLATFORM.PATHNAME, dbb->dbb_pathname);
    START_TRANSACTION dbb->dbb_transaction RESERVING LTCS.FAILURES FOR SHARED READ;
END_FOR;

if (!dbb)
    printf ("Couldn't find database %s\n", name);

return dbb;
}

static get_gtcs ()
{
/**************************************
 *
 *	g e t _ g t c s
 *
 **************************************
 *
 * Functional description
 *	Attach to global tcs database.
 *
 **************************************/

if (global_tcs)
    return;

#ifdef apollo
gdb_name = "./tests/gtcs.gdb";
#else
#if (defined WIN_NT || defined OS2_ONLY)
gdb_name = "./tests/gtcs.gdb";
#else
gdb_name = "./tests/gtcs.gdb";
#endif
#endif

global_tcs = (DBB) alloc (sizeof (struct dbb));

READY GDS_VAL (gdb_name) GTCS;
global_tcs->dbb_handle = GTCS;
strcpy (global_tcs->dbb_pathname, gdb_name);
strcpy (global_tcs->dbb_system, "GLOBAL");
strcpy (global_tcs->dbb_platform, "GLOBAL");

START_TRANSACTION global_tcs->dbb_transaction RESERVING GTCS.TESTS FOR SHARED WRITE;
}

static get_test (args, arg1, arg2, dbb_ret, test_ret)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
    DBB		*dbb_ret;
    TEXT	**test_ret;
{
/**************************************
 *
 *	g e t _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Resolve database and test name from defaults.
 *
 **************************************/
DBB	dbb;
TEXT	*test;

if (!args)
    {
    if (!(*dbb_ret = current_platform))
	{
	printf ("No platform given\n");
	return FALSE;
	}
    if (!current_test [0])
	{
	printf ("No test name given\n");
	return FALSE;
	}
    LTCS = current_platform->dbb_handle;
    *test_ret = current_test;
    return TRUE;
    }

if (args == 2)
    {
    if (!(*dbb_ret = get_database (1, arg1)))
	return FALSE;
    *test_ret = arg2;
    return TRUE;
    }

if (*dbb_ret = current_platform)
    {
    *test_ret = arg1;
    LTCS = current_platform->dbb_handle;
    return TRUE;
    }

if (!current_test [0] ||
    !(*dbb_ret = get_database (1, arg1)))
    return FALSE;

*test_ret = current_test;

return TRUE;
}

static toggle_local_mode (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	t o g g l e _ l o c a l _ m o d e
 *
 **************************************
 *
 * Functional description
 *	Go into local init record mode
 *
 **************************************/

global_mode = FALSE;
printf ("Now in Local Init mode\n");

}

static toggle_global_mode (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	t o g g l e _ g l o b a l _ m o d e
 *
 **************************************
 *
 * Functional description
 *	Go into global init record mode
 *
 **************************************/

global_mode = TRUE;
get_gtcs();
printf ("Now in Global Init mode\n");

}

static interact ()
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
TEXT		buffer[128], *p, *q, **string, *strings [10], temp [145];
SSHORT		n, c;

printf ("tan> ");

if (!gets (buffer))
    return FALSE;

reset_signal();

return interprete_command (buffer);
}

static interprete_command (buffer)
char	*buffer;
{
/**************************************
 *
 *	i n t e r p r e t e _ c o m m a n d
 *
 **************************************
 *
 * Functional description
 *	Read a command, parse it, execute it, and return.  If end of
 *	file, return FALSE.
 *
 **************************************/
struct cmd	*cmd;
TEXT		*p, *q, **string, *strings [10], temp [145];
SSHORT		n, c;

output = stdout;

/* Parse into command and test/series name */

string = strings;
p = buffer; 
q = temp;

for (;;)
    {
    while (*p == ' ' || *p == '\t')
	p++;
    if (!*p)
	break;
    *string++ = q;
    if (*p == '>')
	*q++ = *p++;
    else
	while (*p && *p != ' ' && *p != '\t' && *p != '>')
	    *q++ = *p++;
    *q++ = 0;
    }

*string = NULL;

/* Look thru arguments looking for re-direction of output */

for (string = strings; *string; string++)
    if (strcmp (*string, ">"))
	upcase (*string);
    else
	{
	if (!(output = fopen (string [1], "w")))
	    {
	    perror (string [1]);
	    return TRUE;
	    }
	break;
	}

n = string - strings;

if (n <= 0)
    return TRUE;

/* Interpret command */

for (cmd = commands; cmd->cmd_string; cmd++)
    if (strcmp (cmd->cmd_string, strings [0]) == 0)
	{
        if (!cmd->cmd_routine)
	    return FALSE;
        if (n <= cmd->cmd_args)
	    {
	    printf ("Missing arguments for command '%s', try HELP\n", strings [0]);
	    return TRUE;
	    }
	(*cmd->cmd_routine)(n - 1, strings [1], strings [2], strings [3]);
	if (output != stdout)
	    {
	    fclose (output);
	    output = stdout;
	    }
	return TRUE;
	}

printf ("Invalid command '%s', type HELP or ? for command list\n", strings [0]);

return TRUE;
}

static list_categories (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	l i s t _ c a t e g o r i e s
 *
 **************************************
 *
 * Functional description
 *	List test categories for platform.
 *
 **************************************/
DBB	dbb;
SSHORT	count;

/* Lookup database/test */

if (!(dbb = get_database (args, arg1)))
    return TRUE;

LTCS = dbb->dbb_handle;

FOR (REQUEST_HANDLE dbb->dbb_lc, TRANSACTION_HANDLE dbb->dbb_transaction)
  X IN LTCS.CATEGORIES
    fprintf (output, "    %s\n", X.CATEGORY);
END_FOR
    ON_ERROR
	local_failure (dbb->dbb_pathname, gds__status);
	return;
    END_ERROR;

return TRUE;
}

static list_commands ()
{
/**************************************
 *
 *	l i s t _ c o m m a n d s
 *
 **************************************
 *
 * Functional description
 *	Print a list of the commands.
 *
 **************************************/

struct cmd	*cmd;

printf ("Commands are:\n");

for (cmd = commands; cmd->cmd_string; cmd++)
    printf (" %s\t\t%s\n", cmd->cmd_string, cmd->cmd_text);

}

static list_failures (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	l i s t _ f a i l u r e s
 *
 **************************************
 *
 * Functional description
 *	List failures for platform.
 *
 **************************************/
DBB	dbb;
SSHORT	count;

/* Lookup database/test */

if (!(dbb = get_database (args, arg1)))
    return TRUE;

clear_tests();
LTCS = dbb->dbb_handle;
count = 0;

fprintf (output, "Failures for run %s, version %s on %s:\n", run_name, version, current_platform->dbb_system);
FOR (REQUEST_HANDLE dbb->dbb_lf, TRANSACTION_HANDLE dbb->dbb_transaction)
  X IN LTCS.FAILURES WITH X.RUN = run_name
  REDUCED TO X.TEST_NAME
  SORTED BY X.DATE
    if (sw_quit)
	return TRUE;
    fprintf (output, "    %s at %s\n", X.TEST_NAME, X.DATE.CHAR[19]);
    add_test (X.TEST_NAME, dbb);
    ++count;
END_FOR;

if (!count)
    fprintf (output, "No failures on %s/%s\n", dbb->dbb_system, dbb->dbb_platform);

return TRUE;
}

#ifdef DBS_SPECIAL
static resolve_failures (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	r e s o l v e _ f a i l u r e s
 *
 **************************************
 *
 * Functional description
 *	quickly go though a list of failures resolving them.
 *
 **************************************/
DBB	dbb;
SSHORT	count;
int	*resolve_transaction = NULL;

/* Lookup database/test */

if (!(dbb = get_database (args, arg1)))
    return TRUE;

LTCS = dbb->dbb_handle;
count = 0;

START_TRANSACTION resolve_transaction RESERVING LTCS.TESTS FOR SHARED READ;

fprintf (output, "Failures for run %s, version %s on %s:\n", run_name, version, current_platform->dbb_system);
FOR (REQUEST_HANDLE dbb->dbb_resolve_failure, TRANSACTION_HANDLE resolve_transaction)
  X IN LTCS.FAILURES WITH X.RUN = run_name 
    if (sw_quit)
	{
	ROLLBACK resolve_transaction;
	return TRUE;
	}
    fprintf (output, "    %s at %s\n", X.TEST_NAME, X.DATE.CHAR[19]);
    ++count;
    compare_zap (1, X.TEST_NAME, NULL);
END_FOR;

COMMIT resolve_transaction;

if (!count)
    fprintf (output, "No failures on %s/%s\n", dbb->dbb_system, dbb->dbb_platform);

return TRUE;
}
#endif

static list_failures_only (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	l i s t _ f a i l u r e s _ o n l y
 *
 **************************************
 *
 * Functional description
 *	List failures for platform.
 *
 **************************************/
DBB	dbb;
SSHORT	count;

/* Lookup database/test */

if (!(dbb = get_database (args, arg1)))
    return TRUE;

clear_tests();
LTCS = dbb->dbb_handle;
count = 0;

FOR (REQUEST_HANDLE dbb->dbb_lfo, TRANSACTION_HANDLE dbb->dbb_transaction)
    X IN LTCS.FAILURES WITH X.RUN = run_name 
    REDUCED TO X.TEST_NAME
    SORTED BY X.DATE
    if (sw_quit)
	return TRUE;
    fprintf (output, "  %s\n", X.TEST_NAME);
    add_test (X.TEST_NAME, dbb);
    ++count;
END_FOR;

if (!count)
    fprintf (output, "No failures on %s/%s\n", dbb->dbb_system, dbb->dbb_platform);

return TRUE;
}

static list_platforms (args, arg)
    TEXT	*arg;
{
/**************************************
 *
 *	l i s t _ p l a t f o r m s
 *
 **************************************
 *
 * Functional description
 *	Lists platforms that contain a particular failure.
 *
 **************************************/
TEXT	*test, date [21];
DBB	dbb;
USHORT	count;

test = (args) ? arg : current_test;
roundup();
clear_tests();

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    {
    LTCS = dbb->dbb_handle;
    count = 0;
    FOR (REQUEST_HANDLE dbb->dbb_lp, TRANSACTION_HANDLE dbb->dbb_transaction)
	X IN LTCS.FAILURES WITH X.TEST_NAME EQ test SORTED BY X.DATE
	strcpy (date, X.DATE.CHAR[20]);
	++count;
    END_FOR;
    if (count)
	{
	fprintf (output, "    Test %s failed on %s / %s at %s\n", 
		test, dbb->dbb_system, dbb->dbb_platform, date);
	add_test (test, dbb);
	}
    }
}

static list_ref_failures (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	l i s t _ r e f _ f a i l u r e s
 *
 **************************************
 *
 * Functional description
 *	List failures for platform.
 *
 **************************************/
DBB	dbb;
SSHORT	count;

/* Start by getting the reference database */

if (!reference_platform)
    {
    printf ("No references database specified.  Use SR command\n");
    return FALSE;
    }

/*
clear_tests();
*/
LTCS = reference_platform->dbb_handle;
count = 0;

fprintf (output, "Failures for run %s, version %s on %s:\n", run_name, version, reference_platform->dbb_system);
FOR (REQUEST_HANDLE reference_platform->dbb_lfr, 
       TRANSACTION_HANDLE reference_platform->dbb_transaction)
  X IN LTCS.FAILURES WITH X.RUN = run_name REDUCED TO X.TEST_NAME
    if (sw_quit)
	return TRUE;
    fprintf (output, "    %s at %s\n", X.TEST_NAME, X.DATE.CHAR[19]);
    add_test (X.TEST_NAME, dbb);
    ++count;
END_FOR;

if (!count)
    fprintf (output, "No failures on %s/%s\n", reference_platform->dbb_system, reference_platform->dbb_platform);

LTCS = dbb->dbb_handle;
return TRUE;
}

static list_runs (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	l i s t _ r u n s
 *
 **************************************
 *
 * Functional description
 *	List runs showing failures for platform.
 *
 **************************************/
DBB	dbb;
BASED ON LTCS.FAILURES.RUN	run_name;
BASED ON LTCS.FAILURES.DATE	max_date;
BASED ON LTCS.FAILURES.DATE	min_date;
ULONG				run_count;
ULONG				count;
struct tm			max_tm;
struct tm			min_tm;
UCHAR				*input_pattern;
USHORT				have_database_parm;

/* Lookup database/test */
/* WILL DO NOTHING UNTIL gpre IS FIXED

if (args == 0)
    input_pattern = "%";
else if (args == 1)
    input_pattern = arg1;
else
    input_pattern = arg2;

have_database_parm = (args > 1) ? 1 : 0;

if (!(dbb = get_database (have_database_parm, arg1)))
    return TRUE;

LTCS = dbb->dbb_handle;
count = 0;

fprintf (output, "Runs like %s showing failures: version %s on %s:\n", 
		input_pattern, version, current_platform->dbb_system);

*/

/* This kind of fetch is easier to do in SQL than in GDML - 
 * so we now have a mixed mode program.  Note that SQL doesn't
 * currently support notions of request handles, so there is
 * special cleanup work going on to remove the request handle.
 * We have to do that just in case this request gets used
 * once and then we change databases.
 */

/* gpre doesn't like the aggregate functions, 
 * so don't do it until gpre is fixed
 * FSG 14.Nov.2000


EXEC SQL DECLARE LR CURSOR FOR 
     SELECT RUN, COUNT(*), MAX(DATE), MIN(DATE)
     FROM LTCS.FAILURES
     WHERE RUN LIKE :input_pattern
     GROUP BY RUN
     ORDER BY 2 DESCENDING, 1;

EXEC SQL OPEN TRANSACTION dbb->dbb_transaction LR;

EXEC SQL FETCH LR INTO :run_name, :run_count, :max_date, :min_date;
while (!SQLCODE)
    {
    count++;
    gds__decode_date (&max_date, &max_tm);
    gds__decode_date (&min_date, &min_tm);
    fprintf (output, " %s\t%d\t", run_name, run_count);
    fprintf (output, "%02d-%s-%02d %2d:%02d", 
	     min_tm.tm_year, short_month_names[min_tm.tm_mon], min_tm.tm_mday,
	     min_tm.tm_hour, min_tm.tm_min);
    fprintf (output, "\t");
    fprintf (output, "%02d-%s-%02d %2d:%02d", 
	     max_tm.tm_year, short_month_names[max_tm.tm_mon], max_tm.tm_mday,
	     max_tm.tm_hour, max_tm.tm_min);
    fprintf (output, "\n");
    EXEC SQL FETCH LR INTO :run_name, :run_count, :max_date, :min_date;
    }

EXEC SQL CLOSE LR;
*/
/* Close does not drop the request handle, so we drop it here.
 * Note that this depends on this SQL cursor being the only
 * request outstanding for LTCS that doesn't have it's own
 * request handle stashed away in dbb
 */
/*RELEASE_REQUESTS FOR LTCS;

if (!count)
    fprintf (output, "No runs showing failures on %s/%s\n", 
		dbb->dbb_system, dbb->dbb_platform);
*/
return TRUE;
}

static local_failure (pathname, operation)
    TEXT	*pathname;
    TEXT	*operation;
{
/**************************************
 *
 *	l o c a l _ f a i l u r e
 *
 **************************************
 *
 * Functional description
 *	Report failure in access to local database.
 *
 **************************************/
SCHAR	s [160];
int	*vector;

printf ("Failure during %s on database %s\n", operation, pathname);
vector = gds__status;

while (gds__interprete (s, &vector))
    printf ("    %s\n", s);
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
    fprintf(stderr, "Invalid version %s",name,0,0);
    return NULL_PTR;
    }
q = version_buffer + 3 - (p - s);
p = s;
while (*p && *p >= '0' && *p <= '9')
    {
    if (q == end)
        {
        fprintf(stderr, "Invalid version %s",name,0,0);
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
    fprintf(stderr, "Invalid version %s",name,0,0);
    return NULL_PTR;
    }
q = q + 3 - (p - s);
p = s;
while (*p && *p >= '0' && *p <= '9')
    {
    if (q == end)
        {
        fprintf(stderr, "Invalid version %s",name,0,0);
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
    fprintf(stderr, "Invalid version %s",name,0,0);
    return NULL_PTR;
    }
q = q + 3 - (p - s);
p = s;
while (*p && *p >= '0' && *p <= '9')
    {
    if (q == end)
        {
        fprintf(stderr, "Invalid version %s",name,0,0);
        return NULL_PTR;
        }
    *q++ = *p++;
    }
/* End of numeric fields. There may still be an alpha character. */
while (*p && isalpha(*p) )
    {
    if (q == end)
        {
        fprintf(stderr, "Invalid version %s",name,0,0);
        return NULL_PTR;
        }
    *q++ = *p++;
    }
*q = 0;
return version_buffer;
}

static mark_known_failure (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	m a r k _ k n o w n _ f a i l u r e
 *
 **************************************
 *
 * Functional description
 *	Mark a failure record as "known".
 *
 **************************************/
DBB	dbb;
TEXT	*test;
SSHORT	count;

if (!NOT_NULL (known_failures_run_name))
    {
    printf ("Use SKF to set a known failures run name\n");
    return TRUE;
    }

/* Lookup database/test */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

LTCS = dbb->dbb_handle;
count = 0;

if (!global_mode)
    {
    FOR (REQUEST_HANDLE dbb->dbb_mkf, TRANSACTION_HANDLE dbb->dbb_transaction)
      X IN LTCS.FAILURES WITH X.TEST_NAME EQ test AND X.RUN = run_name
	++count;
	MODIFY X USING
	    strcpy (X.RUN, known_failures_run_name);
	END_MODIFY
	    ON_ERROR
		local_failure (dbb->dbb_system, "store known_failure");
		return FALSE;
	    END_ERROR;
    END_FOR;
    } 
else
    {
    get_gtcs();
    FOR (REQUEST_HANDLE dbb->dbb_mkf2, TRANSACTION_HANDLE dbb->dbb_transaction)
      X IN LTCS.FAILURES WITH X.TEST_NAME EQ test AND X.RUN = run_name
        ++count;
        BLOB_TEXT_DUMP (&X.OUTPUT, dbb->dbb_handle, dbb->dbb_transaction, "failure.loc");
	STORE (REQUEST_HANDLE global_tcs->dbb_mkf3, TRANSACTION_HANDLE global_tcs->dbb_transaction)
	    KF IN GTCS.FAILURES 
		strcpy (KF.TEST_NAME, X.TEST_NAME);
		strcpy (KF.VERSION, X.VERSION);
		strcpy (KF.RUN, known_failures_run_name);
    		BLOB_TEXT_LOAD (&KF.OUTPUT, global_tcs->dbb_handle, global_tcs->dbb_transaction, "failure.loc");
		KF.DATE = X.DATE;
		strcpy (KF.BOILER_PLATE_NAME, X.BOILER_PLATE_NAME);
		strcpy (KF.ENV_NAME, X.ENV_NAME);
	END_STORE
	    ON_ERROR
		local_failure (global_tcs->dbb_system, "store global.failure");
		return FALSE;
	    END_ERROR;
        unlink ("failure.loc");
    END_FOR;
    }

if (!count)
    printf ("No failure for test %s on %s/%s\n", test, dbb->dbb_system, dbb->dbb_platform);
else
    printf ("Failure for test %s on %s/%s marked as known failure under run %s\n",
	test, dbb->dbb_system, 
        (global_mode) ? global_tcs->dbb_platform : dbb->dbb_platform, 
	known_failures_run_name);

return TRUE;
}

static modify_init_version (args, string, vers1, vers2)
    USHORT	args;
    TEXT	*string, *vers1, *vers2;
{
/**************************************
 *
 *	m o d i f y _ i n i t _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Modify version of an init
 *
 **************************************/
USHORT	count;
TEXT *v1, *v2;

if ( !(v1 = make_version (vers1)))
    return;

if ( !(v2 = make_version (vers2)))
    return;

count = 0;

LTCS = current_platform->dbb_handle;
FOR (REQUEST_HANDLE current_platform->dbb_miv, TRANSACTION_HANDLE current_platform->dbb_transaction)
    I IN LTCS.INIT WITH I.TEST_NAME EQ string AND I.VERSION = v1
    MODIFY I
        gds__vtov (v2, I.VERSION, sizeof (I.VERSION));
    END_MODIFY;        
    count++;
END_FOR;

if (count) 
    return;

printf ("Init %s, version %s, isn't there.\n", string, v1);
}

static modify_local_test_version (args, string, vers1, vers2)
    USHORT	args;
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

if ( !(v1 = make_version (vers1)))
    return;

if ( !(v2 = make_version (vers2)))
    return;

count = 0;

LTCS = current_platform->dbb_handle;
FOR (REQUEST_HANDLE current_platform->dbb_mltv, TRANSACTION_HANDLE current_platform->dbb_transaction)
    T IN LTCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v1
    MODIFY T
        gds__vtov (v2, T.VERSION, sizeof (T.VERSION));
    END_MODIFY;        
    count++;
END_FOR;

if (count) 
    return;

printf ("Test %s, version %s, isn't there.\n", string, v1);
}

static modify_test_category (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	m o d i f y _ t e s t _ c a t e g o r y
 *
 **************************************
 *
 * Functional description
 *	Modify a global test's category
 *
 **************************************/
TEXT	*test = NULL, *category = NULL;
USHORT	count;

get_gtcs();

if (args == 2)
    {
    test = arg1;
    category = arg2;
    }
else
    {
    test = current_test;
    category = arg1;
    }

if (!test)
    {
    printf ("No current test\n");
    return;
    }

if (!category)
    {
    printf ("Deleting test category\n");
    }

count = 0;

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction) T IN GTCS.TESTS WITH T.TEST_NAME EQ test
    MODIFY T
	if (category)
	    {
	    strcpy (T.CATEGORY, category);
	    T.CATEGORY.NULL = FALSE;
	    }
	else
	    T.CATEGORY.NULL = TRUE;
    END_MODIFY
	ON_ERROR
	    local_failure ("gtcs.gdb", gds__status);
	    return;
	END_ERROR;
    count++;
END_FOR;

if (!count)
    printf ("Test %s doesn't exist -- try TCS\n", test);
}

static modify_test_version (args, string, vers1, vers2)
    USHORT	args;
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

if ( !(v1 = make_version (vers1)))
    return;

if ( !(v2 = make_version (vers2)))
    return;

count = 0;

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction)
    T IN GTCS.TESTS WITH T.TEST_NAME EQ string AND T.VERSION = v1
    MODIFY T
        gds__vtov (v2, T.VERSION, sizeof (T.VERSION));
    END_MODIFY;        
    count++;
END_FOR;

if (count) 
    return;

printf ("Test %s, version %s, isn't there.\n", string, v1);
}

static next_test ()
{
/**************************************
 *
 *	n e x t _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Set next test to be default test/platform.
 *
 **************************************/
TEST	test;

if (!(test = test_list))
    {
    printf ("No tests pending\n");
    return FALSE;
    }

set_test (1, test->test_name);
current_platform = test->test_dbb;
test_list = test->test_next;
test->test_next = free_tests;
free_tests = test;

printf ("%s on %s / %s\n", current_test, 
	current_platform->dbb_system, current_platform->dbb_platform);

return TRUE;
}

static *openblob (dbb, blob_id)
    DBB		dbb;
    SLONG	*blob_id;
{
/**************************************
 *
 *	o p e n b l o b
 *
 **************************************
 *
 * Functional description
 *	Open a blob against a particular database.
 *
 **************************************/
int	*blob;
STATUS	status_vector [20];

blob = NULL;

if (gds__open_blob (status_vector,
	GDS_REF (dbb->dbb_handle),
	GDS_REF (dbb->dbb_transaction),
	GDS_REF (blob),
	GDS_VAL (blob_id)))
    {
    gds__print_status (status_vector);
    return NULL;
    }

return blob;
}

static print_blob (dbb, blob_id)
    DBB		dbb;
    SLONG	*blob_id;
{
/**************************************
 *
 *	p r i n t _ b l o b
 *
 **************************************
 *
 * Functional description
 *	Dump a blob to standard out.
 *
 **************************************/
TEXT	buffer [1028];
SSHORT	length;
int	*blob;
STATUS	status_vector [20];
USHORT	lines = 0;

if (!(blob = openblob (dbb, blob_id)))
    return FALSE;

while (!sw_quit && !gds__get_segment (status_vector,
	GDS_REF (blob),
	GDS_REF (length),
	sizeof (buffer),
	buffer))
    {
    if (lines++ == 0)
	fprintf (output, "-------------------\n");
    buffer [length] = 0;
    fputs (buffer, output);
    }

gds__close_blob (status_vector, GDS_REF (blob));

#ifndef DECOSF
if (lines && buffer [length - 1] != '\n')
    putchar ('\n');
#endif

if (lines)
    fprintf (output, "-------------------\n");

return TRUE;    
}

static print_category (args, arg)
    USHORT	args;
    TEXT	*arg;
{
/**************************************
 *
 *	p r i n t _ c a t e g o r y
 *
 **************************************
 *
 * Functional description
 *	Print test definition.
 *
 **************************************/
TEXT	*test;
USHORT	count;

get_gtcs();
test = (args) ? arg : current_test;
count = 0;

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction) X IN GTCS.TESTS WITH X.TEST_NAME EQ test
    ++count;
    if (X.CATEGORY.NULL) 
       	printf ("For version %s, test %s is generic\n", X.VERSION, test);
    else
	printf ("For version %s, test %s is category %s\n", X.VERSION, test, X.CATEGORY);
END_FOR;

if (!count)
    printf ("Test %s doesn't seem to exist\n", test);
}

static print_differences (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	p r i n t _ d i f f e r e n c e s
 *
 **************************************
 *
 * Functional description
 *	Print differences between expected and actual results.
 *
 **************************************/
DBB	dbb;
TEXT	*test;
SSHORT	count;

/* Lookup database/test */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

LTCS = dbb->dbb_handle;
count = 0;

FOR (REQUEST_HANDLE dbb->dbb_diffs, TRANSACTION_HANDLE dbb->dbb_transaction)
   FIRST 1 X IN LTCS.FAILURES
   WITH X.TEST_NAME EQ test AND X.RUN = run_name
    printf ("Differences for test %s, version %s on %s:\n", test, version, dbb->dbb_system);
    print_blob (dbb, &X.DIFFERENCES);
    ++count;
END_FOR;

if (!count)
    printf ("No failure for test %s on %s/%s\n", test, dbb->dbb_system, dbb->dbb_platform);

return TRUE;
}

static print_failure (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
    TEXT	*arg2;
{
/**************************************
 *
 *	p r i n t _ f a i l u r e
 *
 **************************************
 *
 * Functional description
 *	Print differences between expected and actual results.
 *
 **************************************/
DBB	dbb;
TEXT	*test;
SSHORT	count;

/* Lookup database/test */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

LTCS = dbb->dbb_handle;
count = 0;

FOR (REQUEST_HANDLE dbb->dbb_pf, TRANSACTION_HANDLE dbb->dbb_transaction)
  FIRST 1 X IN LTCS.FAILURES WITH X.TEST_NAME EQ test AND X.RUN = run_name
    printf ("Failure for test %s, version %s on %s:\n", test, version, dbb->dbb_system);
    print_blob (dbb, &X.OUTPUT);
    ++count;
END_FOR;

if (!count)
    printf ("No failure for test %s on %s/%s\n", test, dbb->dbb_system, dbb->dbb_platform);

return TRUE;
}

static print_local_test (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	p r i n t _ l o c a l _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Print test definition.
 *
 **************************************/
TEXT	*test;
DBB	dbb;
USHORT	count;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

count = 0;

FOR (REQUEST_HANDLE dbb->dbb_plt, TRANSACTION_HANDLE dbb->dbb_transaction)
   FIRST 1 X  IN LTCS.TESTS
   WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
    ++count;
    print_blob (dbb, &X.SCRIPT);
END_FOR;

if (!count)
    printf ("Test %s doesn't seem to exist\n", test);
}

static print_meta_series (args, string)
    USHORT	args;
    TEXT        *string;
{
/**************************************
 *
 *      p r i n t _ m e t a _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *      Print series_names of series in
 *      in given meta_series
 *
 **************************************/
DBB	dbb;
USHORT   count, is_there;

count = 0;
is_there = 1;

if (!(dbb = get_database (0)))
    is_there = FALSE;


printf ("Series in meta_series %s:\n", string);

if (is_there)
{
    LTCS = current_platform->dbb_handle;

    FOR (REQUEST_HANDLE dbb->dbb_pms, TRANSACTION_HANDLE dbb->dbb_transaction)
        M IN LTCS.META_SERIES WITH M.META_SERIES_NAME EQ string SORTED BY M.SEQUENCE
        if (sw_quit)
	    break;
        printf ("\t%d %s\n", M.SEQUENCE, M.SERIES_NAME);
        count++;
    END_FOR;
}

get_gtcs();

if (!count)
    FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction)
	M IN GTCS.META_SERIES WITH M.META_SERIES_NAME EQ string SORTED BY M.SEQUENCE
	if (sw_quit)
	    break;
	printf ("\t%d %s\n", M.SEQUENCE, M.SERIES_NAME);
	count++;
    END_FOR;
}

static print_note (args, arg1)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	p r i n t _ n o t e
 *
 **************************************
 *
 * Functional description
 *	Print notes, if any, about a test.
 *
 **************************************/
TEXT	*test;

get_gtcs();
test = (args) ? arg1 : current_test;

if (!test)
    {
    printf ("No current test\n");
    return;
    }

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction) X IN GTCS.NOTES WITH X.TEST_NAME EQ test
    print_blob (global_tcs, &X.NOTE);
END_FOR;
}

static print_result (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1;
{
/**************************************
 *
 *	p r i n t _ r e s u l t
 *
 **************************************
 *
 * Functional description
 *	Print expected result.
 *
 **************************************/
DBB	dbb;
TEXT	*test;
SSHORT	count;

/* Lookup database/test */

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

LTCS = dbb->dbb_handle;
count = 0;

FOR (REQUEST_HANDLE dbb->dbb_pr, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 X IN LTCS.INIT WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
    printf ("Result for test %s, version %s on %s:\n", test, X.VERSION, dbb->dbb_system);
    print_blob (dbb, &X.OUTPUT);
    ++count;
END_FOR;

if (reference_platform && !count)
{
    LTCS = reference_platform->dbb_handle;

    FOR (REQUEST_HANDLE reference_platform->dbb_compare2e,
         TRANSACTION_HANDLE reference_platform->dbb_transaction)
        FIRST 1 X IN LTCS.INIT WITH X.TEST_NAME EQ test AND X.VERSION <= ref_version
          SORTED BY DESCENDING X.VERSION
        printf ("Result for test %s for version %s on %s:\n", test, X.VERSION, reference_platform->dbb_system);
        print_blob (reference_platform, &X.OUTPUT);
        ++count;
    END_FOR;
}

if (!count)
    printf ("No initialization for test %s on %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);

return TRUE;
}

static print_ref_version ()
{
/**************************************
 *
 *	p r i n t _ r e f _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	print the current reference version
 *
 **************************************/

printf ("Reference version is %s\n", ref_version);
}

static print_run ()
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

if (run_name[0])
    printf ("Run name is %s\n", run_name);
else
    printf ("There is no current run_name\n");
}

static print_series (args, string)
    USHORT	args;
    TEXT        *string;
{
/**************************************
 *
 *      p r i n t _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *      Print names of tests in
 *      in a given series
 *
 **************************************/
DBB	dbb;
USHORT   count, is_there;

count = 0;
is_there = 1;

if (!(dbb = get_database (0)))
    is_there = FALSE;


printf ("Tests in series %s:\n", string);

if (is_there)
{
    LTCS = current_platform->dbb_handle;

    FOR (REQUEST_HANDLE dbb->dbb_ps, TRANSACTION_HANDLE dbb->dbb_transaction)
        M IN LTCS.SERIES WITH M.SERIES_NAME EQ string SORTED BY M.SEQUENCE
        if (sw_quit)
	    break;
        printf ("\t%d %s\n", M.SEQUENCE, M.TEST_NAME);
        count++;
    END_FOR;
}

get_gtcs();

if (!count)
    FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction)
	M IN GTCS.SERIES WITH M.SERIES_NAME EQ string SORTED BY M.SEQUENCE
	if (sw_quit)
	    break;
	printf ("\t%d %s\n", M.SEQUENCE, M.TEST_NAME);
	count++;
    END_FOR;
}

static print_test (args, arg)
    USHORT	args;
    TEXT	*arg;
{
/**************************************
 *
 *	p r i n t _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Print test definition.
 *
 **************************************/
TEXT	*test;
USHORT	count;

get_gtcs();
test = (args) ? arg : current_test;
count = 0;

FOR (TRANSACTION_HANDLE global_tcs->dbb_transaction) FIRST 1 X IN GTCS.TESTS
  WITH X.TEST_NAME EQ test AND X.VERSION <= version
      SORTED BY DESCENDING X.VERSION
    ++count;
    print_blob (global_tcs, &X.SCRIPT);
END_FOR;

if (!count)
    printf ("Test %s doesn't seem to exist\n", test);
}

static print_version ()
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

printf ("Version is %s\n", version);
}

static print_zap_delete (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	p r i n t _ z a p _ d e l e t e
 *
 **************************************
 *
 * Functional description
 *	Print differences, and optionally zap and delete.
 *
 **************************************/
DBB	dbb;
TEXT	*test;

print_differences (args, arg1, arg2);

if (!yesno ("Zap and delete? "))
    return;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return FALSE;

if (sw_quit)
    return FALSE;

zap (args, arg1, arg2);
delete_failure (args, arg1, arg2);
}

static TEXT *prompt (prompt_string, buffer)
    TEXT	*prompt_string, *buffer;
{
/**************************************
 *
 *	p r o m p t
 *
 **************************************
 *
 * Functional description
 *	Prompt for a string and upcase the result.
 *
 **************************************/

printf (prompt_string);

if (!gets (buffer))
    return NULL;

upcase (buffer);

return buffer;
}

static repeat (args, arg1, arg2, arg3, arg4)
    USHORT	args;
    TEXT	*arg1, *arg2, *arg3, *arg4;
{
/**************************************
 *
 *	r e p e a t
 *
 **************************************
 *
 * Functional description
 *	Repeat a series of tests.
 *
 **************************************/
struct cmd	*cmd;

if (!test_list)
    {
    printf ("No test list\n");
    return;
    }

--args;

while (test_list)
    {
    if (sw_quit)
	{
	if (!yesno ("Continue? "))
	    return FALSE;
	reset_signal();
	}
    next_test();
    for (cmd = commands; cmd->cmd_string; cmd++)
	if (args >= cmd->cmd_args && strcmp (cmd->cmd_string, arg1) == 0)
	    {
	    if (!cmd->cmd_routine)
		{
		printf ("Command %s not found\n", arg1);
		return FALSE;
		}
	    (*cmd->cmd_routine)(args, arg2, arg3, arg4);
	    }
    }
}

static reset_signal ()
{
/**************************************
 *
 *	r e s e t _ s i g n a l
 *
 **************************************
 *
 * Functional description
 *	Reset from a QUIT.
 *
 **************************************/

signal (SIGQUIT, signal_quit);
sw_quit = FALSE;
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

static rollback_db (dbb)
    DBB		dbb;
{
/**************************************
 *
 *	r o l l b a c k _ d b b
 *
 **************************************
 *
 * Functional description
 *	Rollback a database specific transaction and start a new one.
 *
 **************************************/
int	*old_ltcs;

old_ltcs = LTCS;
LTCS = dbb->dbb_handle;
ROLLBACK dbb->dbb_transaction;
START_TRANSACTION dbb->dbb_transaction RESERVING LTCS.TESTS FOR SHARED READ;
LTCS = old_ltcs;
}

static rollback_trans (args, arg)
    USHORT	args;
    TEXT	*arg;
{
/**************************************
 *
 *	r o l l b a c k _ t r a n s
 *
 **************************************
 *
 * Functional description
 *	Rollback either a single platform LTCS or all databases.
 *
 **************************************/
DBB	dbb;

if (args)
    {
    if (!(dbb = get_database (args, arg)))
	return TRUE;
    rollback_db (dbb);
    return TRUE;
    }

if (global_tcs && global_tcs->dbb_transaction)
    rollback_db (global_tcs);

ROLLBACK rollup_trans;
START_TRANSACTION rollup_trans RESERVING DB.FAILURES FOR SHARED WRITE;

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    rollback_db (dbb);
}

static rollup ()
{
/**************************************
 *
 *	r o l l u p
 *
 **************************************
 *
 * Functional description
 *	Update failure abstract from various target TCS's.
 *
 **************************************/
DBB	dbb;
BASED_ON	LTCS.FAILURES.TEST_NAME	test_name;
USHORT	count;

roundup();

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    {
    FOR (TRANSACTION_HANDLE rollup_trans) X IN DB.FAILURES WITH 
	    X. PLATFORM EQ dbb->dbb_platform
	ERASE X;
    END_FOR;
    test_name [0] = 0;
    count = 0;
    LTCS = dbb->dbb_handle;
    FOR (REQUEST_HANDLE dbb->dbb_rollup, TRANSACTION_HANDLE dbb->dbb_transaction)
	    FAILURE IN LTCS.FAILURES SORTED BY FAILURE.TEST_NAME, DESC FAILURE.DATE
	if (strcmp (test_name, FAILURE.TEST_NAME))
	    {
	    ++count;
	    strcpy (test_name, FAILURE.TEST_NAME);
	    STORE (TRANSACTION_HANDLE rollup_trans) NEW IN DB.FAILURES
		NEW.DATE = FAILURE.DATE;
/*		(NEW.DATE).gds_quad_low = 0;*/
		strcpy (NEW.TEST_NAME, FAILURE.TEST_NAME);
		strcpy (NEW.SYSTEM, dbb->dbb_system);
		strcpy (NEW.PLATFORM, dbb->dbb_platform);
	    END_STORE;
	    }
    END_FOR;
    printf ("    %d failures on %s / %s\n", count, dbb->dbb_system, dbb->dbb_platform);
    }

return TRUE;
}

static roundup ()
{
/**************************************
 *
 *	r o u n d u p
 *
 **************************************
 *
 * Functional description
 *	Attach all known databases.
 *
 **************************************/
TEXT	system [16];

if (sw_roundup)
    return;

sw_roundup = TRUE;

FOR (TRANSACTION_HANDLE rollup_trans) X IN DB.PLATFORMS WITH X.ACTIVE NE 0
    copy (X.SYSTEM, system);
    get_database (1, system);
END_FOR;
}

static set_config(rfn)
    TEXT        *rfn;
{
/*************************************
 *
 *      s e t _ c o n f i g
 *
 *************************************
 *
 * Functional description
 *      Read SRN and SVR commands from
 *      the file .tan_config if it exists.
 *
 ************************************/
TEXT    line_buf[MAX_LINE],cmd[MAX_LINE];
FILE    *rfp;
USHORT   line_idx,cmd_idx;

/* Open the configuration file. */

if ((rfp = fopen(rfn,"r")) == NULL)
    return;

/* Loop until EOF. */

while (fgets(line_buf,sizeof(line_buf),rfp))
    {

/* Copy the command modifier from LINE_BUF to CMD. Since fgets() was used,
   LINE_BUF may not be NULL terminated. */

    for ( cmd_idx = 0, line_idx = 0;
          line_buf[line_idx] != NULL && line_buf[line_idx] != '\n';
          line_idx++, cmd_idx++ )

        cmd[cmd_idx] = UPPER(line_buf[line_idx]);

    cmd[cmd_idx] = 0;

    interprete_command (cmd);

    }

fclose(rfp);
return;

}

static set_known_failures (args, name)
    USHORT	args;
    TEXT	*name;
{
/**************************************
 *
 *	s e t _ k n o w n _ f a i l u r e s
 *
 **************************************
 *
 * Functional description
 *	Set run name of known failures
 *
 **************************************/

if (NOT_NULL (name))
    strcpy (known_failures_run_name, name);
else
    strcpy (known_failures_run_name, "");
}

static set_platform_activity (args, arg1, flag)
    USHORT	args;
    TEXT	*arg1;
    USHORT	flag;
{
/**************************************
 *
 *	s e t _ p l a t f o r m _ a c t i v i t y
 *
 **************************************
 *
 * Functional description
 *	Set activity for a platform.
 *
 **************************************/
USHORT	count;

if (!args)
    {
    printf ("Platform name is requested\n");
    return;
    }

count = 0;

FOR (TRANSACTION_HANDLE rollup_trans) X IN DB.PLATFORMS WITH X.PLATFORM EQ arg1 OR X.SYSTEM EQ arg1
    ++count;
    MODIFY X
	X.ACTIVE = flag;
    END_MODIFY;
END_FOR;

if (!count)
    printf ("Platform %s not found\n", arg1);
}

static set_platform (args, platform)
    USHORT	args;
    TEXT	*platform;
{
/**************************************
 *
 *	s e t _ p l a t f o r m
 *
 **************************************
 *
 * Functional description
 *	Set default platform name
 *
 **************************************/
DBB	dbb;

if (!args)
    {
    current_platform = NULL;
    printf ("Clearing current platform\n");
    return TRUE;
    }

if (!(dbb = get_database (1, platform)))
    return TRUE;

current_platform = dbb;

return TRUE;
}

static set_ref_version (args, name)
    USHORT	args;
    TEXT	*name;
{
/**************************************
 *
 *	s e t _ r e f _ v e r s i o n
 *
 **************************************
 *
 * Functional description
 *	Set reference version
 *
 **************************************/
TEXT *v;

if ( !(v = make_version (name)))
    return;
strcpy (ref_version, v);
}

static set_reference (args, platform)
    USHORT	args;
    TEXT	*platform;
{
/**************************************
 *
 *	s e t _ r e f e r e n c e
 *
 **************************************
 *
 * Functional description
 *	Set references platform name
 *
 **************************************/
DBB	dbb;

if (!args)
    {
    reference_platform = NULL;
    printf ("Clearing reference platform\n");
    return TRUE;
    }

if (!(dbb = get_database (1, platform)))
    return TRUE;

reference_platform = dbb;
strcpy (ref_version, version);

return TRUE;
}

static set_run (args, name)
    USHORT	args;
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

if (NOT_NULL (name))
    strcpy (run_name, name);
else
    strcpy (run_name, "");
}

static set_test (args, test)
    USHORT	args;
    TEXT	*test;
{
/**************************************
 *
 *	s e t _ t e s t
 *
 **************************************
 *
 * Functional description
 *	Pick up current test name.
 *
 **************************************/

if (!args)
    {
    printf ("Clearing current test\n");
    current_test [0] = 0;
    return TRUE;
    }

strcpy (current_test, test);
print_note (args, test);

return TRUE;
}

static set_version (args, name)
    USHORT	args;
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

if ( !(v = make_version (name)))
    return;
strcpy (version, v);
}

static set_vms (args, value)
    USHORT	args;
    TEXT	*value;
{
/**************************************
 *
 *	s e t _ v m s
 *
 **************************************
 *
 * Functional description
 *	Pick up current test name.
 *
 **************************************/

if (args)
    sw_vms = atoi (value);
else
    sw_vms = !sw_vms;
}



typedef struct cntr {
    USHORT	cntr_inits;
    USHORT	cntr_tests;
    USHORT	cntr_series; 
    USHORT	cntr_notes;
    USHORT	cntr_failures;
} *CNTR;

static show_test (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
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
struct cntr total;
TEXT	*name;
DBB	dbb;

total.cntr_inits  = 0;
total.cntr_tests  = 0;
total.cntr_series = 0;
total.cntr_notes  = 0;
total.cntr_failures = 0;

if (!get_test (args, arg1, arg2, &dbb, &name))
    return;

printf ("Information for test %s\n", name);

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    {
    if (strcmp (dbb->dbb_platform, "GLOBAL"))
        show_test_info (dbb, name, &total);
    }

get_gtcs();
show_test_info (global_tcs, name, &total);

if (!total.cntr_tests)
    printf ("Test '%s' was not found\n", name);
if (!total.cntr_inits)
    printf ("Test '%s' has no init records\n", name);
if (!total.cntr_series)
    printf ("Test '%s' is not part of any series\n", name);

}


static show_test_info (dbb, name, results)
    DBB		dbb;
    TEXT	*name;
    CNTR	results;
{
/**************************************
 *
 *	s h o w _ t e s t _ i n f o 
 *
 **************************************
 *
 * Functional description
 *	Show various useful information about a test.
 *
 *	A clone of this function is in tcs/tan.e
 *
 **************************************/

struct cntr local;
BASED_ON LTCS.TESTS.COMMENT	test_comment;
int				has_comment;

local.cntr_inits  = 0;
local.cntr_tests  = 0;
local.cntr_series = 0;
local.cntr_notes  = 0;
local.cntr_failures = 0;

/* Report basic info on the test: versions, creators, editors, etc */

LTCS = dbb->dbb_handle;
has_comment = FALSE;
FOR (REQUEST_HANDLE dbb->dbb_st1, TRANSACTION_HANDLE dbb->dbb_transaction)
    T IN LTCS.TESTS WITH T.TEST_NAME = name SORTED BY DESCENDING T.VERSION
    if (local.cntr_tests == 0)
        printf (         "%-14s :Test Editor :Edit date:       :Creator:   :flags:\n", dbb->dbb_platform);
            /*  "  VVVVVVVVVV   BBBBBBBBBBBB DDDDDDDDDDDDDDDDD BBBBBBBBBBBB " */
    printf ("  %-10s   %-12s %-17s %-12s ",
		RIGHT_TRIM (T.VERSION), 
		RIGHT_TRIM (T.EDIT_BY), T.EDIT_DATE.CHAR[17],
		RIGHT_TRIM (T.CREATED_BY));
    if (T.NO_INIT_FLAG)
	printf ("(No init)");
    if (T.NO_RUN_FLAG)
	printf ("(Run only %d)", T.NO_RUN_FLAG);
    printf ("\n");
    if (!T.COMMENT.NULL)
	{
	test_comment = T.COMMENT;
	has_comment = TRUE;
	}
    local.cntr_tests++;
END_FOR;

/* Now report on the various init records for the test */

FOR (REQUEST_HANDLE dbb->dbb_st2, TRANSACTION_HANDLE dbb->dbb_transaction)
    I IN LTCS.INIT WITH I.TEST_NAME = name SORTED BY DESCENDING I.VERSION
    if (local.cntr_inits == 0)
        printf (         "%-14s :init by:    :init date:       :Boilerplate:\n", dbb->dbb_platform);
            /*  "  VVVVVVVVVV   BBBBBBBBBBBB DDDDDDDDDDDDDDDDD BBBBBBBBBBBB" */
    printf ("  %-10s   %-12s %-17s %s\n",
		I.VERSION, RIGHT_TRIM (I.INIT_BY), I.INIT_DATE.CHAR[17],
		RIGHT_TRIM (I.BOILER_PLATE));
    local.cntr_inits++;
END_FOR;

/* Finally, determine which series contain the test */

FOR (REQUEST_HANDLE dbb->dbb_st3, TRANSACTION_HANDLE dbb->dbb_transaction)
    S IN LTCS.SERIES WITH S.TEST_NAME = name SORTED BY S.SERIES_NAME, S.SEQUENCE
    if (local.cntr_series == 0)
	printf (   "%s series: ", dbb->dbb_platform);
    else if ((local.cntr_series % 4) == 0)
	printf (",\n               ");
    else
	printf (", ");
    printf ("%s (%d)", RIGHT_TRIM (S.SERIES_NAME), S.SEQUENCE);
    local.cntr_series++;
END_FOR;
if (local.cntr_series)
    printf ("\n");

/* And might as well dump out any failures stored for the test */

FOR (REQUEST_HANDLE dbb->dbb_st4, TRANSACTION_HANDLE dbb->dbb_transaction)
    F IN LTCS.FAILURES WITH F.TEST_NAME = name
    SORTED BY DESCENDING F.VERSION, F.DATE
    if (local.cntr_failures == 0)
        printf (     " %-13s     :date:        :run_by:     :run:                :Boilerplate:\n",
		dbb->dbb_platform);
            /*  " VVVVVVVVVV DDDDDDDDDDDDDDDDD NNNNNNNNNNNN RRRRRRRRRRRRRRRRRRRR BBBBBBBBBBBBBBBBB " */
    printf (    " %-10s %-17s %-12s %-20s %s\n",
		F.VERSION, F.DATE.CHAR[17], RIGHT_TRIM (F.RUN_BY),
		RIGHT_TRIM (F.RUN), RIGHT_TRIM (F.BOILER_PLATE_NAME));
    local.cntr_failures++;
END_FOR;

/* And might as well dump out any notes stored for the test */

if (has_comment)
    print_blob (dbb, &test_comment);

FOR (REQUEST_HANDLE dbb->dbb_st5, TRANSACTION_HANDLE dbb->dbb_transaction)
    N IN LTCS.NOTES WITH N.TEST_NAME = name AND N.NOTE NOT MISSING
    printf (" %s Note:\n", dbb->dbb_platform);
    print_blob (dbb, &N.NOTE);
    local.cntr_notes++;
END_FOR;


if (local.cntr_tests || local.cntr_inits || local.cntr_series ||
    local.cntr_notes || local.cntr_failures)
    printf ("\n");

results->cntr_tests  += local.cntr_tests;
results->cntr_inits  += local.cntr_inits;
results->cntr_series += local.cntr_series;
results->cntr_notes  += local.cntr_notes;
results->cntr_failures += local.cntr_failures;
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
 *
 **************************************/

sw_quit = TRUE;
signal (SIGQUIT, SIG_DFL);
}

static status ()
{
/**************************************
 *
 *	s t a t u s
 *
 **************************************
 *
 * Functional description
 *	Print current program state.
 *
 **************************************/
DBB	dbb;

printf ("\n");

if (current_test [0])
    printf ("Current test:\t\t%s\n", current_test);
else
    printf ("No current test\n");

printf ("Current run name:\t%s\n", run_name);
printf ("Known failures run:\t%s\n", known_failures_run_name);

if (current_platform)
    printf ("Current platform:\t%s / %s\nCurrent version:\t%s\n", 
	current_platform->dbb_system,
	current_platform->dbb_platform,
	version);
else
    printf ("No current platform\n");

if (reference_platform)
    printf ("Reference platform:\t%s / %s\nReference version:\t%s\n", 
	reference_platform->dbb_system,
	reference_platform->dbb_platform,
	ref_version);
else
    printf ("No reference platform\n");

printf ("Rollup database:\t%s\n", db_name);
printf ("Attached databases:\n");

for (dbb = databases; dbb; dbb = dbb->dbb_next)
    printf ("    %s / %s\n", dbb->dbb_system, dbb->dbb_platform);

if (global_mode)
    printf ("In Global Init mode\n");
else
    printf ("In Local Init mode\n");

printf ("\n");
}

static upcase (string)
    TEXT	*string;
{
/**************************************
 *
 *	u p c a s e
 *
 **************************************
 *
 * Functional description
 *	Upcase a string.
 *
 **************************************/

for (; *string; ++string)
    *string = UPPER (*string);
}

static yesno (string)
    TEXT	*string;
{
/**************************************
 *
 *	y e s n o
 *
 **************************************
 *
 * Functional description
 *	Get a simple yes/no answer to a question.
 *
 **************************************/
TEXT	response [20];

while (prompt (string, response))
    if (response [0] == 'Y')
	return TRUE;
    else if (response [0] == 'N')
	return FALSE;

return FALSE;
}

static zap (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	z a p
 *
 **************************************
 *
 * Functional description
 *	Reset an initialization from the most recent failure for a
 *	particular test/platform.
 *
 **************************************/

if (global_mode)
    return zap_global (args, arg1, arg2);
else
    return zap_local (args, arg1, arg2);

}

static zap_local (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	z a p _ l o c a l
 *
 **************************************
 *
 * Functional description
 *	Reset an local initialization from the most recent failure for a
 *	particular test/platform.
 *
 **************************************/
TEXT	*test, prmpt[200], response [20];
DBB	dbb;
USHORT	count, init_count, zap_it;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

count = 0;
LTCS = dbb->dbb_handle;

FOR (REQUEST_HANDLE dbb->dbb_zap1, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 FAILURE IN LTCS.FAILURES WITH FAILURE.RUN = run_name
	AND FAILURE.TEST_NAME EQ test 
	SORTED BY DESC FAILURE.DATE
    ++count;
    init_count = 0;
    zap_it = 0;
    FOR (REQUEST_HANDLE dbb->dbb_zap2, TRANSACTION_HANDLE dbb->dbb_transaction)
	FIRST 1 X IN LTCS.INIT WITH X.TEST_NAME EQ test AND X.VERSION <= version
        SORTED BY DESCENDING X.VERSION
        zap_it = 1;

	/* We have an init of the current version level, but failure
	 * was NOT of current version - better ask the user
	 */
        if ((strcmp (X.VERSION, version) == 0) && 
		(strcmp (FAILURE.VERSION, version) != 0))
            {
            zap_it = 0;
            sprintf (prmpt, "Current version %s, init version %s, failure version %s\n\tzap it (Z), store new (S) or do nothing (N): ", version, X.VERSION, FAILURE.VERSION);
            while (prompt (prmpt, response))
                if (response [0] == 'Z')
                    {
                    zap_it = 1;
                    break;
                    }
                else if (response [0] == 'S')
                    break;
                else if (response [0] == 'N')
                    {
                    zap_it = -1;
                    break;
                    }
            }
	/* We have an init version OLDER than current version - just
	 * store a new version;
	 */
	else if (strcmp (X.VERSION, version) < 0)
	     zap_it = 0;
	 
        if (zap_it == 1)
	    MODIFY X
	        ++init_count;
	        printf ("Zapping %s on %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);
	        strcpy (X.VERSION, version);
	        X.OUTPUT = FAILURE.OUTPUT;
	        X.INIT_DATE = FAILURE.DATE;
	        strcpy (X.BOILER_PLATE, FAILURE.BOILER_PLATE_NAME);
	        strcpy (X.ENV_NAME, FAILURE.ENV_NAME);
	    END_MODIFY;
    END_FOR;
    if (!init_count && zap_it != -1)
	{
	printf ("Initializing %s on %s / %s\n", test, 
		dbb->dbb_system, dbb->dbb_platform);
	STORE (REQUEST_HANDLE dbb->dbb_zap3, TRANSACTION_HANDLE dbb->dbb_transaction)
	    X IN LTCS.INIT 
		strcpy (X.TEST_NAME, test);
		strcpy (X.VERSION, version);
		X.OUTPUT = FAILURE.OUTPUT;
		X.INIT_DATE = FAILURE.DATE;
		strcpy (X.BOILER_PLATE, FAILURE.BOILER_PLATE_NAME);
		strcpy (X.ENV_NAME, FAILURE.ENV_NAME);
	END_STORE
	    ON_ERROR
		local_failure (dbb->dbb_system, "store ltcs.init");
		return FALSE;
	    END_ERROR;
	}
END_FOR;

if (!count)
    {
    printf ("Test %s not found on %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);
    return FALSE;
    }

return TRUE;
}

static zap_global (args, arg1, arg2)
    USHORT	args;
    TEXT	*arg1, *arg2;
{
/**************************************
 *
 *	z a p _ g l o b a l
 *
 **************************************
 *
 * Functional description
 *	Reset the global initialization from the most recent failure for a
 *	particular test/platform.
 *
 **************************************/
TEXT	*test, prmpt[200], response [20];
DBB	dbb;
USHORT	count, init_count, zap_it;

if (!get_test (args, arg1, arg2, &dbb, &test))
    return TRUE;

get_gtcs();

count = 0;
LTCS = dbb->dbb_handle;

FOR (REQUEST_HANDLE dbb->dbb_gzap1, TRANSACTION_HANDLE dbb->dbb_transaction)
    FIRST 1 FAILURE IN LTCS.FAILURES WITH FAILURE.RUN = run_name
	AND FAILURE.TEST_NAME EQ test 
	SORTED BY DESC FAILURE.DATE
    ++count;
    init_count = 0;
    zap_it = 0;
    BLOB_TEXT_DUMP (&FAILURE.OUTPUT, dbb->dbb_handle, dbb->dbb_transaction, "failure.loc");
    FOR (REQUEST_HANDLE global_tcs->dbb_gzap2, TRANSACTION_HANDLE global_tcs->dbb_transaction)
	FIRST 1 X IN GTCS.INIT WITH X.TEST_NAME EQ test AND X.VERSION <= version
        SORTED BY DESCENDING X.VERSION
        zap_it = 1;

	/* We have an init of the current version level, but failure
	 * was NOT of current version - better ask the user
	 */
        if ((strcmp (X.VERSION, version) == 0) && 
		(strcmp (FAILURE.VERSION, version) != 0))
            {
            zap_it = 0;
            sprintf (prmpt, "Current version %s, init version %s, failure version %s\n\tzap it (Z), store new (S) or do nothing (N): ", version, X.VERSION, FAILURE.VERSION);
            while (prompt (prmpt, response))
                if (response [0] == 'Z')
                    {
                    zap_it = 1;
                    break;
                    }
                else if (response [0] == 'S')
                    break;
                else if (response [0] == 'N')
                    {
                    zap_it = -1;
                    break;
                    }
            }
	/* We have an init version OLDER than current version - just
	 * store a new version;
	 */
	else if (strcmp (X.VERSION, version) < 0)
	     zap_it = 0;
	 
        if (zap_it == 1)
	    MODIFY X
	        ++init_count;
	        printf ("Zapping Global init for %s from %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);
    		BLOB_TEXT_LOAD (&X.OUTPUT, global_tcs->dbb_handle, global_tcs->dbb_transaction, "failure.loc");
	        X.INIT_DATE = FAILURE.DATE;
	        strcpy (X.VERSION, version);
	        strcpy (X.BOILER_PLATE, FAILURE.BOILER_PLATE_NAME);
	        strcpy (X.ENV_NAME, FAILURE.ENV_NAME);
	    END_MODIFY;
    END_FOR;
    if (!init_count && zap_it != -1)
	{
	printf ("Initializing Global %s on %s / %s\n", test, 
		dbb->dbb_system, dbb->dbb_platform);
	STORE (REQUEST_HANDLE global_tcs->dbb_gzap3, TRANSACTION_HANDLE global_tcs->dbb_transaction)
	    X IN GTCS.INIT 
		strcpy (X.TEST_NAME, test);
		strcpy (X.VERSION, version);
    		BLOB_TEXT_LOAD (&X.OUTPUT, global_tcs->dbb_handle, global_tcs->dbb_transaction, "failure.loc");
		X.INIT_DATE = FAILURE.DATE;
		strcpy (X.BOILER_PLATE, FAILURE.BOILER_PLATE_NAME);
		strcpy (X.ENV_NAME, FAILURE.ENV_NAME);
	END_STORE
	    ON_ERROR
		local_failure (global_tcs->dbb_system, "store global.init");
		return FALSE;
	    END_ERROR;
	}
    unlink ("failure.loc");
END_FOR;

if (!count)
    {
    printf ("Test %s not found on %s / %s\n", test, dbb->dbb_system, dbb->dbb_platform);
    return FALSE;
    }

return TRUE;
}
