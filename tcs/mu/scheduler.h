/*
 *      PROGRAM:        C preprocessor
 *      MODULE:         scheduler.h
 *      DESCRIPTION:    Definitions used by the scheduler to manage all
 *			the client process.
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
#include <string.h>
#include <time.h>
#include <errno.h>
#ifdef SOLARIS
#include <wait.h>
#else
#include <sys/wait.h>
#endif

#ifndef _STDC_
/* Definitions for ANSI only features */
#define volatile	/* nothing */
#define const		/* nothing */
#endif

#ifndef PID_T
#define PID_T
typedef long pid_t;     /* For process ID's and Process Group ID's */
#endif /* PID_T */

#ifndef PIPEFD_T
#define PIPEFD_T
typedef int pipefd_t;  /* For Pipe File Descriptors */
#endif /* PIPEFD_T */

#ifndef CPU_T
#define CPU_T
typedef short cpu_t;   /* For Elapsed CPU time in secs/ticks */
#endif /* CPU_T */

/*************************** Global Definitions *******************************/
#define	SEC_PER_MIN			60 
#define LOWER_SCHED_LIMIT 		0 
#define PIPE_BUFFER 			256
#define ABSOLUTE_UNBLOCKED_SIGNAL_MASK 		0L
#define MIN_SCHED_FREQ 			1
#define DEFAULT_QUANTUM			10 * SEC_PER_MIN /* seconds */
#define DEFAULT_LIMIT_PREEMPT		10 /* count value,no units */
#define NUMBER_OF_SIGNAL_HANDLERS       8
#define ZERO				0
#define STOP_CPU 			-1000L
#define CLIENT_REGISTRATION 		-2000L
#define TEMP_DIR			"/tmp"
#define MU_CONFIG_FILE			"./.mu_config"
#define MU_BASEQUANTUM			"MU_BASEQUANTUM"

/* No SIGURG on SCO Unix - try to use SIGPWR */

#ifdef SCO_UNIX
#define SIGURG SIGPWR
#endif

/* Signal Definitions */

#define SIGNAL_SIGUSR1 0
#define SIGNAL_SIGUSR2 1
#define SIGNAL_SIGALRM 2
#define SIGNAL_SIGCONT 3
#define SIGNAL_SIGTSTP 4
#define SIGNAL_SIGURG 5
#define SIGNAL_SIGABRT 6
#define SIGNAL_SIGCHLD 7

/***************************** Typedefs ***************************************/

typedef enum {COM = 0, HIB = 1, EXT = 2, DLK = 3} PROCESS_STATE; /* Define VMS style codes */
					       /* for process states     */
typedef enum {ERROR = -1, FALSE = 0, TRUE = 1} BOOL; /* Define BOOL to C-Style
alse/true */

typedef enum {SYNC = 0, ASYNC = 1} SCHEDULER_MODE; /* Defines Scheduler Mode */
						  /* Synchronous/Asynchronous */ 
typedef struct pcb_node{
	pid_t           pid;            /* Current Process ID */
	cpu_t           pstart_cpu;     /* CPU time at start of setup for */
                                        /* process scheduling             */
        cpu_t           pconsumed_cpu;  /* Delta CPU time consumed by process */
	cpu_t		plast_read_cpu; /* Last CPU value read from the pipe  */	
	cpu_t		ptotal_cpu;     /* Total CPU time used by the process */	

	pipefd_t        ppipe_fd[2];    /* Pipe File Descriptor used to write */
	PROCESS_STATE	pstate;		/* Current State of Process         */
					/* COM=Swapped in  HIB=Swapped out  */ 
	struct pcb_node	*next;		/* Pointer to next PCB node  */
	char 		** pclient_args;/* Pointer to a vector of client args */
	short 		pclient_argcnt; /* Number of client args	*/
	char 		pclient_name[40]; /* Name of client program  */
	int		p_sched_freq;   /* Number of times a client will be */
					/* successively scheduled	    */
/* If set to 2 then schedule it twice in succession */
	int		p_current_sched_freq; /* Same as p_sched_freq, */
					      /* (running count) */
	int		p_quantum;	/* Time quantum in secs for which to */
					/* schedule process		*/		 
	int 		p_prempted_count; /* Count of number of times the process was pre-empted during scheduling i.e the alarm went off */

	int 		p_prempted_limit; /* Limit of the number of times a process can be pre-empted during scheduling i.e the alarm goes off */

}PCB_NODE;

typedef PCB_NODE * PCB_NODE_PTR; /* Define a PCB_NODE type pointer  */		

typedef struct jib_node{

	SCHEDULER_MODE 	mode; /* Current Mode of Scheduler SYNC/ASYNC   */
	BOOL 		verbose; /* Verbose Flag	   */
	long		active_clients; /* # of clients being scheduled */ 
	long 		inactive_clients; /* # of clients not being scheduled */
	long 		total_clients; /* Total clients in the system */	
	long 		garbage_clients; /* # of garbage clients  */	
	unsigned int    base_quantum;   /* Base Time quantum in secs for which
					  to scheduler process*/
}JIB_NODE;

typedef JIB_NODE * JIB_NODE_PTR; /* Define a JIB_NODE type pointer */

/*****************************************************************************/

/*************************** Global Variables *******************************/

PCB_NODE_PTR volatile head_pcb_ptr, volatile current_pcb_ptr;
JIB_NODE_PTR volatile current_jib_ptr;

#ifdef POSIX_SIGNALS

struct signal_structure_posix_style{
struct sigaction oact;
struct sigaction act;
char signal_name[40];
int signal_no;
} volatile SIGNAL_ARRAY[NUMBER_OF_SIGNAL_HANDLERS];
sigset_t volatile mask;

#else

struct signal_structure_non_posix_style{
int signal_no;
char signal_name[40];
int (*signal_handler)();
} volatile SIGNAL_ARRAY[NUMBER_OF_SIGNAL_HANDLERS];

#endif

FILE volatile *fp_logfile;
BOOL volatile blocked_flag;
BOOL volatile abort_current_process;
BOOL volatile child_execed_flag;
BOOL volatile exec_error;

/*************************************************************************/


/**************************  Function definitions  ************************/

extern void init_signal_handlers();
extern BOOL init_scheduler();
extern BOOL parse_scheduler_args();
extern BOOL dispatch_clients();
extern BOOL schedule_clients();
extern BOOL cleanup_scheduler();
extern void  print_sys_error();
extern void update_aborted_pcb_jib();
extern void update_died_pcb_jib();
extern int signal_handler_sigabrt_hwfaults();
extern int signal_handler_sigurg_execed_child();
extern int signal_handler_sigurg_freeze();
extern int killpg();

/*************************************************************************/

/****************************  Macro Definitions ************************/
#ifdef POSIX_SIGNALS 
#define POSIX_SOURCE 1
#endif

#if defined(MPP) || defined(SMP)
#define DEFAULT_BASE_QUANTUM 0
#else
#define DEFAULT_BASE_QUANTUM 5
#endif

#define MAX(a,b)  (((a) > (b)) ? (a) : (b))
#define MIN(a,b)  (((a) < (b)) ? (a) : (b))

