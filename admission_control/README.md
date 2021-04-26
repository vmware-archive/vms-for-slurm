Setup a database using sqlite for all hosts in a cluster based on information from vCenter. 

**Requirements:**
1. python version 3.6
2. pip install packages sqlite3, time, TextWrapper
Setup the following global variables before using the program.

**Command line arguments:**

1. initdb : Initialize the databse and create table named hosts.
2. add_vm : requires host name,cpu and memory. will update the table based on new allocation. 
3. remove_vm: requires host name,cpu and memory. will update the table based on new allocation. 
4. get\_free: requires cpu and memory. Return a compatible host to satosfy the new allocation. 
5. update\_from\_cluster: update the table based on real-time information of the cluster from vcenter.
6. list: list all hosts in the cluster from the table hosts
7. delete: Delete the hosts table from databases.

**global Variables:**

1. MBFACTOR = float(1 << 20) : defines the size of 1MB in bytes
2. OVERCOMMITTMENT= : Degree of overcommitment allowed for CPU in the cluster
3. FIRST\_AVAILABLE= : If set to 1, get\_free will return a first available hosts from compatible hosts.
4. RANDOM\_SELECT= : If set to 1, get\_free will return a random host from compatible hosts.
5. FROM\_VCENTER = : If set to 1, it will populate the table values from cluster information in vCenter. Otherwise it will populate values from host\_file defined.
6. Set the hostaddress, username , password and port number fpr vCenter as well.
7. Set the database path is dbpath="<dbpath>"

**Note**: Both FIRST\_AVAILABLE and RANDOM\_SELECT cannot be set to 1 at the sametime. 
