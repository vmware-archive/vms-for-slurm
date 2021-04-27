# vm-provisioning-plugin-for-slurm
# Copyright 2019-2021 VMware, Inc.
# SPDX-License-Identifier: BSD-2

# This product is licensed to you under the BSD-2 license (the "License").
# You may not use this product except in compliance with the BSD-2 License.

# This product may include a number of subcomponents with separate copyright
# notices and license terms. Your use of these subcomponents is subject to
# the terms and conditions of the subcomponent's license, as noted in the LICENSE file.


################################################################################
# setup slurmd daemon for slave nodes.
# copy munge authentication keys and restart the the slurmd daemon
# setup folder permissions for /var/spool folder
################################################################################


set -x
chown munge: /etc/munge/munge.key
chown -R munge: /etc/munge/ /var/log/munge/
chmod 400 /etc/munge/munge.key
systemctl restart munge
master=10.118.232.21
echo $(ssh-keyscan -H $master >> ~/.ssh/known_hosts)
echo $(sshpass -p "ca\$hc0w" ssh-copy-id root@$master)
echo $(munge -n | ssh root@$master unmunge > slave_log)
cat /etc/hostname >> slave_log
mkdir /var/spool/slurmd
chown slurm: /var/spool/slurmd
chmod 755 /var/spool/slurmd
touch /var/log/slurmd.log
chown slurm: /var/log/slurmd.log
slurmd -C >> slave_log
systemctl restart slurmd
tail /var/log/slurmd.log >> slave_log
systemctl restart slurmd
echo $(sshpass -p "ca\$hc0w" scp slave_log root@$master:/var/spool)
