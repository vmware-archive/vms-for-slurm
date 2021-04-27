-- vm-provisioning-plugin-for-slurm
-- Copyright 2019-2021 VMware, Inc.
-- SPDX-License-Identifier: BSD-2
--
-- This product is licensed to you under the BSD-2 license (the "License"). 
-- You may not use this product except in compliance with the BSD-2 License.  
--
-- This product may include a number of subcomponents with separate copyright 
-- notices and license terms. Your use of these subcomponents is subject to 
-- the terms and conditions of the subcomponent's license, as noted in the LICENSE file.

--job_submit plguin used to create a unique name for each job by using job_name and current time stamp.
-- Create a folder in /var/spool using the unique jobname.
--Captures job configuration and save it to job_config file in the unique folder.
function slurm_job_submit(job_desc, part_list, submit_uid)
	if job_desc.account == nil then
		local account = "***TEST_ACCOUNT***"
		slurm.log_info("slurm_job_submit: job from uid %u, setting default account value: %s",
				submit_uid, account)
		job_desc.account = account
		--job_desc.clusters="all"
		local submit_time = tostring(os.time())
        	if job_desc.name == nil then
			job_desc.name="noname"		
		end
		----------------------
		-- set defaullt values for cpu and memory if not specificed in sbatch script
		----------------------
		if job_desc.pn_min_memory == nil then
			job_desc.pn_min_memory=4	
		end
		if job_desc.min_cpus == nil then
			job_desc.min_cpus = 2
			
		end
 		if job_desc.ncpus_per_task == nil then
			job_desc.cpus_per_task = job_desc.min_cpus
		end
		if job_desc.min_nodes>=100000 then
            slurm.log_info("setting min nodes")
            job_desc.min_nodes=1
        end
		if job_desc.num_tasks >= 4294967294 then
			job_desc.num_tasks=1
		end
		local job_name = job_desc.name:gsub("%s+", "")
        	local job_name =  job_name .. "-" ..submit_time 
		job_desc.comment = job_name
		slurm.log_info("slurm job arguments: %d user_id %s min_cpus %d mem_per_cpu %d job_name %s submit time %s",job_desc.argc,job_desc.user_id,job_desc.min_cpus,job_desc.pn_min_memory, job_desc.name, job_desc.comment);		
	
		local params =
		{
		  "mkdir /var/spool/",
		  job_name
		}
		local command = table.concat(params, " ")
		local handle = os.execute(table.concat(params, " "))
		slurm.log_info("os execute %s",command)

		local params =
		{
		  "echo \"ncpus: ",
                  job_desc.cpus_per_task,
                  "\nmemory: ",
                  job_desc.pn_min_memory,
                  "\nuserid: ",
                  job_desc.user_id,
                  "\njob_name: ",
                  job_name,
                  "\nmin_nodes: ",
                  job_desc.min_nodes,
	          "\nnum_tasks: ",
	          job_desc.num_tasks,
		  "\" >/var/spool/",
                  job_name,
                  "/job_config"
		}	
		local command = table.concat(params, "")
		local handle = os.execute(table.concat(params, ""))
		slurm.log_info("os execute %s",command)
	        local params =
		{
		 "echo \"",
		 job_desc.script,
		 "\" > /var/spool/",
		job_name,
		"/job_script"
		}
		local handle = os.execute(table.concat(params,""))
		slurm.log_info("os execute %s",table.concat(params, ""))
		
		---------- dummy command to ensure the plugin works are expected -----------
		local handle1 = os.execute('ls -l > list')
		slurm.log_info("os execute script %s",handle1);
	end

	return slurm.SUCCESS
end
    function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)

        --can be modified if required

         return slurm.SUCCESS
end
slurm.log_info("initialized")
return slurm.SUCCESS
