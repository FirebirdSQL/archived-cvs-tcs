/*
 *      PROGRAM:        Multi-User Test Tool
 *      MODULE:         SCHEDULER.C
 *      DESCRIPTION:    Main Module for Multi-User Test tool.
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
#ifdef POSIX_SIGNALS
#define LOOP_NUMBER 1000000000
long loop_count;
sigset_t chldset, mset;
int ext_count = 0;
#endif

void schedule_async_client();
void schedule_sync_client();
void install_signal_handler();
void install_signal_handler_by_handler();
void signal_handler_sigabrt_hwfaults();
void signal_handler_sigurg_execed_child();
void dump_pcb_node();
void clean_pcb_node();

BOOL configure_scheduler_type()
{
/***********************************************************
 *
 *        c o n f i g u r e _ s c h e d u l e r _ t y p e 
 *
 ***********************************************************
 *
 *  Functional Description
 *	This module configures the scheduler based on the type
 *	of clients in the scheduler (i.e. ASYNC v/s SYNC) 
 *	It essentially installs the appropriate signal handlers
 *	and creates some temp fd's based on the type.
 *
 ****************************************************************/

char fname[256];

/* Create a temp file to control behaviour of clients running in
	SYNC/ASYNC mode. Although the documentation recommends that
	clients started ASYNC'ly should not use a qa_mu_pause() call
	but users may accidentaly use it, in that case the scheduler
	was designed to hang.  But this temp file basically writes
	the mode out as a result the client libraries basically
	checks for the type and if ASYNC it no-ops the qa_mu_pause() call
*/

if (current_jib_ptr->mode == SYNC)
	sprintf(fname,"%s%s%ld%s",TEMP_DIR,"/mu_",(long)getpid(),".sync");
else
	sprintf(fname,"%s%s%ld%s",TEMP_DIR,"/mu_",(long)getpid(),".async");

if (! fopen(fname,"w+"))
	{
	char error_message[256];

	sprintf(error_message,"Failed to create temp file, Error No : %d ",errno);
	print_sys_error("parse_scheduler_args()",error_message);
	return ( FALSE );
	}

return(TRUE);
}



BOOL dispatch_clients()
{
/**********************************************************
 *
 *        d i s p a t c h _ c l i e n t s 
 *
 **********************************************************
 *
 *  Functional Description
 *       Traverses the circularly linked list of PCB's opening
 *       pipes for IPC between the scheduler and the various 
 *       clients then forking/execing  clients in the PCB's.
 *
 ***********************************************************/

char module_name[40];
char fdstr[10];
char * strnset();
int count = ZERO;

strcpy(module_name,"dispatch_clients()");

current_jib_ptr->active_clients = ZERO;
current_jib_ptr->inactive_clients = 
	current_jib_ptr->total_clients - current_jib_ptr->active_clients;

/* Install the SIGURG handler that flags an invalid execed child 
	in the scheduler 
*/
install_signal_handler_by_handler(SIGNAL_SIGURG,SIGURG,signal_handler_sigurg_execed_child);

#ifdef sun
install_signal_handler_sigxcpu();
#endif

current_pcb_ptr = head_pcb_ptr;
do
	{
	child_execed_flag = FALSE;
	exec_error = FALSE;

	if ((BOOL)pipe(current_pcb_ptr->ppipe_fd) == ERROR)
		{
		print_sys_error(module_name,"Open Pipe System Call");
		return(FALSE);
		}
	strnset(fdstr,0,strlen(fdstr));		
	sprintf(fdstr,"%d",current_pcb_ptr->ppipe_fd[1]);

	/* Copy the write end of the pipe as the last client argument */
	current_pcb_ptr->pclient_args[current_pcb_ptr->pclient_argcnt - 1] = fdstr;
	current_pcb_ptr->pstart_cpu = current_pcb_ptr->pconsumed_cpu = 
		current_pcb_ptr->ptotal_cpu = (cpu_t)ZERO;

	/* Fork the clients here */

	current_pcb_ptr->pid = fork();
	switch(current_pcb_ptr->pid)
		{
		case -1 : 
			print_sys_error(module_name,"Fork System Call");
			break;
		case 0 :
			if ((BOOL)close(current_pcb_ptr->ppipe_fd[0]) == ERROR)
				print_sys_error("Execed child","Failure Closing Reading End of Pipe");

			execvp(current_pcb_ptr->pclient_name,current_pcb_ptr->pclient_args);
			kill (getppid(),SIGURG);
			_exit(1);
			break;
		}			

		/* Close the Writing end of the Pipe in the Parent */
		if ((BOOL)close(current_pcb_ptr->ppipe_fd[1]) == ERROR)
			print_sys_error(module_name,"Failure Closing Writing End of Pipe");
		
#ifdef POSIX_SIGNALS
/*		sigemptyset(&mask);
		sigsuspend(&mask);
*/
		loop_count = LOOP_NUMBER;
		while(!child_execed_flag)
			if (--loop_count <= 0)
				{
				abort_current_process = TRUE;
				break;
				}

#else
		sigsuspend(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif

		if (exec_error)
			{
			/* If there was an exec error then compensate by 
				decrementing active clients and incrementing inactive's
			*/
			current_jib_ptr->garbage_clients += 1;
			current_jib_ptr->total_clients -=1;
			}	

		if (current_jib_ptr->verbose)
			{
			count ++;
			fprintf(fp_logfile,
				"Forked Client # %d\t Name : %s \t Process ID : %ld\n",count,current_pcb_ptr->pclient_name,current_pcb_ptr->pid);
			fprintf(fp_logfile,
				"** Total Clients = %d\tActive Clients = %d\tInactive Clients = %d\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);
			}

		current_pcb_ptr = current_pcb_ptr->next;

	} while (current_pcb_ptr != head_pcb_ptr);

current_jib_ptr->inactive_clients = current_jib_ptr->total_clients -
					    current_jib_ptr->active_clients;	
	return TRUE;
}



BOOL schedule_clients()
{
/**********************************************************
 *
 *        s c h e d u l e  _ c l i e n t s 
 *
 **********************************************************
 *
 *  Functional Description
 *	 Loops until the scheduler has no more process to be 
 *       scheduled. It schedules the individual clients based
 *       on their mode SYNC/ASYNC.
 *
 ***********************************************************/

blocked_flag = FALSE;
fp_logfile = stderr;

#ifdef POSIX_SIGNALS	
		sigemptyset (&chldset);
		sigaddset (&chldset, SIGCHLD);
		sigemptyset (&mset);
		sigaddset (&mset, SIGUSR1);
		sigaddset (&mset, SIGUSR2);
		sigaddset (&mset, SIGALRM);
		sigprocmask (SIG_BLOCK, &mset, NULL);
#endif	

/* 
	Install the handler to trap hardware faults generated in the 
	child processes
*/
install_signal_handler_by_handler(SIGNAL_SIGURG,SIGURG,signal_handler_sigurg_freeze);

	
if (current_jib_ptr->verbose)
	{
	fprintf(fp_logfile,"\n*** Scheduling Clients ***\n");
	}

if (current_jib_ptr->verbose)
	{
	fprintf(fp_logfile,
		"\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);
	}

current_pcb_ptr = head_pcb_ptr;

while (current_jib_ptr->active_clients > LOWER_SCHED_LIMIT)
	{
#ifdef POSIX_SIGNALS
/* MMM - This check is added because sometimes on solaris we
   are getting situation when there are no process to schedule
   but the current_jib_ptr->active_clients is more than 
   LOWER_SCHED_LIMIT (0), which means we are in loop forever
*/
	if (current_pcb_ptr == head_pcb_ptr)
		{
		if (ext_count >= current_jib_ptr->total_clients +
				 current_jib_ptr->garbage_clients)
			{
			print_sys_error("schedule_clients()", "Inconsistent data structures: no clients to schedule");
			break;
			}
		else
			ext_count = 0;
		}
#endif
	switch(current_jib_ptr->mode)	
		{ 
		case ASYNC:
			schedule_async_client();
			break;
		case SYNC:
			schedule_sync_client();
			break;
		default :
			return(FALSE);
			break;
		}
#ifdef DEBUG_INFO
printf("\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);
fflush (stdout);
#endif
	}
#ifdef POSIX_SIGNALS	
	sigprocmask (SIG_UNBLOCK, &mset, NULL);
#endif	


if (current_jib_ptr->verbose)
	{
	fprintf(fp_logfile,
		"\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);
	}
	return (TRUE);
}


void schedule_async_client()
{
/***********************************************************
 * 
 *          s c h e d u l e _ a s y n c _ c l i e n t 
 *
 ***********************************************************
 *
 * Functional Description
 *    	This procedure waits until a client finishes and then		
 *	immediately sends a sleep signal to all the clients so that 
 *	it can take its time to update the jib and the pcb block 
 *	associated with the dead client.  After this is done all of
 *	clients are revived and the waiting continues until the next	
 *	client dies.							
 *
 ****************************************************************/ 

pid_t pid;
pid_t the_group = getpid();		/* Get the group id(the parents pid) */
PCB_NODE_PTR save_pcb_ptr = current_pcb_ptr;

#ifdef POSIX_SIGNALS	
	sigprocmask (SIG_UNBLOCK, &mset, NULL);
#endif	


/*killpg(the_group,SIGCONT);*/		/* Wake the clients back up */

kill(-the_group,SIGCONT);		/* Wake the clients back up */

pid=wait(0L);

/*killpg(the_group,SIGTSTP);*/		/* Put all clients to sleep */

kill(-the_group,SIGTSTP);		/* Put all clients to sleep */
 
while(current_pcb_ptr->pid!=pid)		/* Set current_pcb_ptr correctly. */
	current_pcb_ptr=current_pcb_ptr->next;
 
current_jib_ptr->active_clients -= 1;		/* Update the jib. */
current_jib_ptr->inactive_clients = 
	current_jib_ptr->total_clients - current_jib_ptr->active_clients;
current_pcb_ptr->pstate = EXT;		/* Set state to extinct */
current_pcb_ptr=save_pcb_ptr->next;

#ifdef POSIX_SIGNALS	
	sigprocmask (SIG_BLOCK, &mset, NULL);
#endif	

}


void schedule_sync_client()
{
/***************************************************
 *
 *      s c h e d u l e _ s y n c _ c l i e n t
 *
 ***************************************************
 *
 *	Functional Description
 *		Synchronously schedule the individual clients.
 *		A process is considered for scheduling iff its
 *		state not equal to EXT. 	
 *
 ****************************************************/
   
if (current_pcb_ptr->pstate != EXT)
	{
	if (current_jib_ptr->verbose)
		fprintf(fp_logfile, "\n\n** Scheduling Client = %s  PID = %ld  **\n",
			current_pcb_ptr->pclient_name,current_pcb_ptr->pid);

	if (current_pcb_ptr->p_current_sched_freq > MIN_SCHED_FREQ)
		{
		blocked_flag = TRUE;

		abort_current_process = FALSE;

		current_pcb_ptr->p_current_sched_freq -=1;
		current_pcb_ptr->pstate = COM;

		/* Sets alarm to detect deadlock */
		alarm(current_pcb_ptr->p_quantum + current_jib_ptr->base_quantum); 

		/* Sends process SIGCONT */
		if (kill(current_pcb_ptr->pid,SIGCONT) == ERROR)	
			{
			abort_current_process = TRUE;

			if (errno == ESRCH)
				{
				char error_buffer[256];	

				sprintf (error_buffer, 
				"MU failed to find child process %ld\n", current_pcb_ptr->pid);
				print_sys_error("schedule_sync_clients()",error_buffer);
				}
			else
				{
				char error_buffer[256];	

				sprintf (error_buffer, 
				"MU found some configuration problems with the child process %ld\n", current_pcb_ptr->pid);
				print_sys_error("schedule_sync_clients()",error_buffer);
				}
			}

		/* Blocks waiting for SIGUSR1 or SIGUSR2 to be delivered */
#ifdef POSIX_SIGNALS
		sigprocmask (SIG_UNBLOCK, &mset, NULL);
		loop_count = LOOP_NUMBER;
		while(blocked_flag && (!abort_current_process))
			if (--loop_count <= 0)
				{
				abort_current_process = TRUE;
				break;
				}
		sigprocmask (SIG_BLOCK, &mset, NULL);

#else
		sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif
			
		/* Cancels the Alarm in case the alarm did not go off */
		alarm(0);

		/* If the execution of the process was aborted then set state to EXT
		and continue
		*/
		if (abort_current_process)
			update_aborted_pcb_jib ();

		if (current_pcb_ptr->pstate == DLK)
			{	
			current_pcb_ptr->p_current_sched_freq = 
				current_pcb_ptr->p_sched_freq;
			current_pcb_ptr = current_pcb_ptr->next;
			}
		}	
	else
		{
		if(current_pcb_ptr->p_current_sched_freq == MIN_SCHED_FREQ)
			{
			current_pcb_ptr->pstate = COM;

			blocked_flag = TRUE;

			abort_current_process = FALSE;
	
			/* Sets alarm to detect deadlock BASEPRIORITY + USERPRIORITY*/

			alarm(current_pcb_ptr->p_quantum + current_jib_ptr->base_quantum); 

#ifdef DEBUG_INFO
printf("Parent sending child process %ld SIGCONT to stuff pipe with data\tBlocking for response/control ....\n",current_pcb_ptr->pid);fflush(stdout);
#endif

			/* Sends process SIGCONT */
			if (kill(current_pcb_ptr->pid,SIGCONT) == ERROR)
				{
				abort_current_process = TRUE;

				if (errno == ESRCH)
					{
					char error_buffer[256];	

					sprintf (error_buffer, 
				"MU failed to find child process %ld\n", current_pcb_ptr->pid);
					print_sys_error("schedule_sync_clients()",error_buffer);
				}
			else
				{
				char error_buffer[256];	

				sprintf (error_buffer, 
				"MU found some configuration problems with the child process %ld\n", current_pcb_ptr->pid);
				print_sys_error("schedule_sync_clients()",error_buffer);
				}
			}	


			/* Blocks waiting for SIGUSR1 or SIGALRM to be delivered */
#ifdef POSIX_SIGNALS
			sigprocmask (SIG_UNBLOCK, &mset, NULL);
			loop_count = LOOP_NUMBER;
			while(blocked_flag && (!abort_current_process))
				if (--loop_count <= 0)
					{
					abort_current_process = TRUE;
					break;
					}
			sigprocmask (SIG_BLOCK, &mset, NULL);

#else
			sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif

			/* Cancels the Alarm in case the alarm did not go off */
			alarm(0);

			current_pcb_ptr->p_current_sched_freq = 
				current_pcb_ptr->p_sched_freq;

			/* Call update_aborted_pcb_jib() to register the untimely 
				   death of a child process and set state to EXT amongst 
				   other things
			*/

			if (abort_current_process)
				update_aborted_pcb_jib();
 
#ifdef DEBUG_INFO
printf("Context switching from process %ld (state = %d) --> process %ld (state = %d) \n", current_pcb_ptr->pid, current_pcb_ptr->pstate, current_pcb_ptr->next->pid, current_pcb_ptr->next->pstate);
#endif

			/* Move the current PCB pointer to the next process 
				to be scheduled 
			*/
				current_pcb_ptr = current_pcb_ptr->next;
				}
			else  /* Redundant Code - Should Never Get Here */
				{
				/* This code will only be executed if the */
				/* scheduler frequency is -ve. This stops */
				/* the current process.			  */

				current_jib_ptr->active_clients -= 1;
        		current_jib_ptr->inactive_clients = 
					current_jib_ptr->total_clients - current_jib_ptr->active_clients;
				current_pcb_ptr->pstate = EXT;
				kill(current_pcb_ptr->pid,SIGTSTP);
				}
			}
		}
	else
		{

#ifdef DEBUG_INFO
printf("Context switching from process %ld (state = %d) --> process %ld (state = %d) \n", current_pcb_ptr->pid, current_pcb_ptr->pstate, current_pcb_ptr->next->pid, current_pcb_ptr->next->pstate);
#endif

		current_pcb_ptr	= current_pcb_ptr->next;
#ifdef POSIX_SIGNALS
		ext_count++;
#endif
		}

	if (current_jib_ptr->verbose)
	{
		/*
		fprintf(fp_logfile,"\n** Program = %s\t Process ID = %ld **\n",current_pcb_ptr->pclient_name,current_pcb_ptr->pid);
		fprintf(fp_logfile,"\n** Last Consumed CPU = %ld\t Total Consumed CPU = %ld **\n",current_pcb_ptr->pconsumed_cpu,current_pcb_ptr->ptotal_cpu);
		*/
		fprintf(fp_logfile,
			"\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);
	}
}	

/*****************************************************************************
 *
 *
 *     S  I  G  N  A  L    H  A  N  D  L  E  R   -   R  O  U  T  I  N  E  S
 *
 *
 *****************************************************************************/

void signal_handler_sigusr1()
{
char pipe_message[PIPE_BUFFER];	
cpu_t pipe_cpu_value = (cpu_t)0;
char module_name[40];

/* If we are here that means a client is in qa_mu_pause() function
   yeilding control, so we don't need to preempt it. Reset alarm.
*/
alarm(0);
#ifndef POSIX_SIGNALS
	/* Re-installs SIGUSR1 handler */
	re_install_signal_handler(SIGNAL_SIGUSR1); 
#endif

strcpy(module_name,"signal_handler_sigusr1()");
blocked_flag = FALSE;

if (read(current_pcb_ptr->ppipe_fd[0],pipe_message,sizeof(pipe_message)) == ERROR)
	print_sys_error(module_name,"Read Pipe System Call");	
	
if (!strcmp(pipe_message, "-2000"))
	{

#ifdef DEBUG_INFO
printf("Parent received SIGUSR1 as Registration notification from %ld\n",current_pcb_ptr->pid);fflush(stdout);
#endif

	current_jib_ptr->active_clients += 1;
	current_jib_ptr->inactive_clients = 
		current_jib_ptr->total_clients - current_jib_ptr->active_clients;
	child_execed_flag = TRUE;
	}
else
	{
	if (!strcmp(pipe_message, "-1000"))
		{

#ifdef DEBUG_INFO
printf("Parent received SIGUSR1 as Hangup notification from %ld\n",current_pcb_ptr->pid);fflush(stdout);
#endif
#ifdef POSIX_SIGNALS
/* Don't want to be interrupted by SIGCHLD while updating data structures */
		sigprocmask (SIG_BLOCK, &chldset, NULL);
#endif	
		current_jib_ptr->active_clients -= 1;
        current_jib_ptr->inactive_clients = 
			current_jib_ptr->total_clients - current_jib_ptr->active_clients;
		current_pcb_ptr->pstate = EXT;
		current_pcb_ptr->p_prempted_count = ZERO;
#ifdef POSIX_SIGNALS
		sigprocmask (SIG_UNBLOCK, &chldset, NULL);
#endif	

		/* Don't care about checking 'cause process may be dead */
/*
		kill(current_pcb_ptr->pid,SIGTSTP);
*/
		kill(current_pcb_ptr->pid,SIGCONT);
		}
	else
		{

#ifdef DEBUG_INFO
printf("Parent received SIGUSR1 as data notification from %ld\tUnblocking and returning control ...\n",current_pcb_ptr->pid);fflush(stdout);
#endif
		pipe_cpu_value = atoi(pipe_message);
		current_pcb_ptr->pconsumed_cpu = 
			pipe_cpu_value - current_pcb_ptr->plast_read_cpu;
		current_pcb_ptr->plast_read_cpu = pipe_cpu_value;
		current_pcb_ptr->ptotal_cpu += current_pcb_ptr->pconsumed_cpu;

		current_pcb_ptr->p_prempted_count = ZERO;
		current_pcb_ptr->pstate = HIB;
/*
		if (kill(current_pcb_ptr->pid,SIGTSTP) == ERROR)
			{
			abort_current_process = TRUE;

			if (errno == ESRCH)
				{
				char error_buffer[256];	

				sprintf (error_buffer, 
				"MU failed to find child process %ld\n", current_pcb_ptr->pid);
				print_sys_error("signal_handler_sigusr1()",error_buffer);
				}
			else
				{
				char error_buffer[256];	

				sprintf (error_buffer, 
				"MU found some configuration problems with the child process %ld\n", current_pcb_ptr->pid);
				print_sys_error("signal_handler_sigusr1()",error_buffer);
				}
			}
*/
		}
	}
}


void signal_handler_sigusr2()
{
char pipe_message[PIPE_BUFFER];	
cpu_t pipe_cpu_value = (cpu_t)0;
char module_name[40];

#ifndef POSIX_SIGNALS

/* Re-installs SIGUSR2 handler */
re_install_signal_handler(SIGNAL_SIGUSR2); 

#endif

strcpy(module_name,"signal_handler_sigusr2()");
blocked_flag = FALSE;
	
#ifdef DEBUG_INFO
printf("Parent received SIGUSR2 from %ld indicating data to be read on pipe\n",current_pcb_ptr->pid);fflush(stdout);
#endif

if (read(current_pcb_ptr->ppipe_fd[0],pipe_message,sizeof(pipe_message)) == 
		ERROR)
	print_sys_error(module_name,"Read Pipe System Call");	

pipe_cpu_value = atoi(pipe_message);
current_pcb_ptr->pconsumed_cpu = 
	pipe_cpu_value - current_pcb_ptr->plast_read_cpu;
current_pcb_ptr->plast_read_cpu = pipe_cpu_value;
current_pcb_ptr->ptotal_cpu += current_pcb_ptr->pconsumed_cpu;

#ifdef DEBUG_INFO
printf("Parent read from pipe value %s\tUnblocking ...\n", pipe_message);fflush(stdout);
#endif
}



void signal_handler_sigalrm()
{
#ifndef POSIX_SIGNALS
	
/* Re-installs SIGALRM handler */
re_install_signal_handler(SIGNAL_SIGALRM); 

#endif

/*blocked_flag = TRUE;
*/
blocked_flag = FALSE;

#ifdef DEBUG_INFO
printf("Parent received SIGALRM from %ld \t preparing to pre-empt current process\n",current_pcb_ptr->pid);fflush(stdout);
#endif

alarm(0); /* Cancel previous alarm calls */

current_pcb_ptr->p_prempted_count ++;
/*
#ifdef DEBUG_INFO
printf("Parent sending child process %ld SIGUSR2 to stuff pipe\tBlocking for response ....\n",current_pcb_ptr->pid);fflush(stdout);
#endif

if (kill(current_pcb_ptr->pid,SIGUSR2) == ERROR)
	{
	abort_current_process = TRUE;

	if (errno == ESRCH)
		{
		char error_buffer[256];	

		sprintf(error_buffer, "MU failed to find child process %ld\n", 
			current_pcb_ptr->pid);
       	print_sys_error("signal_handler_sigalrm()",error_buffer);
		}
	else
		{
		char error_buffer[256];	

		sprintf(error_buffer, "MU found some configuration problems with the child process %ld\n", current_pcb_ptr->pid);
		print_sys_error("signal_handler_sigalrm()",error_buffer);
		}
	}	

#ifdef POSIX_SIGNALS

loop_count = LOOP_NUMBER;
while(blocked_flag && (!abort_current_process))
	if (--loop_count <= 0)
		{
		abort_current_process = TRUE;
		break;
		}

#else

sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);

#endif
*/
if (current_pcb_ptr->p_prempted_count > current_pcb_ptr->p_prempted_limit)
	{
#ifdef POSIX_SIGNALS
/* Don't want to be interrupted by SIGCHLD while updating data structures */
	sigprocmask (SIG_BLOCK, &chldset, NULL);
#endif	
	current_jib_ptr->active_clients -= 1;
	current_jib_ptr->inactive_clients = 
		current_jib_ptr->total_clients - current_jib_ptr->active_clients;
	current_pcb_ptr->pstate = EXT;
#ifdef POSIX_SIGNALS
	sigprocmask (SIG_UNBLOCK, &chldset, NULL);
#endif	
		
	fprintf(fp_logfile,"\n\n****  BEGIN ERROR RECORD  ****\n");
	fprintf(fp_logfile,"Client Name = %s is deadlocked\t",
		current_pcb_ptr->pclient_name);
	fprintf(fp_logfile,"Process ID = %ld \n",current_pcb_ptr->pid);
	fprintf(fp_logfile,"Could not resolve deadlock after %ld seconds\n",
		current_pcb_ptr->p_prempted_limit*current_pcb_ptr->p_quantum);
	fprintf(fp_logfile,"\tKilled process %ld\n",current_pcb_ptr->pid);
	fprintf(fp_logfile,"\n\n****  END ERROR RECORD  ****\n");
		
	kill(current_pcb_ptr->pid,SIGKILL);
	}
else
	{
	if(current_jib_ptr->verbose)
		{
		fprintf(fp_logfile,
		"\n--->>> Prempted Client < %s > , PID = %ld \t(Count = %d / %d)\n\n",
		current_pcb_ptr->pclient_name,current_pcb_ptr->pid,
		current_pcb_ptr->p_prempted_count,current_pcb_ptr->p_prempted_limit); 
		}
	current_pcb_ptr->pstate = DLK;
	if (kill(current_pcb_ptr->pid,SIGTSTP) == ERROR)
		{
		abort_current_process = TRUE;

		if (errno == ESRCH)
			{
			char error_buffer[256];	

			sprintf (error_buffer, "MU failed to find child process %ld\n", current_pcb_ptr->pid);
       				print_sys_error("signal_handler_sigalrm()",error_buffer);
			}
		else
			{
			char error_buffer[256];	

			sprintf (error_buffer, 
				"MU found some configuration problems with the child process %ld\n", current_pcb_ptr->pid);
			print_sys_error("signal_handler_sigalrm()",error_buffer);
			}
		}

	}
	
}	

void signal_handler_sigurg_freeze()
{
/***************** signal_handler_sigurg_freeze *************************
 *
 * Functional Description
 *              SIGURG handler stops all process walks the PCB queue
 *              and dumps the info to the fp_logfile
 *
 ************************************************************************/
PCB_NODE_PTR temp1_ptr;
pid_t the_group = getpid();

#ifndef POSIX_SIGNALS

/* Re-installs SIGURG handler */
re_install_signal_handler(SIGNAL_SIGURG);

#endif

temp1_ptr = head_pcb_ptr;

if (current_jib_ptr->mode == SYNC)
	{
	fprintf(fp_logfile,
		"\n\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n", current_jib_ptr->total_clients, current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);

	kill(current_pcb_ptr->pid,SIGTSTP);

	do
		{
		if (temp1_ptr == current_pcb_ptr)
			dump_pcb_node(temp1_ptr,"CURRENT") ;
		else
			dump_pcb_node(temp1_ptr,"OTHER");

		temp1_ptr = temp1_ptr->next;
        } while (temp1_ptr != head_pcb_ptr);

	kill(current_pcb_ptr->pid,SIGCONT);
	}
	else
	{
	fprintf(fp_logfile,
		"\n\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);

	kill(-the_group,SIGTSTP);

	do
		{
		dump_pcb_node(temp1_ptr,"OTHER") ;
		temp1_ptr = temp1_ptr->next;
		} while (temp1_ptr != head_pcb_ptr);

	kill(-the_group,SIGCONT);
	}
}


void signal_handler_sigtstp()
{
/********************** signal_handler_sigtstp **************************
 *  This is a dummy handler to prevent the parent(scheduler) from
 *  being put to sleep when a global sleep signal is sent out to
 *  the group. Only true for the ASYNC mode.
 ************************************************************************/

#ifndef POSIX_SIGNALS
	
/* Re-installs SIGTSTP handler */
re_install_signal_handler(SIGNAL_SIGTSTP); 

#endif
}

void signal_handler_sigcont()
{
/********************** signal_handler_sigcont **************************
 *  This is a dummy handler to prevent the parent(scheduler) from
 *  getting upset when it receives a SIGCONT that is sent to the
 *  scheduler from a global signal going to all children of the
 *  scheduler.
 ************************************************************************/

#ifndef POSIX_SIGNALS
	
/* Re-installs SIGCONT handler for ASYNC processes*/
re_install_signal_handler(SIGNAL_SIGCONT); 

#endif
}	


void signal_handler_sigabrt_hwfaults()
{
/********************* signal_handler_sigabrt_hwfaults *****************
 *
 *  This handler is invoked if a SIGSEGV or SIGBUS is generated by the
 *  child process and the child is initialized with the option to trap
 *  such errors(bus errors -or- seg faults).  In  this case a core
 *  file is generated by using the abort() call in the child and the
 *  parent (this process) is sent a SIGTSTP, this causes the parent to
 *  register the fact that the child core-dumped and will not be
 *  subsequently scheduled. Only true for the SYNC mode.
 *
 ***********************************************************************/

#ifndef POSIX_SIGNALS
	
/* Re-installs SIGABRT handler to detect the death of children
		due to a bus error or a seg fault while running as a 
		SYNC processes
*/

re_install_signal_handler(SIGNAL_SIGABRT); 

#endif

/* Unblocks the scheduler */
blocked_flag = FALSE;

/* Resets the Alarm */
alarm(0);

current_jib_ptr->active_clients -= 1;
current_jib_ptr->inactive_clients = current_jib_ptr->total_clients -
	current_jib_ptr->active_clients;
current_pcb_ptr->pstate = EXT;

fprintf(fp_logfile,"\n\n****  BEGIN ERROR RECORD  ****\n");
fprintf(fp_logfile,"Client Name = %s core dumped/seg-faulted\t",
	current_pcb_ptr->pclient_name);

fprintf(fp_logfile,"Process ID = %ld \n",current_pcb_ptr->pid);
fprintf(fp_logfile,"Check Core File \n");
fprintf(fp_logfile,"\n\n****  END ERROR RECORD  ****\n");
}	


void signal_handler_sigurg_execed_child()
{
/************* signal_handler_sigurg_execed_child ********************
 *                                                             
 * This handler is invoked when the child sends the parent a signal
 * during the fork/exec phase indicating that there was an error
 * during the exec and as a result the parent should not scheduler it
 * in the future.
 *
 **********************************************************************/

char error_message[256];

#ifndef POSIX_SIGNALS
	
/* Re-installs SIGABRT handler to detect the death of children
		due to a bus error or a seg fault while running as a 
		SYNC processes
*/
re_install_signal_handler(SIGNAL_SIGURG); 

#endif

sprintf(error_message,"Exec Failed for %s, Incorrect Child process",
	current_pcb_ptr->pclient_name);

print_sys_error("dispatch_clients()",error_message);

child_execed_flag = TRUE;
exec_error = TRUE;

current_pcb_ptr->pstate = EXT; /*Set this pcb to EXT so it is not scheduled */
}

#ifdef POSIX_SIGNALS
void signal_handler_sigchld()
{
/********************** signal_handler_sigchld **************************
 ************************************************************************/
char error_message[256];
pid_t pid;
int   found = 0;
PCB_NODE_PTR ptr;

if ((pid = wait(NULL)) == ERROR)
	print_sys_error("signal_handler_sigchld()", "Wait failed");

#ifdef DEBUG_INFO
printf("Child process %ld died\n", pid);fflush(stdout);
printf ("\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);
fflush (stdout);
#endif

/* Find the client that died */
ptr = head_pcb_ptr;
do	{
	if (ptr->pid == pid)
		{
		found++;
		break;
		}
	ptr = ptr->next;
	} while (ptr != head_pcb_ptr);

if (!found)
	{
	sprintf (error_message, "Process %ld is not on the list of clients", pid);
	print_sys_error("signal_handler_sigchld()", error_message);
	}
else
	{
	if (ptr == current_pcb_ptr)
		{
#ifdef DEBUG_INFO
		printf ("Current process\n"); fflush (stdout);
#endif
		if (ptr->pstate != EXT)
			abort_current_process = TRUE;
		}
	else
		{
#ifdef DEBUG_INFO
	printf ("Not current process\n"); fflush (stdout);
#endif
		if (ptr->pstate != EXT)
			update_died_pcb_jib (ptr);
		}
	}
#ifdef DEBUG_INFO
printf ("\n** Total Clients = %d\n** Total Active Clients = %d\n** Total Inactive Clients = %d\n\n",current_jib_ptr->total_clients,current_jib_ptr->active_clients,current_jib_ptr->inactive_clients);
#endif
}	
#endif

#ifdef sun
signal_handler_sigxcpu()
{
/********************** signal_handler_sigxcpu **************************
 *
 * This handler is invoked on Sun-based platforms when SIGXCPU is sent
 * to process. MU sends SIGKILL to every client in the list and exits
 ************************************************************************/
char error_message[256];
pid_t pid;
PCB_NODE_PTR ptr;

printf ("!!!Got SIGXCPU, killing clients\n");

ptr = head_pcb_ptr;
do	{
	kill (ptr->pid, SIGKILL);
#ifdef DEBUG_INFO
	printf ("   SIGKILL sent to the child process %ld\n", ptr->pid);
	fflush (stdout);
#endif

	ptr = ptr->next;
	} while (ptr != head_pcb_ptr);
exit(1);
}
#endif

/**************************************************************************
 *
 *    E N D    S I G N A L    H A N D L E R    R O U T I N E S
 *
 *************************************************************************/

void update_aborted_pcb_jib ()
{
#ifdef POSIX_SIGNALS
/* Don't want to be interrupted by SIGCHLD while updating data structures */
		sigprocmask (SIG_BLOCK, &chldset, NULL);
#endif	
current_jib_ptr->active_clients -= 1;
current_jib_ptr->inactive_clients = 
	current_jib_ptr->total_clients - current_jib_ptr->active_clients;
current_pcb_ptr->pstate = EXT;
current_pcb_ptr->p_prempted_count = ZERO;
#ifdef POSIX_SIGNALS
		sigprocmask (SIG_UNBLOCK, &chldset, NULL);
#endif	
}

#ifdef POSIX_SIGNALS
void update_died_pcb_jib (ptr)
	PCB_NODE_PTR ptr;
{
current_jib_ptr->active_clients -= 1;
current_jib_ptr->inactive_clients = 
	current_jib_ptr->total_clients - current_jib_ptr->active_clients;
ptr->pstate = EXT;
ptr->p_prempted_count = ZERO;
}
#endif

void print_sys_error(p_name,error_string)
	char *p_name;
	char *error_string;
{
char error_message[256];
	
sprintf(error_message,"Error : %s in %s\n",error_string,p_name);
perror(error_message);
}


void dump_pcb_node(ptr, type)
	PCB_NODE_PTR ptr;
	char type[10];
{
if (!strcmp(type,"CURRENT"))
	{
	fprintf(fp_logfile,"\n\n**** BEGIN PCB NODE ****\n");
	fprintf(fp_logfile,"                            \n");
	fprintf(fp_logfile,"************************\n");
	fprintf(fp_logfile,"*** CURRENT PCB NODE ***\n");
	fprintf(fp_logfile,"************************\n");
	fprintf(fp_logfile,"\nProgram Name = %s\n",ptr->pclient_name);
	fprintf(fp_logfile,"\nProcess ID = %ld\n",ptr->pid);
	fprintf(fp_logfile,"\nProcess State = %d\n",ptr->pstate);
	fprintf(fp_logfile,"\nDeadlock Quantum = %d secs\n",ptr->p_quantum);
	fprintf(fp_logfile,"\nPre-empted count = %d /Limit  = %d\n",
		ptr->p_prempted_count,ptr->p_prempted_limit);
	fprintf(fp_logfile,"\n\n**** END PCB NODE ****\n");
	}
else
    {
	fprintf(fp_logfile,"\n\n**** BEGIN PCB NODE ****\n");
	fprintf(fp_logfile,"\nProgram Name = %s\n",ptr->pclient_name);
	fprintf(fp_logfile,"\nProcess ID = %ld\n",ptr->pid);
	fprintf(fp_logfile,"\nProcess State = %d\n",ptr->pstate);
	fprintf(fp_logfile,"\nDeadlock Quantum = %d secs\n",ptr->p_quantum);
	fprintf(fp_logfile,"\nPre-empted count = %d of a limit of %d\n",
		ptr->p_prempted_count,ptr->p_prempted_limit);
	fprintf(fp_logfile,"\n\n**** END PCB NODE ****\n");
	}
}


BOOL cleanup_scheduler()
{
/**************************************
 *
 *     c l e a n u p _ s c h e d u l e r 
 *
 **************************************
 *
 * Functional description
 *      
 *      
 *
 **************************************/

PCB_NODE_PTR temp1,temp2;
char fname[256];

/* Unlink the temp file that controls the fact if the clients are
		in the mu environment or not 
*/
sprintf(fname,"%s%s%ld%s",TEMP_DIR,"/mu_",getpid(),".tmp");
if (unlink(fname))	
	{
	char error_message[80];
		
	if (errno !=  ENOENT)
		{
		sprintf(error_message,"Deleting File %s Errno : %d",fname,errno);
		print_sys_error("cleanup_scheduler()",error_message);
		}
	}

/* Unlink the temporary file that indicates wheter the scheduler is 
		running in the SYNC or ASYNC mode 
*/
if(current_jib_ptr->mode == ASYNC)
	sprintf(fname,"%s%s%ld%s",TEMP_DIR,"/mu_",getpid(),".async");
else
	sprintf(fname,"%s%s%ld%s",TEMP_DIR,"/mu_",getpid(),".sync");

if (unlink(fname))
	{
	char error_message[80];
		
	if (errno !=  ENOENT)
		{
		sprintf(error_message,"Deleting File %s Errno : %d",fname,errno);
		print_sys_error("cleanup_scheduler()",error_message);
		}
	}
			
	
/* Walk through PCB list and free every element */

if (current_pcb_ptr != NULL)
	{
	current_pcb_ptr = NULL;
	temp1 = head_pcb_ptr;
	temp2 = temp1->next;
	while(temp2 != head_pcb_ptr)	
		{
		temp1->next = temp2->next;
		clean_pcb_node(&temp2);
		free(temp2);
		temp2 = temp1->next;
		}
	}

if (head_pcb_ptr != NULL)
	{
	free(head_pcb_ptr);
	head_pcb_ptr = NULL;
	}

/* Free JIB Node */
free(current_jib_ptr);
return(TRUE);
}

void clean_pcb_node(node_ptr)
	PCB_NODE_PTR *node_ptr;
{
/**************************************
 *
 *      c l e a n _ p c b _ n o d e 
 *
 **************************************
 *
 * Functional description
 *      
 *      
 *
 **************************************/

(*node_ptr)->pid = ZERO;
(*node_ptr)->pstart_cpu = ZERO;
(*node_ptr)->pconsumed_cpu = ZERO;
(*node_ptr)->ptotal_cpu = ZERO;
(*node_ptr)->plast_read_cpu = ZERO;
(*node_ptr)->ppipe_fd[0] = ZERO;
(*node_ptr)->ppipe_fd[1] = ZERO;
(*node_ptr)->pstate = EXT;
(*node_ptr)->next = NULL;
(*node_ptr)->pclient_args = NULL;
(*node_ptr)->pclient_argcnt = ZERO;
strcpy((*node_ptr)->pclient_name , "") ;
(*node_ptr)->p_sched_freq = ZERO;
(*node_ptr)->p_quantum = ZERO;
(*node_ptr)->p_prempted_count = ZERO;
}	


void init_signal_handlers()
{
#ifdef POSIX_SIGNALS

SIGNAL_ARRAY[0].act.sa_handler = signal_handler_sigusr1;
sigemptyset(&(SIGNAL_ARRAY[0].act.sa_mask));
sigaddset(&(SIGNAL_ARRAY[0].act.sa_mask), SIGALRM);
sigaddset(&(SIGNAL_ARRAY[0].act.sa_mask), SIGUSR2);
SIGNAL_ARRAY[0].act.sa_flags = ZERO;
SIGNAL_ARRAY[0].signal_no = SIGUSR1;
strcpy(SIGNAL_ARRAY[0].signal_name , "SIGUSR1");

SIGNAL_ARRAY[1].act.sa_handler = signal_handler_sigusr2;
sigemptyset(&(SIGNAL_ARRAY[1].act.sa_mask));
sigaddset(&(SIGNAL_ARRAY[1].act.sa_mask), SIGUSR1);
SIGNAL_ARRAY[1].act.sa_flags = ZERO;
SIGNAL_ARRAY[1].signal_no = SIGUSR2;
strcpy(SIGNAL_ARRAY[1].signal_name , "SIGUSR2");
	

SIGNAL_ARRAY[2].act.sa_handler = signal_handler_sigalrm;
sigemptyset(&(SIGNAL_ARRAY[2].act.sa_mask));
sigaddset(&(SIGNAL_ARRAY[2].act.sa_mask), SIGUSR1);
SIGNAL_ARRAY[2].act.sa_flags = ZERO;
SIGNAL_ARRAY[2].signal_no = SIGALRM;
strcpy(SIGNAL_ARRAY[2].signal_name , "SIGALRM");

SIGNAL_ARRAY[3].act.sa_handler = signal_handler_sigcont;
sigemptyset(&(SIGNAL_ARRAY[3].act.sa_mask));
SIGNAL_ARRAY[3].act.sa_flags = ZERO;
SIGNAL_ARRAY[3].signal_no = SIGCONT;
strcpy(SIGNAL_ARRAY[3].signal_name , "SIGCONT");

SIGNAL_ARRAY[4].act.sa_handler = signal_handler_sigtstp;
sigemptyset(&(SIGNAL_ARRAY[4].act.sa_mask));
SIGNAL_ARRAY[4].act.sa_flags = ZERO;
SIGNAL_ARRAY[4].signal_no = SIGTSTP;
strcpy(SIGNAL_ARRAY[4].signal_name , "SIGTSTP");

SIGNAL_ARRAY[6].act.sa_handler = signal_handler_sigabrt_hwfaults;
sigemptyset(&(SIGNAL_ARRAY[6].act.sa_mask));
SIGNAL_ARRAY[6].act.sa_flags = ZERO;
SIGNAL_ARRAY[6].signal_no = SIGABRT;
strcpy(SIGNAL_ARRAY[6].signal_name , "SIGABRT");

SIGNAL_ARRAY[7].act.sa_handler = signal_handler_sigchld;
sigemptyset(&(SIGNAL_ARRAY[7].act.sa_mask));
sigaddset(&(SIGNAL_ARRAY[7].act.sa_mask), SIGUSR1);
sigaddset(&(SIGNAL_ARRAY[7].act.sa_mask), SIGUSR2);
sigaddset(&(SIGNAL_ARRAY[7].act.sa_mask), SIGALRM);
SIGNAL_ARRAY[7].act.sa_flags = ZERO;
SIGNAL_ARRAY[7].signal_no = SIGCHLD;
strcpy(SIGNAL_ARRAY[7].signal_name , "SIGCHLD");

install_signal_handler(SIGNAL_SIGUSR1);
/*
install_signal_handler(SIGNAL_SIGUSR2);
*/
install_signal_handler(SIGNAL_SIGALRM);
install_signal_handler(SIGNAL_SIGCONT);
install_signal_handler(SIGNAL_SIGTSTP);
install_signal_handler(SIGNAL_SIGABRT);
install_signal_handler(SIGNAL_SIGCHLD);

#else

SIGNAL_ARRAY[0].signal_no = SIGUSR1;
strcpy(SIGNAL_ARRAY[0].signal_name , "SIGUSR1");
SIGNAL_ARRAY[0].signal_handler =  signal_handler_sigusr1;
	
SIGNAL_ARRAY[1].signal_no = SIGUSR2;
strcpy(SIGNAL_ARRAY[1].signal_name , "SIGUSR2");
SIGNAL_ARRAY[1].signal_handler =  signal_handler_sigusr2;

SIGNAL_ARRAY[2].signal_no = SIGALRM;
strcpy(SIGNAL_ARRAY[2].signal_name , "SIGALRM");
SIGNAL_ARRAY[2].signal_handler =  signal_handler_sigalrm;


SIGNAL_ARRAY[3].signal_no = SIGCONT;
strcpy(SIGNAL_ARRAY[3].signal_name , "SIGCONT");
SIGNAL_ARRAY[3].signal_handler =  signal_handler_sigcont;


SIGNAL_ARRAY[4].signal_no = SIGTSTP;
strcpy(SIGNAL_ARRAY[4].signal_name , "SIGTSTP");
SIGNAL_ARRAY[4].signal_handler =  signal_handler_sigtstp;

SIGNAL_ARRAY[6].signal_no = SIGABRT;
strcpy(SIGNAL_ARRAY[6].signal_name , "SIGABRT");
SIGNAL_ARRAY[6].signal_handler =  signal_handler_sigabrt_hwfaults;

SIGNAL_ARRAY[7].signal_no = SIGCHLD;
strcpy(SIGNAL_ARRAY[7].signal_name , "SIGCHLD");
SIGNAL_ARRAY[7].signal_handler =  SIG_IGN;

install_signal_handler(SIGNAL_SIGUSR1);
/*
install_signal_handler(SIGNAL_SIGUSR2);
*/
install_signal_handler(SIGNAL_SIGALRM);
install_signal_handler(SIGNAL_SIGCONT);
install_signal_handler(SIGNAL_SIGTSTP);
install_signal_handler(SIGNAL_SIGABRT);
install_signal_handler(SIGNAL_SIGCHLD);

#endif
}


void install_signal_handler(array_index)
	short array_index;
{
#ifdef POSIX_SIGNALS

if(sigaction(SIGNAL_ARRAY[array_index].signal_no,&(SIGNAL_ARRAY[array_index].act),&(SIGNAL_ARRAY[array_index].oact)) == ERROR)

	print_sys_error("install_signal_handler()","Error installing Signal handler");

#else

	/* installs handler for System V style signal handling */
	signal(SIGNAL_ARRAY[array_index].signal_no,SIGNAL_ARRAY[array_index].signal_handler);

#endif
}


void install_signal_handler_by_handler(array_index,signal_number,handler_func_ptr)
	short array_index;
	int signal_number;
	void (* handler_func_ptr)();
{
#ifdef POSIX_SIGNALS

SIGNAL_ARRAY[array_index].act.sa_handler = handler_func_ptr;
sigemptyset(&(SIGNAL_ARRAY[array_index].act.sa_mask));
SIGNAL_ARRAY[0].act.sa_flags = ZERO;
SIGNAL_ARRAY[array_index].signal_no  = signal_number;
strcpy(SIGNAL_ARRAY[array_index].signal_name,"SIGURG");

#else

SIGNAL_ARRAY[array_index].signal_no = signal_number;
SIGNAL_ARRAY[array_index].signal_handler = handler_func_ptr; 
strcpy(SIGNAL_ARRAY[array_index].signal_name,"SIGURG");

#endif
install_signal_handler(array_index);
}


void re_install_signal_handler(array_index)
	short	array_index;
{
	/* Re-installs handler for System V style signal handling */
	install_signal_handler(array_index);
}

#ifdef sun
install_signal_handler_sigxcpu(array_index,signal_number,handler_func_ptr)
{
#ifdef POSIX_SIGNALS
	struct sigaction act;

	act.sa_handler = signal_handler_sigxcpu;
	sigemptyset(&(act.sa_mask));
	sigaddset(&(act.sa_mask), SIGCHLD);
	act.sa_flags = ZERO;

	sigaction (SIGXCPU, &act, NULL);
#else
	signal (SIGXCPU, signal_handler_sigxcpu);
#endif
}
#endif


char *strnset(str, ch, bytes)
	char *str;
	int ch;
	int bytes;
{
/**************************************
 *
 *      s t r n s e t
 *
 **************************************
 *
 * Functional description
 *   
 *   
 *
 **************************************/
while (bytes)
	{
	*(str + bytes) = ch;
	bytes--;
	}
*str = ch;
return str;
}
