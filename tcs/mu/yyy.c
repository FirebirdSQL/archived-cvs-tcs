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
main(argc,argv,envp)
int argc;
char ** argv;
char **envp;
{
char inp[2];

 /* printf (" first executable \n"); fflush (stdout); */

if (!qa_mu_init (argc,argv)){
	printf ("Error in initialising the scheduler\n"); 
	qa_mu_cleanup ();
	exit (1);
	}
printf("Env Variable %s\n",envp[0]);
printf ("Pausing in %s (1)\n", argv[0]); 
qa_mu_pause();
printf ("Pausing in %s (2)\n", argv[0]); 
qa_mu_pause();
printf ("Pausing in %s (3)\n", argv[0]); 
qa_mu_pause();
printf ("Exitting in %s \n", argv[0]); 

qa_mu_cleanup();
}
