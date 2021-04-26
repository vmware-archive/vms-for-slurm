Plugins used in slurm to enable support for VM per job Model
The plugins can be customized if required. The source of the plugins is available in src folder.
The functions of each plugin is given below.

**job\_submit**

Used to Set defaults in job submit request specifications. It is developed by slurm communiuty.
Currently we use this plugin enables to capture job specific requirements and also sets default values if not specified in the job\_submission script. The requirements which can be recorded are jobname, cpu, memory, and num\_nodes. The timestamp of job\_submission is captured in the plugin and its saved in comment field of internal job datastructure. The timestamp concatenated with job\_name is used to uniquely indentify every incoming job.

**sched\_hold**

The plugin holds all incoming slurm jobs. Also it acquires a lock and adds the job information (job unique\_name and jobid to a queued\_jobs file. If the lock is busy it acquires another lock called pendinglock and adds the job information to a pendinig\_jobs file. The information from these files is directly used by the vhpc\_launch daemon to spawn VMs for jobs in the slurm queue. 

**select\_linear**

Selects nodes for a job so as to minimize the number of sets of consecutive nodes using a best-fit algorithm. We have modified this algorithm to return True irrespective of whether a node can satisfy the jobs requests. We do so because the node ffor the job will be ready at the later stage because the VM spawning might not be completed by this time. We handle VM launch failures later in the vhpc\_launch daemon and cancel jobs if nodes are not available. 

**vhpc\_plugin**

We define a spank plugin named vhpc to which gets called at the following context in slurm.

1. job\_epilog context 
   * this is called after the job completion from the slurmd daemon of worker node.
   * We call a script cleanup.sh which is available on every worker node. This script ensures that the node state is markded as down( not schedulable) and also notifies the controller about job\_completion. It also copies the job\_output\_logs to the controller node. 

**Compilation instructions for all plugins:**

If you plan on modifying any of the plugins, you need to compile them and copy the library file to slurm_libs(/usr/lib/slurm) directory. 
Note that, you need to compile these files from the original slurm source folder. In case you installed slurm using rpms, then you should 
1. Download slurm from [slurm_downloads](https://www.schedmd.com/downloads.php).
2. Run ./configure from the downloaded slurm folder.
3. Follow the instructions below for compiling individual pluguins. 

    1. **job\_submit**  Its a lua program. you can modifiy the lua program. There is no need to recompile the lua code. Just make sure you copy the updated lua program to /etc/slurm
    2. **sched\_hold** : If you modify the hold\_wrapper.c C file, you need to compile it to a shared .so file. 
    * copy the hold_wrapper.c to <slurm\_source>/src/plugins/sched/hold
    * compile using the command below
       gcc --shared -DHAVE_CONFIG_H -I. -I../../../.. -I../../../../slurm -I../../../.. -I../../../../src/common -DNUMA_VERSION1_COMPATIBILITY -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -pthread -ggdb3 -Wall -g -O1 -fno-strict-aliasing  -fPIC -DPIC -o sched\_hold.so hold\_wrapper.c
    * copy the sched\_hold.so file to /usr/lib(64)/slurm
   3. **select\_linear** : Similar to sched\_hold plugin
    * copy the modified select\_linear.c file to  <slurm\_source>/src/plugins/select/linear
    * compile using the command below
       gcc --shared -DHAVE_CONFIG_H -I. -I../../../.. -I../../../../slurm -I../../../.. -I../../../../src/common -DNUMA_VERSION1_COMPATIBILITY -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -pthread -ggdb3 -Wall -g -O1 -fno-strict-aliasing  -fPIC -DPIC -o select\_linear.so select\_linear.c
    * copy the select\_linear.so file to /usr/lib(64)/slurm
   4. **vhpc\_plugin**: 
    * modify the source file vhpc.c
    * compile using gcc -shared -fPIC  -o vhpc.so vhpc.c 
    * copy the vhpc.so file to /usr/lib(64)/slurm 


   


