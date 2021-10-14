
# Dynamic VM orchestration for virtualized HPC frameworks
## Introduction
vm-provisioning-plugin-for-slurm (also called Multiverse) implements dynamic VM orchestration for virtualized HPC. In other words it a VM per job model which spawns individual VMs on demand for evey incoming job in a HPC SLURM cluster.


## **Preliminaries** 

### Requirements

1. Supported OS: 
   * Instruction are provided for **Centos-7**. Other linux operating systems are supported as well. But slurm installation would differ accordingly. 
2. vSphere **>=6.5**
3. Python version 3.6
4. Install `vhpc-toolkit` as per instructions from [vhpc-toolkit](https://github.com/vmware/vhpc-toolkit)
5. Download slurm. This framework is developed with Slurm 19.05. 
    * you can choose to download the full source of Slurm from [slurm](https://www.schedmd.com/downloads.php). Compile it from scratch and then install.   
    * Alternatively you can use our provided rpm files to directly install 
    slurm from install script. More details are provided in [slurm_install](slurm_install/)
6. Install the following packages
   * yum install bc sshpass -y
   
### Install and setup

1. Copy the `vhpc-toolkit` directory to `/home` in the controller node. 

2. Install Slurm in the controller and compute nodes. You can follow instructions from the article [how to install slurm on centos 7 cluster](https://www.slothparadise.com/how-to-install-slurm-on-centos-7-cluster/). 
Alternatively, you can use the installation script 
[install_slurm.sh](slurm_install/install_slurm.sh) or follow the [README.md](slurm_install/README.md) in the `slurm_install` folder. 

3. Setup slurmdbd by following instructions from [slurmdbd](https://wiki.fysik.dtu.dk/niflheim/Slurm_database)

4. Clone this repo into the controller node.

5. Copy the contents of [slurm](slurm/) folder to `/var/spool/` folder on the controller node.

6. Copy the contents of [admission\_control](admission_control/) to `/var/spool`

7. Change the ip address of master and ip in [slurm/slurmctld/cleanup.sh](slurm/slurmctld/cleanup.sh) file

8. You can manually do steps 9-11 or use [slurm/setup.sh](slurm/setup.sh) file. 

9. Create the following folders in `/var/spool` in controller node
    * completed\_jobs
    * completed\_job\_logs
    * job\_timelogs
    * completed\_slurmd\_logs
    * vm\_spawn\_logs
    * lock

10. Change the permissions of the two main locks in the lock folder
   * chmod 777 /var/spool/slurmcltd/lock/vmlock
   * chmod 777 /var/spool/slurmcltd/lock/pendinglock
   
11. Setup two system service daemons in controller node. Copy the following files from [daemon](daemons/) folder to `/etc/systemd/system`.
   * vhpcLaunch.service
   * vhpcCleanup.service
   * Copy the daemon source files from [src](daemons/src) folder to `/usr/bin` folder in the controller node 
   * Start the daemons using `systemctl restart vhpcLaunch` and `systemctl restart vhpcCleanup`
   
12. Copy the following files from [configuation](configuration/) folder to `/etc/slurm` in the controller node.
   * slurm.conf
   * slurm\_slaves.conf
   * plugstack.conf
   
13. Change the following parameters in `/etc/slurm/slurm.conf` file as per your 
cluster configuration
   * NodeName
   * NodeAddr
   * ClusterName
   * ControlAddr
   * Parition name and nodenames
   * AccoutingStorageType (slurmdbd if you start slurmdbd service)
   
14. Start the slurm controller daemon 
   * `systemctl restart slurmctld` for controller node
   * `systemctl restart slurmd` for slave/login node
   
15. Store the guest vm password in the file `/var/spool/password.txt` in controller node
 
### Prepare the VM template
A template VM needs to spawmned and ready in advance to use this framework. Follow the same installation instrutions as given in [install slurm](https://www.slothparadise.com/how-to-install-slurm-on-centos-7-cluster/) specific to slave nodes.
This VM will be used as template to clone all worker/slave slurm nodes. The framework supports all cloning types.
1. Instant clone:
   If using instant clone, configure the daemons in advance to use instant clone. Currently we support instant clone by having a template VM in frozen state on each host. This VM will be used as a template for cloning on a particular host.
   The template VM is named using the convention "<hostipaddress>.t". To follow instructions on how to setup a frozen VM for instant clone, refer [instant_clone](hhttps://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-F559CE9C-2D8F-4F69-A846-56A1F4FC8529.html)
2. Full and Linked clone, having a single template VM on any host is sufficient. 

## **Using The Framework**
### VM/Cluster configuration
Both clone and cluster command of vhpc\_toolkit can be used for cloning new VMs. The default option right now is cluster command. You can change the standard parameters like datacenter, cluster, resource\_pool etc in the [cluster\_config](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm/slurmctld/cluster_config) file which is used a template for every new VM configuration.
For instant clone or if you want to use staticIP, the network configuration parameters also need to be defined in the cluster_config template. 

### Prepare the slurm configuration template
[slurm.conf.template](slurm/slurm.conf.template) file is used as a template 
to generate a `slurm.conf` file on every worker node. You can modify the 
parameters in this file as per your requirements. All slave nodes information
 is maintained in slurm_slaves.conf which should be present in all Slurm nodes. 
This file is copied to every slave node during customization of the VM after cloning. 

### Admission Control and Load Balancing

1. In order to chose the right host for spawning VMs, we maintain all host specific information sunch as host\_name, max\_available\_cpu, max\_available\_memory,allocated\_cpu, allocated\_memory and num\_vms in a sqlite databse.
2. Refer to [admission_control](admission_control/) on how to use the 
different options in the API. The common functions such as initializing the hosts table, updating information about the cluster, querying the best available for host to clone VMs etc are available.
 
### Logging

The following information are logged by the different processes. All file names are same as jobid

1. Job completed logs are logged to `/var/spool/completed_job_logs`
2. slurmd daemon logs are logged to `/var/spool/completed_slurmd_logs`
3. The vm\_launch script logs for every new VM is logged to `/var/spool/vm_spawn_logs`
4. The timestamps for clone start and end are logged in `/var/spool/job_timelogs`
5. The system daemon logs can be checked at
   * tail /var/log/vhpc.log
   * tail /var/log/vhpcCleanup.log

## Need help?
This project is not maintained by any VMware employee. If you have questions, please contact the original developer Jashwant Raj <jashwant.raj92@gmail.com>.
