/*
 *	PROGRAM:	Test Control System
 *	MODULE:		mpexl.h
 *	DESCRIPTION:	
 *
 *	These are system-specific declarations for MPEXL
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
	NULL,		/* ada */
	NULL,		/* basic */
	" %s\n",	/* c */
	NULL,		/* cobol */
	NULL,		/* fortran */
	NULL,		/* pascal */
	NULL,		/* pli */
	" %s %s\n",	/* link */
	NULL,		/* c++ */
	NULL
	};

static struct defn extensions[] =
     {
     NULL, NULL
     };

static TEXT *link_ext[] =
      { ".o",
	" ",
        ".o",
        ".o",
        ".o",
        ".o",
        ".o",
        ".o",
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
	"ADA",		"\0",		fix_ada_compile, 
	"\t\tInvokes ada compiler",
	"ADA_LINK",	"\0",		fix_ada_link,
	"\tInvokes ada linker",
	"ADA_MKFAM",	"\0",		fix_ada_mkfam, 
	"\tInvokes ada family manager to create a family",
	"ADA_MKLIB",	"\0",		fix_ada_mklib,
	"\tCreates an ada library",
	"ADA_RMFAM",	"\0",		fix_ada_rmfam,
	"\tInvokes ada family manager to remove a family",
	"ADA_RMLIB",	"\0",		fix_ada_rmlib,
	"\tRemoves an ada library",
	"ADA_SEARCH",	"\0",		fix_ada_search,
	"",
	"ADA_SETLIB",	"\0",		fix_ada_setlib,
	"",
	"API",		"tcsapi",	fix_isc,
	"\t\tapi",
	"CC",		"tcscc",	fix_cc,    
	"\t\tInvokes the c compiler",
	"COB",		"tcscob",	fix_cob,
	"\t\tInvokes cobol compiler",
	"COBOL", 	"tcscob",	fix_cob,
	"\t\tInvokes cobol compiler (same as above)",
	"COB_LINK", 	"tcslink",	fix_link,
	"\tInvokes cobol linker",
	"COPY",		"tcscp",	fix_isc,
	"",	
	"CRE",		"tcscreate",	fix_isc,	
	"",	
	"CREATE",	"tcscreate",	fix_isc,    
	"",	
	"DEL",		"tcsrm",	fix_del,	  
	"",	
	"DELETE",	"tcsrm",	fix_del,      
	"",	
	"DIR",		"tcsdir",	fix_isc,	
	"",	
	"DIRECTORY",	"tcsdir",	fix_isc, 
	"",	
	"FOR",		"tcsftn",	fix_ftn,      
	"",	
	"FORTRAN",	"tcsftn",	fix_ftn, 
	"",	
	"GBAK",		"tcsgds gbak",	fix_isc, 
	"",	
	"GCON",		"tcsgds gcon",	fix_isc, 
	"",	
	"GCSU",		"tcsgds gcsu",	fix_isc, 
	"",	
	"GDEF",		"tcsgds gdef",	fix_isc,
	"",	
	"GFIX",		"tcsgds gfix",	fix_isc,   
	"",	
	"GJRN",		"tcsgds gjrn",	fix_isc,
	"",	
	"GLTJ",		"tcsgds gltj",	fix_isc,  
	"",	
	"GPRE",		"tcsgds gpre",	fix_isc, 
	"",	
	"GRST",		"tcsgds grst",	fix_isc,
	"",	
	"GSEC", 	"tcsgds gsec",  fix_isc,
	"",	
        "ISQL",         "tcsisql",      fix_isc,
	"",	
	"LINK",		"tcslink",	fix_link,
	"",	
	"PAS",		"tcspas",	fix_pas,
	"",	
	"PASCAL",	"tcspas",	fix_pas,       
	"",	
	"QLI",		"tcsgds qli",	fix_qli,
	"",	
	"RUN",		"tcsrun",	fix_isc,       
	"",	
	"TYPE",		"tcstype",	fix_isc,  
	"",	
	NULL,		NULL,		NULL,
	NULL
    };

#define     PATH_SEPARATER   NULL
#define     OPTION_CHAR      '-'
