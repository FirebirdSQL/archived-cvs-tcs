/*
 *      PROGRAM:        C preprocessor
 *      MODULE:         client.h
 *      DESCRIPTION:    Client definitions for client modules
 *                      isc_qa_init and isc_qa_pause
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
#include <signal.h>
#include <ctype.h>
#include <stdlib.h>
#include <time.h>
#include <fcntl.h>
#include <errno.h>
#ifdef SOLARIS_MT
#include <thread.h>
#endif

#define PIPE_MODE O_RDWR
#define ABSOLUTE_UNBLOCKED_SIGNAL_MASK 0L
#define NUMBER_OF_SIGNAL_HANDLERS 6
#define ZERO 0
#define FREE 1
#define PIPE_BUFFER 256
#define STOP_CPU -1000
#define CLIENT_REGISTRATION -2000
#define TEMP_DIR "/tmp"
#define TRAP_HARDWARE_FAULTS 1

#define SIGNAL_SIGTSTP 0
#define SIGNAL_SIGCONT 1
#define SIGNAL_SIGUSR2 2
#define SIGNAL_SIGTSTP_CLEANUP 3
#define SIGNAL_SIGBUS 4
#define SIGNAL_SIGSEGV 5

#ifndef _STDC_
/* Definitions for ANSI only features */
#define volatile	/* nothing */
#define const		/* nothing */
#endif

#ifndef PID_T
#define PID_T
typedef long pid_t;	 /* For process ID's and Process Group ID's */ 
#endif /* PID_T */

#ifndef PIPEFD_T
#define PIPEFD_T
typedef int pipefd_t;	/* For Pipe File Descriptors */		
#endif /* PIPEFD_T */

#ifndef CPU_T
#define CPU_T
typedef short cpu_t;	/* For Elapsed CPU time in secs/ticks */
#endif /* CPU_T */
 
typedef enum {ERROR = -1, FALSE = 0, TRUE = 1} BOOL; /* Define BOOL to C-Style false/true */


typedef struct 
	{
	pid_t 		pid;  		/* Current Process ID */
	pid_t 		ppid; 		/* Parent's Process ID */
	pipefd_t 	pipe_fd;	/* Pipe File Descriptor used to write */
				        /* back to the scheduler              */
	cpu_t 		start_cpu;	/* CPU time at start of setup for     */
					/* process scheduling	              */
	cpu_t 		consumed_cpu;	/* Delta CPU time consumed by process */

#ifdef SOLARIS_MT
	thread_t	sig_thr_id;	/* Signal handler thread id */
	thread_t	main_thr_id;	/* Main thread id of the client */
	sema_t		smph;		/* Semaphore to start/stop main thr. */
#endif
} CLIENT_STAT;
 


/* Pre-defined global variables that are used by all the client routines */
#ifdef POSIX_SIGNALS

#define POSIX_SOURCE 1

	struct signal_structure_posix_style{
			struct sigaction oact;
			struct sigaction act;
			char signal_name[40];
			int signal_no;
}volatile SIGNAL_ARRAY[NUMBER_OF_SIGNAL_HANDLERS];
sigset_t mask;

#else
	struct signal_structure_non_posix_style{
			int signal_no;
			char signal_name[40];
			int (* signal_handler)();
	}volatile SIGNAL_ARRAY[NUMBER_OF_SIGNAL_HANDLERS];
#endif

CLIENT_STAT volatile * client_stat_ptr; /* Pointer to client status structure */

BOOL volatile spin_flag;
		/* Flag indicating the wheter the process should spin or be */
                /* processing                                               */

BOOL volatile continue_execution;
			/* Flag indicating wheter the process should continue 
			    execution after it found the process it sends a 
			    kill() dies
		        */

extern long gds__status[20];

