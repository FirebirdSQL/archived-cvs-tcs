/*
 *	PROGRAM:	Test Control System
 *	MODULE:		unix.h
 *	DESCRIPTION:	
 *
 *      These are system-specific declarations for UNIX
 *      systems to aid in modifying command lines in tests.
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
	" -c -w -g %s\n",
	NULL,
	NULL,
	NULL,
	NULL,
	" %s -o %s\n",
	" -c -w -g %s\n"
	};

static struct defn extensions[] =
     {
     NULL, NULL
     };

static TEXT *link_ext[] =
      { ".bin",
	" ",
        ".bin",
        ".o",
        ".int",
#ifdef APOLLO
        ".bin",
#else
        ".o",
#endif
        ".bin",
        ".bin",
	".o",
	".o"};

/* PTSL Command lookup table */
static struct  ptl_cmd {
       SCHAR *ptsl_cmds; 
       SCHAR *cmd_replacemt; 
       int  (*fixup)();
       SCHAR *ptsl_cmd_text;
} ptl_lookup[] =
    {
        "ADA",			"\0",			fix_ada_compile, 
	"\t\tInvokes ada compiler",
	"ADA_LINK",		"\0",			fix_ada_link,
	"\tInvokes ada linker",
        "ADA_MKFAM",		"\0",			fix_ada_mkfam, 
	"\tInvokes ada family manager to create a family",
	"ADA_MKLIB",		"\0",			fix_ada_mklib,
	"\tCreates an ada library",
	"ADA_RMFAM",		"\0",			fix_ada_rmfam,
	"\tInvokes ada family manager to remove a family",
	"ADA_RMLIB",		"\0",			fix_ada_rmlib,
	"\tRemoves an ada library",
	"ADA_SEARCH",		"\0",			fix_ada_search,
	"\tNecessary for ada test to run on VMS",
	"ADA_SETLIB",		"\0",			fix_ada_setlib,
	"\tNecessary for ada test to run on VMS",
        "API",			"api",			fix_isc,
	"\t\tapi",
#ifndef CRAY
        "CC",			"cc",			fix_cc,    
	"\t\tcc",
#else
        "CC",			"scc",			fix_cc,    
	"\t\tscc",
#endif
        "CXX",			"CC",			fix_cxx,    
	"\t\tInvokes c++ compiler",
        "CXX_LINK",		"CC",			fix_link,    
	"\tInvokes c++ linker",
        "COB",			"cob",			fix_cob,  
	"\t\tInvokes cobol compiler",
        "COBOL",		"cob",			fix_cob,
	"\t\tInvokes cobol compiler (same as above)",
	"COB_LINK",		"cob",			fix_link,
	"\tInvokes cobol linker",
        "COPY",			"cp ",			fix_isc,
	"\t\t\"cp\"",
        "CRE",			"cat > ",		fix_isc,        
	"\t\t\"cat >\"",
        "CREATE",		"cat > ",		fix_isc,    
	"\t\t\"cat >\"",
        "DEL",			"rm -f",		fix_del,          
	"\t\t\"rm -f\"",
        "DELETE",		"rm -f",		fix_del,      
	"\t\t\"rm -f\"",
        "DIR",			"ls ",			fix_isc,        
	"\t\t\"ls\"",
        "DIRECTORY",		"ls ",			fix_isc, 
	"\t\"ls\"",
        "DROP",			"drop_gdb",		fix_isc, 
	"\t\t\"drop_gdb\"",
#ifdef APOLLO
#define FORTRAN_DEFS
        "FOR",			"ftn",			fix_ftn,      
	"\t\tInvokes fortran compiler",
        "FORTRAN",		"ftn",			fix_ftn, 
	"\t\tInvokes fortran compiler (same as above)",
        "FORTRAN_LINK",		"ld",			fix_link,
	"\tInvokes fortran linker",
#endif
#ifdef DGUX
#define FORTRAN_DEFS
        "FOR",			"ghf77",		fix_ftn,      
	"\t\tInvokes fortran compiler",
        "FORTRAN",		"ghf77",		fix_ftn, 
	"\t\tInvokes fortran compiler (same as above)",
	"FORTRAN_LINK",		"ghf77 gds_blk_data.f",	fix_link,
	"\tInvokes fortran linker",
#endif
#ifndef FORTRAN_DEFS
        "FOR",			"f77",			fix_ftn,      
	"\t\tInvokes fortran compiler",
        "FORTRAN",		"f77",			fix_ftn, 
	"\t\tInvokes fortran compiler (same as above)",
	"FORTRAN_LINK",		"f77",			fix_link,
	"\tInvokes fortran linker",
#endif
        "GBAK",			"gbak",			fix_isc, 
	"\t\t\"gbak\"",
        "GCON",			"gcon",			fix_isc, 
	"\t\t\"gcon\"",
        "GCSU",			"gcsu",			fix_isc, 
	"\t\t\"gcsu\"",
        "GDEF",			"gdef",			fix_isc,
	"\t\t\"gdef\"",
	"GDS_CACHE_MANAGER",	"gds_cache_manager",	fix_isc,
	"\"gds_cache_manager\"",
        "GFIX",			"gfix",			fix_isc,   
	"\t\t\"gfix\"",
	"GJRN",			"gjrn",			fix_isc,
	"\t\t\"gjrn\"",
        "GLTJ",			"gltj",			fix_isc,  
	"\t\t\"gltj\"",
        "GPRE",			"gpre",			fix_isc, 
	"\t\t\"gpre\"",
        "GRST",			"grst",			fix_isc,
	"\t\t\"grst\"",
	"GSEC",			"gsec",			fix_isc,
	"\t\t\"gsec\"",

	"ISQL",			"isql",			fix_isc,
	"\t\t\"isql\"",
	"JAVA",			"java",			fix_java,
	"\t\t\"java\"",
	"JAVAC",		"javac",		fix_javac,
	"\t\t\"javac\"",

#ifdef APOLLO
        "LINK",			"ld",			fix_link,
	"\t\tInvokes unix linker(ld)",
#else
        "LINK",			"cc",			fix_link,
	"\t\tInvokes unix linker(cc)",
#endif
	"MAKE",			"make",			fix_isc,
	"\t\t\"make\"",
        "PAS",			"pas",			fix_pas,
	"\t\tInvokes pascal compiler",
        "PASCAL",		"pas",			fix_pas,       
	"\t\tInvokes pascal compiler (same as above)",
        "QLI",			"qli",			fix_qli,
	"\t\t\"qli\"",
#ifdef hpux
	"RSH",			"remsh",		fix_isc,
	"\t\t\"remsh\"",
#else
	"RSH",			"rsh",			fix_isc,
	"\t\t\"rsh\"",
#endif
        "RUN",			"\0",			fix_isc,       
	"\t\tExecute in the shell",
	"SH",			"sh",			fix_isc,
	"\t\t\"sh\"",
	"TYPE",			"cat <",		fix_isc,  
	"\t\t\"cat <\"",
	NULL,			NULL,			NULL,
	NULL
    };

#define     PATH_SEPARATER   '/'
#define     OPTION_CHAR      '-'
