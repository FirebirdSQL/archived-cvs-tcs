/*
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

EXEC SQL
   INCLUDE SQLCA;

/* EXEC SQL
   WHENEVER SQLERROR GO TO ERR; */

EXEC SQL 
   SET SCHEMA DB = "atlas.gdb"; 

/* DATABASE DB = "atlas.gdb"; */

main(argc,argv) 
int argc;
char **argv;
{
  char inp[2];

  if (!qa_mu_init(argc,argv,0))
  {
	printf("Error ... Exitting\n");
	qa_mu_cleanup();
	exit(1);
  }

EXEC SQL CONNECT DB ;
/* READY DB; */

EXEC SQL SET TRANSACTION RESERVING CITIES FOR SHARED WRITE;
/* START_TRANSACTION; */
  qa_mu_pause ();
  printf ("In p1: after set trans \n");

  EXEC SQL 
	UPDATE CITIES SET CITY = 'FOO' WHERE POPULATION > 300000;
  printf("Updated cities in p1 for : UPDATE CITIES SET CITY = 'FOO' WHERE POPULATION > 300000 \n");
  qa_mu_pause();
  printf ("In p1: after first update \n");

  EXEC SQL 
	UPDATE CITIES SET CITY = 'LOO' WHERE POPULATION < 100000;
  printf("Updated cities in p1 for : UPDATE CITIES SET CITY = 'LOO' WHERE POPULATION < 100000 \n");
  qa_mu_pause();
  printf ("in p1: after second update \n");

  EXEC SQL
      COMMIT ;
  printf ("in p1: after committing\n");
  qa_mu_cleanup();
  exit(0);

ERR:
   EXEC SQL WHENEVER SQLERROR CONTINUE;

   printf("Database error, SQLCODE = %d\n", SQLCODE);
   gds__print_status (gds__status);
   EXEC SQL
      ROLLBACK ;
   qa_mu_cleanup();
   exit (1);
}
