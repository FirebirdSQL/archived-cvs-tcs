/*
 *	PROGRAM:	Test Control System
 *	MODULE:		vms.h
 *	DESCRIPTION:	
 *
 *      These are system-specific declarations for VMS to
 *      aid in modifying command lines in tests.
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

static struct defn del_exts[] =
	{
	"e",	".e;*",
	"c",	".c;*",
	"eftn",	".efor;*",
        "efor", ".efor;*",
        "for",  ".for;*",
	"ftn",	".for;*",
	"gdb",	".gdb;*",
	"o",	".obj;*",
	"bin",	".obj;*",
	"ddl",	".ddl;*",
	"ea",	".eada;*",
	"a",	".ada;*",
	"ebas",	".ebas;*",
	"bas",	".bas;*",
	"ecob",	".ecob;*",
	"cob",	".cob;*",
	"epli",	".epli;*",
	"pli",	".pli;*",
	"epas", ".epas;*",
	"pas", ".pas;*",
	"*",	".*;*",
	NULL,   NULL
	};

static struct defn extensions[] =
	{
	".eftn", ".efor",
        ".efor", ".efor",
        ".for",  ".for",
	".ftn",	".for",
	".ea",	".eada",
	".a",	".ada",
	NULL,   NULL
	};

static TEXT *defaults[] =
	{
        NULL,        /* the unknown language */
	NULL,        /* ada */
	NULL,        /* basic */
        " %s\n",       /* c */
	NULL,        /* cobol */
	NULL,        /* fortran */ 
	NULL,        /* pascal */
	NULL,        /* pli */
	"/exe=%s.exe %s sys$input/opt\nsys$library:vaxcrtlg.exe/share\n"
	};

static TEXT *link_ext[] =
      { ",", "", ",", "," ,",", ",", ",", ",", ",",","};

/* PTSL Command lookup table */
static struct  ptl_cmd {
       SCHAR *ptsl_cmds; 
       SCHAR *cmd_replacemt; 
       int  (*fixup)();
       SCHAR *ptsl_cmd_text;
} ptl_lookup[] =
    {
        "ADA",			"\0",			fix_ada_compile, 
	"\tInvokes ada compiler",
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
	"",
	"ADA_SETLIB",		"\0",			fix_ada_setlib,
	"",
        "API",			"api",			fix_isc,
	"\t\tapi",
        "BAS",			"basic",		NULL,
	"",
        "BASIC",		"basic",		NULL, 
	"",
        "CC",			"cc",			fix_cc,    
	"\t\tcc",
        "CXX",                  "cxx",                  fix_cxx,
        "\t\tInvokes c++ comiler",
        "CXX_LINK",             "link",                  fix_link,
        "\t\tInvokes c++ linker",
        "COB",			"cobol",		fix_cob,  
	"\t\tInvokes cobol compiler",
        "COBOL",		"cobol",		fix_cob,
	"\t\tInvokes cobol compiler (same as above)",
	"COB_LINK",		"link",		fix_link,
	"\t\tInvokes cobol linker.",
        "COPY",			"copy ",		fix_isc,
	"\t\t\"copy\"",
        "CRE",			"create ",		fix_isc,        
	"\t\t\"create\"",
        "CREATE",		"create ",		fix_isc,    
	"\t\t\"create\"",
        "DEL",			"delete",		fix_del,          
	"\t\t\"delete\"",
        "DELETE",		"delete",		fix_del,      
	"\t\t\"delete\"",	
        "DIR",			"dire ",		fix_del,        
	"\t\t\"dire\"",
        "DIRECTORY",		"dire ",		fix_del, 
	"\t\"dire\"",
        "FOR",			"for",			fix_ftn,      
	"\t\tInvokes fortran compiler",
        "FORTRAN",		"for",			fix_ftn, 
	"\t\tInvokes fortran compiler (same as above)",
        "FORTRAN_LINK",		"link",			fix_link,
	"\t\tInvokes fortran linker.",
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
        "ISQL",                 "isql",                 fix_isc,
	"\t\t\"isql\"",
        "LINK",			"link",			fix_link,
	"\t\tInvokes vms linker",
        "PAS",			"pas",			fix_pas,
	"\t\tInvokes pascal compiler",
        "PASCAL",		"pas",			fix_pas,       
	"\t\tInvokes pascal compiler (same as above)",
        "PL1",			"pli",			NULL,           
	"pli",
        "QLI",			"qli",			fix_qli,       
	"\t\t\"qli\"",
	"RSH",			"rsh",			fix_isc,
	"\t\t\"rsh\"",
        "RUN",			"run",			fix_isc,       
	"\t\tExecute in the shell",
	"TYPE",			"type ",		fix_isc,  
	"\t\t\"type \"",
	NULL,			NULL,			NULL,
	NULL
};

#define     EXE_EXT          ".exe;*"
#define     PATH_SEPARATER   NULL
#define     OPTION_CHAR      '/'
#define     DEL_STAR_EXT    ".*;*"
