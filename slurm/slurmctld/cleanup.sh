# vm-provisioning-plugin-for-slurm
# Copyright 2019-2021 VMware, Inc.
# SPDX-License-Identifier: BSD-2

# This product is licensed to you under the BSD-2 license (the "License").
# You may not use this product except in compliance with the BSD-2 License.

# This product may include a number of subcomponents with separate copyright
# notices and license terms. Your use of these subcomponents is subject to
# the terms and conditions of the subcomponent's license, as noted in the LICENSE file.

######## completion script for slave nodes######################################
# remove the node configuration from slurm_slaves.conf file
# mark the node state as down to prevent execution of further jobs.
# copy completed file to controller node. This is used by vhpcCleanup daemon to\
# enable deleteion of VM
# copy the slurmd daemon logs, and job output logs to controller and login node
################################################################################
scriptname=$(basename $0)

echo "*****in cleanup.sh*****"
source ~/.bashrc
export PATH=$PATH:/root/vhpc_cfg/bin/
export PYTHONPATH=$PYTHONPATH:/root/vhpc_cfg/
echo $(/root/vhpc_cfg/bin/vhpc_cfg view > cleanup.txt)
#/root/vhpc_cfg/bin/vhpc_cfg getip --vm master
vhpc="/root/vhpc_cfg/bin/vhpc_toolkit"
master=10.118.232.21
login=10.118.232.22
ssh-keyscan -H $master >> ~/.ssh/known_hosts
slave=$(hostname)
echo $(sed -i "/$slave/d" /etc/slurm/slurm_slaves.conf)

jobid=$1
jobname=$(cat /root/job_config | grep job_name | awk '{print $2}')
echo $jobid
echo $(sshpass -f /root/password.txt scp /root/completion root@$master:/var/spool/completed_jobs/$jobname)
echo $(sshpass -f /root/password.txt scp /root/completion root@$login:/var/spool/completed_jobs/$jobname)
echo $(sshpass -f /root/password.txt scp /var/log/slurmd.log root@$master:/var/spool/completed_slurmd_logs/$jobname)
echo $(sshpass -f /root/password.txt scp /var/log/slurmd.log root@$login:/var/spool/completed_slurmd_logs/$jobname)
echo $(sshpass -f /root/password.txt scp /root/slurm.s_$jobid.$jobid.err root@$master:/var/spool/completed_job_logs/$jobid.err)
echo $(sshpass -f /root/password.txt scp /root/slurm.s_$jobid.$jobid.err root@$login:/var/spool/completed_job_logs/$jobid.err)
echo $(sshpass -f /root/password.txt scp /root/slurm.s_$jobid.$jobid.out root@$master:/var/spool/completed_job_logs/$jobid.out)
echo $(sshpass -f /root/password.txt scp /root/slurm.s_$jobid.$jobid.out root@$login:/var/spool/completed_job_logs/$jobid.out)

scontrol update nodename=$slave State=DOWN Reason="$jobname completed"


