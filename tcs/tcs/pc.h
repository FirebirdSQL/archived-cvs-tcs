/*
 *	PROGRAM:	Test Control System
 *	MODULE:		pc.h
 *	DESCRIPTION:
 *
 *	These are system-specific declarations for OS/2 and for NT systems
 *	to aid in modifying command lines in tests.
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

static TEXT *defaults[] =
	{
	NULL,
	NULL,
	NULL,
#if (defined WIN_NT || defined OS2_ONLY)
	NULL,
#else
	" -c -Alfu -G2 -W0 -Zi -DDLL %s\n",
#endif
	NULL,
	NULL,
	NULL,
	NULL,
#if (defined WIN_NT || defined OS2_ONLY)
	NULL,
#else
	" \\msc\\lib\\crtexe %s /STACK:20000 /SE:200 /NOI /CO , %s , , crtlib os2 gdslib dsqllib /NOD ; \n",
#endif
	NULL
	};

static struct defn extensions[] =
	  {
		{ "", "" }
	  };

static TEXT *link_ext[] =
	 {
	 ".obj",
	 " ",
	 ".obj",
	 ".obj",
	 ".obj",
	 ".obj",
	 ".obj",
	 ".obj",
	 ".obj",
	 ".obj"
	 };

/* Define the replacement table for NT and OS/2 when the '-m'(mks) switch
	is thrown. */

#if (defined WIN_NT || defined OS2_ONLY)
static struct mks_cmd {
	 SCHAR	*ptsl_cmds;
	 SCHAR	*mks_equiv;
	 SCHAR	*help_text;
} mks_replacement[] =
	 {
		{ "COPY",	"cp ",	 "\t\t\"cp\""          },
		{ "DEL",	   "rm -f", "\t\t\"rm -f\""        },
		{ "DELETE",	"rm -f", "\t\t\"rm -f\""        },
		{ "DIR",	   "ls ",   "\t\t\"ls\""           },
		{ "DIRECTORY",	"ls ",   "\t\"ls\""          },
		{ "RUN",	"./",    "\t\tExecute in the shell" },
		{ "SH",		"sh",	"\t\t\"sh\""              },
		{ NULL,		NULL,	NULL                      }
	};

#endif

/* PTSL Command lookup table */

static struct  ptl_cmd {
	 SCHAR	*ptsl_cmds;
	 SCHAR	*cmd_replacemt;
	 int		(*fixup)();
	 SCHAR	*ptsl_cmd_text;
} ptl_lookup[] =
	 {
	 { "ADA",			"\0",			fix_ada_compile,
		"\t\tInvokes ada compiler" },
	 { "ADA_LINK",		"\0",			fix_ada_link,
		"\tInvokes ada linker"     },
	 { "ADA_MKFAM",		"\0",			fix_ada_mkfam,
		"\tInvokes ada family manager to create a family" },
	 { "ADA_MKLIB",		"\0",			fix_ada_mklib,
		 "\tCreates an ada library" },
	 { "ADA_RMFAM",		"\0",			fix_ada_rmfam,
		 "\tInvokes ada family manager to remove a family" },
	 { "ADA_RMLIB",		"\0",			fix_ada_rmlib,
		 "\tRemoves an ada library" },
	 { "ADA_SEARCH",		"\0",			fix_ada_search,
		 "" },
	 { "ADA_SETLIB",		"\0",			fix_ada_setlib,
		 "" },
	 { "API",			"api",			fix_isc,
		 "\t\tapi"    },
#ifdef WIN_NT
	 { "CC",			"cl386",		fix_cc,
		 "\t\tC Compile" },
#else
#ifdef OS2_ONLY
	 { "CC",			"bcc",			fix_cc,
		 "\t\tC Compile" },
#else
	 { "CC",			"cl",			fix_cc,
		"\t\tC Compile" },
#endif
#endif

#ifdef WIN_NT /* Set  default to MS compiler according to tradition */
	{ "CXX",			"cl",			fix_cxx,
		 "\t\tC++ compile"   },
#endif
		  
	{ "COPY",			"copy ",		fix_isc,
		"\t\t\"copy\"" },
	{ "CRE",			"cat > ",		fix_isc,
		 "\t\t\"cat >\"" },
	{ "CREATE",		"cat > ",		fix_isc,
		"\t\t\"cat >\"" },
	{ "DEL",			"del",			fix_del,
		"\t\t\"del\"" },
	{ "DELETE",		"del",			fix_del,
		"\t\t\"del\"" },
	{ "DIR",			"dir /b ",		fix_isc,
		"\t\t\"dir /b\"" },
	{ "DIRECTORY",		"dir /b ",		fix_isc,
		"\t\"dir /b\"" },
	{ "DROP",			"drop_gdb",		fix_isc,
	  "\t\t\"drop_gdb\"" },
	{ "FOR",			"ftn",			fix_ftn,
		"\t\tInvokes fortran compiler" },
	{  "FORTRAN",		"ftn",			fix_ftn,
		"\t\tInvokes fortran compiler (same as above)" },
	{ "GBAK",			"gbak",			fix_isc,
	"\t\t\"gbak\"" } ,
	{ "GCON",			"gcon",			fix_isc,
		"\t\t\"gcon\"" } ,
	{  "GCSU",			"gcsu",			fix_isc,
		"\t\t\"gcsu\"" } ,
	{  "GDEF",			"gdef",			fix_isc,
		"\t\t\"gdef\"" } ,
	{ "GDS_CACHE_MANAGER",	       "ibcache.exe",		        fix_isc,
		"\"ibcache.exe\"" } ,
		  {  "GFIX",			"gfix",			fix_isc,
		 "\t\t\"gfix\"" } ,
	{ "GJRN",			"gjrn",			fix_isc,
		"\t\t\"gjrn\"" } ,
	{ "GLTJ",			"gltj",			fix_isc,
		 "\t\t\"gltj\"" } ,
	{ "GPRE",			"gpre",			fix_isc,
		 "\t\t\"gpre\"" } ,
	{ "GRST",			"grst",			fix_isc,
		 "\t\t\"grst\"" } ,
	{ "GSEC",			"gsec",			fix_isc,
		"\t\t\"gsec\"" } ,
	{ "ISQL",         "isql",       	fix_isc,
		"\t\t\"isql\"" } ,
	{  "JAVA",        "java",        fix_java,
				"\t\t\"java\"" } ,
	{ "JAVAC",        "javac",       fix_javac,
			 "\t\t\"javac\"" } ,

#ifdef WIN_NT
	{ "LINK", 		"link32",		fix_link,
		"\t\tInvokes NT linker" } ,
	{ "MAKE",			"nmake",		fix_isc,
		"\t\t\"nmake\"" } ,
#else
#ifdef OS2_ONLY
	{  "LINK", 		"tlink",		fix_link,
		 "\t\tInvokes OS/2 linker" } ,
	{  "MAKE",			"make",			fix_isc,
		"\t\t\"make\"" } ,
#else
	{  "LINK", 		"link",			fix_link,
		 "\t\tInvokes the linker" } ,
	{  "MAKE",			"make",			fix_isc,
		 "\t\t\"make\"" } ,
#endif
#endif
	{  "PAS",			"pas",			fix_pas,
		"\t\tInvokes pascal compiler" } ,
	{  "PASCAL",		"pas",			fix_pas,
	  "\t\tInvokes pascal compiler (same as above)" } ,
	{ "QLI",			"qli",			fix_qli,
	  "\t\t\"qli\"" } ,
	{  "RUN",			"\0",			fix_isc,
		"\t\tExecute in the shell" } ,
	{  "SH",			"cmd.exe",		fix_isc,
		"\t\t\"cmd.exe\"" } ,
	{  "TYPE",			"cat <",		fix_isc,
		"\t\t\"cat <\"" } ,
	{  NULL,			NULL,			NULL,
		NULL }
	 };

#define	    EXE_EXT	     ".exe"
#define     PATH_SEPARATER   '/'
#define     OPTION_CHAR      '-'
