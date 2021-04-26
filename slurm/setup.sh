# vm-provisioning-plugin-for-slurm
# Copyright 2019-2021 VMware, Inc.

# This product is licensed to you under the BSD-2 license (the "License"). 
# You may not use this product except in compliance with the BSD-2 License.  

# This product may include a number of subcomponents with separate copyright 
# notices and license terms. Your use of these subcomponents is subject to 
# the terms and conditions of the subcomponent's license, as noted in the LICENSE file.

cp -r * /var/spool
cp * /var/spool
cp ../admission_control /var/spool
cp ../daemons /etc/systemd/system
cp ../daemons/src /usr/bin
mkdir /var/spool/completed_jobs
mkdir /var/spool/completed_job_logs
mkdir /var/spool/completed_slurmd_logs
mkdir /var/spool/job_timelogs
mkdir /var/spool/vm_spawn_logs
chmod 777 /var/spool/slurmctld/lock/vmlock
chmod 777 /var/spool/slurmctld/lock/pendinglock
systemctl restart vhpcLaunch
systemctl restart vhpcCleanup

