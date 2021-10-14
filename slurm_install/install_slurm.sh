################################################################################
#this script is conveneient to install slurm incuding all dependencies.
#By default this script is used to install slurm for controller nodes.
#in order to install in a slave node, uncomment or comment certain lines which are given.
#the script installs the followinf tools
#  1. munge
#  2. mysql mariadb server
#  3. rng_tools
#  4. ntp

#Install options
   # 1. you can install from source, by uncommenting the lines to download slurm.
   #    and use rpmbuild to buld the rpms from source.
   #2. Alternatively, if you already have rpms copied to /root/rmps/slurm folder
   #   you can skip the compiling face and directly install the rpms.
#For slave nodes:
    #Master node name and ip address should be known and defined in advance.
    #mariadb server is mot required to ne installed
    #The munge.key has to be same for slave and master nodes. 
    #You can scp the key to /etc/munge
################################################################################

######uncomment for slave node######
#master="<ip addr>"
#echo "$master <master node naae>" >> /etc/hosts

if [ -z "$1" ]
then
echo "please enter hostname and host ip addr"
exit 1
fi
echo $1 > /etc/hostname
echo "$2 $1" >> /etc/hosts


systemctl restart network
hostnamectl status
yum remove mariadb-server mariadb-devel -y
yum remove slurm munge munge-libs munge-devel -y
userdel -r slurm
userdel -r munge

###comment for slave node #####
yum install mariadb-server mariadb-devel -y
##########

export MUNGEUSER=991
groupadd -g $MUNGEUSER munge
useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge  -s /sbin/nologin munge
export SLURMUSER=992
groupadd -g $SLURMUSER slurm
useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm  -s /bin/bash slurm

yum install epel-release
yum install munge munge-libs munge-devel -y
yum install rng-tools -y
rngd -r /dev/urandom
/usr/sbin/create-munge-key -r

#echo $(sshpass -p "ca\$hc0w" scp root@$master:/etc/munge/munge.key /etc/munge)


dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

chown -R munge: /etc/munge/ /var/log/munge/
chmod 0700 /etc/munge/ /var/log/munge/
#echo $(sshpass -p "ca\$hc0w" scp root@$master:/etc/munge/munge.key /etc/munge)
systemctl enable munge
systemctl restart munge

munge -n
munge -n | unmunge
remunge

###uncomment for slave VM #####
#echo $(munge -n | ssh root@master unmunge)
yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad -y
#wget https://download.schedmd.com/slurm/slurm-18.08.7.tar.bz2
#yum install rpm-build
#rpmbuild -ta slurm-18.08.7.tar.bz2

mkdir /var/spool
mkdir /var/spool/slurmctd
mkdir /var/spool/slurmd
chown slurm: /var/spool/
chown -R slurm /var/spool
chown -R slurm /var/spool/slurmctld
chown -R slurm /home
chmod 755 /var/spool/slurmctld
touch /var/log/slurmd.log
touch /var/log/slurmctld.log
chown slurm /var/log/slurmd.log
chown slurm: /var/log/slurmctld.log
touch /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
chown slurm: /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log

cd /root/rpms/slurm
for entry in $(ls)
do 
yum --nogpgcheck localinstall "$entry" -y
done
########################################################################################
#Alterntively you can comment the for loop and install only required rpms
# skip slurmctld rpm for slave node
#######################################################################################

slurmd -C

systemctl stop firewalld
systemctl disable firewalld

yum install ntp -y
chkconfig ntpd on
ntpdate pool.ntp.org
systemctl start ntpd

#sh launch_slurm_compute.sh