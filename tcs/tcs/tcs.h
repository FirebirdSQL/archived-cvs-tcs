/*
 *      PROGRAM:        Test Control System
 *      MODULE:         tcs.h
 *      DESCRIPTION:    Main Module for test control system.
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

#include <stdio.h>
#include <ctype.h>
#ifndef mpexl
#include <signal.h>
#else
#include "../jrd/mpexl.h"
#endif
/* #include "source/jrd/common.h" */
/* #include "source/jrd/time.h" */

#ifndef mpexl
#define PROLOG_FILE     "tcsedit.tmp"
#else
#define PROLOG_FILE     "tcsedit.temp"
#endif

#ifdef APOLLO
#define CMD_STRING      "/bin/sh %s >%s 2>&1"   
#define DAT_FILE        "tcs.data%d"
#define SHELL           "/bin/sh"
#define COMPARE_STRING  "%s %s %s %s -i"
#define COMPARE         "isc_diff"
#define GDS_NULL        *gds__null
#endif

#ifdef VMS
#include descrip
#define DBB_NAME2       "gtcs.gdb"
#define DBB_NAME        "gds_tests:ltcs.gdb"
#define GDS_NULL        0
#define COMPARE_STRING  "%s %s %s %s -i"
#define COMPARE         "isc_diff"
#define DAT_FILE        "tcsdata.%d"
#define FINI_OK         1
#define FINI_ERROR      44
#endif

#ifdef PC_PLATFORM
#define CMD_STRING      "%s > %s 2>&1"
#define COMPARE_STRING  "%s %s %s %s -i"
#define DAT_FILE        "tcsdata.%d"
#define COMPARE         "diff"
#define GDS_NULL        0L
#define NULL            0L /* is this a barbarism? */
#endif

#if (defined UNIX || defined LINUX)
#define CMD_STRING      "/bin/sh %s >%s 2>&1"   
#define DAT_FILE        "tcs.data%d"
#define SHELL           "/bin/sh"
#define COMPARE_STRING  "%s %s %s %s -i"
#define COMPARE         "isc_diff"
#define GDS_NULL        0       
#endif

#if (defined WIN_NT || defined OS2_ONLY)
#define CMD_STRING      "%%ComSpec%% /c %s > %s 2>&1"
#define COMPARE_STRING  "%s %s %s %s -i"
#define DAT_FILE        "tcs.data%d"
#define COMPARE         "diff"
#define GDS_NULL        0L
#define MKS_CMD_STRING  "sh -L -c \"%s > %s 2>&1\""

#define BLOB_TEXT_LOAD  BLOB_text_load
#define BLOB_TEXT_DUMP  BLOB_text_dump
#endif

#ifdef mpexl
#define CMD_STRING      "tcsexecute %s %s"
#define DAT_FILE        "tcs%d.data"
#define SHELL           ""
#define COMPARE_STRING  "%s;info=/"%s %s %s -i/""
#define COMPARE         "iscdiff"
#define GDS_NULL        0
#endif

#ifdef hpux
#ifdef HP10
#define DBB_NAME        "tests/hu_ltcs.gdb"
#else
#ifdef hp9000s300
#define DBB_NAME        "tests/h3_ltcs.gdb"
#else
#define DBB_NAME        "tests/hp_ltcs.gdb"
#endif
#endif
#endif

#ifdef DGUX
#ifdef DA
#define DBB_NAME        "tests/da_ltcs.gdb"
#endif
#endif

#ifdef IMP
#define DBB_NAME        "tests/im_ltcs.gdb"
#endif

#ifdef DELTA
#define DBB_NAME        "tests/dl_ltcs.gdb"
#define DBB_NAME2       "jedi:/usr/gds/tests/gtcs.gdb"
#endif

#ifdef apollo
#ifdef SR95
#define DBB_NAME        "tests/ad_ltcs.gdb"
#else
#if _ISP__A88K
#define DBB_NAME        "tests/ap_ltcs.gdb"
#else
#define DBB_NAME        "tests/ax_ltcs.gdb"
#endif
#endif
#endif

#ifdef sun
#ifdef sparc
#ifdef SOLARIS
#define DBB_NAME        "tests/so_ltcs.gdb"
#else
#define DBB_NAME        "tests/s4_ltcs.gdb"
#endif
#else
#ifdef I386
#define DBB_NAME        "tests/si_ltcs.gdb"
#else
#define DBB_NAME        "tests/s3_ltcs.gdb"
#endif
#endif
#endif

#ifdef ultrix
#ifdef mips
#define DBB_NAME        "tests/mu_ltcs.gdb"
#else
#define DBB_NAME        "tests/ul_ltcs.gdb"
#endif
#endif

#ifdef AIX
#define DBB_NAME        "tests/ia_ltcs.gdb"
#endif

#ifdef AIX_PPC
#define DBB_NAME        "tests/pa_ltcs.gdb"
#endif

#ifdef DECOSF
#define DBB_NAME        "tests/ao_ltcs.gdb"
#endif

#ifdef M88K
#define DBB_NAME        "tests/m8_ltcs.gdb"
#endif

#ifdef sgi
#define DBB_NAME        "tests/sg_ltcs.gdb"
#endif

#ifdef PC_PLATFORM
#define DBB_NAME        "/gds/tests/ms_ltcs.gdb"
#define DBB_NAME2       "/gds/tests/gtcs.gdb"
#endif

#ifdef SCO_UNIX
#define DBB_NAME        "tests/sc_ltcs.gdb"
#endif

#ifdef OS2_ONLY
#define DBB_NAME        "/gds/tests/os2_ltcs.gdb"
#define DBB_NAME2       "jedi:/usr/gds/tests/gtcs.gdb"
#endif

#ifdef WIN_NT
#define DBB_NAME        "/gds/tests/nt_ltcs.gdb"
#define DBB_NAME2       "jedi:/usr/gds/tests/gtcs.gdb"
#endif

#ifdef mpexl
#define DBB_NAME        "hxltcs.gdb.tcs"
#define DBB_NAME2       "hxgtcs.gdb.tcs"
#endif

#ifdef DG_X86
#define DBB_NAME	"tests/di_ltcs.gdb"
#endif

#ifdef LINUX
#define DBB_NAME	"tests/li_ltcs.gdb"
#endif

#ifndef DBB_NAME
#define DBB_NAME        "tests/ltcs.gdb"
#endif

#ifndef DBB_NAME2
#define DBB_NAME2       "tests/gtcs.gdb"
#endif

#ifndef BLOB_TEXT_LOAD
#define BLOB_TEXT_LOAD  BLOB_load
#endif

#ifndef BLOB_TEXT_DUMP
#define BLOB_TEXT_DUMP  BLOB_dump
#endif

#define NULL_STR(s)             (!(s) || !*(s))
#define NOT_NULL(s)             ((s) && *(s))

#define FALSE   0
#define TRUE    1

typedef short           SSHORT;
typedef unsigned short  USHORT;
#ifndef WIN_NT
typedef unsigned short  BOOLEAN;
#endif
typedef long            SLONG;
typedef unsigned long   ULONG;
typedef char            TEXT;
/*typedef signed char     SCHAR; */
typedef char     SCHAR;
typedef unsigned char   UCHAR;
typedef long            STATUS;

extern TEXT	*script_file;
extern TEXT	*output_file;
extern TEXT	*compare_file;
extern TEXT	*info_file;
extern TEXT	*diff_file;

#if (defined WIN_NT || defined OS2_ONLY)

extern TEXT   *mks_script_file;

#endif

/* externing the entry points */

#define CMD           1        /* line type for commands */
#define SYMDFN        2        /* line type for symbol definitions */
#define NOXCMD        3        /* line type for non translated commands */
#define REGTXT        4        /* line type for regular text */
#define BUFSIZE    1024        /* max input line length */

/* Miscellaneous constants */

#define TCS_NAME                "tcs"
#define BOILERPLATE_NAME        "DEFAULT"
#define TCS_CONFIG              ".tcs_config"
#define MAX_LINE                80
#define TCS_VERSION             "V4.16   29-Jan-1998"
#define MISSING_ARG             "-"
#define DEFAULT_VERSION         "004005000"
#define DEFAULT_RUN_NAME        "DEFAULT"
#define MAX_UPPER               32000
#ifdef VMS
#define LIST_CMDS_TMP           "SYS$SCRATCH:tcslistcmds.tmp"
#else
#ifdef WIN_NT
#define LIST_CMDS_TMP           "/temp/tcslistcmds.tmp"
#else
#define LIST_CMDS_TMP           "/tmp/tcslistcmds.tmp"
#endif
#endif

/* Note: NT needs LIST_CMDS_TMPNT to be the same as
	 LIST_CMDS_TMP except that the "/" must be
	 "\\".  This is only used for removing the
	 file after help has completed. */

#ifdef WIN_NT
#define LIST_CMDS_TMPNT         "\\temp\\tcslistcmds.tmp"
#endif
#ifdef OS2_ONLY
#define LIST_CMDS_TMPNT         "\\tmp\\tcslistcmds.tmp"
#endif




/* Test result codes */

typedef enum test_result {
   passed = 0,

   test_system_failed,

   failed,
   failed_known,
   failed_noinit,

   skipped,
   skipped_notfound,
   skipped_flagged,

   unknown_result

} TEST_RESULT;

#define NUM_RESULTS (((int)(unknown_result - passed)) + 1)


/* External functions declarations for NT */
#if (defined WIN_NT || defined OS2_ONLY)
  extern void handle_where_gdb(TEXT* buffer);
  extern void handle_sys_env(char* in_line);
  extern	print_error (TEXT*, TEXT*, TEXT*, TEXT*);
  
  extern USHORT   sw_nt_mks;
  extern USHORT   sw_nt_bash;
#endif

#ifndef FINI_OK
#define FINI_OK         0
#define FINI_ERROR      1
#endif

#define NULL_PTR        ((void*) 0)
#define gds__dpb_version1                  1
#define gds__dpb_user_name                 28
#define gds__dpb_password                  29

#if (defined(__IBMC__) && defined(__OS2__)) || (defined(__BORLANDC__) && defined(__OS2__))
#ifdef __IBMC__
#define CLIB_ROUTINE    _Optlink
#else
#define CLIB_ROUTINE    __stdcall
#endif
#endif

#if (defined(_MSC_VER) && defined(WIN32)) || (defined(__BORLANDC__) && defined(__WIN32__))
#define CLIB_ROUTINE    __cdecl
#endif

#ifndef CLIB_ROUTINE
#define CLIB_ROUTINE
#endif

#define UPPER(c)                (((c) >= 'a' && (c)<= 'z') ? (c) - 'a' + 'A' : (c))

#ifndef MAX
#define MAX(a,b)                (((a) > (b)) ? (a) : (b))
#endif
#ifndef MIN
#define MIN(a,b)                (((a) < (b)) ? (a) : (b))
#endif

#ifndef apollo
#define GDS_VAL(val)    val
#define GDS_REF(val)    &val
#else
#define GDS_VAL(val)    (*val)
#define GDS_REF(val)    val
#endif

