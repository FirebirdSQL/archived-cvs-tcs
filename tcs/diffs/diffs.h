/*
 *	PROGRAM:	isc_diffs
 *	MODULE:		diffs.h
 *	DESCRIPTION:	defines, includes and typedefs
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

#define FALSE   0
#define TRUE    1

#define PAGESIZE	4096	/* default line page size */
#define MASK		0x0FFF	/* 12 bit hash value */
#define MAXLINE		256	/* maximum line length */

#define CHANGE		0	/* change a range of lines */
#define DELETE		1	/* delete a range of lines */
#define ADD		2	/* add a range of lines */
#define TRUE		1
#define FALSE		0
#define MIN(a,b)	((a < b) ? a : b)
#define UPPER(c)	(((c) >= 'a' && (c)<= 'z') ? (c) - 'a' + 'A' : (c))
#define OUTFILE         "dif.out"
#define BUFSIZE        4096
#define BUF_FULL       4080

/* Data Types */

typedef short           SSHORT;
typedef unsigned short  USHORT;
typedef unsigned short  BOOLEAN;
typedef long            SLONG;
typedef unsigned long   ULONG;
typedef char            TEXT;
typedef char		SCHAR;
typedef unsigned char   UCHAR;

typedef struct 
{
	TEXT	*addr;		/* address of string in buffer*/
	ULONG	hash;	        /* hash value for string */
	SLONG	linenum;	/* line number in file */
}
LINE;

typedef struct file_block
    {                      
    TEXT	*buffer;
    SLONG	line_count;
    LINE		line_ptr [1];
} *FILE_BLK_PTR, FILE_BLK;

static SLONG window;                      
static SLONG minmatch;
static SLONG ignore_whtsp;


extern UCHAR*   ISC_EXPORT gds__alloc (SLONG);
