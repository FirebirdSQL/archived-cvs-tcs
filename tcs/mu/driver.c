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

#include "scheduler.h"

#ifdef sun
#include <sys/time.h>
#include <sys/resource.h>

void limit_cpu_time(time_limit)
int time_limit;
{
struct rlimit *rlp;

rlp = (struct rlimit *) malloc(sizeof(struct rlimit));
rlp->rlim_max = time_limit;
rlp->rlim_cur = time_limit;
setrlimit(RLIMIT_CPU,rlp);
free(rlp);
}
#endif /* sun */

int main(argc,argv)
int argc;
char **argv;
{
current_pcb_ptr = head_pcb_ptr = NULL;
current_jib_ptr = NULL;
	
#ifdef sun
/* Limit mu and kids to 90 minutes of cpu time */
limit_cpu_time(90 * SEC_PER_MIN); 
#endif /* sun */
 
init_signal_handlers(); 

if (!init_scheduler())
	exit(1);

if (parse_scheduler_args(argc,argv))
	{
	if (configure_scheduler_type())
		{
		dispatch_clients();
		schedule_clients();	
		}
	}
cleanup_scheduler();
return 0;
}
