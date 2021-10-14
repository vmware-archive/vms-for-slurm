**Dependencies:**

Before installing slurm, make sure you have the following dependencies installed.

1. Perl libraries.
   * yum install perl-devel perl-CPAN -y
   
2. Python 3.6 and pip
   * yum update
   * yum install yum-utils -y
   * sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
   * yum install python36u python36u-pip install python36u-devel -y

3. Install GCC libraries.

   * yum install gcc gcc-c++ autoconf automake -y

**Installation from rpm**
1. Copy the rpms from [slurm_install/rpms](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/tree/master/slurm_install/rpms) folder to the following folder in the new node **/root/rpms/slurm**.

2. Then use the install_slurm.sh to install slurm.

3. Copy the following files from [plugins](https://gitlab.eng.vmware.com/jgunasekaran/multiverse/tree/master/slurm/plugins) to the respective folders in the new node as given below.

   * sched_hold.so to /usr/lib64/slurm
   * select_linear.so to /usr/lib64/slurm
   * vhpc.so to /usr/lib64/slurm
   * job_submit.lua to /etc/slurm

**Installation from source**

1. Copy the slurm_source folder the new node.
2. Compile from scratch as follows
     * ./configure --prefix=<install_directory>
     * make all
     * make install
3. Follow the same instruction on step 3 as given above in "installation from rpm".
     


