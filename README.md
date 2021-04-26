
# Dynamic VM orchestration for virtualized HPC frameworks
## Introduction
vm-provisioning-plugin-for-slurm (also called Multiverse) implements dynamic VM orchestration for virtualized HPC. In other words it a VM per job model which spawns individual VMs on demand for evey incoming job in a HPC SLURM cluster.


## **Preliminaries** 

### Requirements

1. Supported OS: 
   * Instruction are provided for **Centos-7**. Other linux operating systems are supported as well. But slurm installation would differ accordingly. 
2. vSphere **>=6.5**
3. Python version 3.6
2. Install vHPC\_toolkit as per instructions from [vhpc\_toolkit](https://github.com/vmware/vhpc-toolkit)
2. Download slurm  [slurm](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm_source). This framework is developed with Slurm 19.05. 
    * you can choose to download the full source of Slurm from [slurm](https://www.schedmd.com/downloads.php). Compile it from scratch and then install.   
    * Alternatively you can use our provided rpm files to directly install slurm from install script. More details are provided in [slurm_install](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm_install/)
1. Install the following packages
   * yum install bc sshpass -y
### Install and setup

1. Copy the vhpc_toolkit installation directory to /home in controller node. 
2. Install Slurm in the master and remote nodes. You can follow instructions from [install slurm](https://www.slothparadise.com/how-to-install-slurm-on-centos-7-cluster/) or use the installation script available in the repository [install_slurm.sh](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm_install/install_slurm.sh). Alternatively you can install from [slurm_install](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm_install/)
2. Setup slurmdbd by follwing instructions from [slurmdbd](https://wiki.fysik.dtu.dk/niflheim/Slurm_database)
3. Clone this repo into the new node.
4. Copy the contents of [slurm](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm) folder to /var/spool/ folder on the controller node.
4. Copy the contents of [admission\_control](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/admission_control) to /var/spool
5. Change the ipaddress of master and ip in [slurmctld/cleanup.sh](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm/slurmctld/cleanup.sh) file
5. You can manually do steps 9-11 or navigate to /multiverse/slurm and run setup.sh file.
6. Create the following folders in /var/spool  in controller node
    * completed\_jobs
    * completed\_job\_logs
    * job\_timelogs
    * completed\_slurmd\_logs
    * vm\_spawn\_logs
    * lock

7. Change the permissions of the two main locks in the lock folder
   * chmod 777 /var/spool/slurmcltd/lock/vmlock
   * chmod 777 /var/spool/slurmcltd/lock/pendinglock
8. Copy the vhpc_cfg folder to /home directory 
6. Setup two system service daemons in controller node. Copy the following files from [daemon](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/daemons) folder to /etc/systemd/system.
   * vhpcLaunch.service
   * vhpcCleanup.service
   * Copy the daemon source files from [src](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/daemons/src) folder to /usr/bin folder in the controller.
   * Start the daemons using "systemctl restart vhpcLaunch" and "systemctl restart vhpcCleanup"
7. Copy the following files from [configuation](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/configuration/) folder to /etc/slurm in the controller. node.
   * slurm.conf
   * slurm\_slaves.conf
   * plugstack.conf
8. Change the following parameters in /etc/slurm/slurm.conf file as per your cluster configuration
   * NodeName
   * NodeAddr
   * ClusterName
   * ControlAddr
   * Parition name and nodenames
   * AccoutingStorageType (slurmdbd if you start slurmdbd service)
   * 
9. Start the slurm controller daemon 
   * systemctl restart slurmctld for controller node
   * systemctl restart slurmd for slave/login node
   
10. Store the guest vm password in the file /var/spool/password.txt in controller node
 
### Prepare the VM template
A template VM needs to spawmned and ready in advance to use this framework. Follow the same installation instrutions as given in [install slurm](https://www.slothparadise.com/how-to-install-slurm-on-centos-7-cluster/) specific to slave nodes.
This VM will be used as template to clone all worker/slave slurm nodes. The framework supports all cloning types.
1. Instant clone:
   If using instant clone, configure the daemons in advance to use instant clone. Currently we support instant clone by having a template VM in frozen state on each host. This VM will be used as a template for cloning on a particulr host.
   The template VM is named using the convention "<hostipaddress>.t". To follow instructions on how to setup a frozen VM for instant clone, refer [instant_clone](https://gitlab.eng.vmware.com/hpc/vhpc_cfg/blob/feature/instant/docs/sample-operations.md)
2. Full and Linked clone, having a single template VM on any host is sufficient. 

## **Using The Framework**
### VM/Cluster configuration
Both clone and cluster command of vhpc\_toolkit can be used for cloning new VMs. The default option right now is cluster command. You can change the standard parameters like datacenter, cluster, resource\_pool etc in the [cluster\_config](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm/slurmctld/cluster_config) file which is used a template for every new VM configuration.
For instant clone or if you want to use staticIP, the network configuration parameters also need to be defined in the cluster_config template. 

### Prepare the slurm configuration template
[slurm.conf.template](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/blob/master/slurm/slurmctld/slurm.conf.template) file is used as a template to generate a slurm.conf file on every slave/worker node. you can modify the parameters in this file as per your requirements. All slave nodes information is maintained in slurm_slaves.conf which should be present in all slurm nodes. 
This file is copied to every slave node during customization of the VM after cloning. 

### Admission Control and Load Balancing

1. In order to chose the right host for spawning VMs, we maintain all host specific information sunch as host\_name, max\_available\_cpu, max\_available\_memory,allocated\_cpu, allocated\_memory and num\_vms in a sqlite databse.
2. Refer to [admission_control](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/tree/master/admission_control) on how to use the different options in the api. The common functions such as initializing the hosts table, updating information about the cluster, querying the best available for host to clone VMs etc are available.
 
### Logging

The following information are logged by the different processes. All file names are same as jobid

1. Job completed logs are loggeed to /var/spool/completed\_job\_logs
2. slurmd daemon logs are loggeed to /var/spool/completed\_slurmd\_logs
3. The vm\_launch script logs for every new VM is logged to /var/spool/vm\_spawn\_logs
4. The timestamps for clone start and end are logged in /var/spool/job\_timelogs
5. The system daemon logs can be checked at
   * tail /var/log/vhpc.log
   * tail /var/log/vhpcCleanup.log

