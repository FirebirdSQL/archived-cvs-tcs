/*
 *      PROGRAM:        Test Control System
 *      MODULE:         display.e
 *      DESCRIPTION:    put things on the screen
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

#include <stdio.h>
#include <string.h>
#include "tcs.h"
#include <gds.h>
#if (defined WIN_NT || defined OS2_ONLY || defined(SINIXZ))
static ULONG *open_blob (SLONG* blob_id, SLONG* db_handle);
static int response (SCHAR* response_string, int length);
int disp_upcase (TEXT* string, TEXT* name);
#else

static ULONG *open_blob();

#endif

DATABASE TCS = EXTERN COMPILETIME FILENAME "ltcs.gdb";
DATABASE TCS_GLOBAL = EXTERN COMPILETIME FILENAME "gtcs.gdb";




int DISP_add_series (db_flag, meta, series, sequence)
    TEXT   db_flag, *meta, *series;
    SSHORT  sequence;
{
/**************************************
 *
 *	D I S P _ a d d _ s e r i e s
 *
 **************************************
 *
 * Functional description
 *     handle details of adding series to metaseries
 *
 **************************************/
USHORT	max;

/*	If the flag passed in (db_flag) is 'l' then check the local	*
 *	DB for the meta series.  If the meta series exists then store	*
 *	the series name and sequence number == sequence.		*/

if (db_flag == 'l')

{

/*	If the sequence number is negative one then we need to use the	*
 *	last existing sequence number to create a new one.  Find the 	*
 *	last sequence number, add one to it and make that the new 	*
 *	sequence number.						*/

    if (sequence == -1)

    {
        max = 0;
        FOR M IN TCS.META_SERIES WITH M.META_SERIES_NAME EQ meta
           max = MAX (max, M.SEQUENCE);
        END_FOR;
        sequence = max + 1;
    }

/*	Add series to the meta series ...				*/

    STORE M IN TCS.META_SERIES
        gds__vtov (series, M.SERIES_NAME, sizeof (M.SERIES_NAME));
        gds__vtov (meta, M.META_SERIES_NAME, sizeof (M.META_SERIES_NAME));
        M.SEQUENCE = sequence;
    END_STORE;
    return 0;
} 

/*	If the flag passed in (db_flag) is 'g' then check the global 	*
 *	DB for the meta series.  If the meta series exists then store	*
 *	the series name and sequence number == sequence.		*/

if (db_flag == 'g')

{

/*	If the sequence number is negative one then we need to use the	*
 *	last existing sequence number to create a new one.  Find the 	*
 *	last sequence number, add one to it and make that the new 	*
 *	sequence number.						*/

    if (sequence == -1)

    {
        max = 0;
        FOR M IN TCS_GLOBAL.META_SERIES WITH M.META_SERIES_NAME EQ meta
           max = MAX (max, M.SEQUENCE);
        END_FOR;
        sequence = max + 1;
    }

/*	Add series to the meta series ...				*/

    STORE M IN TCS_GLOBAL.META_SERIES
        gds__vtov (series, M.SERIES_NAME, sizeof (M.SERIES_NAME));
        gds__vtov (meta, M.META_SERIES_NAME, sizeof (M.META_SERIES_NAME));
        M.SEQUENCE = sequence;
    END_STORE;
}
 return 0;
}

int DISP_add_test (db_flag, series, test, sequence)
    TEXT   db_flag, *series, *test;
    SSHORT  sequence;
{
/**************************************
 *
 *	D I S P _ a d d _ t e s t
 *
 **************************************
 *
 * Functional description
 *                               
 *    handle details of adding test to series
 *
 **************************************/
USHORT	max;

/*	If the flag passed in (db_flag) is 'l' then check the local	*
 *	DB for the series.  If the series exists then store the test	*
 *	name and sequence number == sequence.				*/

if (db_flag == 'l')

{

/*	If the sequence number is negative one then we need to use the	*
 *	last existing sequence number to create a new one.  Find the 	*
 *	last sequence number, add one to it and make that the new 	*
 *	sequence number.						*/

	 if (sequence == -1)

	 {
		  max = 0;
		  FOR M IN TCS.SERIES WITH M.SERIES_NAME EQ series
			  max = MAX (max, M.SEQUENCE);
		  END_FOR;
		  sequence = max + 1;
	 }

/*	Add test to the series ...					*/

	 STORE M IN TCS.SERIES
		  gds__vtov (series, M.SERIES_NAME, sizeof (M.SERIES_NAME));
		  gds__vtov (test, M.TEST_NAME, sizeof (M.TEST_NAME));
		  M.SEQUENCE = sequence;
	 END_STORE;
	 return 0;
}

/*	If the flag passed in (db_flag) is 'g' then check the global 	*
 *	DB for the series.  If the series exists then store the test	*
 *	name and sequence number == sequence.				*/

if (db_flag == 'g')

{

/*	If the sequence number is negative one then we need to use the	*
 *	last existing sequence number to create a new one.  Find the 	*
 *	last sequence number, add one to it and make that the new 	*
 *	sequence number.						*/

	 if (sequence == -1)

	 {
		  max = 0;
		  FOR M IN TCS_GLOBAL.SERIES WITH M.SERIES_NAME EQ series
			  max = MAX (max, M.SEQUENCE);
		  END_FOR;
		  sequence = max + 1;
	 }

/*	Add test to the series ...					*/

	 STORE M IN TCS_GLOBAL.SERIES
		  gds__vtov (series, M.SERIES_NAME, sizeof (M.SERIES_NAME));
		  gds__vtov (test, M.TEST_NAME, sizeof (M.TEST_NAME));
		  M.SEQUENCE = sequence;
	 END_STORE;
}
  return 0;
}


int disp_get_string (prompt_string, response_string, length)
SCHAR	*prompt_string, *response_string;
int		length;
{
/**************************************
*
*	d i s p _ g e t _ s t r i n g
*
**************************************
*
* Functional description
*	Write a prompt and read a string.  If the string overflows,
*	try again.  If we get an EOF, return FAILURE.
*
**************************************/          
printf ("%s: ", prompt_string);

if (!response(response_string, length))
    return FALSE;  

return TRUE;
}      
          
int disp_get_answer (prompt_string, response_string, length)
SCHAR	*prompt_string, *response_string;
int		length;
{
/**************************************
*
*	g e t _ a n s w e r
*
**************************************
*
* Functional description
*	Write a prompt and read a string.  If the string overflows,
*	try again.  If we get an EOF,or upcase (input)
*       == "QUIT", return FAILURE.
*
**************************************/          

printf ("%s: ", prompt_string);

if (!response(response_string, length))
   return FALSE;   

disp_upcase (response_string, response_string);

if (!strcmp (response_string, "QUIT"))
    return FALSE;      

return TRUE;
}      

int disp_print_blob (blob_id, db_handle)
    SLONG	*blob_id;
    SLONG	*db_handle;
{
/**************************************
 *
 *	d i s p _ p r i n t _ b l o b
 *
 **************************************
 *
 * Functional description
 *	Dump a blob to standard out.
 *
 **************************************/
TEXT	buffer [1028];
SSHORT	length = 0;
ULONG	*blob;
STATUS	status_vector [20];
SSHORT  buf_len;
USHORT	lines = 0;


/*	Open the BLOB, if not successful then return */

if (!(blob = open_blob (blob_id, db_handle)))
{
    return TRUE;
}

/*	Loop through the blob for each segment, printing each segment	*
 *	to stdout as we go.						*/

buf_len = sizeof (buffer) - 1;	/* APOLLO cannot type cast const value */

/*  I changed the following  to handle blobs with segment_length > buf_len
 *  though I don't know why we don't use BLOB_display directly  
 *  FSG 11.Nov.2000                                                    */


for (;;)
{ 
       gds__get_segment (status_vector,
	GDS_REF (blob),
	GDS_REF (length),
	buf_len,		/* SSHORT, not int.	Andrew  */
	buffer);

       if (status_vector [1] && status_vector [1] != gds__segment)
        {
        if (status_vector [1] != gds__segstr_eof)
                gds__print_status (status_vector);
        break;
        }
    if (lines++ == 0)
	printf ("-------------------\n");
    buffer [length] = 0;
    fputs (buffer, stdout);
}


/*	Close the BLOB and clean up.					*/	

gds__close_blob (status_vector, GDS_REF (blob));

#ifndef DECOSF
if (lines && buffer [length - 1] != '\n')
    putchar ('\n');
#endif

if (lines)
    printf ("-------------------\n");

return FALSE;    
}

          
int disp_upcase (string, name)
    TEXT	*string, *name;
{
/**************************************
 *
 *	d i s p _ u p c a s e
 *
 **************************************
 *
 * Functional description
 *	Translate a string into a name.  The string may be either
 *	blank or null terminated.  The output name is null terminated.
 *
 **************************************/
TEXT	c;

while ((c = *string++) && c != ' ')
    *name++ = UPPER (c);

*name = 0;

 return 0;
}

          
static ULONG *open_blob (blob_id, db_handle)
	 SLONG	*blob_id;
	 SLONG	*db_handle;
{
/**************************************
 *
 *	o p e n _ b l o b
 *
 **************************************
 *
 * Functional description
 *	Open a blob and check the status.  If everything is ok,
 *	return the blob handle, else NULL.
 *
 **************************************/
ULONG	*blob;
STATUS	status_vector [20];

blob = NULL;

if (!gds__open_blob (NULL, 
	GDS_REF (db_handle), 
	GDS_REF (gds__trans), 
	GDS_REF (blob), 
	GDS_VAL (blob_id)))
    return blob;

gds__print_status (status_vector);
return NULL;
}

          
static int response (response_string, length)
    SCHAR	*response_string;
    int	length;
{
/**************************************
*
*	r e s p o n s e
*
**************************************
*
* Functional description
*	read a string.  If the string overflows,
*	try again.  If we get an EOF, return FAILURE.
*
**************************************/          
SCHAR	*p;
SSHORT	l, c;


/*	Loop...keep trying to read the string				*/
 
while (TRUE)

{

/*	Read from the prompt, moving the response into response_string	*
 *	while making sure the buffer does not overflow (length).	*/

    for (p = response_string, l = length; l; --l)

    {
    	c = getchar();

/*	Hit an EOF prematurely...					*/

        if (c == EOF)
            return FALSE;

/*	If we got through the whole line put a NULL at the end and 	*
 *	return happily.							*/	

        if (c == '\n')

        {
            *p = 0;
            return TRUE;
        }

        *p++ = c;
    }

/*	Buffer overflowed, finish reading the line			*/

    while (getchar() != '\n')
        ;

	 print_error ("** Maximum length of a string is exceeded **\n",0,0,0);
    }
}

