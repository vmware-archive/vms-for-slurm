# vm-provisioning-plugin-for-slurm
# Copyright 2019-2021 VMware, Inc.
# SPDX-License-Identifier: BSD-2

# This product is licensed to you under the BSD-2 license (the "License").
# You may not use this product except in compliance with the BSD-2 License.

# This product may include a number of subcomponents with separate copyright
# notices and license terms. Your use of these subcomponents is subject to
# the terms and conditions of the subcomponent's license, as noted in the LICENSE file.

LOG_LOCATION="/var/spool/vm_spawn_logs"
exec >> $LOG_LOCATION/$2.log 2>&1

set -x
echo "*****in pending launch cluster.sh*****"
#rm -rf slave_list
#echo "Acquiring up lock $$" >> output.txt
#exec 20>/var/spool/slurmctld/lock/iplock
#echo "doing flock for conf file" >> output.txt
#flock -x 20;

#flock -u 20
export PATH=$PATH:/home/vhpc_cfg/bin/
#export PYTHONPATH=$PYTHONPATH:/home/vhpc_cfg/
export PYTHONPATH=/home/vhpc_cfg/
vhpc="/home/vhpc_cfg/bin/vhpc_toolkit"
alias python=python3.6
ip_type="dynamic"
#####to check if lock is busy####
### currently unused function ####
#function busy {
#echo "lock busy"
#echo "$1 $2" >> pending_jobs
#exit 1
#}
#################################
jobname=$1
jobid=$2
clone=$3
################################
cd /var/spool/$jobname
cp /var/spool/job_completion.sh /var/spool/$jobname
cp /var/spool/cleanup.sh /var/spool/$jobname
rm -rf slave_list
lock=/var/spool/slurmctld/lock/$jobid
echo "Acquiring lock $$"
exec 8>$lock;
echo "doing flock by job $jobid"
flock --nb 8
echo "*********acquired lock by  $jobid"
####### JOB CONFIGURATION ############
CPU=$(cat job_config | grep ncpu | awk '{print $2}')
if [ -z "$CPU" ]
then
    CPU=1
fi
MEM=$(cat job_config | grep memory | awk '{print $2}')
if [ -z "$MEM" ]
then
    MEM=2
fi

mem=$(echo $MEM | awk '{print $MEM/1024 + 1}')
echo "cpu is $CPU mem is $MEM $mem" >> output.txt
nodes=$(cat job_config | grep min_nodes | awk '{print $2}')
jobname=$(cat job_config | grep job_name | awk '{print $2}')
tasks=$(cat job_config | grep num_tasks | awk '{print $2}')
min_cpu=$CPU
CPU=$((CPU*tasks*nodes))
job=$(echo $jobname | awk -F - '{print $1}')
cp /var/spool/password.txt .
cp /var/spool/slurmctld/vm_config .
#cp job_config $jobname
#cp job_script $jobname
echo "setting up a virtual cluster for job $jobname with CPU $CPU and memory $mem with $nodes nodes" >> output.txt
#echo " flock successfull, clonig VM s_$jobid" >> output.txt
######### VIRTUAL CLUSTER CONFIGURATION for clone command###########
###uncomment to use clone command by reading config from vm_config file#####
#datastore=$(cat vm_config | grep datastore | awk -F : '{print $2}')
#cluster=$(cat vm_config | grep cluster | awk -F : '{print $2}')
#template=$(cat vm_config | grep template | awk -F : '{print $2}')
#resource_pool=$(cat vm_config | grep resource_pool | awk -F : '{print $2}')
#port_group=$(cat vm_config | grep port_group | awk -F : '{print $2}')
#dns=$(cat vm_config | grep dns | awk -F : '{print $2}')
#gateway=$(cat vm_config | grep gateway | awk -F : '{print $2}')
#netmask=$(cat vm_config | grep netmask | awk -F : '{print $2}')
#domain=$(cat vm_config | grep domain | awk -F : '{print $2}')
#guest_hostname=$(cat vm_config | grep guest_hostname | awk -F : '{print $2}')
#ip=$(cat vm_config | grep ip | awk -F : '{print $2}')
#####################################################
cp /var/spool/slurmctld/cluster_config cluster.conf
master_ip=10.118.232.21
login=10.118.232.22
#cpu=$((CPU * 1000))
#python /var/spool/adm_ctrl.py initdb
python /var/spool/adm_ctrl.py list
python /var/spool/adm_ctrl.py list >> output.txt
echo "$CPU $MEM"
Lock="admCtrlLock";
echo "Acquiring slurmconfig lock $$" >> output.txt
exec 10>/var/spool/slurmctld/lock/$Lock;
echo "doing flock for conf file" >> output.txt
flock -x 10
host=$(python /var/spool/adm_ctrl.py get_compatible_host $((CPU*nodes)) $((MEM*nodes))  | grep host | cut -d: -f 2)
echo $host
if echo $host | grep "no"
then
echo "all compatible host are busy"
echo "writing 1 to $lock" >> output.txt
echo "1" > $lock
exit 1
elif echo $host | grep "invalid"
then
echo "no compatible host in cluster"
echo "writing 3 to $lock" >> output.txt
echo "3" > $lock
exit 1
else
echo $(python /var/spool/adm_ctrl.py add_vm $host $CPU $(echo $mem*1024 | bc) $nodes)
fi
source ~/.bashrc
ipstart=`expr $NODEID + 1`
sed -i '/NODEID/d' ~/.bashrc
echo "export NODEID=$ipstart" >> ~/.bashrc

flock -u 10

export PYTHONPATH=/home/vhpc_cfg/
######SETUP CLUSTER CONF FILE######
#####comment if using clone command#########
if [ "$clone" == "instant" ]
then
if [ "$ip_type" == "dynamic" ]
then
sed -i 's/is_dhcp: false/is_dhcp: true/g' cluster.conf
fi
echo "template: $host.t" >> cluster.conf
echo "instant: 1" >> cluster.conf
else
if [ "$clone" == "linked" ]
then
echo "linked: 1" >> cluster.conf
fi
echo "template: small-template" >> cluster.conf
echo "cpu: $CPU" >> cluster.conf
echo "memory: $mem" >> cluster.conf
fi
echo "[HOST-LIST]" >> cluster.conf
echo "hostname $host ****" >> output.txt
echo "host: $host" >> cluster.conf

echo "[_VMS_]" >> cluster.conf
#echo -e "C_$jobid: BASE HOST-LIST" >> cluster.conf
###check clone type or if static ip has to be used.
#use NETWORK with staic ipaddress in that case

if [ "$clone" == "instant" ]
then
if [ "$ip_type" == "static" ]
then
echo -e "s_$jobid.{1:$nodes}: SLAVE HOST-LIST NETWORK ip:10.118.232.$ipstart" >> cluster.conf
else
echo -e "s_$jobid.{1:$nodes}: SLAVE HOST-LIST NETWORK" >> cluster.conf
fi
else
if [ "$ip_type" == "static" ]
then
echo -e "s_$jobid.{1:$nodes}: SLAVE HOST-LIST NETWORK ip:10.118.232.$ipstart" >> cluster.conf
else
echo -e "s_$jobid.{1:$nodes}: SLAVE HOST-LIST" >> cluster.conf
fi
fi
#uncomment for cloning a using cluster command
clonestart=$(date +%s)
echo "clonestart: $clonestart" >> /var/spool/job_timelogs/$jobid
echo $($vhpc cluster --create --file cluster.conf)

find=$($vhpc view | grep s_$jobid)
if [ -z "$find" ]
then
echo "Clone failure. check vhpc_toolkit logs"
echo "2" > $lock
exit 2
fi
cloneend=$(date +%s)
echo "cloneEnd: $cloneend" >> /var/spool/job_timelogs/$jobid

export PYTHONPATH=/home/vhpc_cfg/


############################################################################################################
######## CLONE VMS from configutation #######
#controller VM
#1 clone
#2 power-on and get ip
#3 setup keyless ssh
#4 change hostname
#5 copy needed files for controller and slave slurm setup.
echo "cloning $nodes Slave VMs" >> output.txt
for i in $(seq 1 $nodes)
do

#uncomment if using clone command#########
:'clone_command=""
if [ ! -z "$template" ]
then
clone_command="$clone_command --$template"
elif [ "$clone" == "instant" ]
then
clone_command="$clone_command --$host.t"
fi
if [ ! -z "$datatore" ]
then
clone_command="$clone_command --$datastore"
fi
if [ ! -z "$cluster" ]
then
clone_command="$clone_command --$cluster"
fi
if [ ! -z "$resource_pool" ]
then
clone_command="$clone_command --$resource_pool"
fi
if [ ! -z "$host" ]
then
clone_command="$clone_command --$host"
fi
if [ ! -z "$port_group" ]
then
clone_command="$clone_command --$port_group"
fi
if [ ! -z "$gateway" ]
then
clone_command="$clone_command --$gateway"
fi
if [ ! -z "$netmask" ]
then
clone_command="$clone_command --$netmask"
fi
if [ ! -z "$dns" ]
then
clone_command="$clone_command --$dns"
fi
if [ ! -z "$domain" ]
then
clone_command="$clone_command --$domain"
fi
if [ ! -z "$ip" ]
then
clone_command="$clone_command --$ip"
fi
if [ "$clone" == "instant"]
then
echo $(/home/instant/vhpc_cfg/bin/vhpc_toolkit instant_clone $clone_command)
else
echo $($vhpc clone $clone_command)
fi '
echo $($vhpc power --on --vm s_$jobid.$i)
echo "copying slave $jobid.$i to slave_list" >> output.txt
echo "s_$jobid.$i" >> slave_list
slave_ip=$($vhpc getip --vm s_$jobid.$i | grep ip: | sed -En "s/ip: //;s/.*?(([0-9]*\.){3}[0-9]*).*/\0/p")
regexp="([0-9]{1,3}\.)+([0-9]{1,3})"
match=$([[ $slave_ip =~ $regexp ]] && echo match)
if [ -z "$match" ]
then
    echo "4" > $lock
    exit 4
fi
if [ "$clone" == "instant" ]
then
#host_ip=$($vhpc getip --vm $host.t | grep ip: | sed -En "s/ip: //;s/.*?(([0-9]*\.){3}[0-9]*).*/\0/p")
host_ip=$(cat /var/spool/slurmctld/host_ips | grep $host.t | awk -F : '{print $2}')
while [ "$slave_ip" == "$host_ip" ]
do
sleep 2
slave_ip=$($vhpc getip --vm s_$jobid.$i | grep ip: | sed -En "s/ip: //;s/.*?(([0-9]*\.){3}[0-9]*).*/\0/p")
done
fi
echo "the new slave s_$jobid.$i ip is $slave_ip" >> output.txt
########configure the new VM#####
#i=$((i+1))
done
############################################################################################################
##setup slurm configuration file
#sed -i '/ClusterName/d' /var/spool/slurm.conf
#sed -i '/ControlMachine/d' /var/spool/slurm.conf
#sed -i '/ControlAddr/d' /var/spool/slurm.conf
######### slurm config file update ##################
LOCK="configlock";
echo "Acquiring slurmconfig lock $$" >> output.txt
exec 200>/var/spool/slurmctld/lock/$LOCK;
echo "doing flock for conf f le" >> output.txt
flock -x 200
#
#####add slave node name and ip to conf file
while read slave
do
echo "updating slurm conf file" >> output.txt
slave_ip=$($vhpc getip --vm $slave | grep 'ip:' | sed -En "s/ip: //;s/.*?(([0-9]*\.){3}[0-9]*).*/\0/p")
echo $(ssh-keyscan -H $slave_ip >> ~/.ssh/known_hosts)
echo $(ssh-keyscan -H $slave_ip >> ssh_log)
password=$(cat password.txt)
echo $(sshpass -f password.txt ssh root@$slave_ip "ip addr" >> ssh_log)
echo $(sshpass -f password.txt ssh root@$slave_ip "echo $slave > /etc/hostname")
echo $(sshpass -f password.txt ssh root@$slave_ip "echo $slave_ip $slave >> /etc/hosts")
echo $(sshpass -f password.txt ssh root@$slave_ip "systemctl restart network")
echo $(sshpass -f password.txt ssh root@$slave_ip "hostnamectl >> ssh_log")

echo "NodeName=$slave NodeAddr=$slave_ip CPUs=$min_cpu RealMemory=$MEM Features=$jobid State=UNKNOWN" >> /etc/slurm/slurm_slaves.conf
done < slave_list
echo $(sshpass -f password.txt scp /etc/slurm/slurm_slaves.conf root@$login:/etc/slurm/)
#echo $(sshpass -f password.txt ssh root@$login 'systemctl restart slurmd')
####### copy conf file to all slave nodes
echo "updating all slave nodes" >> output.txt
flock -u 200
while read slave
do
slave_ip=$($vhpc getip --vm $slave | grep ip: | sed -En "s/ip: //;s/.*?(([0-9]*\.){3}[0-9]*).*/\0/p")
echo $(sshpass -f password.txt scp /etc/slurm/slurm.conf root@$slave_ip:/etc/slurm/)
echo $(sshpass -f password.txt scp /var/spool/vhpc.so root@$slave_ip:/usr/lib64/slurm)
echo $(sshpass -f password.txt scp /home/vhpc_cfg/vcenter.conf root@$slave_ip:/root/vhpc_cfg/config/)
echo $(sshpass -f password.txt scp /home/vhpc_cfg/vcenter.conf root@$slave_ip:/root/vhpc_cfg/)
echo $(sshpass -f password.txt scp password.txt root@$slave_ip:/root)
echo $(sshpass -f password.txt scp /etc/munge/munge.key root@$slave_ip:/etc/munge/)
echo $(sshpass -f password.txt scp /etc/slurm/slurm_slaves.conf root@$slave_ip:/etc/slurm/)
echo $(sshpass -f password.txt scp /var/spool/slurmctld/cleanup.sh root@$slave_ip:.)
echo $(sshpass -f password.txt scp /var/spool/$jobname/job_config root@$slave_ip:.)
echo $(sshpass -f password.txt scp /var/spool/slurmctld/slave_setup.sh root@$slave_ip:.)
echo $(sshpass -f password.txt scp /var/spool/$jobname/slave_list root@$slave_ip:.)
echo $($vhpc post --vm $slave --guest_password $password --script /var/spool/slurmctld/slave_setup.sh)
sleep 5
#echo $(sshpass -p "ca\$hc0w" ssh root@$slave_ip 'sh /root/slave_setup.sh')
done < slave_list
echo "all slave nodes updated with new slurm.conf" >> output.txt

#slaveip=$(grep "$slave" /etc/slurm/slurm.conf | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])')
###### copy conf and slave setup file to controller
echo "starting slurm on the new virtual cluster" >> output.txt
echo "completed virtual cluster setup Cluster name $jobname" >> output.txt
#echo $(echo "ca\$hc0w" | sudo -S systemctl restart slurmctld) >> output.txt
echo "writing 0 to $lock" >> output.txt
echo "0" > $lock
customEnd=$(date +%s)
echo "customEnd: $customEnd" >> /var/spool/job_timelogs/$jobid

flock -u 8
