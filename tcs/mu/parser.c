/*
 *      PROGRAM:        MU
 *      MODULE:         PARSER.C
 *      DESCRIPTION:    The command-line parser for the multi-user
 *			scheduler.
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
#include "scheduler.h"

/******************************* insert_pcb **********************************/
static insert_pcb()
{
if (head_pcb_ptr == NULL) 
	{	/* First program arg */
	current_pcb_ptr = head_pcb_ptr = (PCB_NODE_PTR) malloc(sizeof(PCB_NODE));
	current_pcb_ptr->next = current_pcb_ptr;
	} 
else 
	{	/* All others */
	current_pcb_ptr->next = (PCB_NODE_PTR) malloc(sizeof(PCB_NODE));
	current_pcb_ptr = current_pcb_ptr->next;
	current_pcb_ptr->next = head_pcb_ptr;
	}
current_jib_ptr->total_clients += 1;	/* increment the number of clients */
}


/*************************** create_client_instances *************************/
static BOOL create_client_instances(create_instances)
int *create_instances;
{
int	x;

for (x = 1; x < *create_instances; x++) 
	{
	current_pcb_ptr->next = (PCB_NODE_PTR) malloc(sizeof(PCB_NODE));
	memcpy(current_pcb_ptr->next, current_pcb_ptr, sizeof(PCB_NODE));
	current_pcb_ptr = current_pcb_ptr->next;
	current_pcb_ptr->next = head_pcb_ptr;
	current_jib_ptr->total_clients += 1;	/* increment the # of clients */
	}
*create_instances = 0;	/* initialize create_instances */
}


/******************************* set_client_args *****************************/
static BOOL set_client_args(argc, argv, initial)
int             argc;
char           *argv[];
int            *initial;
{
int count = 1;	/* What slot to start putting args into */
int i = *initial + 1;

while (i < argc && argv[i][0] != '-')
		++i;	/* Count how many */

/* set the arg count  (args on cmd line +1) */
current_pcb_ptr->pclient_argcnt = (i - *initial) + 1;	

/* (args on the cmd line+3, first for client_name, last two for empty
* slot, and a trailing NULL)
*/
current_pcb_ptr->pclient_args = (char **) calloc(sizeof(char *), 
	current_pcb_ptr->pclient_argcnt + 1);

current_pcb_ptr->pclient_args[0] = current_pcb_ptr->pclient_name;

if (current_pcb_ptr->pclient_argcnt > 2) 
	{
	while ((*initial = *initial + 1) < i) 
		{	/* Store the args */
		if (argv[*initial][0] == '\\')
			current_pcb_ptr->pclient_args[count++] = 
				(char *) &argv[*initial][1];
		else
			current_pcb_ptr->pclient_args[count++] = argv[*initial];
		}

	/* the current argv is left too high from 
		the while loop so decrement one. */
	*initial = *initial - 1;	
	}

current_pcb_ptr->pclient_args[count + 1] = NULL;	/* add trailing NULL */
return TRUE;
}


/*************************** print_description *******************************/
static print_description(argv)
char *argv[];
{

printf("\nUsage: %s -p PROG_1 [ -c client_args ] [ -f frequency ] [ -i instances ]\n", argv[0]);
printf("	    [ -q quantum ] [ -l limit ] { -p PROG_n [ -c client_args ] \n");
printf("	    [ -f frequency ] [ -i instances ] [ -q quantum ] [ -l limit ] } \n");
printf("	    [ -s | -a ] [ -x ] [ -z ] [ -v ]\n\n");
printf("	-p	The name of the client program to be scheduled.\n");
printf("	-c	Arguments to be passed to each client program.\n");
printf("	-f	Frequency of scheduling in relation to the other\n");
printf("		client programs (default = 1).\n");
printf("	-i	# of instances of the client program to be executed (default = 1)\n");
printf("	-q	Timeout interval in seconds; This describes the \n");
printf("		# of seconds the client program will be executing\n");
printf("                in-between scheduler calls before a context switch.\n");
printf("                (default = 10 minutes/600 secs)\n");
printf("	-l	# of times a client program can timeout in-between\n");
printf("                scheduler calls before resolving deadlock (default = 10)\n");
printf("	-s	Run client programs synchronously (default).\n");
printf("	-a	Run client programs asynchronously.\n");
printf("	-x	Print this explanation.\n");
printf("	-z	Print the program and InterBase versions.\n");
printf("	-v	Verbose, display detailed information.\n");
}


/************************** parse_scheduler_args ***************************/
BOOL parse_scheduler_args(argc, argv)
int argc;
char *argv[];
{
int i;
long create_instances = 0;

/* Determine what flags and filename */
for (i = 1; i < argc; i++) 
	{
	/* update the pcb queue and set the client name */
	if (!strcmp(argv[i], "-p")) 
		{
		if (i + 1 < argc && argv[i + 1][0] != '-') 
			{
			(current_pcb_ptr && !current_pcb_ptr->pclient_argcnt) &&
				i-- && set_client_args(argc, argv, &i) && i++;

			(create_instances) && create_client_instances(&create_instances);

			insert_pcb();	/* update the pcb queue */

			/* set up pcb with initial values */
			/* set the client name */
			strcpy(current_pcb_ptr->pclient_name, argv[++i]);

			/* set state to hibernate */
			current_pcb_ptr->pstate = HIB;

			/* set frequency to default */
			current_pcb_ptr->p_sched_freq =
			current_pcb_ptr->p_current_sched_freq = MIN_SCHED_FREQ;

			/* set quantum to default */
			current_pcb_ptr->p_quantum = DEFAULT_QUANTUM;

			/* set limit to default */
			current_pcb_ptr->p_prempted_count = 0;
			current_pcb_ptr->p_prempted_limit = DEFAULT_LIMIT_PREEMPT;
			current_pcb_ptr->pclient_argcnt = 0;
			current_pcb_ptr->pclient_args = 0;
			} 
		else 
			{
			printf("\n%s: no argument for -p given\n", argv[0]);
			print_description(argv);
			return FALSE;
			}
		}
	/* set client arguments */
	else if (!strcmp(argv[i], "-c")) 
		{
		if (i + 1 < argc && argv[i + 1][0] != '-') 
			{
			if (current_pcb_ptr && !current_pcb_ptr->pclient_args &&
				set_client_args(argc, argv, &i));
			else 
				{
				printf("\n%s: only one [ -c args] for every -p PROG_n\n",
					       argv[0]);
				print_description(argv);
				return FALSE;
				}
			} 
		else
			printf("\n%s: no argument(s) for -c given, flag ignored\n",
				       argv[0]);
		} 

	/* create many instances of the client program */
	else if (!strcmp(argv[i], "-i")) 
		{
		if (head_pcb_ptr == NULL) 
			{
			printf("\n%s: -p PROG_1 must be given first\n", argv[0]);
			print_description(argv);
			return FALSE;
			} 
		else if (i + 1 < argc && argv[i + 1][0] != '-') 
			{
			char *endptr[20];
			if (create_instances = strtol(argv[++i], endptr, 10)) 
				{
				if (**endptr != NULL)
					printf("%s: argument for -i: trailing '%s' ignored\n", 
						argv[0], *endptr);
				} 
			else 
				{
				create_instances = 0;
				printf("\n%s: argument for -i must be a number, flag ignored\n", 
					argv[0]);
				}
			} 
		else
			printf("\n%s: no argument for -i given, flag ignored\n", argv[0]);
		}
	/* set client program frequency */
	else if (!strcmp(argv[i], "-f")) 
		{
		if (head_pcb_ptr == NULL) 
			{
			printf("\n%s: -p PROG_1 must be given first\n", argv[0]);
			print_description(argv);
			return FALSE;
			} 
	else if (i + 1 < argc && argv[i + 1][0] != '-') 
		{
		char *endptr[20];
		if (current_pcb_ptr->p_sched_freq = strtol(argv[++i], endptr, 10)) 
			{
			if (**endptr != NULL)
				printf("%s: argument for -f: trailing '%s' ignored\n", 
					argv[0], *endptr);
			} 
		else 
			{
			current_pcb_ptr->p_sched_freq = MIN_SCHED_FREQ;
			printf("\n%s: argument for -f must be a number, flag ignored\n", 
					argv[0]);
			}
		current_pcb_ptr->p_current_sched_freq = 
			current_pcb_ptr->p_sched_freq;
		} 
	else
		printf("\n%s: no argument(s) for -f given, flag ignored\n", argv[0]);
	}
	/* set client program quantum */
	else if (!strcmp(argv[i], "-q")) 
		{
		if (head_pcb_ptr == NULL) 
			{
			printf("\n%s: -p PROG_1 must be given first\n", argv[0]);
			print_description(argv);
			return FALSE;
			} 
	else if (i + 1 < argc && argv[i + 1][0] != '-') 
		{
		char *endptr[20];
			if (current_pcb_ptr->p_quantum = 
				strtol(argv[++i], endptr, 10)) 
				{
				if (**endptr != NULL)
					printf("%s: argument for -q: trailing '%s' ignored\n", 
							argv[0], *endptr);
				} 
			else 
				{
				current_pcb_ptr->p_quantum = DEFAULT_QUANTUM;
				printf("\n%s: argument for -q must be a number, flag ignored\n", argv[0]);
				}
			} 
		else
			printf("\n%s: no argument(s) for -q given, flag ignored\n", 
					argv[0]);
		}
	/* set client program alarm expire limit */
	else if (!strcmp(argv[i], "-l")) 
		{
		if (head_pcb_ptr == NULL) 
			{
			printf("\n%s: -p PROG_1 must be given first\n", argv[0]);
			print_description(argv);
			return FALSE;
			} 
		else if (i + 1 < argc && argv[i + 1][0] != '-') 
			{
			char *endptr[20];
			if (current_pcb_ptr->p_prempted_limit = 
				strtol(argv[++i], endptr, 10)) 
				{
				if (**endptr != NULL)
					printf("%s: argument for -l: trailing '%s' ignored\n ", 
						argv[0], *endptr);
				} 
			else 
				{
				current_pcb_ptr->p_prempted_limit = DEFAULT_LIMIT_PREEMPT;
				printf("\n%s: argument for -l must be a number, flag ignored\n", argv[0]);
				}
			} 
		else
			printf("\n%s: no argument(s) for -l given, flag ignored\n", 
					argv[0]);
		}
	/* leave mode as synchronous */ 
	else if (!strcmp(argv[i], "-s")) 
		{
		current_pcb_ptr && !(current_pcb_ptr->pclient_argcnt) &&
			i-- && set_client_args(argc, argv, &i) && i++;

		(create_instances) &&
			create_client_instances(&create_instances);
		}
	/* set mode to asynchronous */ 
	else if (!strcmp(argv[i], "-a")) 
		{
		current_pcb_ptr && !(current_pcb_ptr->pclient_argcnt) &&
			i-- && set_client_args(argc, argv, &i) && i++;

		(create_instances) &&
		create_client_instances(&create_instances);
		current_jib_ptr->mode = ASYNC;
		}
	/* print explanation */
	else if (!strcmp(argv[i], "-x")) 
		{
		current_pcb_ptr && !(current_pcb_ptr->pclient_argcnt) &&
			i-- && set_client_args(argc, argv, &i) && i++;

		(create_instances) &&
			create_client_instances(&create_instances);
		print_description(argv);
		}
	/* print version */
	else if (!strcmp(argv[i], "-z")) 
		{
		current_pcb_ptr && !(current_pcb_ptr->pclient_argcnt) &&
			i-- && set_client_args(argc, argv, &i) && i++;

		(create_instances) &&
			create_client_instances(&create_instances);
		print_version();
		}
	/* set verbose */
	else if (!strcmp(argv[i], "-v")) 
		{
		current_pcb_ptr && !(current_pcb_ptr->pclient_argcnt) &&
			i-- && set_client_args(argc, argv, &i) && i++;

		(create_instances) &&
			create_client_instances(&create_instances);
		current_jib_ptr->verbose = TRUE;
		} 
	else 
		{
		printf("\n%s: '%s' invalid flag\n", argv[0], argv[i]);
		print_description(argv);
		return FALSE;
		}
	}

current_pcb_ptr && !(current_pcb_ptr->pclient_argcnt) &&
	i-- && set_client_args(argc, argv, &i) && i++;

(create_instances) &&
	create_client_instances(&create_instances);

if (current_pcb_ptr)
	return TRUE;
else
	return FALSE;
}


/************ history *******************************************************
 *									    *
 *    	Created by:	Scott Van Voris, June 30, 1993.		            *
 *									    *
 *	Modified by:    Subhransu Basu, Oct 4, 1993			    *
 *		--> 	Modified init_scheduler() to create temp file that  *
 *			determines whether the clients are in the 	    *
 *			domain of the scheduler.			    *
 *									    *
 *	Modified by:    Subhransu Basu, Sep 14, 1993			    *
 *		--> 	Modified init_scheduler() to set fp_logfile to      *
 *			stderr			                            *
 *									    *
 *	Modified by:    Subhransu Basu, Feb 3, 1994			    *
 *		--> 	Modified init_scheduler() to set module_name to be  *
 *			of size 20 rather than 15 due to bad things on NT   *
 *									    *
 *      <Please add maint info on changes to header>			    *
 ****************************************************************************
 *									    *
 *	PROGRAM:	C						    *
 *	MODULE:		init_scheduler.c				    *
 *	DESCRIPTION:	This sets up the scheduler, ie. the JIB		    *
 *									    *
 ****************************************************************************/

/*************************** init_scheduler ********************************/
BOOL 
init_scheduler()
{
	char            module_name[20];
	char            fname[256];
	char            qnum[256];
	FILE           *fp1;
	char           *s_ptr;

	strcpy(module_name, "init_scheduler()");

	/* allocate space */
	if ((current_jib_ptr = (JIB_NODE_PTR) malloc(sizeof(JIB_NODE))) == NULL) {
		print_sys_error(module_name, "malloc error of JIB block");
		return (FALSE);
	}
	/* initialize fields */
	current_jib_ptr->mode = SYNC;
	current_jib_ptr->verbose = FALSE;
	current_jib_ptr->active_clients = ZERO;
	current_jib_ptr->inactive_clients = ZERO;
	current_jib_ptr->total_clients = ZERO;
	current_jib_ptr->garbage_clients = ZERO;
	current_jib_ptr->base_quantum = ZERO;

	/*
	 * Read the config file or the env. variable for a base quantum If
	 * none are found use the default quantum
	 */
	if ((fp1 = fopen(MU_CONFIG_FILE, "r+")) != NULL) {
		fgets(qnum, 256, fp1);
		for (s_ptr = qnum; *s_ptr != '='; s_ptr++);
		current_jib_ptr->base_quantum = atoi(++s_ptr);
	} else {
		if ((s_ptr = getenv(MU_BASEQUANTUM)) != NULL)
			current_jib_ptr->base_quantum = atoi(s_ptr);
		else
			current_jib_ptr->base_quantum = DEFAULT_BASE_QUANTUM;
	}

	/* Set the Error log File to stderr */
	fp_logfile = stderr;

	/*
	 * Create a temp file whenever the scheduler is running to so clients
	 * can check for its existence and accordingly act or no-op the
	 * client calls
	 */

	sprintf(fname, "%s%s%ld%s", TEMP_DIR, "/mu_", getpid(), ".tmp");
	if (!fopen(fname, "w+")) {
		char            error_message[256];
		sprintf(error_message, "Failed to create temp file, Error No : %d", errno);
		print_sys_error(module_name, error_message);
		return FALSE;
	}
	return TRUE;
}

/************ history *******************************************************
 *									    *
 *    	Created by:	Scott Van Voris, June 29, 1993.		            *
 *									    *
 *      <Please add maint info on changes to header>			    *
 ****************************************************************************
 *									    *
 *	PROGRAM:	C						    *
 *	MODULE:		get_version.c	 				    *
 *	DESCRIPTION:	Retrieves the current InterBase version by way of   *
 *			a "gpre -z" call, filters it through the shell      *
 *			script "get_version.sh", and prints it out as well  *
 *			as the global variable PROGRAM_VER.		    *
 *									    *
 ****************************************************************************/

char            PROGRAM_VER[] = "QA InterBase multi-tasking scheduler, ver 1.1a";

/***************************** get_version **********************************/
static 
print_version()
{
	printf("%s\n", PROGRAM_VER);

	system("gpre -z > /tmp/out 2>&1");
	system("cat /tmp/out | grep version|sed 's/gpre/InterBase/g'");
	system("rm /tmp/out");
}
