# vm-provisioning-plugin-for-slurm
# Copyright 2019-2021 VMware, Inc.

# This product is licensed to you under the BSD-2 license (the "License"). 
# You may not use this product except in compliance with the BSD-2 License.  

# This product may include a number of subcomponents with separate copyright 
# notices and license terms. Your use of these subcomponents is subject to 
# the terms and conditions of the subcomponent's license, as noted in the LICENSE file.

#####LOGGING##########
LOG_LOCATION="/var/log"
exec >> $LOG_LOCATION/vhpc.log 2>&1


##### SET PATH for vhpc_toolkit to work #######
export PATH=$PATH:/home/vhpc_cfg/bin/
export PYTHONPATH=$PYTHONPATH:/home/vhpc_cfg/
#/home/vhpc_cfg/bin/vhpc_cfg getip --vm master
vhpc="/home/vhpc_cfg/bin/vhpc_cfg"

####cluster name and clone typepredefined before starting the daemon. clone types supported are "instant linked and full"######
cluster="vSAN"
clone="full"

######rate limit is set prior to start of the monitoring process #######
start_time=$(date +%s)
rate_limiter=0
if [ "$clone" == "instant" ]
then
limit=200
else
limit=10
fi

####function to check if wait if lock is busy
function busy {
	echo "pending job busy so sleeping $1"
		sleep $1
		continue
}
######## if all hosts are busy and cannot accomoate a new VM, then requeue the job ########
function nohost {
	$jobid=$2
		$jobname = $1 
		echo $(sed -i "/$jobname/d" /var/spool/slurmctld/spawning_jobs)
		echo "deleted spawning jobs and unlocking"
		echo "no hosts available. requeue the job"
		echo "$jobname $jobid" >> /var/spool/slurmctld/queued_jobs
}
######3 if there is a clone failure due to some reason, again reque the job #######
function clone_fail {
        jobname=$1
		jobid=$2
	    echo $(sed -i "/$jobid/d" /var/spool/slurmctld/spawning_jobs)
		echo "deleted spawning jobs and unlocking"
		echo "clone error, requening the job"
		echo $(sed -i "/$jobname/d" /var/spool/slurmctld/spawning_jobs)
		echo "$jobname $jobid" >> /var/spool/slurmctld/queued_jobs
}
###### if the clone and customization of new VM is successfull, then attach the new VM to slurmctld. change the job features to schedule to the new node, release the job from hold ###########
function run_job {
	    jobname=$1
		jobid=$2
		#echo "VMfile contents"
		#cat $lock
		#echo $jobname,$jobid
		#echo "******* acquired flock by job $jobid"
		echo "update job $jobid information to new features ******"
		scontrol update jobid=$jobid features=$jobid
		scontrol release $jobid
		echo "$jobid $jobname" >> /var/spool/slurmctld/running_jobs
		echo $(sed -i "/$jobid/d" /var/spool/slurmctld/spawned_jobs)
		echo "deleted spawned jobs and unlocking for job $jobid"
		#echo " unlock VM $jobid********"
		vhpcend=$(date +%s)
		echo "vhpcEnd: $vhpcend" >> /var/spool/job_timelogs/$jobid

}
function incompatible_job {
	jobid=$1
		echo $(sed -i "/$jobid/d" /var/spool/slurmctld/spawning_jobs)
		echo "no compatible host in the cluster to run job"
		scancel $jobid

}

##temporary function used in case dhcp fails. destroy the node and cancel the job #####
function ip_fix {
jobid=$1
jobname=$2
echo "DHCP problem. need to destroy VM and respawn"
cd /var/spool/$jobname
sh cleanup.sh $clone
cd -
scancel $jobid
echo $(sed -i "/$jobid/d" /var/spool/slurmctld/spawning_jobs)
#echo "respawning VM"
#sh /var/spool/slurmctld/pending_slave_vm_launch.sh $jobname $jobid $clone &
}

#### for all jobs if VM is spawned and ready, changed job state from spawning to spawned###
function addSpawned {
jobid=$1
jobname=$2
echo "****** job $jobid VM spawning complete*****"
echo $(sed -i "/$jobid/d" /var/spool/slurmctld/spawning_jobs)
echo "$jobname $jobid" >> /var/spool/slurmctld/spawned_jobs
}

echo "initializng host database"
#python /var/spool/adm_ctrl.py delete
#python /var/spool/adm_ctrl.py initdb /var/spool/host_list
python /var/spool/adm_ctrl.py initdb
python /var/spool/adm_ctrl.py list
while true
do
    current_time=$(date +%s)
    interval=$((current_time - start_time))
    if [ $interval -ge 60 ]
    then
        start_time=$current_time
        rate_limiter=0
    fi
    #echo "******$current_time $start_time $interval $rate_limiter*****"
    lock="/var/spool/slurmctld/lock/vmlock"
    #echo "Acquiring main VM lock $$"
    exec 200>$lock;
    #echo "doing flock"
    flock --nb 200 || busy $1 
    #echo "looking up spawning VMs"

####################### For all cloned/spawned VMs, restart the controller and call function to run job  #########
    jobs=$(cat /var/spool/slurmctld/spawned_jobs | wc -l)
    #echo $slaves >> output.txt
	if [ $jobs -ge 1 ] 
	then
	echo "/////// restarting controller for all jobs $jobs /////////"
	systemctl restart slurmctld
	sleep 5
	while read job
	do
		jobname=$(echo $job | awk '{print $1}')
		jobid=$(echo $job | awk '{print $2}')
		run_job $jobname $jobid
	done < /var/spool/slurmctld/spawned_jobs
    fi

####################### 
# Looking up if VM spawning is complete for all new VMS in progress  
# 1 indicated no currently available host
# 2 indicates if clone failed for some unknown reason
# 3 indicated if job requirements can never be satisifed by any host
# 4 indiciates if there is a DHCP problem
# 0 indicates clone and customization is successfull.
########################
    jobs=$(cat /var/spool/slurmctld/spawning_jobs | wc -l)
    #echo $slaves >> output.txt
	if [ $jobs -ge 1 ] 
	then
	
	while read job
	do
	jobname=$(echo $job | awk '{print $1}')
	jobid=$(echo $job | awk '{print $2}')
    #echo "**********SPAWNING acquiring VM file lock:"
	lock=/var/spool/slurmctld/lock/$jobid
    isEmpty=$(cat $lock)
	if [ -z "$isEmpty" ]  
	then
	    continue
	elif [ $isEmpty -eq 1 ]
	then
	    nohost $jobid
	elif [ $isEmpty -eq 2 ]
	then
	    clone_fail $jobid
	elif [ $isEmpty -eq 3 ]
	then
	    incompatible_job $jobid
	elif [ $isEmpty -eq 4 ]
	then
	    ip_fix $jobid $jobname
	elif [ $isEmpty -eq 0 ]
	then
	    addSpawned $jobid $jobname 
	#run_job $jobname $jobid
	else
	    echo "unknown error. cannot spawn VM for job"
	fi
	done < /var/spool/slurmctld/spawning_jobs
	fi

####################### 
#jobids are added to queued_jobs by using sched plugin 
#looks up all jobs in queued_jobs and initiates VM launch script
########################

#echo "looking up queued VMs"
jobs=$(cat /var/spool/slurmctld/queued_jobs | wc -l)
#echo $slaves >> output.txt
	if [ $jobs -ge 1 ] 
	then
	while read job
	do
	jobname=$(echo $job | awk '{print $1}')
	echo $jobname
	jobid=$(echo $job | awk '{print $2}')
	echo $jobid
	echo "adding VM to spawn"
        vhpcstart=$(date +%s)
	#echo "vhpcStart: $vhpcstart" >> /var/spool/job_timelogs/$jobid
	if [ $rate_limiter -le $limit ]
        then
	echo "$jobname $jobid" >> /var/spool/slurmctld/spawning_jobs
	echo $(sed -i "/$jobid/d" /var/spool/slurmctld/queued_jobs)
	sh /var/spool/slurmctld/pending_slave_vm_launch.sh $jobname $jobid $clone &
        rate_limiter=$((rate_limiter + 1))
	else
	    echo "rate limit exceeded"
        fi
	done < /var/spool/slurmctld/queued_jobs
	fi
   flock -u 200
   sleep $1


#######################
#If lock was busy in sched plugin,then jobs are added to pending_job file #########
#looks up all jobs in queued_jobs and initiates VM launch script
#########################
    #echo "looking up pending VMs"
    lock="/var/spool/slurmctld/lock/pendinglock"
    #echo "Acquiring pending VM lock $$"
    exec 8>$lock;
    #echo "doing flock"
    flock --nb 8 || busy $1
	#echo "acquired pending lock"
    jobs=$(cat /var/spool/slurmctld/pending_jobs | wc -l)
    #echo $slaves >> output.txt
	if [ $jobs -ge 1 ] 
	then
	while read job
	do
	   jobname=$(echo $job | awk '{print $1}')
	   echo $jobname
	   jobid=$(echo $job | awk '{print $2}')
	   echo $jobid
	   echo "adding pending VM to spawn"
	   #date +%s > jobs_completion/$jobid
   	    if [ $rate_limiter -le $limit ]
        then
	        echo "$jobname $jobid" >> /var/spool/slurmctld/spawning_jobs
	        echo $(sed -i "/$jobid/d" /var/spool/slurmctld/pending_jobs)
    	    sh /var/spool/slurmctld/pending_slave_vm_launch.sh $jobname $jobid $clone &
            rate_limiter=$((rate_limiter + 1))
	    else
           echo "rate limit exceeded"
	    fi
	done < /var/spool/slurmctld/pending_jobs
	fi
	#echo "unlocking pending"
	flock -u 8
    sleep $1
	done

