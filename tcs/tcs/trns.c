/*
 *      PROGRAM:        Test Control System
 *      MODULE:         trns.c
 *      DESCRIPTION:
 *
 *
 *      Note: Once script is translated (or as)
 *      must still apply platform dependent rules on
 *      structuring the files (scripts, pgms) to be run.
 *
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
#include <setjmp.h>
#include <stdlib.h>
#include <string.h>
#include "tcs.h"

extern jmp_buf  JumpBuffer;

#if defined( IMP ) || defined( DELTA )
#  define NO_STRSTR
#endif

/* Static declarations */
#if  (defined WIN_NT || defined OS2_ONLY)
  static int process_command (TEXT* in_line, TEXT* result);
  static int process_defn (TEXT* in_line, TEXT* result);
  static int process_noxcmd (TEXT* in_line, TEXT*  result);
  static int process_regtxt (TEXT* in_line, TEXT*  result);

  static int zap_hp_dollarsign (TEXT* target);
  static int addstr (TEXT* wrd, TEXT** bufr, TEXT delim);
  static int lang_compile (TEXT* line, TEXT* bufr);

  static int fix_ada_compile (TEXT* line, TEXT* bufr);
  static int fix_ada_link (TEXT* line, TEXT* bufr);
  static int fix_ada_mkfam (TEXT* line, TEXT* bufr);
  static int fix_ada_mklib (TEXT* line, TEXT* bufr);
  static int fix_ada_rmfam (TEXT* line, TEXT* bufr);
  static int fix_ada_rmlib (TEXT* line, TEXT* bufr);
  static int fix_ada_search (TEXT* line, TEXT* bufr);
  static int fix_ada_setlib (TEXT* line, TEXT* bufr);

  static int fix_isc (TEXT* line, TEXT* bufr);
  static int fix_cc (TEXT* line, TEXT* bufr);
  static int fix_cxx (TEXT* line, TEXT* bufr);
  static int fix_del (TEXT* line, TEXT* bufr);
  static int fix_ftn (TEXT* line, TEXT* bufr);
  static int fix_java (TEXT* line, TEXT* bufr);
  static int fix_javac (TEXT* line, TEXT* bufr);
  static int fix_link (TEXT* line, TEXT* bufr);
  static int fix_pas (TEXT* line, TEXT* bufr);
  static int fix_qli (TEXT* line, TEXT* bufr);
  static fix_compile (TEXT* line, TEXT* result);

  static TEXT *mytokget (TEXT** position, TEXT* delimiters);
  static struct defn *lookup_defn (TEXT* wrd);
  static handle_options (TEXT* options, TEXT* opt_template);
  static int handle_filename (TEXT* name);
  static int handle_path (TEXT* tok, TEXT*  wrd, TEXT* word2, TEXT** result);
  static int handle_extensions (TEXT* tok, TEXT* ch);
  static int handle_keyword (TEXT* in_line, TEXT* result);
  static int zap_under_under (TEXT* target);
  static int zap_vms_run (TEXT* in_line, TEXT* result);

  /* External declarations */
  extern int disp_upcase (TEXT* string, TEXT* name);

#else

  /* forward declarations */

static struct defn *lookup_defn();

static int fix_ada_compile(), fix_ada_link(), fix_ada_mkfam(), fix_ada_mklib(),
		  fix_ada_rmfam(), fix_ada_rmlib(), fix_ada_search(), fix_ada_setlib(),
		  fix_cc(), fix_cxx(), fix_cob(), fix_ftn(), fix_isc(), fix_qli(),
		  fix_link(), fix_run(), fix_del(), fix_sys(), fix_java(), fix_javac(),
		  fix_pas(), lang_compile(), fix_compile(), handle_filename(),
		  handle_path(), process_command(), process_defn(), process_noxcmd(),
		  process_regtxt(), handle_options(), zap_hp_dollarsign();

static		  TEXT *mytokget();
		  void list_keywords();
		  int  keyword_search();
#endif

int	language = 0;  	  /* programming language flag */

static int	defn_ofst = 0;	  /* offset into defintion table for next symbol */

#define MAXDEFNS        80        /* Max number of definitions */
#define MAXIDLEN        40        /* Max length of ident field */
#define MAXRPCLN        256       /* Max length of replacement field */

#define ADA	1              /* language flags */
#define BASIC   2
#define CC      3
#define COBOL   4
#define FORTRAN 5
#define PASCAL  6
#define PL1	    7
#define LINK    8
#define CXX     9
#define JAVA   10
#define JAVAC  11

#define NO_DOLLAR_SIGN

#ifdef hpux
#define ADA_COMPILE	"ada Ada_Lib"
#define ADA_LINK	"ada Ada_Lib"
#define ADA_GPRE_EXT	".eada"
#define ADA_EXT		".ada"
#ifdef hp9000s300
#define ADA_MAKE_FAM	" "
#define ADA_MAKE_LIB	"ada.mklib -f Ada_Lib"
#define ADA_REMOVE_FAM	" "
#define ADA_REMOVE_LIB	"ada.rmlib -f Ada_Lib"
#else
#define ADA_MAKE_FAM	"ada.mkfam Ada_Fam"
#define ADA_MAKE_LIB	"ada.mklib Ada_Fam Ada_Lib"
#define ADA_REMOVE_FAM	"ada.rmfam -f Ada_Fam"
#define ADA_REMOVE_LIB	" "
#endif
#define E_FORTRAN_EXT	".ef"
#define FORTRAN_EXT	".f"
#endif

#ifdef APOLLO
#undef NO_DOLLAR_SIGN
#define ADA_MAKE_LIB	"a.mklib -f . $ADADIR/verdixlib"
#define ADA_REMOVE_FAM	" "
#define ADA_REMOVE_LIB	"a.rmlib"
#define ADA_COMPILE	"ada" 
#define ADA_LINK	"a.ld"
#define ADA_GPRE_EXT	".ea"
#define ADA_EXT		".a"
#define E_FORTRAN_EXT	".eftn"
#define FORTRAN_EXT	".ftn"
#endif

#ifdef DGUX
#ifndef DG_X86
#undef NO_DOLLAR_SIGN
#endif
#endif

#ifdef sun
#ifndef SOLARIS
#undef NO_DOLLAR_SIGN
#endif
#define ADA_MAKE_LIB	"a.mklib -f . $ADADIR/verdixlib"
#define ADA_REMOVE_FAM	" "
#define ADA_REMOVE_LIB	"a.rmlib"
#define ADA_COMPILE	"ada" 
#define ADA_LINK	"a.ld"
#define ADA_GPRE_EXT	".ea"
#define ADA_EXT		".a"
#define E_FORTRAN_EXT	".ef"
#define FORTRAN_EXT	".f"
#endif

#ifdef VMS
#undef NO_DOLLAR_SIGN
#define ADA_REMOVE_LIB	"acs del lib [.tcs_ada_library]"
#define ADA_MAKE_LIB	"acs cre lib [.tcs_ada_library]"
#define ADA_COMPILE	"ada"
#define ADA_LINK	"acs link"
#define ADA_GPRE_EXT	".EADA"
#define ADA_EXT		".ADA"
#define ADA_SETLIB	"acs set lib [.tcs_ada_library]"
#define ADA_SEARCH	"acs enter foreign/share SYS$COMMON:[interbase.syslib]gdsshr.exe"
#define E_FORTRAN_EXT	".efor"
#define FORTRAN_EXT	".for"
#define E_COBOL_EXT	".ecob"
#define COBOL_EXT	   ".cob"
#define E_CXX_EXT	   ".EXX"
#define CXX_EXT		".CXX"
#endif

#ifdef mpexl
#define USHORT_NAMES
#endif

#if (defined WIN_NT || defined OS2_ONLY)
#define E_CXX_EXT ".exx"
#define CXX_EXT   ".cpp"
#define GBAK_EXT	".gbk"
#endif

#ifdef SCO_UNIX
#define ADA_COMPILE	"ada compile"
#define ADA_EXT		".a"
#define ADA_GPRE_EXT	".ea"
#define ADA_LINK	"ada bind"
#define ADA_MAKE_LIB	"ada lib.new Ada_Lib"
#define ADA_REMOVE_LIB	"ada lib.erase Ada_Lib confirm=no"
#endif


/* Define blanks for ADA stuff if necessary. */

/*
#ifndef ADA_COMPILE
#define ADA_COMPILE	0
#define ADA_EXT		0
#define ADA_GPRE_EXT	0
#define ADA_LINK	0
#define ADA_MAKE_FAM	0
#define ADA_MAKE_LIB	0
#define ADA_REMOVE_FAM	0
#define ADA_REMOVE_LIB	0
#define ADA_SEARCH	0
#define ADA_SETLIB	0
#endif
*/

#ifndef ADA_MAKE_FAM
#define ADA_MAKE_FAM	" "
#endif

#ifndef ADA_REMOVE_FAM
#define ADA_REMOVE_FAM	" "
#endif

#ifndef ADA_MAKE_LIB
#define ADA_MAKE_LIB	" "
#endif

#ifndef ADA_REMOVE_LIB
#define ADA_REMOVE_LIB	" "
#endif

#ifndef ADA_SEARCH
#define ADA_SEARCH	" "
#endif

#ifndef ADA_SETLIB
#define ADA_SETLIB	" "
#endif

#ifndef E_CXX_EXT
#define E_CXX_EXT	".E"
#define CXX_EXT 	".C"
#endif

#ifndef E_COBOL_EXT
#define E_COBOL_EXT	".ecbl"
#define COBOL_EXT	   ".cbl"
#endif

#ifndef E_FORTRAN_EXT
#define E_FORTRAN_EXT	".ef"
#define FORTRAN_EXT	   ".f"
#endif

#ifndef GBAK_EXT
#define GBAK_EXT	".gbak"
#endif


struct defn         /* Entry for symbol definition */
	 {
	 SCHAR ident[MAXIDLEN];
	 SCHAR replacement[MAXRPCLN];
	 };



/***** this table contains phrases which signal presence of
		 $ which makes the hp  c compiler choke.  only $
		 qualified by these prefixes should be zapped */

static TEXT	*qual_strings [] = {
	"gds_",
	"GDS_",
	"PYXIS_",
	"pyxis_",
	"blob_",
	"BLOB_",
	0};

static TEXT	*vector [256];

/* include the proper file for translation of system-specific commands */

#ifdef VMS
#include "vms.h"
#else
#ifdef PC_PLATFORM
#include "pc.h"
#else
#if (defined WIN_NT || defined OS2_ONLY)
#include "pc.h"
#else
#ifdef mpexl
#include "mpexl.h"
#else
#include "unix.h"
#endif
#endif
#endif
#endif

struct defn definitions[MAXDEFNS + 1] = {{"", ""}};

#ifdef NO_STRSTR
char *strstr(text, sub)
	 char        *text,
					 *sub;
{
/**************************************
 *
 *	s t r s t r
 *
 **************************************
 *
 * Functional description
 *   finds the first occurance of sub in text and
 *   returns a pointer to it, otherwise returns 0
 *
 **************************************/
char *ptr, *cmp1, *cmp2;
for (ptr = text; *ptr != '\0'; ptr++)
{
	 for (cmp1 = sub, cmp2 = ptr; *cmp1 && (*cmp1 == *cmp2);cmp1++, cmp2++);
	 if (!*cmp1) return ptr;
}
return (char*)0;
}
#endif

int PTSL_set_table ()
{
/**************************************
 *
 *	P T S L _ s e t _ t a b l e
 *
 **************************************
 *
 * Functional description
 *          for hp, create the $ zap table
 **************************************/
TEXT 	**ptr;

/* 	Initialize a string translation table  				*
 *	Set up the table that contains strings that may signal the 	*
 *	presence of a '$' which needs to be removed.			*/

for (ptr = qual_strings; *ptr; ptr++)
	 vector [**ptr] = (*ptr) + 1;

  return 0;
}



int PTSL_2ap (in_line, result)
	 TEXT *in_line, *result;
{
/**************************************************************************
 *
 *	P T S L _  2 a p
 *
 **************************************************************************
 *
 *	Translate a portable script to its apollo form.
 *      Return the linetype for the edification of the
 *      command file parser
 *
 **************************************************************************/
USHORT linetype;
USHORT success;
TEXT *c;

c = in_line;

/*	If the first character in the line is a '$' then we have a 	*
 *	verb (command) that needs translation.  Call process_command	*
 *	to translate.							*/

/*	call handle_where_gdb() before anything else is done.		*/
handle_where_gdb(in_line);

if (*c == '$')

{
	 linetype = CMD;
	 success = (USHORT) process_command (in_line, result); /* command line */

#ifdef VMS

/*	Handle command line args for VMS.				*/

	 if (!strncmp(result,"$ run",5))

	 {
		  zap_vms_run (in_line, result);
	 }

#endif

}

/*	If the first two characters on the line are colons, then we	*
 *	have encountered an environment variable definition. (Symbol)	*
 *	Call process_defn() to translate into table to be checked	*
 *	when parsing commands and text.					*/

else if (*c == ':' && *(c + 1) == ':')

{
	 linetype = SYMDFN;
	 success = (USHORT) process_defn (in_line, result);	/* symbol definition */
}

/*	If the first character is a carat and the second is a '$'	*
 *	then we do not process the command, but mark it as a command	*
 *	anyway and return.						*/

else if (*c == '^' && *(c + 1) == '$')

{
	 success = (USHORT) process_noxcmd (in_line, result);	/* no translate cmd */
	 linetype = CMD;
}

/*	What ever is left by the time we reach here must be plain old	*
 *	text, so call process_regtxt() to handle that, and remove 	*
 *	dollar signs if need be.					*/

else

{
	 linetype = REGTXT;
	 success = (USHORT) process_regtxt (in_line,  result); /* regular text */

#ifdef NO_DOLLAR_SIGN
	 zap_hp_dollarsign (result);
#else
	 zap_under_under (result);
#endif

}

return (success ? linetype : FALSE);
}

static int addstr (wrd, bufr, delim)
	 TEXT  *wrd, **bufr, delim;
{
/**************************************
 *
 *	a d d s t r
 *
 **************************************
 *
 * Functional description
 *       add a word to a linebuffer, bumping pointers
 *       end the line with the caller's choice of SCHARs
 *
 **************************************/
TEXT    *bptr;
SSHORT	nl;

/*	If we didn't get a value in wrd to put in bufr return 		*/

if (NULL_STR (wrd))
	 return 1;

nl = FALSE;

/*	If the wrd already has a new line following it, then do not 	*
 *	add delimiters to the end of the line.				*/

if (*wrd == '\n') nl = TRUE;

/*	Do the move wrd into bufr, and make sure we haven't stopped	*
 *	copying.							*/

for (bptr = *bufr; (*bptr = *wrd); bptr++, wrd++)

{
	 if (!*bptr)
		 break;
}

/*	If we have a delimiter, and the new word did not end with a 	*
 *	new line, then put the delimiter at the end of the line.	*/

if ((SSHORT)delim && !nl)
	 *bptr++ = delim;

*bufr = bptr;

 return 0;
}

static int fix_ada_compile (line, bufr)
	 TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ c o m p i l e
 *
 **************************************
 *
 * Functional description
 *	generate the compile code for ADA.
 *
 **************************************/

/*	Put in the proper notation for invoking this platforms Ada 	*
 *	compiler, or if not define'd then print an error.		*/

#ifdef ADA_COMPILE
	 addstr(ADA_COMPILE,&bufr,' ');  	/* Put in the right compiler */
#else
	 print_error ("ADA_COMPILE is not #define'd for this machine.\n",0,0,0);
	 longjmp (JumpBuffer, 1);
#endif

language = ADA;

/*	Call fix_compile() to handle any environment variables or 	*
 *	filename suffixes.						*/

lang_compile(line,bufr);

 return 0;
}

static int fix_ada_link (line, bufr)
	 TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ l i n k
 *
 **************************************
 *
 * Functional description
 *	generate the link code for ADA.
 *
 **************************************/

/*	Put in the proper notation for invoking this platform's Ada 	*
 *	linker, or if not define'd then print an error.			*/

#ifdef ADA_LINK
	 addstr(ADA_LINK, &bufr, ' ');  	/* Throw in the #define'd value... */
#else
	 print_error ("ADA_LINK has not been #define'd for this machine\n",0,0,0);
	 longjmp (JumpBuffer, 1);
#endif

/*	Call fix_link() to handle any regular or link style environment *
 *	variables used,	filename suffixes.				*/

  fix_link(line,bufr);

  return 0;
}

static int fix_ada_mkfam (line, bufr)
	 TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ m k f a m
 *
 **************************************
 *
 * Functional description
 *	generate the mkfam code for ADA.
 *
 **************************************/

/*	Put in the proper notation for invoking this platform's Ada 	*
 *	family manager, or if not define'd then print an error.		*/

#ifdef ADA_MAKE_FAM
	 addstr(ADA_MAKE_FAM, &bufr, ' ');  /* Throw in mkfam code for ada */
#else
	 print_error("ADA_MAKE_FAM has not been #define'd for this machine\n",0,0,0);
	 longjmp (JumpBuffer, 1);
#endif
/*	Call fix_isc() to handle any environment variables or filename	*
 *	suffixes.							*/
  fix_isc (line, bufr);
  return 0;
}

static int fix_ada_mklib (line, bufr)
	 TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ m k l i b
 *
 **************************************
 *
 * Functional description
 *	generate the mklib code for ADA.
 *
 **************************************/

/*	Put in the proper notation for invoking this platform's Ada 	*
 *	library manager, or if not define'd then print an error.	*/

#ifdef ADA_MAKE_LIB
	 addstr(ADA_MAKE_LIB, &bufr, ' ');  	/* Generate mklib code for ADA. */
#else
	 print_error("ADA_MAKE_LIB has not been #define'd for this machine\n",0,0,0);
	 longjmp (JumpBuffer, 1);
#endif
/*	Call fix_isc() to handle any environment variables or filename	*
 *	suffixes.							*/

  fix_isc (line, bufr);
  return 0;
}

static int fix_ada_rmfam (line, bufr)
	 TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ r m f a m
 *
 **************************************
 *
 * Functional description
 *	generate the rmfam code for ADA.
 *
 **************************************/

/*	Put in the proper notation for invoking this platform's Ada 	*
 *	family manager, or if not define'd then print an error.		*/

#ifdef ADA_REMOVE_FAM
	 addstr(ADA_REMOVE_FAM ,&bufr, ' ');	/* Throw in rmfam code for ada */
#else
	 print_error("ADA_REMOVE_FAM has not been #define'd for this machine\n",0,0,0);
	 longjmp (JumpBuffer, 1);
#endif
/*	Call fix_isc() to handle any environment variables or filename	*
 *	suffixes.							*/

 fix_isc (line, bufr);
 return 0;
}

static int fix_ada_rmlib (line, bufr)
	 TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ r m l i b
 *
 **************************************
 *
 * Functional description
 *	generate the rmlib code for ADA.
 *
 **************************************/

/*	Put in the proper notation for invoking this platform's Ada 	*
 *	library manager, or if not define'd then print an error.	*/

#ifdef ADA_REMOVE_LIB
	 addstr(ADA_REMOVE_LIB ,&bufr, ' '); 	/* Throw in rmlib code for ada. */
#else
	 print_error("ADA_REMOVE_LIB is not #define'd on this machine\n",0,0,0);
	 longjmp (JumpBuffer,1);
#endif
/*	Call fix_isc() to handle any environment variables or filename	*
 *	suffixes.							*/

  fix_isc (line, bufr);

  return 0;
}

static int fix_ada_search (line, bufr)
    TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ s e a r c h
 *
 **************************************
 *
 * Functional description
 *	generate the search code for ADA.

------THIS IS USED ONLY FOR THE VMS PLATFORM RIGHT NOW-------

 *
 **************************************/

/*	Throw in the required code, so the linker knows what libraries	*
 *	to search.							*/

#ifdef ADA_SEARCH
	 addstr(ADA_SEARCH,&bufr,' ');	/* Throw in search code for ada. */
#else
	 print_error("ADA_SEARCH not #define'd for this machine\n",0,0,0);
	 longjmp (JumpBuffer,1);
#endif

/*	Call fix_isc() to handle any environment variables or filename	*
 *	suffixes.							*/

  fix_isc (line, bufr);
  return 0;
}

static int fix_ada_setlib (line, bufr)
    TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ a d a _ s e t l i b
 *
 **************************************
 *
 * Functional description
 *	generate the setlib code for ADA.

--------THIS IS ONLY USED FOR THE VMS PLATFORM RIGHT NOW.-----------

 *
 **************************************/

/*	Throw in the required code, so the Ada linker know which	*
 *	library to look in.						*/

#ifdef ADA_SETLIB
	 addstr(ADA_SETLIB,&bufr, ' '); 	/* Throw in setlib code for ada. */
#else
	 print_error("ADA_SETLIB not #define'd for this machine\n",0,0,0);
	 longjmp (JumpBuffer,1);
#endif

/*	Call fix_isc() to handle any environment variables or filename	*
 *	suffixes.							*/

  fix_isc (line, bufr);
  return 0;
}

static int fix_cc (line, result)
	 TEXT  *line, *result;
{
/**************************************
 *
 *	f i x _ c c
 *
 **************************************
 *
 * Functional description
 *        arguments: pointer to remainder of line where cc has
 *        been found,  pointer to next position to be filled in
 *        the result buffer
 *        Task: set language flag; establish file name; handle 
 *        definitions
 *       cc line grammar: CC [FLAG_CC] filename[.ext]
 *       expands to cc -ch [-ch...] filename [-ch...]
 *
 **************************************/
TEXT	*options, *wrd, *tok, *firstname, *posn, upc[MAXRPCLN]; 
TEXT	options_template[MAXRPCLN];
TEXT	*bufr;
struct defn *dptr;

options = NULL;
firstname = NULL;
posn = wrd = line;
bufr = result;

/* 	loop through the line						*/

while ((tok = (SCHAR *)mytokget(&posn, " \t\n")))

{
    disp_upcase (tok, upc);
    dptr = lookup_defn (upc);

/*	If we have encountered an environment variable with no 		*
 *	definition -- then continue looping				*/

    if (*(dptr->ident) && !*(dptr->replacement))
	continue;

/*	If we have encountered a valid environment variable, then 	*
 *	save the value.							*/

    if (*(dptr->ident))

    {
	wrd = dptr->replacement;

	if ((options = (TEXT*) strchr (dptr->replacement, OPTION_CHAR)) &&
	    (handle_options (wrd, options_template)))
	    continue;
    }

/*	Otherwise modify the suffix of a filename appropriately.	*/	

    else	

    {
        if (!firstname)
	    firstname = tok;

        if (!strchr (firstname, '.'))
	    strcat (firstname, ".c");

	handle_filename (firstname);
	break;
    }

    addstr (wrd, &bufr, ' ');
    wrd = posn;
}

/*	If we did not find a filename then print an error.		*/

if (!firstname)

{
    print_error ("%s fails parse.\nFilename missing\n",line,0,0);
    return FALSE;
}

/*	If no environment variable was found, use a default.		*/

if (!options)
    sprintf (bufr, defaults[CC], firstname);

/*	If a valie environment value was found use it.			*/

else if  (*options_template)
    sprintf (bufr, options_template, firstname);

/*	Else move whatever is left in firstname into the buffer.	*/	

else

{
    addstr (firstname, &bufr, NULL);
    *bufr++ = '\n';
    *bufr = 0;
}

language = CC;
return 0;
}

static int fix_cxx (line, result)
    TEXT  *line, *result;
{
/**************************************
 *
 *	f i x _ c x x
 *
 **************************************
 *
 * Functional description
 *        arguments: pointer to remainder of line where cc has
 *        been found,  pointer to next position to be filled in
 *        the result buffer
 *
 **************************************/
language = CXX;

fix_compile (line, result);
return 0;
}

static int fix_cob (line, bufr)
    TEXT *line, *bufr;
{
/**************************************
 *
 *	f i x _ c o b
 *
 **************************************
 *
 * Functional description
 *	Set the language flag and let 
 *	fix_compile() check for environment
 *	variables.
 *
 **************************************/

language = COBOL;

lang_compile (line, bufr);
return 0;
}

static int fix_compile (line, result)
    TEXT *line, *result;
{
/**************************************
 *
 *	f i x _ c o m p i l e
 *
 **************************************
 *
 * Functional description
 *	parse the rest of the line for
 *	environment variables expected
 *	on a compile line.
 *
 **************************************/
TEXT 	*options, *wrd, *tok, *firstname, *posn, upc[MAXRPCLN];
TEXT 	*bufr, options_template[MAXRPCLN];
struct defn *dptr;

options = NULL;
firstname = NULL;
posn = wrd = line;
bufr = result;

/* 	loop through the line...					*/

while ((tok = (SCHAR *)mytokget(&posn, " \t\n")))

{
	 disp_upcase (tok, upc);
	 dptr = lookup_defn (upc);

/*	If a valid environment variable has been found, use it.		*/

	 if (*(dptr->ident))

	 {

/*	If an environment variable was found, but that variable has	*
 *	no value, then continue looping.				*/

	if (!*(dptr->replacement))
		 continue;

	wrd = dptr->replacement;
	options = dptr->replacement;


	if (handle_options (wrd, options_template))
		 continue;
	 }

/*	If not an environment variable, check for a filename and modify	*
 *	the suffix of that filename if found.				*/

	 else
	 {
		 if (!firstname) /* If this is a first token */
			 firstname = tok;

		posn += handle_filename (firstname); 	/* Check filename suffix. */
		break;
	 }

	 addstr (wrd, &bufr, ' ');
    wrd = posn;
}

/*	If no filename was found print and error message.		*/

if (!firstname)

{
    print_error ("%s fails parse.\nFilename missing\n",line,0,0);
    return FALSE;
}

/*	If no environment variable was used, then use the defaults	*/

if (!options)
    sprintf (bufr, defaults[language], firstname);

/*	If an environment variable was used, then use it.		*/

else if (*options_template)
    sprintf (bufr, options_template, firstname);

/*	Otherwise move the value in firstname into the buffer		*/

else
{
    addstr (firstname, &bufr, NULL);
    *bufr++ = '\n';
    *bufr = 0;
}
 return 0;
}

static int fix_del (line,  bufr)
    TEXT *line,  *bufr;
{
/**************************************
 *
 *	f i x _ d e l
 *
 **************************************
 *
 * Functional description
 *        build a delete string 
 *        assume that the file names are ok if its
 *        not vms. else look everything up in the
 *        extensions table
 *
 **************************************/
TEXT	*posn, *tok;
TEXT	 tmp_result [512];
#ifdef VMS
TEXT  name[32], *asterisk, *dot;
struct defn *eptr;
#endif

/*	Call fix_isc() to handle any environment variables or filename	*
 *	suffixes.							*/

fix_isc (line, tmp_result);

posn = tmp_result;

#ifdef VMS

/*	Loop through the line...					*/

while ((tok = (SCHAR *)mytokget(&posn, " \t\n")))

{

/*  posn will be left pointing at the wrong spot if .a is changed to .ada so *
 *  increment appropriately.						     */

	 posn += handle_filename (tok); 	/* posn points to the next token... */

/*	If there is a dot in the current token, then make dot point 	*
 *	directly after it.						*/

	 if ((dot = (TEXT*) strchr(tok, '.')))
	dot++;

/*	If there is an asterisk in the current token, then make 	*
 *	asterisk point directly after it.				*/

	 if ((asterisk = (TEXT*) strchr(tok, '*')))
	asterisk++;

/*	If there is no dot or asterisk, then move an exe extension	*
 *	on to the end of the token.					*/

	 if (!dot && !asterisk)

	 {
		  addstr (tok, &bufr, "");
		  addstr (EXE_EXT, &bufr, ",");
	 }

/*	If asterisk is pointing to something, modify the asterisk to	*
 *	the appropriate extension for VMS.				*/

	 else if (!dot && asterisk)

	 {
		addstr (tok, &bufr, "");
		addstr (DEL_STAR_EXT, &bufr, ",");
	 }

/*	Check the dot extension for VMS modification.  Modify if needed */

	 else
		  for (eptr = del_exts; *(eptr->ident);  eptr++)
				if (!strcmp (dot, eptr->ident))
			 {
					 *--dot = 0;
					 addstr (tok, &bufr, "");
					 addstr (eptr->replacement, &bufr, ",");
		break;
				}

/*	Add the appropriate extensions onto a dot for VMS.		*/

	 if (dot && *dot)

	 {
		 addstr (tok, &bufr, ";");
		 *bufr++ = '*';
		 *bufr++ = ',';
	 }
}

#else

/*	Loop through the line...					*/

while ((tok = (SCHAR *)mytokget(&posn, " \t\n")))

{

/*  posn will be left pointing at the wrong spot if .a is changed to .ada so *
 *  increment appropriately.						     */

	 posn += handle_filename (tok);  /* posn points to the next token...  */
	 addstr (tok, &bufr, ' ');
}

#endif

*bufr = 0;
*--bufr = '\n';
 return 0;
}

static int fix_ftn (line, bufr)
	 TEXT *line, *bufr;
{
/**************************************
 *
 *	f i x _ f t n
 *
 **************************************
 *
 * Functional description
 *	Call fix_compile() to translate
 *	the environment variables properly
 *	on the fortran compile line.
 *
 **************************************/

language = FORTRAN;

lang_compile (line, bufr);
return 0;
}

static int fix_isc (line, bufr)
    TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ i s c
 *
 **************************************
 *
 * Functional description
 *       replace any pathname specifiers (and
 *       possibly flags) in an isc  command:
 *       gbak, gfix, gdef, glitj, qli
 *	 Also call handle_filename() to modify suffix properly
 *
 **************************************/
TEXT	*tok, *tok2, upc[MAXRPCLN], *wrd, *posn;
struct defn *dptr;

wrd = posn = line;

/*	Get the first token.						*/

while ((tok = (TEXT *)mytokget(&posn, " \t\n"))) 

{

/*	Get the second token						*/

    if ((tok2 = (TEXT*) strchr (tok, ':')))	  

    {
        *tok2++ = 0; 			  /* Remove colon */

/*  posn is supposed to point to the next token following tok2, but if .a    *
 *  changes to .ada posn must be incremented appropiately by handle_path.    */

        posn += handle_path (tok, wrd, tok2, &bufr);
 /*   	*bufr++ = ' '; */
    	wrd = posn;
        continue;
    }

    disp_upcase (tok, upc);
    dptr = lookup_defn (upc);

/*	If we have a valid environment variable then use it.		*/	

    if (*(dptr->ident))

    {

/*	If the variable has no value, then do not use.			*/

	if (!*(dptr->replacement))
	    continue;

        tok = dptr->replacement;
     }

/*	Evaluate anything else, checking to make sure it has the proper	*
 *	suffix by calling handle_filename()				*/

    else
	/***** Again posn must be incremented appropriately.  *****/
        posn += handle_filename (tok);	

    addstr (tok, &bufr, ' ');		/* Insert value & trailing space */
    wrd = posn;
}

*bufr = 0;
*--bufr = '\n';

 return 0;
}

static int fix_java (line, bufr)
    TEXT  *line, *bufr;
{
/**************************************
 *
 *	 f i x _ j a v a
 *
 **************************************
 *
 * Functional description
 *	Call lang_compile() to appropriately
 *	translate the environment variables
 *	on the java compile line.	
 *
 **************************************/

 language = JAVA;

 lang_compile (line, bufr);

 return 0;
}

static int fix_javac (line, bufr)
    TEXT  *line, *bufr;
{
/**************************************
 *
 *	 f i x _ j a v a c
 *
 **************************************
 *
 * Functional description
 *	Call lang_compile() to appropriately
 *	translate the environment variables
 *	on the javac compile line.	
 *
 **************************************/

language = JAVAC;

lang_compile (line, bufr);
return 0;
}

static int fix_link (line, bufr)
    TEXT *line, *bufr;
{
    
/**************************************
 *
 *	f i x _ l i n k
 *
 **************************************
 *
 * Functional description
 *    link command syntax:
 *         LINK FLAG_LINK filename[ filename...]
 *         where FLAG_LINK may have the form
 *         -ch [-ch...] %s [-ch...]] %s
 *    translation form:
 *    command [switches] objfile(s) [switches] exefile
 *    or vms: command /exe=file file[, file] [switches]
 *
 **************************************/
TEXT	*firstname, *posn, *tok;
TEXT	options_template[512], *fptr, *tfsp;
TEXT	files[MAXRPCLN], upc[MAXRPCLN], tfs[MAXRPCLN];
static struct defn *dptr;
int	first_option;

firstname  = fptr = (TEXT*) NULL;
dptr = NULL;
posn = line;
first_option = FALSE;

/*	Loop through each token on the line.				*/

while ((tok = (SCHAR *)mytokget(&posn, " \t\n")))

{
	 disp_upcase (tok, upc);
	 dptr = lookup_defn (upc);

/*	Check to see if it is in the environment variable table but 	*
 *	does not have a definition.  If this is the case, then continue	*
 *	looping.							*/

	 if (*(dptr->ident) && !*(dptr->replacement))
	continue;

/*	Check to see if it is in the environment variable table, if it	*
 *	is, then use it.						*/

	 if (*(dptr->ident))

	 {
	tok = dptr->replacement;

/*	Move the environment variable value, into options template.	*/

	if (strchr (dptr->replacement, OPTION_CHAR) &&
		 (first_option = handle_options (tok, options_template)))
		 continue;
	 }

/*	If we are not processing an environment variable(symbol), then	*
 *	we must be processing filenames.  So process them and their	*
 *	possible suffixes.						*/

	 else

	 {

/*	Only save the first filename.					*/

		  if (!firstname)

		{
		 fptr = files;
		 firstname = tok;
		}

	tfsp = tfs;
	addstr (tok, &tfsp, NULL);
	addstr (link_ext[language], &tfsp, NULL);
	handle_filename (tfs);
	addstr (tfs, &fptr, ' ');
	continue;
	 }

	 addstr (tok, &bufr, ' ');
}

/*	If did not get a firstname then, print error message.		*/

if (!firstname)

{
	 print_error ("%s fails parse.\nFilename missing\n",line,0,0);
	 return FALSE;
}

*fptr = 0;

/* 	Use the default link info. to run the filename through if we 	*
 *	did not get an environment variable with the link info. in it.	*/

#ifdef VMS
if (!first_option)
	 sprintf (bufr, defaults[LINK], firstname, files);
else if (*options_template)
	 sprintf (bufr, options_template, firstname, files);
#else
if (!first_option)
	 sprintf (bufr, defaults[LINK], files, firstname);
else if (*options_template)
	 sprintf (bufr, options_template, files, firstname);
#endif

return 0;
}

int set_ptl_lookup(verb, def)
    TEXT	*verb, *def;
{
/**************************************
 *
 *	s e t _ p t l _ l o o k u p
 *
 **************************************
 *
 * Functional description
 * 	If the '-m' command line switch 
 *	has been thrown on NT then this
 *	function has been called and it
 *	will change the ptl_lookup table
 *
 **************************************/
struct ptl_cmd *lookup;

/*   	Loop through the '$' verb table... 				*/

for (lookup = ptl_lookup; lookup->ptsl_cmds; lookup++)
    if (!strcmp(lookup->ptsl_cmds, verb))
    {
	lookup->cmd_replacemt = def;
        return TRUE;
    }

return FALSE;
}

#if (defined WIN_NT || defined OS2_ONLY)
void fix_nt_mks_lookup()
{
/**************************************
 *
 *	f i x _ n t _ m k s _ l o o k u p
 *
 **************************************
 *
 * Functional description
 * 	If the '-m' command line switch 
 *	has been thrown on NT then this
 *	function has been called and it
 *	will change the ptl_lookup table
 *	such that it contains all of the 
 *	MKS kit calls instead of the DOS.
 *
 **************************************/
struct mks_cmd *replace;
struct ptl_cmd *lookup;

replace = mks_replacement;

/*   	Loop through the '$' verb table... 				*/

for (lookup = ptl_lookup; replace->ptsl_cmds && lookup->ptsl_cmds; lookup++)

{

/*    	If the verb has an MKS replacement--replace it!			*/	

    if (!strcmp(lookup->ptsl_cmds, replace->ptsl_cmds))

    {
	lookup->cmd_replacemt = replace->mks_equiv;
	lookup->ptsl_cmd_text = replace->help_text;
	replace++;
    } 
 
}

}
#endif

static int fix_pas (line, bufr)
    TEXT  *line, *bufr;
{
/**************************************
 *
 *	 f i x _ p a s
 *
 **************************************
 *
 * Functional description
 *	Call fix_compile() to appropriately
 *	translate the environment variables
 *	on the pascal compile line.	
 *
 **************************************/

language = PASCAL;

lang_compile (line, bufr);
return 0;
}

static int fix_qli (line, bufr)
    TEXT  *line, *bufr;
{
/**************************************
 *
 *	f i x _ q l i
 *
 **************************************
 *
 * Functional description
 *       replace any pathname specifiers (and
 *       possibly flags) in an isc  command:
 *       gbak, gfix, gdef, glitj, qli
 *
 **************************************/
TEXT	*tok, *tok2, upc[MAXRPCLN], *wrd, *posn;
struct defn *dptr;

wrd = posn = line;

/*	Loop through the tokens on the line.				*/

while ((tok = (TEXT *)mytokget(&posn, " \t\n")))

{
#ifdef VMS
	 if (!strcmp (tok, "-v"))
		  break;
#endif

/*	If the have an environment variable that is a path name 	*
 *	specifier, call handle_path() to do the right thing.		*/

	 if ((tok2 = (TEXT*) strchr (tok, ':')))
	 {
		  *tok2++ = 0;
		  handle_path (tok, wrd, tok2, &bufr);
/*        *bufr++ = ' '; */
		  wrd = posn;
		  continue;
	 }

	 disp_upcase (tok, upc);
	 dptr = lookup_defn (upc);

/*	If we have an environment variable as the current token, check	*
 *	to make sure it is a valid one and save its value.		*/

	 if (*(dptr->ident))

	 {

/*	Check to make sure the value is valid.				*/

		  if (!*(dptr->replacement))
				continue;
		  else
				tok = dptr->replacement;
	 }

/*	If the token is a filename then call handle_filename() to check	*
 *	the suffixes.							*/

	 else if (strchr (tok, '.'))
		  handle_filename (tok);

	 addstr (tok, &bufr, ' ');
	 wrd = posn;
}

*bufr = 0;
*--bufr = '\n';
return 0;
}

static int fix_run (line, bufr)
	 TEXT *line, *bufr;
{
/**************************************
 *
 *	 f i x _ r u n
 *
 **************************************
 *
 * Functional description
 *	Translate symbols that exist following
 *	the $RUN verb.
 *
 **************************************/
TEXT	 *posn, upc[MAXRPCLN], *tok;
struct defn *dptr;

posn = line;

/*	Loop through the tokens on the line.				*/

while ((tok = (SCHAR *)mytokget(&posn, " \t\n")))

{
	 disp_upcase (tok, upc);
	 dptr = lookup_defn (upc);

/*	Check to make sure if we have found a symbol(environment 	*
 *	variable) that it is valid.  If not continue.			*/

	 if (*(dptr->ident) && !*(dptr->replacement))
	continue;

/*	If we have a symbol, then use it.				*/

	 if (*(dptr->ident))
	tok = (TEXT*) *(dptr->replacement);

	 addstr (tok, &bufr, ' ');
}

*bufr = 0;
*--bufr = '\n';
return 0;
}

static int fix_sys (line, bufr)
    TEXT *line, *bufr;
{
/**************************************
 *
 *	 f i x _ s y s
 *
 **************************************
 *
 * Functional description
 *      replace any defined symbols which may appear in a
 *      standard system call
 *
 **************************************/
TEXT	*posn, upc[MAXRPCLN], *tok, *tok2, *wrd;
struct defn *dptr;

wrd = posn = line;

/*	Loop through the tokens on the line.				*/

while ((tok = (SCHAR *)mytokget(&posn, " \t\n")))

{
	 disp_upcase (tok, upc);

/*	If we find an environment variable that is a path specifier	*
 *	then call handle_path() to do the right thing.			*/

	 if (tok2 = (TEXT*) strchr (tok, ':'))
	handle_path (tok, wrd, tok2, &bufr);

	 else
	 {
	dptr = lookup_defn (upc);

/*	If we have found a symbol (environment variable), then check	*
 *	it and use it.							*/

		  if (*(dptr->ident))

		  {

/*	Check our environment variable to see if it has a value		*/

				if (!*(dptr->replacement))
					 continue;

/*	Assign the value to tok.					*/

				else
					 tok = dptr->replacement;
		  }

/*	If our filename has a dot in it, then call handle_filename()	*
 *	to check the extension set it appropriately.			*/

		  else if (strchr (tok, '.'))
				handle_filename (tok);

	addstr (tok, &bufr, ' ');
	 }

	 wrd = posn;
}

*bufr = 0;
*--bufr = '\n';
return 0;
}

static int handle_extensions (tok, ch)
	 TEXT   *tok, *ch;
{
/**************************************
 *
 *	h a n d l e _ e x t e n s i o n s
 *
 **************************************
 *
 * Functional description
 *
 *         match extension to table
 **************************************/
struct defn *extptr;

for (extptr = extensions; *(extptr->ident); extptr++)
	 if (!strcmp (ch, extptr->ident))
	 {
			*ch = '\0';
			addstr (extptr->replacement, &tok, ' ');
			break;
	 }
  return 0;
}

static int handle_filename (name)
	 TEXT    *name;
{
/**************************************
 *
 *	h a n d l e _ f i l e n a m e
 *
 **************************************
 *
 * Functional description
 *        squish filename for picky systems
 *        a filename (the part before the extension
 *        is SSHORTened to 8 SCHARs with no '_'
 *
 *        On VMS, convert .eftn suffixes to .efor
 *        and .ftn to .for
 *
 *	  On OS2 (PC_PLATFORM ifdef) emasculate the extension
 *        which should be handled by a nice table but
 *        for only 2 instances is it worth it?
 *
 **************************************/
TEXT 	temp[80];
TEXT  *t, *n, *dot;
SSHORT	i, j;
int 	longer = 0;

#ifndef USHORT_NAMES

/*	If name has a suffix, then try to convert...			*/

if (dot = (TEXT*) strchr(name, '.'))

{
 /*	Convert for a gbak extension...
		The only case for now is NT extension .gbk
 */

	 if (!strcmp(dot, ".gbak") && GBAK_EXT && strcmp(dot, GBAK_EXT))

	 {
		  *dot = '\0';
		  strcat (name, GBAK_EXT);
	 }

/*** 	Fix ada extensions...We do complex calculations here		***
 *** 	because ada extensions may get longer than in the TCS		***
 *** 	test.  If this is the case we have to move the rest of		***
 *** 	the line over, else it will get garbled/written over.		***/

#ifdef ADA_EXT
	 else if (!strcmp(dot, ".a") && ADA_EXT && strcmp(ADA_EXT, ".a"))

	 {

/****  Modify .a to appropriate suffix for ada files and save length  	****
 ****  difference in longer.					     	****/
        *temp = '\0';
		  strcpy(temp, dot+3);		    	/* Save next token. */
		  memcpy(dot, ADA_EXT, strlen(ADA_EXT));	/* Add new suffix. */
		  dot += strlen(ADA_EXT)+1;	    	/* Move dot past new suffix. */
		  *(dot-1) = '\0';			/* Insert delimiter. */

/*	If there was anything else on the line, reattach...		*/

		  if(*temp)
		  {
				addstr (temp, &dot, NULL);  /* Reattach following token/line.*/
				longer = strlen(ADA_EXT)-2;	   /* Calculate difference in length.*/
		  }
		  else
			  longer = strlen(ADA_EXT)-3;
	 }
#endif /* ADA_EXT */

/* 	Another fix for an ada gpre file.				*/

#ifdef ADA_GPRE_EXT
	 else if (!strcmp(dot, ".ea") && ADA_GPRE_EXT && strcmp(ADA_GPRE_EXT, ".ea"))

	 {
/****  Modify .ea to appropriate suffix for ada files and save length  ****
 ****  difference in longer.					     ****/
        *temp = '\0';
		  strcpy(temp, dot+4);		    	/* Save next token. */
		  memcpy(dot, ADA_GPRE_EXT, strlen(ADA_GPRE_EXT));  /* Add new suffix. */
		  dot += strlen(ADA_GPRE_EXT)+1;	    	/* Move dot past new suffix. */
		  *(dot-1) = '\0';			/* Insert delimiter. */

/*	If there was anything else on the line, reattach...		*/

		  if(*temp)
		 {
			 /*  Reattach following token/line.  */
				addstr (temp, &dot, NULL);
			 /* Calculate difference in length.  */
				longer = strlen(ADA_GPRE_EXT)-3;
		 }

		 else
			  longer = strlen(ADA_GPRE_EXT)-4;
	 }
#endif /* ADA_GPRE_EXT */

/*** Handle Fortran extensions...					***
 *** We don't do complicated ada calculations here because extension	***
 *** length for fortran stays the same or gets smaller that the		***
 *** extension in the TCS test--It does not get longer.			***/

#ifdef E_FORTRAN_EXT
	 else if (strcmp(dot, ".eftn") == 0 && strcmp(E_FORTRAN_EXT, dot) != 0)

	 {
		  *dot = '\0';
		  strcat (name, E_FORTRAN_EXT);
	 }
#endif

#ifdef FORTRAN_EXT
	 else if (strcmp(dot, ".ftn") == 0 && strcmp(FORTRAN_EXT, dot) != 0)

	 {
		  *dot = '\0';
		  strcat (name, FORTRAN_EXT);
	 }
#endif

/*** Handle Cobol extensions... 					***/
#ifdef E_COBOL_EXT
	 else if (strcmp(dot, ".ecbl") == 0 && strcmp(E_COBOL_EXT, dot))

	 {
		  *dot = '\0';
		  strcat (name, E_COBOL_EXT);
	 }
#endif

#ifdef COBOL_EXT
	 else if (strcmp(dot, ".cbl") == 0 && strcmp(COBOL_EXT, dot))

	 {
		  *dot = '\0';
		  strcat (name, COBOL_EXT);
	 }
#endif

#ifdef E_CXX_EXT
/*** Handle GPRE C++ extensions... The default is .exx according to the docs***/
	 else if (strcmp(dot, ".E") == 0 && strcmp(E_CXX_EXT, dot))

	 {
/****  Modify .a to appropriate suffix for cxx files and save length 	****
 ****  difference in longer.                                         	****/

        *temp = '\0';
		  strcpy(temp, dot+3);               		/* Save next token. */
		  memcpy(dot, E_CXX_EXT, strlen(E_CXX_EXT));	/* Add new suffix. */
		  dot += strlen(E_CXX_EXT)+1;             /* Move dot past new suffix. */
		  *(dot-1) = '\0';                      		/* Insert delimiter. */

/*	If there was anything else on the line, reattach...		*/

		  if(*temp)

		  {
		 /* Reattach following token/line. */
				addstr (temp, &dot, NULL);
		/* Calculate difference in length.*/
				longer = strlen(E_CXX_EXT)-2;
		  }

		  else
				longer = strlen(E_CXX_EXT)-3;
	 }
#endif

#ifdef CXX_EXT
	 else if ((strcmp(dot, ".cxx") == 0 || strcmp(dot, ".C") == 0) &&
			     strcmp(CXX_EXT, dot) != 0)

	 {
/****  Modify .C to appropriate suffix for cxx files and save length 	****
 ****  difference in longer.                                         	****/
        *temp = '\0';
		  strcpy(temp, dot+3);               /* Save next token. */
		  memcpy(dot, CXX_EXT, strlen(CXX_EXT));/* Add new suffix. */
		  dot += strlen(CXX_EXT)+1;             /* Move dot past new suffix. */
		  *(dot-1) = '\0';                      /* Insert delimiter. */

/*	If there was anything else on the line, reattach...		*/

		  if(*temp)

		  {
				addstr (temp, &dot, NULL);   /* Reattach following token/line.*/
				longer = strlen(CXX_EXT)-2;     /* Calculate difference in length.*/
		  }

		  else
				longer = strlen(CXX_EXT)-3;
	 }
}

#endif /* CXX_EXT */

/**** 	Return the length change for a file suffix modifications. 	****/
if (longer < 0)
   return 0;

return longer;

#else

strcpy (temp, name);
j = 8;
if ((temp[0] == '\"') || (temp[0] == '\''))
	 j = 9;

for (t = temp, n = name, i = 0; i < j; t++)
{
	 if ((!*t) || (*t == '.'))
	break;

	 if (*t == '_' )
	continue;

	 *n++ = *t;
	 i++;
}

dot = (TEXT*) strchr (temp, '.');

#ifdef PC_PLATFORM
if (dot)
	 {
	 t = dot + 1;
	 if ((strncmp (t, "gbak", 4)) || (strncmp (t, "burp", 4)))
		  strcpy (t, "gbk");
	 }
#endif

 *n =0;
 strcat (name, dot);

 return 0;
#endif
}

static int handle_keyword (in_line, result)
	 TEXT   *in_line, *result;
{
/**************************************
 *
 *	h a n d l e _ k e y w o r d 
 *
 **************************************
 *
 * Functional description
 *
 *         handle a line or a partial line with
 *         a filename spec in it.  If this line is
 *         empty then return true.  
 *
 **************************************/
TEXT	*wrd, *posn, *tok, *tok2;

wrd = posn = in_line;

/*	Loop through each token on the line.				*/

while ((tok = mytokget(&posn, " \t\n")))

{

/*	Check for an environment variable path specifier.  If found	*
 *	call handle_path to do the work.				*/

    if ((tok2 = (TEXT*) strchr (tok, ':')) && ( *tok != ':' ))

    {
/*      If there was a space following the colon, then this can't be 	*
 *      a TCS environment variable, so move word over and continue.	*/

	  if ( *(tok2+1) == '\0' )
	  {
		 addstr (wrd, &result, ' ');
		 wrd = posn;
		 continue;
	  }

	  *tok2++ = 0; 		/* Get rid of the colon. */
	  handle_path (tok, wrd, tok2, &result);
	  wrd = posn;
	  continue;
	 }


/*	If we have a dot in our token and we are not in the middle of	*
 *	an #include statement then we have a filename, so call  	*
 *	handle_filename to handle the extension.			*/

	 if (strchr (tok, '.') && (!strchr (tok,'<')))
	 handle_filename (tok);

	 addstr (wrd, &result, ' ');
    wrd = posn;
}

*result = 0;
*--result = '\n';  /* Replace the delimeter with a new line */
return 0;
}

static int handle_options (options, opt_template)
    TEXT    *options, *opt_template;
{
/**************************************
 *
 *	h a n d l e _ o p t i o n s
 *
 **************************************
 *
 * Functional description
 *
 *        if this is an options template put it in
 *        the template buffer with a trailing \n and 
 *	  NULL, otherwise, copy it into
 *        the command result buffer.
 *        a template contains %s
 *
 **************************************/
addstr (options, &opt_template, '\n');     

*opt_template = 0;
return TRUE;
}

static int handle_path (tok, wrd, word2, result)
    TEXT    *tok, *wrd, *word2, **result;
{
/**************************************
 *
 *	h a n d l e _ p a t h
 *
 **************************************
 *
 * Functional description
 *
 *        This assumes that a string containing
 *        a ':' has been found and that the word
 *        preceding the colon is likely to be a 
 *        path definition keyword.
 *
 **************************************/
TEXT 	upc[MAXRPCLN], *resultptr;
struct defn *dptr;
int longer = 0;

resultptr = *result;

/* 	skip SCHARs common in #include statements 			*/

while ((*tok == '"') || (*tok == '<') || (*tok == '\'') || (*tok == '\\'))
    tok++;

disp_upcase (tok, upc);
dptr = lookup_defn (upc);

/*  	preserve the leading white space in the result string 		*/

while (wrd < tok)
    *resultptr++ = *wrd++;

/*	If we found a symbol (environment variable) -- use it.		*/

if (*(dptr->ident))

{
    if (*(dptr->replacement))
    {
        addstr (dptr->replacement, &resultptr, PATH_SEPARATER);
    }

    tok = word2;
}

/*	If we didn't find a symbol, then reconstruct the line the way	*
 *	it used to be and return.					*/

else

{
    addstr (tok, &resultptr, NULL);
    *resultptr++ = ':'; 
    addstr (word2, &resultptr, ' ');
    *result = resultptr;
    return longer;
}
    
longer = handle_filename (tok);  	/* Save length to be passed up */
addstr (tok, &resultptr, ' ');

*result = resultptr;

/* 	Pass up the change in length if .a goes to .ada 		*/
return longer;
}

int keyword_search ( string )
    TEXT    *string;
{
/**************************************
 *
 *      k e y w o r d _ s e a r c h
 *
 **************************************
 *
 *	Functional Description
 *	    Search the list of keywords
 *	for the given keyword (string).
 *	For TCS help.
 *
 **************************************/
struct ptl_cmd *ptl_cmd;

/* 	Scan the table for the '$' verb matching string			*/

for (ptl_cmd = ptl_lookup; ptl_cmd->ptsl_cmds && 
		(strcmp (ptl_cmd->ptsl_cmds,string)); ptl_cmd++) ;
      
/* 	If we found it, then print it out.				*/
 
if (ptl_cmd->ptsl_cmds) 

{
    printf ("TCS script '$' verb:\n");
    printf ( "\t%s\t%s\n", ptl_cmd->ptsl_cmds, ptl_cmd->ptsl_cmd_text );
    return TRUE;
}

return FALSE;
}

static int lang_compile (line, bufr)
	 TEXT *line, *bufr;
{
/**************************************
 *
 *	l a n g _ c o m p i l e
 *
 **************************************
 *
 * Functional description
 *	This function is called by fix_cob
 *	fix_pas, fix_ftn, fix_ada.  These
 *	are languages that do not have a %s
 *	in their compile line TCS variables.
 **************************************/
TEXT 		upc[MAXRPCLN], *options, *tok, *posn;
struct defn 	*dptr;

options = NULL;

posn = line;

while ((tok = (char *) mytokget (&posn, " \t\n")))

{
	 disp_upcase (tok, upc);
	 dptr = lookup_defn (upc);

	 if (*(dptr->ident))

	 {
		if (!*(dptr->replacement))
			continue;

	  tok = dptr->replacement;
	  /* Check if we have an option here and leave it to add at the end */
	  if (options = (TEXT*) strchr (dptr->replacement, OPTION_CHAR))
		 continue;
	 }
	 else
	  /*
		* Check extensions and convert it
		* This happens only in this function because we change the
		* natural flow of the tokens and handle_filename() add the rest of the
		* stuff resulting standalone a in the ada line.
		* The fix is to adjust the posn pointer to point at the right spot
		* if we chnage .a to .ada
		*/
		posn += handle_filename (tok);

		addstr (tok, &bufr, ' ');

}
/* Options are added at the very end of the line */
if (options)
	 addstr (options, &bufr, ' ');

*bufr = 0;
*--bufr = '\n';
return 0;
}

void list_keywords( fp, buffer )
	FILE *fp;
	TEXT *buffer;
{
/**************************************
 *
 *	l i s t _ k e y w o r d s
 *
 **************************************
 *
 *	Functional Description
 *	    List all of the $ keywords 
 *	supported in TCS scripts for
 *	current platform. 
 *
 **************************************/
struct ptl_cmd *ptl_cmd;
SSHORT result;
SCHAR  temp[40];

/* 	Dump the table defined in the .h file.  To the screen if we 	*
 *	don't have a FILE pointer, else to the file.			*/

if ( !fp )

{
    for (ptl_cmd = ptl_lookup; ptl_cmd->ptsl_cmds; ptl_cmd++)
        printf ( "\t%s\t%s\n", ptl_cmd->ptsl_cmds, ptl_cmd->ptsl_cmd_text );
}

/*	Dump the table to the file.  Do the equivalent of "more" for	*
 *	the current platform.  Then clean up our work file in an 	*
 *	appropriate manner for the current platform.			*/

else

{
    for (ptl_cmd = ptl_lookup; ptl_cmd->ptsl_cmds; ptl_cmd++)
        fprintf ( fp, "\t%s\t%s\n", ptl_cmd->ptsl_cmds, ptl_cmd->ptsl_cmd_text);

    fclose( fp );
#ifdef apollo
    for ( result = SIGALRM; result == SIGALRM; result = system ( buffer ))
	;
#else
    system( buffer );
#endif
#ifdef VMS
    strcpy (temp, strchr( buffer, 'S'));
    sprintf( buffer, "DELETE  %s;*", temp); 
#else
#ifdef WIN_NT
    sprintf( buffer, "del /f %s", LIST_CMDS_TMPNT); 
#else
    strcpy (temp, strchr( buffer, '/'));
    sprintf( buffer, "rm -f %s", temp); 
#endif
#endif
    system( buffer ); 
}

}

static struct defn *lookup_defn(wrd)
	 TEXT *wrd;
{
/**************************************
 *
 *	l o o k u p _ d e f n
 *
 **************************************
 *
 * Functional description
 *      Look up word in symbol list and return pointer to the
 *      entry in the lookup table.  If no matching entry return
 *      the address of the first empty space.  
 *      If table is empty, return a point to the first empty space.
 *
 **************************************/
struct defn *dptr;

/* 	If the table exists, lookup the word.				*/	

if (defn_ofst)

{
    for (dptr = definitions; *(dptr->ident);  dptr++)
    	if (!strcmp (wrd, dptr->ident))
				break;
}

else
	 return &definitions [0];

return dptr;
}

static TEXT *mytokget (position, delimiters)
    TEXT   **position, *delimiters;
{
/**************************************
 *
 *	m y t o k g e t
 *
 **************************************
 *
 * Functional description
 *
 *         return a pointer to the next interesting
 *         section of a string. 
 *
 **************************************/
TEXT	*ch, *delim, *str;

if (!(**position))
    return (NULL);

/* 	skip delimiters until the string starts 			*/

for (ch = *position; *ch ; ch++)

{
    for (delim = delimiters; *delim && (*ch != *delim); )
	    delim++;

	 if (!*delim)
		break;
}

if (!*ch)
    return (NULL);

str = ch;

/* 	find the delimiter at the end of the string 			*/
while (*ch)

{
    for (delim = delimiters; *delim && (*ch != *delim); )
	delim++;

    if (*delim)
	break;

    ch++;
}

if (*ch)
    *ch++ = 0;

*position = ch;

return (str);
}

static int process_command (in_line, result)
	 TEXT *in_line, *result;
{
/**************************************
 *
 *	p r o c e s s _ c o m m a n d
 *
 **************************************
 *
 * Functional description
 *      Find the command. Move it to the result string.
 *      Pass the rest of the in_line and the result to
 *      an appropriate fix routine
 *
 **************************************/
TEXT	*resultptr, *word1, *word2, *posn;
SSHORT  found;
TEXT	upc[MAXRPCLN];
struct defn *dptr;
struct ptl_cmd *lookup;

found = 0;
posn = in_line;

/* 	handle empty commands 						*/

if (!(word1 = mytokget (&posn, " $\t\n")) || (!*word1))

{
	 strcpy (result, in_line);
	 return TRUE;
}

for (resultptr = result; in_line < word1; )
	 *resultptr++ = *in_line++;

/* look for a command */

while (!found)
{
	 disp_upcase(word1,  upc);

/* 	is this in the command table? 					*/

	 for (lookup = ptl_lookup; lookup->ptsl_cmds; lookup++)
	if (!strcmp(lookup->ptsl_cmds,  upc))
	{
		  found = 1;
		  break;
	}

/* 	yes - copy it and leave the loop 				*/
	 if (found)
	 {
#if (defined WIN_NT || defined OS2_ONLY)
/***** On NT with '-m'(MKS) switch thrown $RUN translates to "./" so    *****
 ***** must not put space between "./" and the filename.		*****/
	if (sw_nt_mks)

	{
		 if (!strcmp(upc, "RUN"))
		addstr (lookup->cmd_replacemt, &resultptr, NULL);

		 else
				addstr (lookup->cmd_replacemt, &resultptr, ' ');
	}
	 else
#endif
	  addstr (lookup->cmd_replacemt, &resultptr, ' ');
	  break;
	}

/* 	no - so if its a path we need to look up the definition 	*/

	 if ((word2 = (TEXT*) strchr (upc, ':')))
	*word2++ = 0;

	 dptr = lookup_defn (upc);

/* 	If we found the definition, move it in.				*/

	 if (*(dptr->ident))

	 {
	addstr (dptr->replacement, &resultptr, PATH_SEPARATER);
	word1 = word2;

/*	If there is no token following path, then we have a syntax 	*
 *	error.								*/

		  if (!word2)

		  {
				print_error ("Unexpected end of command: %s\n",in_line,0,0);
				return FALSE;
		  }

	continue;
	 }

/*	Otherwise we could not translate...print error			*/

	 else

	 {
	print_error ("Can't translate: %s. Giving up.\n",word1,0,0);
	return FALSE;
	 }
}

/*	If the $ verb was not found then print an error.		*/

if (!found)
{
	 print_error ("Untranslatable command: %s \n",  in_line,0,0);
	 return FALSE;
}

/*	Call the function associated with this $ verb if it exists	*/

if (lookup->fixup)
	 (*lookup->fixup)(posn, resultptr);

return TRUE;
}

static int process_defn (in_line, result)
	 TEXT  *in_line, *result;
{
/**************************************
 *
 *      p r o c e s s _ d e f n
 *
 **************************************
 *
 * Functional description
 *      This routine handles symbol definition.  If a new symbol is
 *      received it is added to the table.  If the symbol is already
 *      defined the definition is replaced with the new one.
 *
 **************************************/
TEXT	*word1, *word2, *posn;
static TEXT	w2 = 0;
struct defn *dptr;

posn = in_line;

/*	Get the environment variable name...				*/

if (!(word1 = mytokget(&posn, " :\t\n")))
    return TRUE;

/* 	Get the value...						*/

if (!(word2 = mytokget(&posn, "\n")))
    word2 = &w2;

/* 	find a definition and replace it if we can.			*
 *   	otherwise, point at 1st empty slot 				*/

/*	If there are any entries in the symbol definition table, then	*
 *	check to see if our symbol exists, and if it does replace it	*
 *	quickly.							*/

if (defn_ofst)				/* This is a counter of symbols */

{
    dptr = lookup_defn (word1);

/*	If we found the symbol in the table, replace with the new one.	*/

    if (*(dptr->ident))

    {
	strcpy (dptr->replacement, word2);
        return TRUE;
    }
}

/*	The symbol definition/replacement table has zero entries	*/

else 
    dptr = definitions;

/* 	store a new definition and mark the end of the table		*/

if (defn_ofst < MAXDEFNS)

{
    strcpy(dptr->ident, word1);
    strcpy(dptr->replacement, word2);
    defn_ofst++;
    dptr++;
    *(dptr->ident) = 0;
    *(dptr->replacement) = 0;
}

else
    print_error ("Maximum number of symbol definitions exceeded\n",0,0,0);

return TRUE; 
}

static int process_noxcmd (in_line, result)
    TEXT *in_line, *result;
{
/**************************************
 *
 *	p r o c e s s _ n o x c m d _ l i n e
 *
 **************************************
 *
 * Functional description
 *      This routine removes the '^" from the front of a command line
 *      that is not to be translated.
 *      
 **************************************/

strcpy(result, ++in_line);
return TRUE;
}

static int process_regtxt (in_line, result)
    TEXT *in_line, *result;
{
/**************************************
 *
 *	p r o c e s s _ r e g t x t 
 *
 **************************************
 *
 * Functional description
 *      This routine processes  the regular text portion of the script.
 *      one string at a time.
 *      It will do symbol substitution for paths if used in a #include,
 *      ready or database statement.  
 *
 *      a DATABASE statement can extend over 2 lines. To process this 
 *      correctly we set keyword and unset it as soon as we find another token
 *      
 **************************************/
TEXT	*wrd, *posn, *rsltptr;
static char parse_database = 0;

rsltptr = result;
wrd = posn = in_line;

/*	If the line contains 'database' then set parse_database to true	*/
if (strstr(wrd,"DATABASE")	||
	 strstr(wrd,"database")	||
	 parse_database)
{
	 parse_database = 1;
}

/*	If the line contains a ';' and parse_database is true then set	*
 *	parse_database to false.					*/
if (strchr(wrd, ';')) parse_database = 0;

/*	If the line is blank or does not contain a colon or a dot then	*
 *	move the line to result and return.				*/
if ((*wrd == '\n') || (!strchr (wrd, ':') && !strchr (wrd, '.')))
{
	 strcpy (result, in_line);
	 return TRUE;
}

/*	If the line does not contain '#include', 'ready' or 'connect'	*
 *	then move the line to result and return.			*/

if ((!strstr(wrd,"#include"))	&&
	 (!strstr(wrd,"#define"))	&&
	 (!strstr(wrd,"CONNECT"))	&&
	 (!strstr(wrd,"connect"))	&&
	 (!strstr(wrd,"READY"))	&&
	 (!strstr(wrd,"ready"))	&&
	 (!strstr(wrd,"DATABASE"))	&&
	 (!strstr(wrd,"database"))	&&
	 (!strstr(wrd,"SCHEMA"))	&&
	 (!strstr(wrd,"schema"))	&&
	 (!parse_database))
{
	 strcpy (result, in_line);
	 return TRUE;
}

/*
 * Processes all the tokens and replaces the env variables
 * Adds \n at the end of the line and zero terminates the string
 */
handle_keyword (posn, rsltptr);

return TRUE;
}

static int zap_hp_dollarsign (target)
    TEXT *target;
{
/**************************************
 *
 *	z a p _ h p _ d o l l a r s i g n
 *
 **************************************
 *
 * Functional description
 *      1. vector is a table of strings, indexed by
 *      first SCHAR and starting with 2nd SCHAR (add
 *      would have index (int) a and point to "dd0"
 *      2.  we go through each string looking up
 *      character in table, checking ensuing chs if
 *      theres a match and only replacing a $ if theres
 *      a string match.. 
 *
 **************************************/
TEXT	*p, *s1;
UCHAR	c;
                                                                   
/* If this is a System V based port, do any qualified name fixups.	*/

p  = target;
s1 = NULL;

while (c = *p++)

{
    if (s1 && c != *s1++)

    {
        if (c == '$' && !s1 [-1])
	    p [-1] = '_';

	s1 = NULL;
    }

    if (!s1)
        s1 = vector [c];
}
  return 0;   
} 
static int zap_under_under (target)
    TEXT *target;
{
/**************************************
 *
 *	z a p _ u n d e r _ u n d e r
 *
 **************************************
 *
 * Functional description
 *      1. vector is a table of strings, indexed by
 *      first SCHAR and starting with 2nd SCHAR (add
 *      would have index (int) a and point to "dd0"
 *      2.  we go through each string looking up
 *      character in table, checking ensuing chs if
 *      theres a match and only replacing a $ if theres
 *      a string match.. 
 *
 **************************************/
TEXT	*p, *s1;
UCHAR	c;
                                                                   
/* If this is a System V based port, do any qualified name fixups.	*/

p  = target;
s1 = NULL;

while (c = *p++)

{
    if (s1 && c != *s1++)

    {
        if (c == '_' && !s1 [-1])
	    p [-1] = '$';

	s1 = NULL;
    }

    if (!s1)
        s1 = vector [c];
}
 return 0;    
} 


static int zap_vms_run (in_line, result)
    TEXT *in_line, *result;
{
/**************************************
 *
 *	z a p _ v m s _ r u n
 *
 **************************************
 *
 * Functional description
 *   handle the case where we want to execute a
 *   local image with command line arguments
 *
 **************************************/
USHORT	tokct;
TEXT	*posn;

strcpy (in_line, result);
posn = in_line;
tokct = 0;

/*	Move past the execute and executable name			*/

mytokget (&posn, " \t\n");
mytokget (&posn, " \t\n");

/*	Count the command line args?					*/

while (mytokget(&posn, " \t\n"))
    tokct++;

/* 	If we have arguments then move them in?				*/	

if (tokct > 1)

{
    in_line[2] = '\0';
    strcat (in_line, &result[5]);
    strcpy (result, in_line);
}
 return 0;
}
