/*****************************************************************************\
 * vm-provisioning-plugin-for-slurm
 * Copyright 2019-2021 VMware, Inc.
 * SPDX-License-Identifier: BSD-2

 * This product is licensed to you under the BSD-2 license (the "License"). 
 * You may not use this product except in compliance with the BSD-2 License.  

 * This product may include a number of subcomponents with separate copyright 
 * notices and license terms. Your use of these subcomponents is subject to 
 * the terms and conditions of the subcomponent's license, as noted in the LICENSE file. 
 *****************************************************************************
\*****************************************************************************/
#include <sys/types.h>
 
#include <stdio.h>
 
#include <stdlib.h>
 
#include <unistd.h>
 
#include <string.h>
 
#include <sys/resource.h>
 
 
 
 
#include <slurm/spank.h>
 
 
 
 
/*
 
 * All spank plugins must define this macro for the
 
 * Slurm plugin loader.
 
 */
 
SPANK_PLUGIN(vhpc, 1);
 
 
 
 
#define PRIO_ENV_VAR "SLURM_RENICE"
 
#define PRIO_NOT_SET 42
 
 
 
 
/*
 
 * Minimum allowable value for priority. May be
 
 * set globally via plugin option min_prio=<prio>
 
 */
 
static int min_prio = -20;
 
 
 
 
static int prio = PRIO_NOT_SET;
 
 
 
 
static int _vhpc_opt_process (int val,
 
                                const char *optarg,
 
                                int remote);
 
static int _str2prio (const char *str, int *p2int);
 
 
 
 
/*
 
 *  provide a vhpc run to srun
 
 */
 
struct spank_option spank_options[] =
 
{
 
    { "vhpc", "[enable]",
 
      "enable vhpc to jobs [enable].", 0, 1,
 
      (spank_opt_cb_f) _vhpc_opt_process
 
    },
 
    SPANK_OPTIONS_TABLE_END
 
};
 
/*
 
 *  Called from both srun and slurmd.
 
 */
 
int slurm_spank_job_epilog(spank_t sp, int ac, char **av)
{
   	int jobid;
        spank_get_item (sp, S_JOB_ID, &jobid); 

	slurm_info("job epilog job completed*********");
	if (spank_context() !=S_CTX_JOB_SCRIPT )
        {
	printf("other conntext not job epilog");
	slurm_info("other conntext not job epilog");
		return 0;
	}
 
        char buf[1024];
	snprintf(buf,sizeof(buf),"echo %d > /root/completion",jobid);
	int error = system(buf);
        slurm_info("system completed %d",error);
        printf("job epilog job completed %d",jobid);
        slurm_info("job epilog job completed %d",jobid);
	snprintf(buf,sizeof(buf),"sh /root/cleanup.sh %d",jobid);
        error = system(buf);
        slurm_info("system completed %d",error);

}

int slurm_spank_init (spank_t sp, int ac, char **av)
 
{
 
    int i;
 
 
 
 
    /* Don't do anything in sbatch/salloc */
 
    if (spank_context () == S_CTX_ALLOCATOR)
 
        return (0);
 
 
 
 
    for (i = 0; i < ac; i++) {
 
        if (atoi(av[i]) == 0 || atoi(av[i])==1 ) {
 
        const char* optarg = av[i];
 
            printf("*******vhpc av1 is ***** %s command",av[i],ac);
 
        if (spank_setenv(sp,"PYTHONPATH","/root/vhpc_cfg/",1) < 0 )
 
        slurm_error("failed to set environment");
 
         
 
        char *command = "/root/vhpc_cfg/bin/vhpc_cfg view > output.txt";
 
        system("export PYTHONPATH=/root/vhpc_cfg/:$PYTHONPATH");
 
        system(command);
 
//      exit(0);
 
      //system("/root/vhpc_cfg/bin/vhpc_cfg view");
 
         
 
        }
 
        else {
 
            slurm_error ("vhpc: Invalid option: %s", av[i]);
 
        }
 
    }
 
 
 
 
    if (!spank_remote (sp))
 
        slurm_verbose ("vhpc: enable = %d",0);
 
 
 
 
    return (0);
 
}
 
static int _vhpc_opt_process (int val,
 
                                const char *optarg,
 
                                int remote)
 
{
 
    if (optarg == NULL) {
 
        slurm_error ("vhpc: invalid argument!");
 
        return (-1);
 
    }
 
 
 
 
    if ((int)atoi(optarg) <= 0) {
 
        slurm_error ("Bad value for --vhpc: %s",
 
                     optarg);
 
        return (-1);
 
    }
 
 
 
 
    return (0);
 
}
