/*
 *	PROGRAM:	diffs
 *	MODULE:		do_diffs.c
 *	DESCRIPTION:	subroutine version of our diff utility
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
#include <errno.h>
#include <string.h>
#include <ibase.h>
#include "diffs.h"

#if (defined PC_PLATFORM || defined WIN_NT)
#include <io.h>
#include <stdlib.h>
#else
#ifndef LINUX
extern char	*sys_errlist[];
extern int	sys_nerr;
#endif
#endif

/* This variable comes from either diffs.c for isc_diff, or tcs.e for tcs */
extern unsigned short	disk_io_error;

#ifdef mpexl
#define FOPEN_READ_TYPE		"r Tm"
#define FOPEN_WRITE_TYPE	"w Ds2 V E32 S100000"
#endif

#ifndef FOPEN_READ_TYPE
#define FOPEN_READ_TYPE		"r"
#define FOPEN_WRITE_TYPE	"w"
#endif
                        
static USHORT	check_match();
static ULONG	hash();
static LINE		*read_file();
static void print_lines(), do_diff();



int do_diffs (input_1, input_2, diff_file, sw_win, sw_match, sw_ignore)
    TEXT *input_1, *input_2, *diff_file;
    USHORT sw_win, sw_match, sw_ignore;

{
/**************************************
 *
 *	d o _ d i f f s
 *
 **************************************
 *
 * Functional description
 *
 **************************************/
FILE		*fileptr1, *fileptr2, *outfile;
FILE_BLK_PTR	file_block1, file_block2;
LINE		*line1, *line2;
TEXT		*p;

if ( !(fileptr1 = fopen (input_1, FOPEN_READ_TYPE)))
    {
    fprintf (stderr, "ISC_DIFF: Unable to open %s\n", input_1);
#ifndef PC_PLATFORM
    fprintf (stderr, "%s\n", sys_errlist [errno]);
#endif
    disk_io_error = TRUE;
    return FALSE;
    }

if ( !(fileptr2 = fopen (input_2, FOPEN_READ_TYPE)))
    {
    fprintf (stderr, "ISC_DIFF: Unable to open %s\n", input_2);
#ifndef PC_PLATFORM
    fprintf (stderr, "%s\n", sys_errlist [errno]);
#endif
    disk_io_error = TRUE;
    return FALSE;
    }

if ( !(outfile = fopen (diff_file, FOPEN_WRITE_TYPE)))
    {
    fprintf (stderr, "ISC_DIFF: Unable to open %s\n", diff_file);
#ifndef PC_PLATFORM
    fprintf (stderr, "%s\n", sys_errlist [errno]);
#endif
    disk_io_error = TRUE;
    return FALSE;
    }

window = (sw_win) ? sw_win: 75;
minmatch = (sw_match) ? sw_match : 6;
ignore_whtsp = sw_ignore;

if ((( line1 = read_file (fileptr1, &file_block1)) == NULL) ||
	    ((line2 = read_file (fileptr2, &file_block2)) == NULL))
    {
    fprintf( stderr, "ISC_DIFF: Out of memory\n" );
    return FALSE;
    }

do_diff(outfile, line1, line2, file_block1->line_count, file_block2->line_count);
fclose (fileptr1);
fclose (fileptr2);
fclose (outfile);
return TRUE;
}

static BOOLEAN check_match(line1, line2, min, linesleft)
LINE *line1, *line2;
SLONG  min, linesleft;     
{
/**************************************
 *
 *	c h e c k _ m a t c h 
 *
 **************************************
 *
 * Functional description
 *        make sure that we have a context
 *        of n strings in a match
 *        as we approach end of buffer stop
 *        being so picky lest we venture
 *        beyond our buffers
 **************************************/
SLONG	i;

if (linesleft < window + min)
    return TRUE;

for (i = 0; i < min;) 
    {
    i++;
    if (line1->hash != line2->hash)
	{
	return FALSE;
	}
    line1++;
    line2++;
    }
return TRUE;
}

static int check_lines( line1, line2, end1, end2, count1, count2,linesleft)
    LINE     **line1, **line2;		
    SLONG     *end1, *end2, count1, count2, linesleft;
    
{
/**************************************
 *
 *	c h e c k _ l i n e s
 *
 **************************************
 *
 * Functional description 
 *      This is a rough check for blatant difference 
 *      Check to see if the hash codes match in this
 *      window. 
 *
 **************************************/
SLONG	i, j;
LINE 	*loop1, *loop2;

loop1 = *line1;

for (i = 0; i != count1; )
    {
    if (!loop1->hash)
	{
	i++;
	loop1++;
	continue;
	}
    loop2 = *line2;
    for (j = 0 ; j < count2; j++, loop2++)
	{
	if  ((loop1->hash == loop2->hash)&&(!strcmp (loop1->addr, loop2->addr)))
	   {
	   if (check_match (loop1, loop2, minmatch, linesleft))
	       {
		*end1 = i;
		*end2 = j;
		*line1 = loop1;
		*line2 = loop2;
		return (TRUE);
	       }
	   }
	}
    i++;
    loop1++;
    }
/* no matches so theres a delete from file1 of i lines */
*line1 = loop1;
*end1 = i;
*end2 = 0;
return (FALSE);
}


static void do_diff (outfile, line1, line2, linecount1, linecount2)
    FILE     *outfile;		
    LINE     *line1, *line2;
    SLONG     linecount1, linecount2;    
{
/**************************************
 *
 *	d o _ d i f f
 *
 **************************************
 *
 * Functional description
 * 	
 *      Do a simple minded interative diff	
 *      checking to be sure that at least min
 *      lines match
 **************************************/                        
SLONG  	max_line1, max_line2, end1, end2;
SLONG	i, j, match, linesleft;
LINE 	*line1ptr, *line2ptr;
	
i = j = 0;
linesleft = MIN (linecount1, linecount2);
while ((i < linecount1) && (j < linecount2))
    {
        if ((line1->hash == line2->hash) && (!strcmp (line1->addr, line2->addr)))
	    {
	    line1++;
	    line2++;
	    i++;
	    j++;
	    linesleft--;
            continue;
	    }
	else
	    {
	    end1  = 0;
	    end2 = 0;
	    max_line1 = MIN (linecount1 - i, window);
	    max_line2 = MIN (linecount2 - j, window);
	    line2ptr = line2;
	    line1ptr = line1;
	    check_lines (&line1ptr, &line2ptr, &end1, &end2, max_line1, max_line2,linesleft);
	    print_lines(outfile, line1, line2, end1, end2);
            i += end1;
            j += end2;
	    linesleft = MIN (linecount1 - i, linecount2 - j);
	    line2 = line2ptr;
	    line1 = line1ptr;
	    }
	
    }
if (j < linecount2)
    print_lines (outfile, line1, line2, (SLONG) 0, linecount2 - j );
else 
   if (i < linecount1)
       print_lines(outfile, line1, line2, linecount1 - i, (SLONG) 0); 
}

static ULONG hash (str)
    SCHAR *str;    
{
/**************************************
 *
 *	h a s h
 *
 **************************************
 *
 * Functional description
 * 
 *  	get stringlength and hashvalue 
 **************************************/
ULONG	chksum;
SCHAR 	*s;
                                       
/*--- Compute checksum of string ---*/

for ( chksum = 0, s = str ; *s ; chksum ^= *s++ )
	;

/*--- return combined 7-bit checksum and length ---*/

return ((chksum & MASK) | ((s - str) << 8) ) ;
}


static void print_lines (outfile, lines1, lines2, end1, end2 )
    FILE    *outfile;
    LINE    *lines1, *lines2;
    SLONG    end1, end2;
{
/**************************************
 *       
 *	p r i n t _ l i n e s 
 *
 **************************************
 *
 * Functional description
 *       fill a diffs file?
 *	file1 is source (or old file) file2 target
 **************************************/
BOOLEAN bSeparator = FALSE;
SLONG nType ;
SCHAR range1[32], range2[32], str[MAXLINE];
	
if (!end2)
    nType = DELETE ;
else if (!end1)
    nType = ADD ;
else
    nType = CHANGE ;
	
if (end1)
    if ( end1 > 1 )
	sprintf(range1, "%ld,%ld", lines1->linenum, lines1->linenum + end1 - 1);
    else
       	sprintf(range1,"%ld", lines1->linenum);
     
if (end2)
    if ( end2 > 1 )
	sprintf(range2, "%ld,%ld", lines2->linenum, lines2->linenum + end2 - 1);
    else 
    	sprintf(range2,"%ld", lines2->linenum);
		
switch (nType)
    {
    case CHANGE:		/* change a range of lines */
        if (fprintf (outfile,"%s c %s\n", range1, range2) == EOF)
	    disk_io_error = TRUE;
        bSeparator = TRUE;
        break;
    case DELETE:
        if (fprintf (outfile,"%s d %ld\n", range1, lines2->linenum) == EOF)
	    disk_io_error = TRUE;
        break ;
    case ADD:
        if (fprintf(outfile, "%ld a %s \n", lines1->linenum, range2) == EOF)
	    disk_io_error = TRUE;
	break;
    }

/*--- print the line range(s) ---*/
for ( ;end1--; lines1++)
    {
    if (fprintf(outfile, "< %s", lines1->addr) == EOF)
	disk_io_error = TRUE;
    if (putc ('\n', outfile) == EOF)
	disk_io_error = TRUE;
    }
     
if ( bSeparator ) 
    if (fprintf(outfile, "---------------------------------------------\n" ) == EOF)
	disk_io_error = TRUE;

for ( ;end2--; lines2++)
    {
    if (fprintf(outfile, "> %s", lines2->addr) == EOF)
	disk_io_error = TRUE;
    if (putc ('\n', outfile) == EOF)
	disk_io_error = TRUE;
    }

if (fprintf(outfile, "++++++++++++++++++++++++++++++++++++++++++++++++++\n" ) == EOF)
    disk_io_error = TRUE;
}

static LINE *read_file (fileptr, fileblock)
    FILE   	 	*fileptr;
    FILE_BLK_PTR	*fileblock;
{
/**************************************
 *
 *	r e a d _ f i l e
 *
 **************************************
 *
 * Functional description
 *  we  shall see
 **************************************/
LINE 	*thisline;
int	c, lastc;
SLONG	i, linecount, charcount, n, sol;
UCHAR	*ptr,*bufptr, *moreptr, *thisptr;

n = 2;
sol = TRUE;
lastc = 0;

if ((bufptr = (UCHAR*) gds__alloc ((SLONG) BUFSIZE)) == NULL)
    return NULL;;
thisptr = bufptr;
for (linecount = 0, charcount = 0;; charcount++)
    {
    if (charcount % BUFSIZE == BUF_FULL)
	{
	if ((moreptr = (UCHAR*) gds__alloc ((SLONG) (n++ * BUFSIZE))) == NULL)
	    return NULL;;
	thisptr = moreptr;
	ptr = bufptr;
	for (i = charcount; i-- ; )
	    *thisptr++ = *ptr++;
	ptr = bufptr;
	bufptr = moreptr;
	isc_free (ptr);
	}
    c = fgetc(fileptr);
    if (c == EOF)
        break;
    if (c == '\n')
        {
	if (ignore_whtsp && lastc == ' ')
	    thisptr--;
	*thisptr++ = 0;
	linecount++;
	sol = TRUE;
	lastc = 0;
	}
    else
	{
        if (!ignore_whtsp)
            *thisptr++ = c;
        else
            {
	    if (c == '\t' || c == ' ')
	        {
	        c = ' ';
	        if (lastc == ' ' || sol == TRUE)
		    charcount--;
	        else
		    *thisptr++ = c;
	        }
	    else
	        *thisptr++ = c;
	    lastc = c;
	    }
	sol = FALSE;
	}
    }
    

if ((*fileblock = (FILE_BLK_PTR) gds__alloc ((SLONG) (sizeof (FILE_BLK) + ((1 + linecount) * sizeof(LINE))))) == NULL)
    return NULL;
(*fileblock)->buffer = (TEXT *)bufptr;
(*fileblock)->line_count = linecount;
thisline = (*fileblock)->line_ptr;
for (i = 1;linecount--; i++)
    {
    thisline->addr = (TEXT*) bufptr;
    thisline->hash = hash (bufptr);
    thisline->linenum = i;
    while (*bufptr++);
    thisline++;
    }
/* one extra record for adds and deletes at fileend */
thisline->linenum = (*fileblock)->line_count + 1;
thisline->hash = 0;
thisline->addr = NULL;

return (*fileblock)->line_ptr;
}
