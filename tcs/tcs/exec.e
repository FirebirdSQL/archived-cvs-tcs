/*
 *      PROGRAM:        Test Control System
 *      MODULE:         exec.e
 *      DESCRIPTION:    Run tests,Evaluate test results,provide runtime reports
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
 * $Id$
 */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "tcs.h"
#undef OLD_STYLE_DIFF

extern USHORT   sw_ignore_init,sw_quiet,sw_save,sw_times,quit;

#if (defined WIN_NT || defined OS2_ONLY || defined(SINIXZ))

/* External declarations */
extern int do_diffs (TEXT* input_1,
							TEXT* input_2,
							TEXT* diff_file,
							USHORT sw_win,
							USHORT sw_match,
							USHORT sw_ignore);
							
extern int disp_print_blob (SLONG* blob_id, SLONG* db_handle);
extern int PTSL_2ap (TEXT* in_line, TEXT* result);

/* Static declarations */
static int read_segment (ULONG* blob, TEXT* buffer, USHORT buff_len);
static int contains (TEXT* s1, TEXT* s2);
static int script_apollo (ULONG* blob_id,
								  ULONG* db_handle,
								  FILE* script,
								  USHORT* n);

static  int execute_apollo (TEXT* script_file, TEXT* output_file);
static int run (ULONG* blob_id,
			  ULONG* db_handle,
			  TEXT* script_file,
			  TEXT* output_file,
			  ULONG* run_time,
			  USHORT sw_no_system,
			  int* file_count);
#ifdef OLD_STYLE_DIFF
static int compare (SLONG* blob_id, TEXT* output_file, SSHORT global);
#else
static int compare (TEXT* compare_file, TEXT* output_file, SSHORT global);
#endif
static int compare_initialized (ULONG* blob_id,
										  TEXT* test_name,
										  TEXT* run_name,
										  SSHORT global,
										  TEXT* version);
static int fail_uninit (TEXT* testname, TEXT* run_name, TEXT* version);
static ULONG *open_blob (SLONG* blob_id, ULONG* db_handle);
static int next_segment (ULONG* blob, TEXT* buffer, USHORT buff_len);
static int next_line (FILE* file, TEXT* buffer, USHORT buff_len);
static int store_blob (ULONG* blob_id,
							  ULONG* db_handle,
							  ULONG* tr_handle,
							  TEXT* file_name);
static int commit_retaining (void);

#else

/* Extern declarations */
extern struct tm        *localtime();

/* Static declarations */
static ULONG    *open_blob ();

#endif

extern TEXT     boilerplate_name[];
extern TEXT     environment_name[];
extern TEXT     known_failures_run_name[];
extern USHORT   disk_io_error;



static TEXT     *months [] =
    {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
    0
    }; 

/* 
    A variety of VMS utilities put unwanted messages in
    unreasonable places.  This table tells us how many
    lines to skip when we find a line put in by the linker
    or one of its friends. 

    The mechanism is around in case other operating systems
    decide to become more verbose.
*/

typedef struct pita {
	TEXT    *line;
	SSHORT  skip;
} *PITA;

static struct pita  nuisances [] = {
#ifdef VMS
	{ "%DCL-I-", 1 },
	{ "%LINK-I-", 1 },
	{ "set noverify", 1 },
	{ "set verify", 1 },
	{ "job terminated at", 10 },
	{ "in shareable image library", 1 },
	{ "DIFFERENCES /IGNORE=()/MERGED=1/OUTPUT", 3 },
	{ "Number of difference sections found:",  1 },
	{ "Number of difference records found:", 1 },
#endif
	{ "CONNECT or CREATE", 1 },
	{ "Owner:", 1 },
#ifdef UNIX
	{ "cc -", 1 },
	{ "cc ", 1 },
	{ "rm ", 1 },
	{ "drop_gdb ", 1 },
	{ "cat ", 1 },
#endif
	{ "rm ", 1 },
	{ "Database", 1 },
	{ "define database", 1 },
	{ "/* CREATE DATABASE", 1 },
#ifdef apollo
#endif
#ifdef mpexl
	{ "HP Link Editor/XL (HP", 4 },
	{ "-----Copying ", 3 },
	{ "-----Purging ", 4 },
#endif
#ifdef DGUX
	{ "ghf77 ", 2 },
#endif
#ifdef AIX
	{ "f77 ", 1 },
#endif
#ifdef sgi
	{ "f77 ", 1 },
#endif
#ifdef sun
	{ "f77 ", 1 },
	{ "license(s) for SPARCompiler", 3 },
		/* The SUN ACC family license server emits messages of the form:
		   All %d license(s) for %s are currently in use, queuing the request\n
		   \n
		   Got the license for %s, continuing\n
		*/ 
#endif
#ifdef hpux
	{ "f77 ", 1 },
	{ "fc ", 1 },
	{ "ld: multiply defined symbol __environ", 1 },
	{ "never used ", 1 },
#endif
#ifdef WIN_NT
	{ "cl386 ", 1 },
	{ "link32 ", 3 },
	{ "warning 505: No modules extracted from", 1 },
	{ "bcc32 ", 3 },
	{ "tlink32 ", 2 },
	{ "del ", 1 },
	{ "Could Not Find ", 1 },
	{ "Borland C++ ",2 },
	{ "Turbo Link ",1 },
#endif
#ifdef OS2_ONLY
	{ "bcc ", 3 },
	{ "tlink ", 2 },
	{ "del ", 1 },
	{ "SYS0002: The system cannot find the file ", 2 },
#endif
	{ "", 0   }
};

#ifdef PC_PLATFORM
#define FILE_DEFINES
TEXT  *script_file = "tcscmd.cmd",  
		*output_file = "tcs.out",
		*compare_file = "tcs.cmp",
		*info_file = "tcs.inf",
		*diff_file = "tcs.dif";
#endif

#ifdef XENIX
#define FILE_DEFINES
TEXT  *script_file = "tcs.script",
		*output_file = "tcs.output",
		*compare_file = "tcs.compare",
		*info_file = "tcs.info",
		*diff_file = "tcs.diffs";
#endif

#ifdef mpexl
#define FILE_DEFINES
TEXT  *script_file = "tcscmnd.temp",
		*output_file = "tcsoutpt.temp",
		*compare_file = "tcscmpar.temp",
		*info_file = "tcsinfo.temp",
		*diff_file = "tcsdiffs.temp";
#endif

#if (defined WIN_NT || defined OS2_ONLY)
#define FILE_DEFINES
#ifdef WIN_NT
TEXT     *script_file = "tcscmd.bat",
#else
TEXT     *script_file = "tcscmd.cmd",
#endif
		*output_file = "tcs.out",
		*compare_file = "tcs.cmp",
		*info_file = "tcs.inf",
		*diff_file = "tcs.dif",
		*mks_script_file = "tcscmd.ksh";
#endif

#ifndef FILE_DEFINES
TEXT     *script_file = "tcs.script",
		*output_file = "tcs.output",
		*compare_file = "tcs.compare",
		*info_file = "tcs.info",
		*diff_file = "tcs.differences";
#endif


#ifdef mpexl
#define FOPEN_READ_TYPE         "r Tm"
#define FOPEN_WRITE_TYPE        "w Ds1 V E32 S100000"
#endif

#ifndef FOPEN_READ_TYPE
#define FOPEN_READ_TYPE         "r"
#define FOPEN_WRITE_TYPE        "w"
#endif

DATABASE
    TCS = EXTERN COMPILETIME FILENAME "ltcs.gdb";

DATABASE
    TCS_GLOBAL = EXTERN COMPILETIME FILENAME "gtcs.gdb";

int EXEC_env (blob_id)
   ULONG  *blob_id; 
{
/**************************************
 *
 *      E X E C _ e n v
 *
 **************************************
 *
 * Functional description
 *   dump the prologue of an environment
 *   to a file and call the system execution
 *   routine on it
 *
 **************************************/
FILE    *script;
USHORT  success, n;
TEXT    data_file [15];

n = 0;          /* The number of data files opened by script_apollo()   */

/*      Open script file                                                */

if (!(script = fopen (script_file, "w")))

{
    print_error ("Can't create file \"%s\"\n", script_file,0,0);
    disk_io_error = TRUE;
    return FALSE;
}

/*      Create the script file, we pass the blob_id, the DB handle      *
 *      and the file pointer of the script file ("script").             *
 *      This is done to eventually call PTSL_2ap which will translate   *
 *      the environment variables into the proper table so they can     *
 *      be looked up at run time.                                       */

#ifdef VMS
success = script_vms (blob_id, TCS, script);
#else
success = script_apollo (blob_id, TCS, script, &n);
#endif

fclose (script);

/*      If we were not successful creating the script then exit, if     *
 *      we are just changing environments then we will not be           *
 *      successful                                                      */

if (!success)
    return FALSE;

/*      As far as I can tell, this code will never be reached unless    *
 *      a '$' command exists in the environment.                        */

/*      Run the script                                                  */

success = FALSE;

#ifdef VMS
success = execute_vms (script_file, NULL, output_file);
#else
success = execute_apollo (script_file, output_file);
#endif

if (!sw_save)
{

/*      If the '-s' option was not set then do NOT save the script      *
 *      files.                                                          */

	 unlink (script_file);
	 unlink (output_file);

/*      Now, do the same for the data files                             */

/*      Loop for each data file that is open...                         */

	 while (n)
	 {
		sprintf (data_file, DAT_FILE, --n);
	   unlink (data_file);
	 }
}
 return TRUE;
}

USHORT EXEC_init (string, blob_id, db_handle, sw_no_system, phase, file_count, version,           global)
	TEXT    *string, *version;
	ULONG    *blob_id, *db_handle;
   USHORT   sw_no_system, phase;
   int     *file_count;
   SSHORT   global;
{
/**************************************
 *
 *       E X E C _ i n i t
 *
 **************************************
 *
 * Functional description
 *
 *         Drive the initialization of
 *         of a test.  Called by init()
 *
 **************************************/
USHORT  count, n;
TEXT    data_file [15];
SLONG   run_time;

count = 0;

if (phase == 0)

{

    if (!global)
	fprintf (stdout, "Initializing test %s locally ... ", string);
    else
	fprintf (stdout, "Initializing test %s globally ... ", string);

    fflush (stdout);

/*      Run the test -- if not successful running the test,return FALSE *
 *      The output will be stored temporarily in the output_file by     *
 *      run().  It will be put in the db later in this function.        */
    if (!run (blob_id, db_handle, script_file, output_file, &run_time, sw_no_system, file_count))
	return FALSE;

/*      If the no system flag is thrown '-n' then exit.                 */

    if (sw_no_system)
	return FALSE;
}

/*      If the phase is one then go here( no system flag '-n').         *
 *      NOTE:  It doesn't look like execution will ever reach here,     *
 *      because the functionality does not exist in main().             */

else

{

/*      If the no system flag is set ... '-n'                           */

    if (sw_no_system)

    {

	if (!global)
	    fprintf (stdout, "Initializing test %s locally ... ", string);
	else
	    fprintf (stdout, "Initializing test %s globally ... ", string);

/*      Delete unwanted data files                                      */

	if (!sw_save)

	{
	    n = *file_count;

	    while (n)

	    {
		sprintf (data_file, DAT_FILE, --n);
		unlink (data_file);
	    }
	}
    }
}

/*      If we have the times switch thrown '-t' then save the current   *
 *      time.                                                           */

if (sw_times)

{
    STORE T IN TCS.TIMES
	strcpy (T.TEST_NAME, string);
	strcpy (T.DATE.CHAR[12], "NOW");
	T.TIME = run_time;
    END_STORE;
}

/*      Store the result (output_file) in the local db                  */

if (!global)

{   
    FOR  I IN TCS.INIT WITH I.TEST_NAME = string AND I.VERSION = version
	MODIFY I USING
	    strcpy (I.INIT_DATE.CHAR[20], "NOW");
	    BLOB_TEXT_LOAD (&I.OUTPUT, TCS, gds__trans, output_file);
	    strcpy (I.BOILER_PLATE, boilerplate_name);
	    strcpy (I.ENV_NAME, environment_name);
	    count++;
	END_MODIFY;
    END_FOR;

/*      Start from scratch if we have to...                             */

    if (!count)

    {   
	STORE I IN TCS.INIT USING
	    gds__vtov (string, I.TEST_NAME, sizeof(I.TEST_NAME));
	    gds__vtov (version, I.VERSION, sizeof(I.VERSION));
	    strcpy (I.INIT_DATE.CHAR[20], "NOW");
	    BLOB_TEXT_LOAD (&I.OUTPUT, TCS, gds__trans, output_file);
	    strcpy (I.BOILER_PLATE, boilerplate_name);
	    strcpy (I.ENV_NAME, environment_name);
	    count++;
	END_STORE;
    }
}

/*      Store the result in the global db                               */

else

{
    FOR  I IN TCS_GLOBAL.INIT WITH I.TEST_NAME = string AND I.VERSION = version
	MODIFY I USING
	    strcpy (I.INIT_DATE.CHAR[20], "NOW");
	    BLOB_TEXT_LOAD (&I.OUTPUT, TCS_GLOBAL, gds__trans, output_file);
	    strcpy (I.BOILER_PLATE, boilerplate_name);
	    strcpy (I.ENV_NAME, environment_name);
	    count++;
	END_MODIFY;
    END_FOR;
 
/*      Start from scratch if we have to...                             */

    if (!count)
    {
	STORE I IN TCS_GLOBAL.INIT USING
	    gds__vtov (string, I.TEST_NAME, sizeof(I.TEST_NAME));
	    gds__vtov (version, I.VERSION, sizeof(I.VERSION));
	    strcpy (I.INIT_DATE.CHAR[20], "NOW");
	    BLOB_TEXT_LOAD (&I.OUTPUT, TCS_GLOBAL, gds__trans, output_file);
	    strcpy (I.BOILER_PLATE, boilerplate_name);
	    strcpy (I.ENV_NAME, environment_name);
	    count++;
	END_STORE;
    }
}

/*      If count is incremented then the initialization and store       *
 *      was a success, so cleanup and exit.                             */

if (count)

{
    printf ("done\n");

/*      If the save switch '-s' is not thrown then cleanup the files.   */

    if (!sw_save)

    {
	unlink (script_file);
	unlink (output_file);
    }
}

return count;
}

TEST_RESULT EXEC_test (test_name, script_id, db_handle, sw_no_system, phase, file_count, version, run_name)
    TEXT    *test_name, *version, *run_name;
    SLONG    *script_id;
    ULONG    *db_handle;
    USHORT   sw_no_system, phase;
    int     *file_count;
{
/**************************************
 *
 *      E X E C _ t e s t
 *
 **************************************
 *
 * Functional description
 *    drive the execution of a test
 *    Return the result of running the test
 *
 **************************************/
USHORT          count, n;
TEST_RESULT     result;
TEXT            data_file [15];
SLONG           run_time;

result = passed;

/*      If phase == 0 (it will always unless '-n' no system flag is     *
 *      set) then run the test, by calling run().                       */

if (phase == 0)

{
    if (test_name[-1] == 'l')
	fprintf (stdout, "Running local test %s ... ", test_name);
    else
	fprintf (stdout, "Running global test %s ... ", test_name);
    if (sw_no_system)
	fprintf (stdout, "\n");
    fflush (stdout);

    if (!run (script_id, db_handle, script_file, output_file, &run_time, sw_no_system, file_count))
	return test_system_failed; 

/*      Exit if the no system flag is set.                              */

    if (sw_no_system)
	return passed;
}

/*      If the phase is 1 then the no system flag is set and this is    *
 *      called from main() were the test_name was read from the         *
 *      info file, so clean up files.                                   */

else

{
/*      If no system flag is set...                                     */

    if (sw_no_system)
    {
	fprintf (stdout, "Running test %s ... ", test_name);

/*      Delete unwanted data files                                      */
	if (!sw_save)
	{
	    n = *file_count;
	    while (n)
	    {
		sprintf (data_file, DAT_FILE, --n);
		unlink (data_file);
	    }
	 }
    }
}

/*      If the ignore initialization flag is not set then compare the   *
 *      output with the the initialization.                             */

count = 0;
if (!sw_ignore_init)

{

/*      Look for a known failure of this test first                     */

    if (!count && !NULL_STR (known_failures_run_name))
    {
	FOR I IN TCS.FAILURES WITH I.TEST_NAME = test_name AND
	 I.RUN = known_failures_run_name AND
	 I.VERSION = version SORTED BY DESCENDING I.VERSION
	    count++;
	    if (compare (&I.OUTPUT, output_file, 0))
		{
		result = failed_known;
		printf("*** failed -- known failure\n");
		break;
		}
	END_FOR;
	if (count && (result == passed))
	    {
	    result = failed;
	    printf("*** failed -- does not match known failure\n");
	    print_error ("Test %s version %s - does not match existing known failure.\n", test_name, version, 0);
	    }
    }

    if (!count && !NULL_STR (known_failures_run_name))
    {
	FOR I IN TCS_GLOBAL.FAILURES WITH I.TEST_NAME = test_name AND
	 I.RUN = known_failures_run_name AND
	 I.VERSION = version SORTED BY DESCENDING I.VERSION
	    count++;
	    if (compare (&I.OUTPUT, output_file, 1))
		{
		result = failed_known;
		printf("*** failed -- known failure\n");
		break;
		}
	END_FOR;
	if (count && (result == passed))
	    {
	    result = failed;
	    printf("*** failed -- does not match known failure\n");
	    print_error ("Test %s version %s - different than known failure.\n", test_name, version, 0);
	    }
    }

/*      Not a known failure, try against known passes                   */

    /* Force a new differences record */
    if (result == failed)
	count = 0;

    if (!count)
    {
	BASED_ON TCS.TESTS.VERSION	best_version;
	GDS__QUAD       *best_output;
	USHORT          best_location;

	strcpy(best_version,"");

	/* Check the local database for the best version available */

	FOR FIRST 1 I IN TCS.INIT WITH I.TEST_NAME = test_name AND
	  I.VERSION <= version
	  SORTED BY DESCENDING I.VERSION
	    best_output = &I.OUTPUT;
	    strcpy(best_version,I.VERSION);
	    best_location = 0;
	    count++;
	END_FOR;

	/* and see if there is a better version in the global database */

	FOR FIRST 1 I IN TCS_GLOBAL.INIT WITH I.TEST_NAME = test_name AND
	 I.VERSION <= version AND I.VERSION > best_version
	 SORTED BY DESCENDING I.VERSION
	     best_output = &I.OUTPUT;
	    /* best_version = &I.VERSION; */
	     strcpy(best_version,I.VERSION);
	     best_location = 1;
	     count++;
	END_FOR;

	if (count)
	    {
	    result = compare_initialized (best_output, test_name, run_name,
					best_location, version);
	    }
    }


}

/*      If count was not incremented then an initialization for the     *
 *      test does not exist, so if the ignore init flag is not set then *
 *      call fail_uninit() to show the output.                          */

if (!count || sw_ignore_init) 
    result = fail_uninit (test_name, run_name, version);

/*      If the test did not fail and the timing flag is set '-t' then   *
 *      store the timing information.                                   */

if ((result == passed) && sw_times)

{
    STORE T IN TCS.TIMES
	strcpy (T.TEST_NAME, test_name);
	strcpy (T.DATE.CHAR[12], "NOW");
	T.TIME = run_time;
    END_STORE;
}

return (result);
}

static int commit_retaining ()
{
/**************************************
 *
 *      c o m m i t _ r e t a i n i n g
 *
 **************************************
 *
 * Functional description
 *      Do a commit retaining, complain (but don't croak) if it fails.
 *
 **************************************/

SAVE
   ON_ERROR
	print_error ("SAVE transaction failed\n",0,0,0);
	gds__print_status (gds__status);
	END_ERROR;

return TRUE;
}

#ifdef OLD_STYLE_DIFF
static int compare (blob_id, output_file, global)
    SLONG       *blob_id;
    TEXT        *output_file;
    SSHORT      global;
{
/**************************************
 *
 *      c o m p a r e
 *
 **************************************
 *
 * Functional description
 *      Do a quick compare of a blob to a file.
 *      Return identical (TRUE) or difference
 *      (FALSE).
 *
 **************************************/
FILE    *file,*blob_file;
STATUS  status_vector [20];
ULONG   *blob;
TEXT    f_buff [2048], b_buff [2048], *p, *q, c, lastc;
USHORT  eof_blob, eof_file;

/*      Check to make sure an output file exists.                       */

if (!(file = fopen (output_file, FOPEN_READ_TYPE)))
    return FALSE;

/*      If the global flag is not set then grab the blob from the       *
 *      local DB.                                                       */




if (!global)

{
/*      If can't open the blob then close the file and exit             */

    if (!(blob = open_blob (blob_id, TCS)))

    { 
	fclose (file);
	return FALSE;
    }
}

/*      Else grab the blob from the Global DB.                          */

else

{
/*      If can't open the blob then close the file and exit             */

    if (!(blob = open_blob (blob_id, TCS_GLOBAL)))

    {
	fclose (file);
	return FALSE;
    }
} 

do 
{
    eof_blob = next_segment (blob, b_buff, sizeof (b_buff));
    eof_file = next_line (file, f_buff, sizeof (f_buff));
    if (eof_blob || eof_file)
	break;


    /* Map multiple white space characters to single spaces */
    p = q = f_buff;
    lastc = 0;

    while (c = *p++)

    {
	if (c == '\t')
	    c = ' ';
	if (c != ' ' || lastc != ' ')
	    lastc = *q++ = c;
    }

    if (q != f_buff && *q == '\n')
	q--;
    if (q != f_buff && *q == ' ')
	q--;
    *q = 0;

    /* Map multiple white space characters to single spaces */
    p = q = b_buff;
    lastc = 0;

    while (c = *p++)

    {
	if (c == '\t')
	    c = ' ';
	if (c != ' ' || lastc != ' ')
	    lastc = *q++ = c;
    }

    if (q != b_buff && *q == '\n')
	q--;
    if (q != b_buff && *q == ' ')
	q--;
    *q = 0;

    /* Scan the lines for a difference */
    for (p = f_buff, q = b_buff; *p && *p == *q; p++, q++)
	continue;

    if (*p != *q) 
	{
	/* Difference found - check for trivial difference */
	char *head1,
	     *head2,
	     *tail1,
	     *tail2;

	/* if the lines both have a ".gdb" this ignore anything that
	 * "looks like" a filename 
	 * Note that some platforms have only UPCASE filenames
	 * This will fail for any lines that have TWO filenames on them.
	 *
	 *  Added 24-Jan-96:  Remove .dat, .gbk from files as well
	 */

	if (((tail1 = (char*)strstr(f_buff, ".gdb")) ||
	     (tail1 = (char*)strstr(f_buff, ".gbk")) ||
	     (tail1 = (char*)strstr(f_buff, ".GBK")) ||
	     (tail1 = (char*)strstr(f_buff, ".dat")) ||
	     (tail1 = (char*)strstr(f_buff, ".DAT")) ||
	     (tail1 = (char*)strstr(f_buff, ".GDB")))
	   &&
	    ((tail2 = (char*)strstr(b_buff, ".gdb")) ||
	     (tail2 = (char*)strstr(b_buff, ".gbk")) ||
	     (tail2 = (char*)strstr(b_buff, ".GBK")) ||
	     (tail2 = (char*)strstr(b_buff, ".dat")) ||
             (tail2 = (char*)strstr(b_buff, ".DAT")) ||
	     (tail2 = (char*)strstr(b_buff, ".GDB")))) 
	    {

	    head1 = tail1;
	    head2 = tail2;

#define FILECHAR(c) (((c) != ' ') && ((c) != '\'') && ((c) != '\"'))

	    /* Backup to the first character that we're sure 
	     * isn't a filename part */
	    while (tail1 > f_buff &&
		   FILECHAR (*(tail1-1)))
			tail1--;
	    while (tail2 > b_buff &&
		   FILECHAR (*(tail2-1)))
			tail2--;

	    /* Check from start of line to start of filename */
	    if ((tail1 - f_buff) != (tail2 - b_buff))
		goto have_difference;

	    if (strncmp (f_buff, b_buff, (tail1 - f_buff)))
		goto have_difference;

	    /* Scan past the .GDB extension & anything that follows
	     * that "looks like" a filename part.
	     */
	    while (*head1 &&
		    FILECHAR (*head1))
			head1++;
	    while (*head2 &&
		    FILECHAR (*head2))
			head2++;

	    /* Check from end of filename to end of line */
	    for (p = head1, q = head2; 
		 *p && *q && *p == *q;
		 p++, q++)
		continue;
	    }
    }
} while (*p == *q);

have_difference:

fclose (file);
gds__close_blob (status_vector, GDS_REF (blob));
return (eof_blob && eof_file) ? TRUE : FALSE;
}

static int compare_initialized (blob_id, test_name, run_name, global, version)
    ULONG    *blob_id;
    TEXT     *test_name, *run_name;
    SSHORT   global;
    TEXT     *version;
{
/**************************************
 *
 *      c o m p a r e _ i n i t i a l i z e d
 *
 **************************************
 *
 * Functional description
 *    When an initialization record exists.
 *    use the stored results for a comparison
 *    
 **************************************/
USHORT           result;
TEST_RESULT     test_result;

test_result = passed;

/*      Check to see if the test passed.  If it didn't then store the   *
 *      diff of the expected result with the actual result in the DB    */

if (!compare (blob_id, output_file, global))

{
	 test_result = failed;

	 printf ("*** failed ****\n");

/*      If not global then dump the initialization to the compare_file  */

	 if (!global)
	BLOB_TEXT_DUMP (blob_id, TCS, gds__trans, compare_file);
	 else
	BLOB_TEXT_DUMP (blob_id, TCS_GLOBAL, gds__trans, compare_file);

/*      Call do_diffs which is linked in at compile time, in order to   *
 *      do the actual diff.  Diff the expected result(compare_file)     *
 *      with the actual result(output_file) and put the diff in the     *
 *      diff_file.                                                      */

	 result = do_diffs (compare_file, output_file, diff_file, 0, 0, 0);

/*      Store the diff and output in the failure relation...            */

	 STORE F IN TCS.FAILURES USING
	gds__vtov (test_name, F.TEST_NAME, sizeof (F.TEST_NAME));
	gds__vtov (version, F.VERSION, sizeof (F.VERSION));
	gds__vtov (environment_name, F.ENV_NAME, sizeof (F.ENV_NAME));
	gds__vtov (boilerplate_name, F.BOILER_PLATE_NAME, sizeof (F.BOILER_PLATE_NAME));

/*      If the run_name is set then store the run name, else leave      *
 *      NULL.                                                           */

	if (NOT_NULL (run_name))

	{
		 gds__vtov (run_name, F.RUN, sizeof (F.RUN));
		 F.RUN.NULL = FALSE;
	}

	else
		 F.RUN.NULL = TRUE;

	if (!disk_io_error)
		 {
		 store_blob (&F.DIFFERENCES, TCS, gds__trans, diff_file);
		 F.DIFFERENCES.NULL = FALSE;
		 }
	else
		 F.DIFFERENCES.NULL = TRUE;

/*      Store the output in the failure relation.                       */

	if (result && !disk_io_error)
		 {
		 BLOB_TEXT_LOAD (&F.OUTPUT, TCS, gds__trans, output_file);
		 F.OUTPUT.NULL = FALSE;
		 }
	else
		 F.OUTPUT.NULL = TRUE;

	strcpy (F.DATE.CHAR[12], "NOW");
		END_STORE;

/*      If we do not have to save the files -- the '-s' is not set      *
 *      then clean them up.                                             */

	 if (!sw_save)

	 {
	unlink (compare_file);
	unlink (diff_file);
	 }
}

/*      The test passed!                                                */

else
	 printf ("passed\n");

/*      Commit          */

commit_retaining();

/*      Clean up again if the '-s' flag is not set.                     */

if (!sw_save)

{
	 unlink (script_file);
	 unlink (output_file);
}

return (test_result);
}
#else
/* !OLD_STYLE_DIFF */
static int compare (compare_file, output_file, global)
    TEXT        *compare_file;
    TEXT        *output_file;
    SSHORT      global;
{
/**************************************
 *
 *      c o m p a r e
 *
 **************************************
 *
 * Functional description
 *      Do a quick compare of two files.
 *      Return identical (TRUE) or difference
 *      (FALSE).
 *      I have changed this to compare
 *      two files instead of a blob
 *      and a file to be able to use 
 *      blobs with any segment length
 *      FSG 12.Nov.2000  
 **************************************/
FILE    *file,*blob_file;
STATUS  status_vector [20];
ULONG   *blob;
TEXT    f_buff [2048], b_buff [2048], *p, *q, c, lastc;
USHORT  eof_blob, eof_file;

/*      Check to make sure an output file exists.                       */

if (!(file = fopen (output_file, FOPEN_READ_TYPE)))
    return FALSE;

if (!(blob_file = fopen (compare_file, FOPEN_READ_TYPE)))
    return FALSE;

do 
{
    eof_blob = next_line (blob_file, b_buff, sizeof (b_buff));
    eof_file = next_line (file, f_buff, sizeof (f_buff));
    if (eof_blob || eof_file)
	break;


    /* Map multiple white space characters to single spaces */
    p = q = f_buff;
    lastc = 0;

    while (c = *p++)

    {
	if (c == '\t')
	    c = ' ';
	if (c != ' ' || lastc != ' ')
	    lastc = *q++ = c;
    }

    if (q != f_buff && *q == '\n')
	q--;
    if (q != f_buff && *q == ' ')
	q--;
    *q = 0;

    /* Map multiple white space characters to single spaces */
    p = q = b_buff;
    lastc = 0;

    while (c = *p++)

    {
	if (c == '\t')
	    c = ' ';
	if (c != ' ' || lastc != ' ')
	    lastc = *q++ = c;
    }

    if (q != b_buff && *q == '\n')
	q--;
    if (q != b_buff && *q == ' ')
	q--;
    *q = 0;

    /* Scan the lines for a difference */
    for (p = f_buff, q = b_buff; *p && *p == *q; p++, q++)
	continue;

    if (*p != *q) 
	{
	/* Difference found - check for trivial difference */
	char *head1,
	     *head2,
	     *tail1,
	     *tail2;

	/* if the lines both have a ".gdb" this ignore anything that
	 * "looks like" a filename 
	 * Note that some platforms have only UPCASE filenames
	 * This will fail for any lines that have TWO filenames on them.
	 *
	 *  Added 24-Jan-96:  Remove .dat, .gbk from files as well
	 */

	if (((tail1 = (char*)strstr(f_buff, ".gdb")) ||
	     (tail1 = (char*)strstr(f_buff, ".gbk")) ||
	     (tail1 = (char*)strstr(f_buff, ".GBK")) ||
	     (tail1 = (char*)strstr(f_buff, ".dat")) ||
	     (tail1 = (char*)strstr(f_buff, ".DAT")) ||
	     (tail1 = (char*)strstr(f_buff, ".GDB")))
	   &&
	    ((tail2 = (char*)strstr(b_buff, ".gdb")) ||
	     (tail2 = (char*)strstr(b_buff, ".gbk")) ||
	     (tail2 = (char*)strstr(b_buff, ".GBK")) ||
	     (tail2 = (char*)strstr(b_buff, ".dat")) ||
             (tail2 = (char*)strstr(b_buff, ".DAT")) ||
	     (tail2 = (char*)strstr(b_buff, ".GDB")))) 
	    {

	    head1 = tail1;
	    head2 = tail2;

#define FILECHAR(c) (((c) != ' ') && ((c) != '\'') && ((c) != '\"'))

	    /* Backup to the first character that we're sure 
	     * isn't a filename part */
	    while (tail1 > f_buff &&
		   FILECHAR (*(tail1-1)))
			tail1--;
	    while (tail2 > b_buff &&
		   FILECHAR (*(tail2-1)))
			tail2--;

	    /* Check from start of line to start of filename */
	    if ((tail1 - f_buff) != (tail2 - b_buff))
		goto have_difference;

	    if (strncmp (f_buff, b_buff, (tail1 - f_buff)))
		goto have_difference;

	    /* Scan past the .GDB extension & anything that follows
	     * that "looks like" a filename part.
	     */
	    while (*head1 &&
		    FILECHAR (*head1))
			head1++;
	    while (*head2 &&
		    FILECHAR (*head2))
			head2++;

	    /* Check from end of filename to end of line */
	    for (p = head1, q = head2; 
		 *p && *q && *p == *q;
		 p++, q++)
		continue;
	    }
    }
} while (*p == *q);

have_difference:

fclose (file);
fclose (blob_file);
return (eof_blob && eof_file) ? TRUE : FALSE;
}

static int compare_initialized (blob_id, test_name, run_name, global, version)
    ULONG    *blob_id;
    TEXT     *test_name, *run_name;
    SSHORT   global;
    TEXT     *version;
{
/**************************************
 *
 *      c o m p a r e _ i n i t i a l i z e d
 *
 **************************************
 *
 * Functional description
 *    When an initialization record exists.
 *    use the stored results for a comparison
 *    
 **************************************/
USHORT           result;
TEST_RESULT     test_result;

test_result = passed;

/*      Check to see if the test passed.  If it didn't then store the   *
 *      diff of the expected result with the actual result in the DB    */


/* Dump the initialization to file */
if (!global)
    BLOB_TEXT_DUMP (blob_id, TCS, gds__trans, compare_file);
else
    BLOB_TEXT_DUMP (blob_id, TCS_GLOBAL, gds__trans, compare_file);


/* and compare it with the test output */
if (!compare (compare_file, output_file, global))

{
	 test_result = failed;

	 printf ("*** failed ****\n");

/*      If not global then dump the initialization to the compare_file  */

/* 	As we have done this previously, this isn't necessary anymore */
 
/*	 if (!global)
 *	BLOB_TEXT_DUMP (blob_id, TCS, gds__trans, compare_file);
 *	 else
 *	BLOB_TEXT_DUMP (blob_id, TCS_GLOBAL, gds__trans, compare_file);
*/

/*      Call do_diffs which is linked in at compile time, in order to   *
 *      do the actual diff.  Diff the expected result(compare_file)     *
 *      with the actual result(output_file) and put the diff in the     *
 *      diff_file.                                                      */

	 result = do_diffs (compare_file, output_file, diff_file, 0, 0, 0);

/*      Store the diff and output in the failure relation...            */

	 STORE F IN TCS.FAILURES USING
	gds__vtov (test_name, F.TEST_NAME, sizeof (F.TEST_NAME));
	gds__vtov (version, F.VERSION, sizeof (F.VERSION));
	gds__vtov (environment_name, F.ENV_NAME, sizeof (F.ENV_NAME));
	gds__vtov (boilerplate_name, F.BOILER_PLATE_NAME, sizeof (F.BOILER_PLATE_NAME));

/*      If the run_name is set then store the run name, else leave      *
 *      NULL.                                                           */

	if (NOT_NULL (run_name))

	{
		 gds__vtov (run_name, F.RUN, sizeof (F.RUN));
		 F.RUN.NULL = FALSE;
	}

	else
		 F.RUN.NULL = TRUE;

	if (!disk_io_error)
		 {
		 store_blob (&F.DIFFERENCES, TCS, gds__trans, diff_file);
		 F.DIFFERENCES.NULL = FALSE;
		 }
	else
		 F.DIFFERENCES.NULL = TRUE;

/*      Store the output in the failure relation.                       */

	if (result && !disk_io_error)
		 {
		 BLOB_TEXT_LOAD (&F.OUTPUT, TCS, gds__trans, output_file);
		 F.OUTPUT.NULL = FALSE;
		 }
	else
		 F.OUTPUT.NULL = TRUE;

	strcpy (F.DATE.CHAR[12], "NOW");
		END_STORE;

/*      If we do not have to save the files -- the '-s' is not set      *
 *      then clean them up.                                             */

	 if (!sw_save)

	 {
  	 unlink (diff_file);
	 }
}

/*      The test passed!                                                */

else
	 printf ("passed\n");

/*      Commit          */

commit_retaining();

/*      Clean up again if the '-s' flag is not set.                     */

if (!sw_save)

{
         unlink (compare_file);
	 unlink (script_file);
	 unlink (output_file);
}

return (test_result);
}

#endif

static int contains (s1, s2)
    TEXT        *s1, *s2;
{
/**************************************
 *
 *      c o n t a i n s
 *
 **************************************
 *
 * Functional description
 *      See if string s1 contains string s2.
 *      By convention, all strings contain the
 *      null string.
 *
 **************************************/
TEXT    *q, *p, *start, *end;
SSHORT  l;

l = strlen (s2);

for (p = start = s1, end = s1 + strlen (s1); 
	p + l <= end; p = ++start)
    {
    for (q = s2; *q; q++)
	if (*p++ != *q)
	    break;
    if (!*q)
	return TRUE;
    }
return FALSE;
}

#ifndef VMS
static int execute_apollo (script_file, output_file)
    TEXT    *script_file, *output_file;
{
/**************************************
 *
 *      e x e c u t e _ a p o l l o  
 *
 **************************************
 *
 * Functional description
 *        run a command file with attendant
 *        data files.  
 **************************************/
TEXT    buffer [512];
USHORT  result;

#if (defined WIN_NT || defined OS2_ONLY)
/*  This is necessary in case the mks option '-m' is set on NT.  *
 *  MKS_CMD_STRING is #define'd in tcs.h.                        */

if (sw_nt_mks)
    sprintf (buffer, MKS_CMD_STRING, script_file, output_file);
else    
#endif

/*      Move in appropriate execute string to buffer and then system()  *
 *      as appropriate.                                                 */ 

sprintf (buffer, CMD_STRING, script_file, output_file);

#ifdef apollo
    for (result = SIGALRM; result == SIGALRM; result = system (buffer))
	;
#else
system (buffer);
#endif

/*      If received SIGINT then print message and return FALSE          */

if (quit)

{
    printf (" aborted\n");
    return FALSE;
}

return TRUE;
}          
#endif
      
#ifdef VMS
static execute_vms (script_file, command_line, output_file)
    TEXT        *script_file, *command_line, *output_file;
    
{
/**************************************
 *
 *      e x e c u t e _ v m s
 *
 **************************************
 *
 * Functional description
 *      
 *     using VMS methods run an operating
 *     system command.  should work with or
 *     without an output file
 **************************************/
struct  dsc$descriptor_s        desc1, desc2, desc3;
UCHAR    event_flag;
ULONG   status, return_status, mask;

if (script_file)
    make_desc (script_file, &desc1);
if (command_line)
    make_desc (command_line, &desc2);    
if (output_file)
    make_desc (output_file, &desc3);

return_status = 0;
event_flag = 32;
mask = 1;

status = lib$spawn (
	((command_line) ? &desc2 : NULL),       /* Command to be executed */
	((script_file) ? &desc1 : NULL),        /* Command file */
	((output_file) ? &desc3 : NULL),        /* Output file */
	&mask,                  /* sub-process characteristics mask */
	NULL,                   /* sub-process name */
	NULL,                   /* returned process id */
	&return_status,         /* completion status */
	&event_flag);           /* event flag for completion */

if (status & 1)
    {
    while (!return_status)
	sys$waitfr (event_flag);
    if (!(return_status & 1))
	lib$signal (status);
    }

else
    lib$signal (status);

return TRUE;
}
#endif          

static int fail_uninit (testname, run_name, version)
    TEXT    *testname, *run_name, *version;
{
/**************************************
 *
 *      f a i l _ u n i n i t
 *
 **************************************
 *
 * Functional description
 *
 *    Fail a test just because no init record exists
 **************************************/
STATUS          status_vector[20];

printf("*** failed -- uninitialized\n");
print_error ("Test %s is uninitialized for version <= %s.\n", testname, version,0);

/*      Store failed output in the output field of the failures         *
 *      relation.                                                       */

STORE F IN TCS.FAILURES USING
    gds__vtov (testname, F.TEST_NAME, sizeof (F.TEST_NAME));
    gds__vtov (version, F.VERSION, sizeof (F.VERSION));

/*      If run_name is set then store it, else set to NULL              */

    if (NOT_NULL (run_name))
    {
	gds__vtov (run_name, F.RUN, sizeof (F.RUN));
	F.RUN.NULL = FALSE;
    }

    else
	F.RUN.NULL = TRUE;

    BLOB_TEXT_LOAD (&F.OUTPUT, TCS, gds__trans, output_file);
    strcpy (F.DATE.CHAR[12], "NOW");

END_STORE
ON_ERROR
    print_error ("FAILURE RECORD STORE FAILED\n",0,0,0);
    gds__print_status (status_vector);
    return test_system_failed;
END_ERROR;

/*      Display the failed output.                                      *
 *      NOTE:  We do not have diff because the expected output is not   *
 *      known.                                                          */

FOR FIRST 1 F IN TCS.FAILURES WITH F.RUN = run_name AND
F.TEST_NAME = testname SORTED BY DESC F.DATE
   disp_print_blob (&F.OUTPUT, TCS);
END_FOR;

/*      Commit          */

commit_retaining();

/*      If we don't have to save the files, then clean up...            */

if (!sw_save)

{
    unlink (script_file);
    unlink (output_file);
}

return failed_noinit;
}

#ifdef VMS
static make_desc (string, desc)
    TEXT        *string;
    struct dsc$descriptor_s     *desc;
{
/**************************************
 *
 *      m a k e _ d e s c
 *
 **************************************
 *
 * Functional description
 *      Fill in a VMS descriptor with a null terminated string.
 *
 **************************************/

desc->dsc$b_class = DSC$K_CLASS_S;
desc->dsc$b_dtype = DSC$K_DTYPE_T;
desc->dsc$w_length = strlen (string);
desc->dsc$a_pointer = string;

return desc;
}
#endif

static int next_line (file, buffer, buff_len)
    FILE                *file;
    TEXT                *buffer;
    USHORT              buff_len;
{
/**************************************
 *
 *      n e x t _ l i n e
 *
 **************************************
 *
 * Functional description
 *      Get the line from a file  and
 *      return it as a null terminated string.
 *      Skip uninteresting lines.  Return TRUE
 *      at end of file.
 *
 **************************************/
int     eof;
PITA    nuisance, end;
USHORT  skip;

skip = 0;

do {

    eof = ! fgets (buffer, buff_len, file);

    for ( nuisance = nuisances, end = nuisance + sizeof (nuisances);
	  nuisance < end && !skip; nuisance++)
	    if (contains (buffer, nuisance->line)) {
		skip = nuisance->skip;
		break;
	    }
} while (!eof && skip--);

return feof(file);
    
}

static int next_segment (blob, buffer, buff_len)
	 ULONG               *blob;
	 TEXT                *buffer;
	 USHORT              buff_len;
{
/**************************************
 *
 *      n e x t _ s e g m e n t
 *
 **************************************
 *
 * Functional description
 *      Read a blob segment and check for boring
 *      lines.  Return true if we hit the end before
 *      finding anything interesting.
 *
 **************************************/
int     eob;
PITA    nuisance, end;
USHORT  skip;

skip = 0;

do {

    eob = read_segment (blob, buffer, buff_len);

    for ( nuisance = nuisances, end = nuisance + sizeof (nuisances);
	  nuisance < end && !skip; nuisance++)
	if (contains (buffer, nuisance->line)) {
	    skip = nuisance->skip;
	    break;
	}
    
} while (!eob && skip--);

return eob;

}

static ULONG *open_blob (blob_id, db_handle)
    SLONG       *blob_id;
    ULONG        *db_handle;
{
/**************************************
 *
 *      o p e n _ b l o b
 *
 **************************************
 *
 * Functional description
 *      Open a blob and check the status.  If everything is ok,
 *      return the blob handle, else NULL.
 *
 **************************************/
ULONG   *blob;
STATUS  status_vector [20];

blob = NULL;

if (!gds__open_blob (GDS_NULL, 
	GDS_REF (db_handle), 
	GDS_REF (gds__trans), 
	GDS_REF (blob), 
	GDS_VAL (blob_id)))
    return blob;

return NULL;
}

static int read_segment (blob, buffer, buff_len)
    ULONG               *blob;
    TEXT                *buffer;
    USHORT              buff_len;
{
/**************************************
 *
 *      r e a d _ s e g m e n t
 *
 **************************************
 *
 * Functional description
 *      Get the next segment from a blob and
 *      put it in the calling routines buffer
 *      as a NULL terminated string.
 *      return TRUE at eof FALSE more to come
 *
 **************************************/
TEXT    *ptr;
STATUS  status_vector[20];
USHORT  seg_length;

buff_len--;

ptr = buffer;
do {
    gds__get_segment (status_vector,  GDS_REF (blob),
	GDS_REF (seg_length), buff_len,
	GDS_VAL (ptr));
    if (status_vector [1] && status_vector [1] != isc_segment)
	if (status_vector [1] == isc_segstr_eof)
	    return TRUE;
	else {
	    gds__print_status (status_vector);
	    exit (1); 
	}
    buff_len -= seg_length;
    ptr += seg_length;
} while ( ptr[-1] != '\n' && buff_len > 0);

*ptr = 0;
return FALSE;
}

static int run (blob_id, db_handle, script_file, output_file, run_time, sw_no_system, file_count)
    ULONG       *blob_id, *db_handle, *run_time;
    TEXT        *script_file, *output_file;
    USHORT      sw_no_system;
    int         *file_count;
{
/**************************************
 *
 *      r u n
 *
 **************************************
 *
 * Functional description
 *      Map a blob into a set of script files and run them.
 *
 **************************************/
FILE    *script;
USHORT  success, n;
TEXT    data_file [15];
TEXT    out_line[BUFSIZE];
SLONG           clock;
struct tm       times1, times2;

n = 0;

/*      Open script file                                                */

if (!(script = fopen (script_file, "w")))

{
    print_error ("Can't create file \"%s\"\n", script_file,0,0);
    disk_io_error = TRUE;
    return FALSE;
}

/*      Dump boilerplate, if any, into script file                      */

FOR B IN TCS.BOILER_PLATE WITH B.BOILER_PLATE_NAME = boilerplate_name
    FOR S IN B.SCRIPT
	strncpy(out_line, S.SEGMENT, S.LENGTH);
	out_line[S.LENGTH] = '\0';
	handle_sys_env(out_line);
	if (fprintf(script,"%s",out_line) == EOF)
	    {
	    print_error ("IO error on write to \"%s\"\n", script_file,0,0);
	    (void) fclose (script);
	    disk_io_error = TRUE;
	    return FALSE;
	    };
    END_FOR;
END_FOR;

/*      Copy blob to script file, counting data files as created.       */

#ifdef VMS
success = script_vms (blob_id, db_handle, script);
#else
success = script_apollo (blob_id, db_handle, script, &n);
#endif

fclose (script);

/*      If we failed at creating script file return FALSE               */

if (!success)
    return FALSE;

/*      Run the script                                                  */ 

/*      If the no run flag is set ('-n') then return before executing   *
 *      the script files.                                               */

if (sw_no_system)
{
    *file_count = n;
    return TRUE;
}

success = FALSE;

/*      If the '-t' flag is set then save the time.                     */

if (sw_times)

{
    clock = time (NULL);
    times1 = *localtime (&clock);
}

/*      Execute the script...                                           */

#ifdef VMS
success = execute_vms (script_file, NULL, output_file);
#else
success = execute_apollo (script_file, output_file);
#endif  

/*      Calculate time it took to run the test...                       */

if (sw_times)

{
    clock = time (NULL);
    times2 = *localtime (&clock);

/*      handle test running through midnight, but bag multi day test    */

    if (times2.tm_mday != times1.tm_mday)

    {
	*run_time = (60 - times1.tm_sec) + (60 - times1.tm_min) * 60
	       + (24 - times1.tm_hour) * 3600;
	*run_time += times2.tm_sec + times2.tm_min * 60
	       + times2.tm_hour * 3600;
    }

    else
	*run_time = (times2.tm_sec - times1.tm_sec) + (times2.tm_min - times1.tm_min) * 60
	       + (times2.tm_hour - times1.tm_hour) * 3600;
}

/*      Delete unwanted data files, if the '-s' save files switch is     *
 *      not thrown.                                                      */

if (!sw_save)

{
    while (n)

    {
	sprintf (data_file, DAT_FILE, --n);
	unlink (data_file);
    }
}

/*      If executing the test was not successful, return FALSE          */

if (!success)
    return FALSE;

/*      If we received a SIGINT then return FALSE.                      */

if (quit)

{
    printf (" aborted\n");
    return FALSE;
}

return TRUE;
}

#ifndef VMS
static int script_apollo (blob_id, db_handle, script, n)
	 ULONG       *blob_id;
	 ULONG        *db_handle;
	 FILE        *script;
	 USHORT       *n;
{
/**************************************
 *
 *      s c r i p t _ a p o l l o
 *
 **************************************
 *
 * Functional description
 *
 *      Apollo specific script parsing
 *      routine
 *      This returns TRUE if datafiles were opened or FALSE if none are opened.
 *      Number of files opened is returned via n counter.
 *      Datafile naming remains 0 based as to change it would change the results of
 *      a number of already initializd tests
 *      buffer lines to hand to ptsltrns/ptsl2ap
 *      which necessitates some fancy \n handling in the
 *      file building : we don't know whether we have a
 *      data file to open or close until we read the next line
 *
 **************************************/
ULONG   *blob;
FILE    *data;
USHORT  command, file_open, cmdcount, count, linetype;
TEXT    *buff, *c, buffer [BUFSIZE], result[BUFSIZE], data_file [32];
TEXT    streambuff[1024];
BSTREAM *input;
SSHORT  ch;

file_open = command = FALSE;
cmdcount = 0;

/*      Call open_blob() to see if we have a valid blob_id/db_handle    */

if (NULL == (blob = open_blob (blob_id,db_handle)))
		return FALSE;

/*      Open the blob                                                   */

input = BLOB_open (blob, streambuff, sizeof (streambuff));

/*      Loop on every character until we get to the end of the file     */

while ((ch = getb (input)) != EOF)

{
	 count = BUFSIZE;
	 buff = buffer;

/*      Loop on every character -- moving a line of text into buff      */

	 while (ch != EOF)

	 {

/*      If we hit a new line character or we max out on the buffer      *
 *      size, then stop moving SCHAR's into ch and exit the loop.       */

	if (((*buff++ = (SCHAR)ch) == '\n') || (!--count))
		 break;
	  ch = getb (input);
	 }

/*      Assign a NULL character to the end of the text in buff.         */
	 *buff = 0;

/*      Call PTSL_2ap() to check for '$' verbs in the line and process  *
 *      them properly.  If not successful processing the line the       *
 *      close up shop and return false.                                 */

	 handle_sys_env(buffer);
	 if (!(linetype = PTSL_2ap (buffer, result)))
	 {

		if (file_open == TRUE)
			 fclose (data);

		 fclose (script);
		 BLOB_close (input);
		 return FALSE;
	 }

/*      If we are processing a TCS environment variable definition,     *
 *      PTSL_2ap() already finished processing the line, so move to     *
 *      the next line.                                                  */

	 if (linetype == SYMDFN)
		 continue;

/*      Copy blob to script file, making data files where required.     */

	 c = result;
	 if (linetype == CMD)

	 {
	  while ((*c == ' ') ||
			 (*c == '\t') ||
			 (*c == '$'))
		 c++;

/*      Since we are processing a '$' verb then we must be done dumping *
 *      a data file, so if one is open close it.                        */

	if (file_open)

	{
		 fclose (data);
		 file_open = FALSE;
	}
	else if (command)
		  {
			 if (putc ('\n',script) == EOF)
			 {
				print_error ("IO error on write to \"%s\"\n", script_file,0,0);
				if (file_open)
				 (void) fclose (data);

				(void) fclose (script);
				BLOB_close (input);
				disk_io_error = TRUE;
				return FALSE;
		    }
		 }

	command = TRUE;         /* Set command flag to TRUE...  */
	cmdcount++;             /* Increment cmdcount... */

/*      Throw the rest of the line in the file.                         */

	while (*c != '\n')
		 if (putc ((unsigned char)*c++, script) == EOF)
		{
		  print_error ("IO error on write to \"%s\"\n", script_file,0,0);
		  if (file_open)
			  (void) fclose (data);

		(void) fclose (script);
		BLOB_close (input);
		disk_io_error = TRUE;
		return FALSE;
		}
	 }

/*      If processing something besides a command or environment        *
 *      variable definition, i.e. plain text -- put in data file.       */

	 else

	 {

/*      If we just finished processing a command then we need to create *
 *      and open a new data file, so do it.                             */

	  if (command)

	  {
		 sprintf (data_file, DAT_FILE, (*n)++);
#ifndef mpexl
		 if (fprintf (script, "<%s\n", data_file) == EOF)
#else
		 if (fprintf (script, " \"<%s\"\n", data_file) == EOF)
#endif
		{
		print_error ("IO error on write to \"%s\"\n", script_file,0,0);
		(void) fclose (script);
		disk_io_error = TRUE;
		return FALSE;
		};

/*      Try to open the data file with the appropriate number.          */

		if (!(data = fopen (data_file, FOPEN_WRITE_TYPE)))

		 {
			print_error ("Can't create file \"%s\"\n", data_file,0,0);
			fclose (script);
			BLOB_close (input);
			disk_io_error = TRUE;
		   return FALSE;
		 }

		 if (fputs (c, data) == EOF) /* Dump to the data file.               */
		 {
			print_error ("IO error on write to \"%s\"\n", data_file,0,0);
			(void) fclose (data);
			(void) fclose (script);
			BLOB_close (input);
			disk_io_error = TRUE;
		   return FALSE;
		}
	    command = FALSE;    /* Set the command flag to FALSE        */
	    file_open = TRUE;   /* Set the file_open flag to TRUE       */
	}

/*      If we are processing a data file then dump into it.             */

	else if (cmdcount)
	    {
	    if (fputs (c, data) == EOF)
		{
		print_error ("IO error on write to \"%s\"\n", data_file,0,0);
		(void) fclose (data);
		(void) fclose (script);
		BLOB_close (input);
		disk_io_error = TRUE;
		return FALSE;
		}
	    }
    }
}       

/*      Finished processing, so clean up.  If a command was the last    *
 *      thing we processed then put a new line at the end.  If we       *
 *      just finished with a data file then close it.                   */

if (command)
	 if (putc ('\n', script) == EOF)
	{
	print_error ("IO error on write to \"%s\"\n", script_file,0,0);
	if (file_open)
		 (void) fclose (data);

	(void) fclose (script);
	BLOB_close (input);
	disk_io_error = TRUE;
	return FALSE;
	}

if (file_open)
	 fclose (data);

BLOB_close (input);

return cmdcount;
}
#endif

#ifdef VMS
static  script_vms (blob_id, db_handle, script)
	 SLONG       *blob_id;
	 ULONG        *db_handle;
	 FILE        *script;
{
/**************************************
 *
 *      s c r i p t _ v m s
 *
 **************************************
 *
 * Functional description
 *      VMS specific script parsing routine.
 *
 **************************************/
ULONG   *blob;
SSHORT  c;
TEXT    *l, *r, linebuf[256], resbuf[256];
int     linetype;
BSTREAM *input;
TEXT    buffer [512];

if (NULL == (blob = open_blob (blob_id,db_handle)))
	 return FALSE;

/*      Copy blob to script file.                                       */

input = BLOB_open (blob, buffer, sizeof (buffer));
l = linebuf;

/*      Loop through the entire blob, dumping all of the output text    *
 *      to one script file.                                             */

while ((c = getb (input)) != EOF)

{
	 *l++ = (TEXT)c;

/*      If we have read an entire line into linebuf, process the line   */

	 if (c == '\n')

	 {
	*l = 0;
	linetype = PTSL_2ap(linebuf, resbuf);
	r = resbuf;
	l = linebuf;

/*      If we are processing a command or text then dump to the file,   *
 *      A symbol definition -- environment variable definition will     *
 *      be handled by PTSL_2ap() and not dumped to the file.            */

	if ((linetype == CMD) || (linetype == REGTXT))
	    while (*r)
		if (putc ((unsigned char)*r++, script) == EOF)
		    {
		    print_error ("IO error on write to script\n", 0,0,0);
		    BLOB_close (input);
		    disk_io_error = TRUE;
		    return FALSE;
		    }
    }
}

BLOB_close (input);

return TRUE;
}         
#endif

#if (defined WIN_NT || defined OS2_ONLY)
set_script_file()
{
/**************************************
 *
 *      s e t _ s c r i p t _ f i l e
 *
 **************************************
 *
 * Functional description
 *      This is called from parse_main_args
 *      in tcs.e if '-m' command line option
 *      is set.  This sets the filename to
 *      an "mks" proper filename.
 *
 *      NOTE:  This function is necessary 
 *             because script_file is a global
 *             with scope limited to this file.
 *
 **************************************/
strcpy (script_file, mks_script_file);
return TRUE;
}
#endif

static int store_blob (blob_id, db_handle, tr_handle, file_name)
    ULONG       *blob_id, *db_handle, *tr_handle;
    TEXT        *file_name;
{
/**************************************
 *
 *      s t o r e _ b l o b 
 *
 **************************************
 *
 * Functional description
 *      Store a blob, screening out boring lines. This
 *      should not be used for storing template or complete
 *      output records since they should contain everything
 *      produced.  However, differences are screened.
 *
 **************************************/
ULONG   *blob;
STATUS  status_vector[20]; 
FILE    *input_file;
TEXT    buffer [512];
USHORT  eof_file;

if (!(input_file = fopen (file_name, FOPEN_READ_TYPE)))
    return FALSE;

blob = NULL;
if (gds__create_blob (status_vector, GDS_REF (db_handle),
	GDS_REF (tr_handle), GDS_REF (blob), GDS_VAL (blob_id)))
    {
    gds__print_status (status_vector);
    fclose (input_file);
    return FALSE;
    }

while (!(eof_file = next_line (input_file, buffer, (SSHORT) sizeof (buffer))))
    if (gds__put_segment (status_vector, GDS_REF (blob), 
		(SSHORT) strlen (buffer), buffer))
	{
	gds__print_status (status_vector);
	break;
	}

fclose (input_file);
gds__close_blob (status_vector, GDS_REF (blob));
return (eof_file) ? TRUE : FALSE;
}    
