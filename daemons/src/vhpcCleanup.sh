# vm-provisioning-plugin-for-slurm
# Copyright 2019-2021 VMware, Inc.
# SPDX-License-Identifier: BSD-2

# This product is licensed to you under the BSD-2 license (the "License").
# You may not use this product except in compliance with the BSD-2 License.

# This product may include a number of subcomponents with separate copyright
# notices and license terms. Your use of these subcomponents is subject to
# the terms and conditions of the subcomponent's license, as noted in the LICENSE file.

#####LOGGING##########
LOG_LOCATION="/var/log"
exec >> $LOG_LOCATION/vhpcCompletion.log 2>&1


#####CLONE TYPE HAS TO BE SET BEFORE STARTING vhpcCompletion DAEMON ##########
clone="full"
################################

#set -x

################################################################################
# Every job creates a fil to indiacate job_completion.\
# The file name is the jobId.
# Look for files in job_completion folder
# Start the cleanup script for every job
# Delete the files.
# The loop is invoked for every t seconds which is passed as command line\
# arugment during startup
################################################################################
while true
do
    scriptname=$(basename $0)
    cd /var/spool/completed_jobs
    clusters=$(ls | wc -l)
    if [ $clusters -ge 1 ]
    then
        echo "cleaning up $clusters VMs"
        for entry in $(ls)
        do
           jobid=$(cat $entry | awk '{print $1}')
           echo "cleaning up VM $jobid"
          cd /var/spool/$entry
          sh cleanup.sh $clone
          cd /var/spool/completed_jobs
          rm -rf $entry
        done
        sleep $1
    else
        #echo "no new node created, sleeping $1 secs"
        sleep $1
    fi
done

