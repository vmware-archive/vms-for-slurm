#!/usr/bin/python
# vm-provisioning-plugin-for-slurm
# Copyright 2019-2021 VMware, Inc.

# This product is licensed to you under the BSD-2 license (the "License"). 
# You may not use this product except in compliance with the BSD-2 License.  

# This product may include a number of subcomponents with separate copyright 
# notices and license terms. Your use of these subcomponents is subject to 
# the terms and conditions of the subcomponent's license, as noted in the LICENSE file. 
# -*- coding: utf-8 -*-
import sqlite3
from distutils.util import strtobool
from pyVmomi import vim, vmodl
from pyVim.connect import Connect, Disconnect
from pyVim.connect import SmartConnect, Disconnect
import log
import sys
import datetime
import time
import random
from textwrap3 import TextWrapper
from get_objs import GetObjects, GetDatacenter, GetHost, GetVM, GetClone
import ssl


MBFACTOR = float(1 << 20)

#Degree of overcommitment allowed for CPU in the cluster
OVERCOMMITTMENT = 2

#If set to 1, get_free will return a first available hosts from compatible hosts.
FIRST_AVAILABLE = 0

#If set to 1, get_free will return a random host from compatible hosts.
RANDOM_SELECT = 1

# If set to 1, it will populate the table values from cluster information in vCenter. Otherwise it will populate values from host_file defined
FROM_VCENTER = 1

#global variables:
MAX_HOST_AVAILABLE_MEMORY = 0
MAX_HOST_AVAILABLE_CPU = 0
hostname ='10.118.149.7'
user ='administrator@vsphere.local'
password ='VMware1!'
port =443
db_name = '/var/spool/cluster.db'
cluster_name = 'vSAN'

##initialize the host database from vcenter
def db_init():

# create table

    c.execute('''CREATE TABLE IF NOT EXISTS hosts
            (date text, name text, CPU_Avail real, MEM_Avail real, CPU_Alloc real, MEM_Alloc real, numVMs real)'''
              )
    c.execute('SELECT * FROM hosts')
    row = c.fetchone()
    #print("latrowid", row)
    if row:
        print("table already exists")
        return

    if FROM_VCENTER:
        hosts = get_hosts(cluster_name)
        now = int(round(time.time() * 1000))
        for host in hosts:
            c.execute("INSERT INTO hosts VALUES ('%s','%s',0,0,0,0,0)"
                      % (str(now), str(host.name)))
        update_from_cluster(cluster_name)
        conn.commit()
        return

#get the maximum available CPU and memory in every host
def update_maximum():

    print("inside maxupdate")

    global MAX_HOST_AVAILABLE_CPU
    global MAX_HOST_AVAILABLE_MEMORY
    cpu_avail = []
    mem_avail = []
    hosts = get_hosts(cluster_name)
    for host in hosts:
        for row in \
            c.execute("SELECT CPU_Avail FROM hosts WHERE name='%s'"
                      % host.name):
            cpu_avail.append([i for i in row])
        for row in \
            c.execute("SELECT MEM_Avail FROM hosts WHERE name='%s'"
                      % host.name):
            mem_avail.append([i for i in row])
    MAX_HOST_AVAILABLE_MEMORY = max(mem_avail)
    MAX_HOST_AVAILABLE_CPU = max(cpu_avail)
    MAX_HOST_AVAILABLE_MEMORY =  MAX_HOST_AVAILABLE_MEMORY[0]
    MAX_HOST_AVAILABLE_CPU = MAX_HOST_AVAILABLE_CPU[0]
    print (MAX_HOST_AVAILABLE_MEMORY, MAX_HOST_AVAILABLE_CPU)

#list information about all hosts in the cluster from the database.
def list_hosts():
    for row in c.execute('SELECT * FROM hosts'):
        print(row)

#formats the out of vcenter resources view
def _view_wrapper(fill_content, indentation):
    """ print out the wrapped output with TextWrapper
/
        Args:
                fill_content (str): the content for printing
                indentation (str): string that will be indented to
                                   the wrapped output

        """

    text_wrapper = TextWrapper(initial_indent=indentation,
                               subsequent_indent=indentation)
    print (text_wrapper.fill(fill_content))


#initiazlizing the connection to vcenter
def vcenter_connect(
    host,
    user,
    pwd,
    port,
    ):
    context = ssl._create_unverified_context()
    si = SmartConnect(host=host, user=user, pwd=pwd, port=port,
                      sslContext=context)
    if not si:
        raise SystemExit('[ERROR] Could not connect to the specifiedhost using specified username and password'
                         )

    content = si.RetrieveContent()

    # atexit.register(Disconnect, si)

    return content

###Return a compatible host to satosfy the new allocation. 
###Load balacning policy is chosen based on global variables set above
def get_compatible_host(req_cpu, req_mem):

    #print("inside get hosts", req_cpu,req_mem)

    cpu_avail = []
    mem_avail = []
    cpu_alloc = []
    mem_alloc = []
    possible_hosts = []
    update_maximum()
    hosts = get_hosts(cluster_name)
    if req_cpu > MAX_HOST_AVAILABLE_CPU or req_mem > MAX_HOST_AVAILABLE_MEMORY:
        print (req_cpu, MAX_HOST_AVAILABLE_CPU, req_mem,
               MAX_HOST_AVAILABLE_MEMORY)
        return 2
    for host in hosts:
        for row in \
            c.execute("SELECT CPU_Avail FROM hosts WHERE name='%s'"
                          % host.name):
            cpu_avail = [i for i in row]
        for row in \
            c.execute("SELECT CPU_Alloc FROM hosts WHERE name='%s'"
                          % host.name):
            cpu_alloc = [i for i in row]
        for row in \
            c.execute("SELECT MEM_Avail FROM hosts WHERE name='%s'"
                          % host.name):
            mem_avail = [i for i in row]
        for row in \
            c.execute("SELECT MEM_Alloc FROM hosts WHERE name='%s'"
                          % host.name):
            mem_alloc = [i for i in row]
        free_cpu = cpu_avail[0] - cpu_alloc[0]
        free_mem = mem_avail[0] - mem_alloc[0]
        if req_cpu <= free_cpu and req_mem <= free_mem:
            print(mem_avail,mem_alloc,cpu_avail,cpu_alloc)
            #print ('free cpu:', free_cpu, 'free_mem:', free_mem)
            if FIRST_AVAILABLE:
                print( 'host:' + str(host.name))
                return 1
            elif RANDOM_SELECT:
                possible_hosts.append(host.name)
    if len(possible_hosts) == 0:
        return 0
    else:
        print('host:' + random.choice(possible_hosts))

## return the list of all host objects in the cluster
def get_hosts(cluster):
    content = vcenter_connect(hostname, user,
                              password, port)
    objs = GetObjects(content)
    datacenters = objs.get_container_view([vim.Datacenter])
    hosts = []

        # print basic information by default (compute resources)

    print ('Basic View:', cluster)
    for datacenter in datacenters:
        print ('|-+: {0} [Datacenter]'.format(datacenter.name))
        for entity in GetDatacenter(datacenter).compute_resources():
            print( entity.name)
            if isinstance(entity, vim.ComputeResource) and entity.name \
                == cluster:
                print ('Cluster', entity.name)
                for host in entity.host:
                    _view_wrapper('|-+:%s [Host][%s]' % (host.name,
                                  host.runtime.connectionState), (1 * 2
                                  + 2) * ' ')
                    CPU_Avail = host.hardware.cpuInfo.numCpuCores \
                        * OVERCOMMITTMENT
                    MEM_Avail = host.hardware.memorySize / MBFACTOR
                    numVMs = len(host.vm)

            # print(host.summary.quickStats, "\nnumVMs :",numVMs,"numCPUs:",CPU_Avail,"Memory(MB):",MEM_Avail)

                    hosts.append(host)

    #print ("available hosts",hosts)

    return hosts

#update the table based on real-time information of the cluster from vcenter.
def update_from_cluster(cluster):
    hosts = get_hosts(cluster)
    if len(hosts) == 0:
        print ('Cluster does not exist')
        return
    for host in hosts:
        _view_wrapper('|-+:%s [Host][%s]' % (host.name,
                      host.runtime.connectionState), (1 * 2 + 2) * ' ')
        CPU_Avail = host.hardware.cpuInfo.numCpuCores * OVERCOMMITTMENT
        MEM_Avail = host.hardware.memorySize / MBFACTOR
        numVMs = len(host.vm)
        print (
            host.summary.quickStats,
            '\nnumVMs :',
            numVMs,
            'numCPUs:',
            CPU_Avail,
            'Memory(MB):',
            MEM_Avail,
            )
        CPU_Alloc = 0
        MEM_Alloc = 0
        for child in host.vm:

                       # print child.config.memoryAllocation
                        # print(child.summary.quickStats)

            print ('CPU:', child.config.hardware.numCPU)
            if child.config.hardware.numCPU:
                CPU_Alloc += child.config.hardware.numCPU
            print ('MEM:', child.summary.runtime.maxMemoryUsage)
            if child.summary.runtime.maxMemoryUsage:
                MEM_Alloc += child.summary.runtime.maxMemoryUsage
        print (
            host.name,
            'Allocated CPU:',
            CPU_Alloc,
            '\n',
            'Allocated Mem',
            MEM_Alloc,
            )
        c.execute("UPDATE hosts SET CPU_Alloc='%s',MEM_Alloc='%s' WHERE name='%s'"
                   % (CPU_Alloc, MEM_Alloc, host.name))
        c.execute("UPDATE hosts SET CPU_Avail='%s',MEM_Avail='%s',numVMs='%s' WHERE name='%s'"
                   % (CPU_Avail, MEM_Avail, numVMs, host.name))
        conn.commit()

                # c.execute("SELECT CPU_Alloc,name,date FROM hosts")

        CPU_Alloc = 0
        MEM_Alloc = 0

                # View(entity, cur_level=1).view_compute_resource()

    return

#invoked during VM creation. will update the table based on new allocation
def add_vm(
    host,
    cpu,
    mem,
    VMs,
    ):

    for row in c.execute("SELECT CPU_Alloc FROM hosts WHERE name='%s'"
                         % host):
        cpu_alloc = [i for i in row]
    for row in c.execute("SELECT MEM_Alloc FROM hosts WHERE name='%s'"
                         % host):
        mem_alloc = [i for i in row]
    for row in c.execute("SELECT numVMs FROM hosts WHERE name='%s'"
                         % host):
        numVMs = [i for i in row]

    new_cpu_alloc = cpu + cpu_alloc[0]
    new_mem_alloc = mem + mem_alloc[0]
    numVMs[0] += VMs
    c.execute("UPDATE hosts SET CPU_Alloc='%s',MEM_Alloc='%s',numVMs='%s' WHERE name='%s'"
               % (new_cpu_alloc, new_mem_alloc, numVMs[0], host))
    conn.commit()

#invoked during VM deletion. will update the table based on status of cluster
def remove_vm(
    host,
    cpu,
    mem,
    VMs,
    ):

    for row in c.execute("SELECT CPU_Alloc FROM hosts WHERE name='%s'"
                         % host):
        cpu_alloc = [i for i in row]
    for row in c.execute("SELECT MEM_Alloc FROM hosts WHERE name='%s'"
                         % host):
        mem_alloc = [i for i in row]
    for row in c.execute("SELECT numVMs FROM hosts WHERE name='%s'"
                         % host):
        numVMs = [i for i in row]

    new_cpu_alloc = cpu_alloc[0] - cpu
    new_mem_alloc = mem_alloc[0] - mem
    numVMs[0] -= VMs
    c.execute("UPDATE hosts SET CPU_Alloc='%s',MEM_Alloc='%s',numVMs='%s' WHERE name='%s'"
               % (new_cpu_alloc, new_mem_alloc, numVMs[0], host))
    conn.commit()


#try:
#    conn = sqlite3.connect(db_name, timeout=30.0)
#except Error as e:
#    print(e)
#    exit()

conn = sqlite3.connect(db_name, timeout=30.0)
c = conn.cursor()
conn.text_factory = str
hostlist = '/var/spool/host_list'

if len(sys.argv) <= 1:
    print("please enter an option {initdb, list, update_from_cluster, add_vm, remove_vm, get_compatible_host, delete}")
    exit()
option = str(sys.argv[1])
if option == 'initdb':
    db_init()
elif option == 'list':
    list_hosts()
elif option == 'add_vm':
    if len(sys.argv) < 5:
        print('ERROR: please enter host name,cpu and memory')
        exit()
    add_vm(sys.argv[2], float(sys.argv[3]), float(sys.argv[4]),
           int(sys.argv[5]))
elif option == 'remove_vm':
    if len(sys.argv) < 5:
        print ('ERROR: please enter host name,cpu and memory')
        exit()
    print (sys.argv[2], float(sys.argv[3]), float(sys.argv[4]),
           int(sys.argv[5]))
    remove_vm(sys.argv[2], float(sys.argv[3]), float(sys.argv[4]),
              int(sys.argv[5]))
elif option == 'update_from_cluster':

    if len(sys.argv) < 3:
        print ('ERROR: please enter cluster name')
        exit()
    update_from_cluster(str(sys.argv[2]))
elif option == 'delete':
    #Delete the hosts table from database.
    c.execute('DROP TABLE hosts')
    conn.commit()
elif option == 'get_compatible_host':
    if len(sys.argv) < 4:
        print ('ERROR: please enter: cpu,mem')
        exit()

    # c.execute('SELECT * FROM hosts')

    rt = get_compatible_host(float(sys.argv[2]),
                             float(sys.argv[3]))
    if rt == 0:
        print ('no available host')
    elif rt == 2:
        print ('invalid host')
    else:
        print("successfull")
else:

    print ('invalid option')
