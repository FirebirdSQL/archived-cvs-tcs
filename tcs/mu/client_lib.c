/*
 *	PROGRAM		:	Client Interface
 *	MODULE		:	client.c
 *	DESCRIPTION	:	Client entrypoints and related modules 
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

#include "client.h"

#ifdef POSIX_SIGNALS
static sigset_t zeromask;
#endif

#ifdef SOLARIS_MT
void *sig_handler(arg)
void *arg;
{
int signo;

#ifdef DEBUG_INFO
printf("%ld:%d> Thread started\n", client_stat_ptr->pid,
				   client_stat_ptr->sig_thr_id);
#endif
for(;;)
	{
	signo = sigwait(&mask);
#ifdef DEBUG_INFO
	printf("%ld:%d> Received signal %d\n", client_stat_ptr->pid,
			 		       client_stat_ptr->sig_thr_id,
					       signo);
#endif
	switch(signo)
		{
		case SIGCONT:
			if (spin_flag)
				sema_post(&(client_stat_ptr->smph));
			else
				thr_continue(client_stat_ptr->main_thr_id);
			break;
		case SIGTSTP:
			if (!spin_flag)
				thr_suspend(client_stat_ptr->main_thr_id);
		}
	}
}
#endif

BOOL qa_mu_environment ()
{
/**********************************************
 *
 *          q a _ m u _ e n v i r o n m e n t  
 * 
 ********************************************** 
 *
 * Functional Description
 *	This module checks for the existence of a 
 *	file mu_<parent pid>.tmp in the /tmp directory
 *	If this file exists then the client is running   
 *	in the multi-user environment, else it is not and
 *	the qa_mu_pause() call along with the cleanup and 
 *	init calls are no-op'ed	
 *
 *********************************************/
char pipe_message[PIPE_BUFFER];
FILE *fp_temp;

char fname[256];
	
sprintf(fname,"%s%s%ld%s",TEMP_DIR,"/mu_",getppid(),".tmp");
	
if (!(fp_temp = fopen(fname,"r")))
	{
	if (errno == ENOENT)
		{	
		/* printf("Running outside the Multi-User Tool Environment ....\n");*/
		return FALSE; /* The file does not exist, outside */
					/* the mu environment		    */
		}
	else
		{
		char error_message[128];

		sprintf(error_message,"No %d",errno);
		print_sys_error("qa_mu_environment()",error_message);
		return ERROR ; /* An error occured */     
		}	
	}
else
	{
	fclose(fp_temp);
	return(TRUE); /* Running in the Multi-user environment */
	}

}


BOOL qa_mu_async()
{
/**********************************************
 *
 *          q a _ m u _ a s y n c 
 * 
 ********************************************** 
 *
 * Functional Description
 *	This module checks for the existence of a 
 *	file mu_<parent pid>.async in the /tmp directory
 *	If this file exists then the client is running 
 *	the multi-user tool in the ASYNC environment, else it is 
 *	running in the SYNC mode. In the ASYNC mode the qa_mu_pause()
 *	call call is no-op'ed	
 *
 *********************************************/
char pipe_message[PIPE_BUFFER];
FILE *fp_temp;
char fname[256];
	
sprintf(fname,"%s%s%ld%s",TEMP_DIR,"/mu_",getppid(),".async");
	
if (!(fp_temp = fopen(fname,"r")))
	return FALSE; /* The file does not exist */
				/* running SYNC ....	   */
else
	{
	fclose(fp_temp);
	return TRUE; /* Running ASYNC .....	*/
	}

}


BOOL qa_mu_init(argcount,argvector,trap_hw_faults)
int argcount;
char ** argvector;
short trap_hw_faults;
{
/**********************************************
 *
 *          q a _ m u _ i n i t 
 *
 **********************************************
 *
 * Functional Description
 *	Initialize the CLIENT_STAT structure with information that 
 *	remains static during the life time of the client process.
 *	Init process id, scheduler process id, starting cpu_time, 
 *	Open the write end of the pipe in the client
 *
 *
 *********************************************/

char module_name[40];
char fdstr[10];
pipefd_t current_pipe_fd;
long init_clock_val = ZERO; 
long registration_value = CLIENT_REGISTRATION;
char pipe_message[PIPE_BUFFER];

strcpy(module_name,"qa_mu_init()");

if (!qa_mu_environment())
	{
	printf("Running outside the Multi-User Tool Environment ....\n");
	fflush(stdout);
	return TRUE;
	}

/* Initialize signal handler array for Client Scheduling */
init_signal_handlers();

/* The following two line were #ifdefed for SOLARIS_MT before because
   because we are using sigwait() function to work with signals. This 
   function in Solaris 2.4 did not care if a signal handler was installed
   It got any signal regardless of its disposition. 
   However, Solaris 2.5 returns to the POSIX interpretation of sigwait()
   fuction. If we want to work with a signal we need to install our
   siganl handler function or sigwait() never gets the signal.

   Mikhail A. Melnikov
   June 10, 1996
*/

/* Set-up individual signal handers */ 
install_signal_handler(SIGNAL_SIGTSTP);
install_signal_handler(SIGNAL_SIGCONT);

/*install_signal_handler(SIGNAL_SIGUSR2);
*/

/* If the option to trap SIGBUS and SIGSEGV are set then install
	their handlers 
*/
if (trap_hw_faults == TRAP_HARDWARE_FAULTS)
	{
	install_signal_handler(SIGNAL_SIGBUS);
	install_signal_handler(SIGNAL_SIGSEGV);
	}

if ((client_stat_ptr = (CLIENT_STAT *)malloc(sizeof(CLIENT_STAT))) == NULL)
	{
	print_sys_error("qa_mu_init()","memory allocation for the client data-structure failed");
	return FALSE;
	}

/* Check to ensure the arguments passed in are not bogus */
if ((argcount <= 1) || (argvector == NULL) || (argvector[argcount - 1] == NULL))
	{
	print_sys_error("qa_mu_init()","Incorrect arguments passed to function. Initialization Failed\n");
	return FALSE;
	}

/* Get CPU time elapsed at init */
client_stat_ptr->start_cpu = clock();

/* Get current process ID	*/
client_stat_ptr->pid = getpid();

/* Get Parent's process ID	*/
client_stat_ptr->ppid = getppid();

/* Get Child's end of Pipe fd passed from the scheduler */
strcpy(fdstr,argvector[argcount - 1]);
	if (!(fdstr[0] >= '0' && fdstr[0] <= '9'))
	{
		free(client_stat_ptr);
		print_sys_error("qa_mu_init()","Last argument should be file descriptor of pipe");
		return(FALSE);
	}
	else 
	{
		current_pipe_fd = atoi(fdstr);
		client_stat_ptr->pipe_fd = (pipefd_t)current_pipe_fd;
	}
#ifdef SOLARIS_MT
sema_init(&(client_stat_ptr->smph), 0, USYNC_THREAD, NULL);
client_stat_ptr->main_thr_id = thr_self();
sigemptyset(&mask);
sigaddset(&mask, SIGCONT);
sigaddset(&mask, SIGTSTP);
thr_sigsetmask(SIG_BLOCK, &mask, NULL);
if (thr_create(NULL, 0, sig_handler, NULL, THR_DETACHED | THR_NEW_LWP, &(client_stat_ptr->sig_thr_id)))
{
	print_sys_error("qa_mu_init()","Failed to create SIG_HANDLER thread");
	return(FALSE);
}
#ifdef DEBUG_INFO
	printf("%ld:%d> Successfully created SIG_HANDLER thread %d\n\n",
		client_stat_ptr->pid,
		client_stat_ptr->main_thr_id,
		client_stat_ptr->sig_thr_id);
	fflush(stdout); 
#endif
/* Give a chance to SIG_HANDLER thread to start */
thr_yield();
#endif
	
/****************************************/
/* *******  Registration Phase ******** */
/****************************************/

	/* Writes the registration value into a buffer */
	sprintf(pipe_message,"%ld",registration_value);

	/* Writes the registration value from the buffer to the pipe */
	if((BOOL)write(client_stat_ptr->pipe_fd,pipe_message,sizeof(pipe_message)) == ERROR)
	{
		print_sys_error("qa_mu_init()","Failed to write to pipe");
		return(FALSE);
	}

	/* Sends parent SIGUSR1 indicating data to be read from the pipe */
#ifdef DEBUG_INFO
	printf("*** Process %ld sending parent process %ld SIGUSR1 indicating data to be read %s on pipe\n Awaiting ACK from scheduler\n\n", client_stat_ptr->pid,client_stat_ptr->ppid, pipe_message);fflush(stdout); 
#endif

	spin_flag = TRUE;
	if (kill(client_stat_ptr->ppid,SIGUSR1) == ERROR)
	{
		if (errno == ESRCH)
			print_sys_error("qa_mu_init()","Failed to find parent process mu");
		else
			print_sys_error("qa_mu_init()","Configuration problem with parent process mu");
		
		continue_execution = FALSE;
		kill (client_stat_ptr->pid, SIGKILL);
		
		return(FALSE);
	}
	else
		continue_execution = TRUE;
	
	if (continue_execution)
	{
#ifdef SOLARIS_MT
#ifdef DEBUG_INFO
printf("%ld:%d> Wait on semaphore\n", client_stat_ptr->pid, client_stat_ptr->main_thr_id);
#endif
		sema_wait(&(client_stat_ptr->smph));
		spin_flag = FALSE;
#ifdef DEBUG_INFO
printf("%ld:%d> Got semaphore\n", client_stat_ptr->pid, client_stat_ptr->main_thr_id);
#endif
#else
#ifdef POSIX_SIGNALS
		/* Waits until it receives a signal from the scheduler acknowled		   ging its registration 
		*/
		sigemptyset (&mask);
		sigaddset (&mask, SIGCONT);
		sigprocmask (SIG_BLOCK, &mask, NULL);
	
		while(spin_flag)
			sigsuspend (&zeromask);
		sigprocmask (SIG_UNBLOCK, &mask, NULL);
#else 
		sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif
#endif /* SOLARIS_MT */
		return(TRUE);
	}
}

/******************************************************************************/

BOOL qa_mu_pause()
{
/**********************************************
 *
 *          q a _ m u _ p a u s e 
 *
 **********************************************
 *
 * Functional Description
 *	This module sets the dynamically changing information 
 *	for the current process
 *	
 *
 *********************************************/
	char pipe_message[PIPE_BUFFER];
/*
#ifdef POSIX_SIGNALS
	sigset_t	act, oact;

	act.sa_handler = SIG_IGN;
	sigemptyset (&(act.sa_mask));
	act.sa_flags = 0;
	sigaction (SIGTSTP, &act, &oact);
#endif
*/

	/* No-op this call if not in the multi-user environment */
	if (!qa_mu_environment())
		return (TRUE);

	/* No-op this call if running in ASYNC mode */
	if (qa_mu_async())
		return (TRUE);

	client_stat_ptr->consumed_cpu = clock() - client_stat_ptr->start_cpu;
	
	/* Writes the clock ticks data into a buffer */
	sprintf(pipe_message,"%ld",client_stat_ptr->consumed_cpu);

	/* Writes the clock ticks data from the buffer to the pipe */
	if((BOOL)write(client_stat_ptr->pipe_fd,pipe_message,sizeof(pipe_message)) == ERROR)
	{
		print_sys_error("qa_mu_pause","Failed to write to pipe");
		return(FALSE);
	}

#ifdef DEBUG_INFO
	printf("*** Process %ld is in pause\n",getpid());fflush(stdout);
#endif

#ifdef DEBUG_INFO
	printf("*** Process %ld sending parent process %ld SIGUSR1 indicating data to be read %s on pipe\n Awaiting ACK from scheduler\n\n", client_stat_ptr->pid,client_stat_ptr->ppid, pipe_message);fflush(stdout); 
#endif

	spin_flag = TRUE;
	
	/* Sends parent SIGUSR1 indicating data to be read from the pipe */
	if (kill(client_stat_ptr->ppid,SIGUSR1) == ERROR)
	{
		if (errno == ESRCH)
			print_sys_error("qa_mu_pause()","Failed to find parent process mu");
		else
			print_sys_error("qa_mu_pause()","Configuration problem with parent process mu");

		continue_execution = FALSE;
		kill (client_stat_ptr->pid, SIGKILL);
		return (FALSE);
	}
	else 
		continue_execution = TRUE;
		
	if (continue_execution)
	{
#ifdef SOLARIS_MT
#ifdef DEBUG_INFO
printf("%ld:%d> Wait on semaphore\n", client_stat_ptr->pid, client_stat_ptr->main_thr_id);
#endif
		sema_trywait(&(client_stat_ptr->smph));
		sema_wait(&(client_stat_ptr->smph));
		spin_flag = FALSE;
#ifdef DEBUG_INFO
printf("%ld:%d> Got semaphore\n", client_stat_ptr->pid, client_stat_ptr->main_thr_id);
#endif
#else
#ifdef POSIX_SIGNALS
	/* Blocks until parent reads pipe and sends child a SIGTSTP */

		sigemptyset (&mask);
		sigaddset (&mask, SIGCONT);
		sigprocmask (SIG_BLOCK, &mask, NULL);

		while(spin_flag)
			sigsuspend (&zeromask);

		sigprocmask (SIG_UNBLOCK, &mask, NULL);
/*
		sigaction (SIGTSTP, &oact, NULL);
*/
#else
		sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif
#endif /* SOLARIS_MT */
		return(TRUE);
	}
}

/******************************************************************************/

BOOL qa_mu_cleanup () 
{
/**********************************************
 *
 *          q a _ m u _ c l e a n u p 
 *
 **********************************************
 *
 * Functional Description
 *	This module signals the parent of its intent to stop being scheduled
 *	 and frees up memory for its data-structues.	
 *	
 *
 *********************************************/
	char pipe_message[PIPE_BUFFER];

	if (!qa_mu_environment())
	{
		printf("Running outside the Multi-User Tool Environment ....\n"); fflush(stdout);
		return(TRUE);
	}
/*
	install_signal_handler(SIGNAL_SIGTSTP_CLEANUP);
*/
	client_stat_ptr->consumed_cpu = STOP_CPU;

	/* Writes the clock ticks data into a buffer */
	sprintf(pipe_message,"%ld",client_stat_ptr->consumed_cpu);

	if((BOOL)write(client_stat_ptr->pipe_fd,pipe_message,sizeof(pipe_message)) == ERROR)
	{	
		print_sys_error("qa_mu_cleanup","Failed to write to pipe");
		return(FALSE);
	}
#ifdef DEBUG_INFO
	printf("*** Process %ld is in cleanup\n",getpid());fflush(stdout);
#endif

	spin_flag = TRUE;
	if (kill(client_stat_ptr->ppid,SIGUSR1) == ERROR)
	{
		if (errno == ESRCH)
			print_sys_error("qa_mu_cleanup()","Failed to find parent process mu");
		else
			print_sys_error("qa_mu_cleanup()","Configuration problem with parent process mu");

		continue_execution = FALSE;
		kill (client_stat_ptr->pid, SIGKILL);
		return (FALSE);
	}
	else 
		continue_execution = TRUE;
		
	if (continue_execution)
	{
#ifdef SOLARIS_MT
#ifdef DEBUG_INFO
printf("%ld:%d> Wait on semaphore\n", client_stat_ptr->pid, client_stat_ptr->main_thr_id);
#endif
		sema_trywait(&(client_stat_ptr->smph));
		sema_wait(&(client_stat_ptr->smph));
		spin_flag = FALSE;
			
#ifdef DEBUG_INFO
printf("%ld:%d> Got semaphore\n", client_stat_ptr->pid, client_stat_ptr->main_thr_id);
#endif
#else
#ifdef POSIX_SIGNALS
		sigemptyset (&mask);
		sigaddset (&mask, SIGCONT);
		sigprocmask (SIG_BLOCK, &mask, NULL);
	
		while(spin_flag)
			sigsuspend (&zeromask);

		sigprocmask (SIG_UNBLOCK, &mask, NULL);
#else
		sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif
#endif
		if ((BOOL)close(client_stat_ptr->pipe_fd) == ERROR)
		{
			print_sys_error("qa_mu_cleanup","Error Closing Pipe");
			return(FALSE);
		}
		free(client_stat_ptr);
		return(TRUE);
	}
}



/************************    SIGNAL HANDLERS      ****************************
 *  Description                                                              * 
 *                                                                           * 
 *                                                                           * 
 *  signal_handler_sigusr2() : SIGUSR2 signal handler gets the current clock * 
 *                            info and writes this data to the pipe, and then* 
 *                            sends the parent SIGUSR2 indicating data to be * 
 *                            read from the pipe                             * 
 *                                                                           * 
 *  signal_handler_sigtstp(): SIGTSTP signal handler sets the spin_flag      * 
 *                            global variable to TRUE and waits until it is  * 
 *                            reset to FALSE by a call to the SIGCONT handler* 
 *			      This is used by the parent to poke/peek the    *
 *			      clock value when an alarm for the current      *
 *			      process has gone off.			     *
 *                                                                           * 
 *  signal_handler_sigcont(): SIGCONT signal handler sets the spin_flag      * 
 *                            global variable to FALSE                       * 
 *                                                                           * 
 *  signal_handler_sigtstp_cleanup() : SIGTSTP handler that is installed in  * 
 *                                     the cleanup routine to synchronize the*
 *                                     childs exit only after the parent has *
 *                                     acknowledged its intent to exit       * 
 *                                                                           *
 *  signal_handler_sighwfaults_sigbus(): SIGBUS signal handler traps the     * 
 * 				  	 SIGBUS signal, and sends the parent * 
 *				  	 a SIGTSTP notifying it of its death *
 *                                                                           *
 *  signal_handler_sighwfaults_sigsegv(): SIGSEGV signal handler traps the   * 
 * 				  	 SIGSEGV signal, and sends the parent* 
 *				  	 a SIGTSTP notifying it of its death *
 *                                                                           *
 *****************************************************************************/

/************************ signal_handler_sigusr2 *****************************/

static signal_handler_sigusr2()
{
	char pipe_message[PIPE_BUFFER];
#ifndef POSIX_SIGNALS
	re_install_signal_handler(SIGNAL_SIGUSR2);
#endif

#ifdef DEBUG_INFO
	printf("*** Process %ld received sigusr2\n",getpid());fflush(stdout);
#endif
	client_stat_ptr->consumed_cpu = clock() - client_stat_ptr->start_cpu;
	
	/* Writes the clock ticks data into a buffer */
	sprintf(pipe_message,"%ld",client_stat_ptr->consumed_cpu);

	/* Writes the clock ticks data from the buffer to the pipe */
	if((BOOL)write(client_stat_ptr->pipe_fd,pipe_message,sizeof(pipe_message)) == ERROR)
		perror("Pipe Error Fail");

	/* Sends parent SIGUSR2 indicating data to be read from the pipe */
	kill(client_stat_ptr->ppid,SIGUSR2);

	/* Blocks until parent reads pipe and sends child a SIGTSTP */
#ifdef POSIX_SIGNALS
		sigemptyset (&mask);
		sigaddset (&mask, SIGCONT);
		sigprocmask (SIG_BLOCK, &mask, NULL);
		spin_flag = TRUE;
	
		while(spin_flag) sigsuspend (&zeromask);

		sigprocmask (SIG_UNBLOCK, &mask, NULL);

#else
		sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif
}
/******************************************************************************/

/******************** signal_handler_sigtstp_cleanup    **********************/
static signal_handler_sigtstp_cleanup()
{
	/* dummy handler - does nothing */
#ifdef DEBUG_INFO 
	printf("*** Process %ld received cleanup_sigtstp\n",getpid());fflush(stdout);
#endif

#ifndef POSIX_SIGNALS
	re_install_signal_handler(SIGNAL_SIGTSTP);
#endif
	spin_flag = FALSE;
}	
/******************************************************************************/

/********************** signal_handler_sigtstp *******************************/
static signal_handler_sigtstp()
{
#ifndef POSIX_SIGNALS
	re_install_signal_handler(SIGNAL_SIGTSTP);
#endif

#ifdef DEBUG_INFO
	printf("*** Process %ld received ACK/sigtstp\n",getpid());fflush(stdout);
#endif
	/* Blocks until parent sends child a SIGCONT */
#ifdef POSIX_SIGNALS
	sigemptyset (&mask);
	sigaddset (&mask, SIGCONT);
	sigprocmask (SIG_BLOCK, &mask, NULL);
	spin_flag = TRUE;

	while(spin_flag)
#ifdef SOLARIS
		{
		/* Don't bother checking the signal number returned
		   by sigwait. It can only be SIGCONT (or error :-))
		*/
		sigwait (&mask);
		signal_handler_sigcont();
		}
#else
		sigsuspend (&zeromask);
#endif

	sigprocmask (SIG_UNBLOCK, &mask, NULL);
#else
	sigpause(ABSOLUTE_UNBLOCKED_SIGNAL_MASK);
#endif

#ifdef DEBUG_INFO
	printf("*** Process %ld leaving sigtstp\n",getpid());fflush(stdout);
#endif
	
} 
/******************************************************************************/

/********************** signal_handler_sigcont *******************************/
static signal_handler_sigcont() 
{ 
#ifndef POSIX_SIGNALS
	re_install_signal_handler(SIGNAL_SIGCONT);
#endif
#ifdef DEBUG_INFO
	printf("\n*** Process %ld received sigcont\n",getpid());fflush(stdout);
#endif
	spin_flag = FALSE;
}
/******************************************************************************/


/***************** signal_handler_sighwfaults_sigbus **************************/
static signal_handler_sighwfaults_sigbus() 
{ 
#ifndef POSIX_SIGNALS
	re_install_signal_handler(SIGNAL_SIGBUS);
#endif
	print_sys_error("Client Program","Bus Error(core dumped)");
	kill(client_stat_ptr->ppid,SIGABRT);
	/* Force the generation of a core file */
	abort();
}

/***************** signal_handler_sighwfaults_sigsegv *************************/
static signal_handler_sighwfaults_sigsegv() 
{ 
#ifndef POSIX_SIGNALS
	re_install_signal_handler(SIGNAL_SIGSEGV);
#endif
	print_sys_error("Client Program","Segmentation Violation (core dumped)");
	kill(client_stat_ptr->ppid,SIGABRT);
	/* Force the generation of a core file */
	abort();
}
/**********************  END SIGNAL HANDLERS  *********************************/

static init_signal_handlers()
{
/*******************************************************************
 *
 *          i n i t _ s i g n a l _ h a n d l e r s  
 *
 *******************************************************************
 *
 * Functional Description
 *	 Initializes the SIGNAL_ARRAY with the signal_no, signal_name and 
 *       corresponding signal handler to be invoked when the appropriate 
 *       signal is delivered.	
 *	
 *
 *******************************************************************/
#ifdef POSIX_SIGNALS

	SIGNAL_ARRAY[0].act.sa_handler = signal_handler_sigtstp;
        sigemptyset(&(SIGNAL_ARRAY[0].act.sa_mask));
        SIGNAL_ARRAY[0].act.sa_flags = ZERO ;
        SIGNAL_ARRAY[0].signal_no = SIGTSTP;
        strcpy(SIGNAL_ARRAY[0].signal_name , "SIGTSTP");

	SIGNAL_ARRAY[1].act.sa_handler = signal_handler_sigcont;
        sigemptyset(&(SIGNAL_ARRAY[1].act.sa_mask));
	sigaddset(&(SIGNAL_ARRAY[1].act.sa_mask), SIGTSTP);
        SIGNAL_ARRAY[1].act.sa_flags = ZERO;
        SIGNAL_ARRAY[1].signal_no = SIGCONT;
        strcpy(SIGNAL_ARRAY[1].signal_name , "SIGCONT");
/*
	SIGNAL_ARRAY[2].act.sa_handler = signal_handler_sigusr2;
        sigemptyset(&(SIGNAL_ARRAY[2].act.sa_mask));
        SIGNAL_ARRAY[2].act.sa_flags = ZERO;
        SIGNAL_ARRAY[2].signal_no = SIGUSR2;
        strcpy(SIGNAL_ARRAY[2].signal_name , "SIGUSR2");
*/

	SIGNAL_ARRAY[3].act.sa_handler = signal_handler_sigtstp_cleanup;
        sigemptyset(&(SIGNAL_ARRAY[3].act.sa_mask));
        SIGNAL_ARRAY[3].act.sa_flags = ZERO;
        SIGNAL_ARRAY[3].signal_no = SIGTSTP;
        strcpy(SIGNAL_ARRAY[3].signal_name , "SIGTSTP");

	SIGNAL_ARRAY[4].act.sa_handler = signal_handler_sighwfaults_sigbus;
        sigemptyset(&(SIGNAL_ARRAY[4].act.sa_mask));
        SIGNAL_ARRAY[4].act.sa_flags = ZERO;
        SIGNAL_ARRAY[4].signal_no = SIGBUS;
        strcpy(SIGNAL_ARRAY[4].signal_name , "SIGBUS");

	SIGNAL_ARRAY[5].act.sa_handler = signal_handler_sighwfaults_sigsegv;
        sigemptyset(&(SIGNAL_ARRAY[5].act.sa_mask));
        SIGNAL_ARRAY[5].act.sa_flags = ZERO;
        SIGNAL_ARRAY[5].signal_no = SIGSEGV;
        strcpy(SIGNAL_ARRAY[5].signal_name , "SIGSEGV");

	sigemptyset (&zeromask);

#else

        SIGNAL_ARRAY[0].signal_no = SIGTSTP;
        strcpy(SIGNAL_ARRAY[0].signal_name,"SIGTSTP");
        SIGNAL_ARRAY[0].signal_handler =  signal_handler_sigtstp;

        SIGNAL_ARRAY[1].signal_no = SIGCONT;
        strcpy(SIGNAL_ARRAY[1].signal_name , "SIGCONT");
        SIGNAL_ARRAY[1].signal_handler =  signal_handler_sigcont;

        SIGNAL_ARRAY[2].signal_no = SIGUSR2;
        strcpy(SIGNAL_ARRAY[2].signal_name,"SIGUSR2");
        SIGNAL_ARRAY[2].signal_handler =  signal_handler_sigusr2;

        SIGNAL_ARRAY[3].signal_no = SIGTSTP;
        strcpy(SIGNAL_ARRAY[3].signal_name,"SIGTSTP");
        SIGNAL_ARRAY[3].signal_handler =  signal_handler_sigtstp_cleanup;

        SIGNAL_ARRAY[4].signal_no = SIGBUS;
        strcpy(SIGNAL_ARRAY[4].signal_name,"SIGBUS");
        SIGNAL_ARRAY[4].signal_handler =  signal_handler_sighwfaults_sigbus;

        SIGNAL_ARRAY[5].signal_no = SIGSEGV;
        strcpy(SIGNAL_ARRAY[5].signal_name,"SIGSEGV");
        SIGNAL_ARRAY[5].signal_handler =  signal_handler_sighwfaults_sigsegv;
#endif
}


static install_signal_handler(signal_index)
		int	signal_index;
{
/***********************************************************
 *
 *          i n s t a l l _ s i g n a l _ h a n d l e r 
 *
 ***********************************************************
 *
 * Functional Description
 *	This module actually installs the signal handler for
 *      non - posix style signal handling. The signal_no to be 
 *      installed is passed as a parameter, this is in-turn as 
 *      an index into the array. 
 *
 *********************************************************/
#ifdef POSIX_SIGNALS
if(sigaction(SIGNAL_ARRAY[signal_index].signal_no,
	&(SIGNAL_ARRAY[signal_index].act),
	&(SIGNAL_ARRAY[signal_index].oact)) == ERROR)
		perror("Error installing Signal handler");
#else
signal(SIGNAL_ARRAY[signal_index].signal_no,
	SIGNAL_ARRAY[signal_index].signal_handler);
#endif
}


static re_install_signal_handler(signal_index)
int signal_index;
{
/***********************************************************
 *
 *          r e _ i n s t a l l _ s i g n a l _ h a n d l e r 
 *
 ***********************************************************
 *
 * Functional Description
 *	This module re-installs the signal handler for
 *      non - posix style signal handling. The signal_no to be 
 *      calls install_signal_handler with the signal_no as an arg.
 *************************************************************/
 
install_signal_handler(signal_index);
}	


static print_sys_error(p_name,error_string)
char * p_name;
char * error_string;
{
char error_message[1024];

sprintf(error_message,"Error : %s in %s\n",error_string,p_name);
fprintf(stderr,"%s\n",error_message);
}
