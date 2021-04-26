/*****************************************************************************\
 * vm-provisioning-plugin-for-slurm
 * Copyright 2019-2021 VMware, Inc.

 * This product is licensed to you under the BSD-2 license (the "License"). 
 * You may not use this product except in compliance with the BSD-2 License.  

 * This product may include a number of subcomponents with separate copyright 
 * notices and license terms. Your use of these subcomponents is subject to 
 * the terms and conditions of the subcomponent's license, as noted in the LICENSE file. 
 *****************************************************************************
 *  hold_wrapper.c - Hold all newly arriving jobs if there is a file
 *  "/etc/slurm.hold", otherwise use Slurm's internal scheduler.
 *****************************************************************************
 *  Copyright (C) 2002 The Regents of the University of California.
 *  Produced at Lawrence Livermore National Laboratory (cf, DISCLAIMER).
 *  Written by Morris Jette <jette1@llnl.gov> et. al.
 *  CODE-OCEC-09-009. All rights reserved.
 *
 *  This file is part of Slurm, a resource management program.
 *  For details, see <https://slurm.schedmd.com/>.
 *  Please also read the included file: DISCLAIMER.
 *
 *  Slurm is free software; you can redistribute it and/or modify it under
 *  the terms of the GNU General Public License as published by the Free
 *  Software Foundation; either version 2 of the License, or (at your option)
 *  any later version.
 *
 *  In addition, as a special exception, the copyright holders give permission
 *  to link the code of portions of this program with the OpenSSL library under
 *  certain conditions as described in each individual source file, and
 *  distribute linked combinations including the two. You must obey the GNU
 *  General Public License in all respects for all of the code used other than
 *  OpenSSL. If you modify file(s) with this exception, you may extend this
 *  exception to your version of the file(s), but you are not obligated to do
 *  so. If you do not wish to do so, delete this exception statement from your
 *  version.  If you delete this exception statement from all source files in
 *  the program, then also delete it here.
 *
 *  Slurm is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 *  details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with Slurm; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA.
 \*****************************************************************************/

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include<time.h>
#include "slurm/slurm_errno.h"

#include "src/common/plugin.h"
#include "src/common/log.h"
#include "src/slurmctld/slurmctld.h"
#include "src/common/slurm_priority.h"

const char		plugin_name[]	= "Slurm Hold Scheduler plugin";
const char		plugin_type[]	= "sched/hold";
const uint32_t		plugin_version	= SLURM_VERSION_NUMBER;

int init(void)
{
	sched_verbose("Hold scheduler plugin loaded");
	return SLURM_SUCCESS;
}

void fini(void)
{
	/* Empty. */
}

int slurm_sched_p_reconfig(void)
{
	return SLURM_SUCCESS;
}

uint32_t slurm_sched_p_initial_priority(uint32_t last_prio,
		struct job_record *job_ptr)
{
	struct stat buf;
	//check if job already on hold then return
	if(job_ptr->priority == 0)
	{
		return priority_g_set(last_prio, job_ptr);
	}

	/* ***** open vmlock file, if successfull, obtain flock on the file
	 *  * add the job to queued job file
	 *   * unlock and return
	 *    * if flock not obtained on vmlock, obtain flock on pendinglock file
	 *     * add job to pending job file
	 *      * unlock and return.
	 *       */

	char *lock = "/var/spool/slurmctld/lock/vmlock";
	int fd = open( lock, O_RDWR|O_CREAT, 0666 );
	if(fd == -1)
	{
		fd = open( lock, O_RDWR|O_CREAT, 0666 );
		info("lock file not openeed %s fd %d",lock,fd);
		return 0;
		close(fd);
	}
	else
	{
		info("lock file openeed at first %s fd %d num_tasks %d",lock,fd, job_ptr->details->num_tasks);
		int ret=-1;
		ret = flock( fd, LOCK_EX|LOCK_NB);
		if (ret < 0){
			info("lock file was opened %s fd %d flock not available %d\n",lock,fd,ret);
			char *lock = "/var/spool/slurmctld/lock/pendinglock";
			int pd = open(lock,O_RDWR|O_CREAT, 0666);
			if(pd >=0)
			{
				info("pendinglockfile opened %s %d\n",job_ptr->comment,job_ptr->job_id);
				ret = flock(pd, LOCK_EX|LOCK_NB);
				if(ret >=0)
				{
					info("pending lock obtained %s %d\n",job_ptr->comment,job_ptr->job_id);
					FILE *f = fopen("/var/spool/slurmctld/pending_jobs", "a");
					if (f >=0)
					{
						fprintf(f,"%s %d\n",job_ptr->comment,job_ptr->job_id);
						info("pending job file updated %s %d\n",job_ptr->comment,job_ptr->job_id);
						fclose(f);
						ret = flock(pd, LOCK_UN);
					}
					else
					{
						info("unable to open pendinig job file\n");
						fclose(f);
					}
				}
				else
				{
					info("not able to lock pendinglock \n");
					close(pd); 
				}

			}
			else{
				info("not able to open pendinglock file\n");
			}
		}
		else
		{
			info("lock file was opened %s fd %d ********** flock available %d\n",lock,fd,ret);
			FILE *f= fopen("/var/spool/slurmctld/queued_jobs", "a");
                        char log_file[1000];
                        //snprintf(log_file,sizeof(log_file),"/var/spool/job_timelogs/%d",job_ptr->job_id);
			//FILE *f1= fopen(log_file, "a");
			struct timeval te; 
   			gettimeofday(&te, NULL); // get current time
    			long long milliseconds = te.tv_sec*1000LL + te.tv_usec/1000; 
			if (f >= 0)
			{
				fprintf(f,"%s %d\n",job_ptr->comment,job_ptr->job_id);
				info("queued job updated flock %d\n",ret); 
                                //fprintf(f1,"vhpcStart : %d",ret);
				ret =  flock(fd, LOCK_UN);
				fclose(f);
				//fclose(f1);
			}
			else
			{
				info("unable to open queued job file, fd %d",f);
				fclose(f);
			}
		}
	}
	close(fd);
	info("*********************finished SCHED launch***********************");
	if (stat("/etc/slurm.hold", &buf) == 0)
		return 0;	/* hold all new jobs */

	return priority_g_set(last_prio, job_ptr);
}
