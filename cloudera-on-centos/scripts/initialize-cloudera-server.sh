#!/usr/bin/env bash

execname=$0

log() {
  echo "$(date): [${execname}] $@" >> /tmp/initialize-cloudera-server.log
}

#fail on any error
set -e

ClusterName=$1
key=$2
mip=$3
worker_ip=$4
HA=$5
User=$6
Password=$7

cmUser=$8
cmPassword=$9

EMAILADDRESS=${10}
BUSINESSPHONE=${11}
FIRSTNAME=${12}
LASTNAME=${13}
JOBROLE=${14}
JOBFUNCTION=${15}
COMPANY=${16}
VMSIZE=${17}

log "BEGIN: master node deployments"

log "Beginning process of disabling SELinux"

log "Running as $(whoami) on $(hostname)"

# Use the Cloudera-documentation-suggested workaround
log "about to set setenforce to 0"
set +e
setenforce 0 >> /tmp/setenforce.out

exitcode=$?
log "Done with settiing enforce. Its exit code was $exitcode"

log "Running setenforce inline as $(setenforce 0)"

getenforce
log "Running getenforce inline as $(getenforce)"
getenforce >> /tmp/getenforce.out

log "should be done logging things"


cat /etc/selinux/config > /tmp/beforeSelinux.out
log "ABOUT to replace enforcing with disabled"
sed -i 's^SELINUX=enforcing^SELINUX=disabled^g' /etc/selinux/config || true

cat /etc/selinux/config > /tmp/afterSeLinux.out
log "Done disabling selinux"

set +e

log "Set cloudera-manager.repo to CM v5"
yum clean all >> /tmp/initialize-cloudera-server.log
while true
    do
       wget http://lilitest528.blob.core.chinacloudapi.cn/cloudera-on-centos/myrepo.repo -O /etc/yum.repos.d/myrepo.repo>> /tmp/initialize-cloudera-server-repo.log 2>> /tmp/initialize-cloudera-server-repo.err && break
       sleep 15s
    done
	
while true
    do
       yum install -y oracle-j2sdk* >> /tmp/initialize-cloudera-server-sdk.log 2>> /tmp/initialize-cloudera-server-sdk.err && break
        sleep 15s
    done
	
while true
    do
       yum install -y cloudera-manager-daemons >> /tmp/initialize-cloudera-server-daemons.log 2>> /tmp/initialize-cloudera-server-daemons.err && break
       sleep 15s
    done

while true
    do
       yum install -y cloudera-manager-server >> /tmp/initialize-cloudera-server-manager.log 2>> /tmp/initialize-cloudera-server-manager.err && break
       sleep 15s
    done

while true
    do
       yum install -y cloudera-manager-agent >> /tmp/initialize-cloudera-server-agent.log 2>> /tmp/initialize-cloudera-server-agent.err && break
       sleep 15s
    done
	
while true
    do
       yum install -y jdk.x86_64 >> /tmp/initialize-cloudera-server-jdk.log 2>> /tmp/initialize-cloudera-server-jdk.err && break
       sleep 15s
    done


#######################################################################################################################
log "installing external DB"
sudo yum install postgresql-server -y
bash install-postgresql.sh >> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err
#restart to make sure all configuration take effects
sudo service postgresql restart

log "finished installing external DB"
#######################################################################################################################

log "start cloudera-scm-server services"
#service cloudera-scm-server-db start >> /tmp/initialize-cloudera-server.log
service cloudera-scm-server start >> /tmp/initialize-cloudera-server.log

#log "Create HIVE metastore DB Cloudera embedded PostgreSQL"
#export PGPASSWORD=$(head -1 /var/lib/cloudera-scm-server-db/data/generated_password.txt)
#SQLCMD=( """CREATE ROLE hive LOGIN PASSWORD 'hive';""" """CREATE DATABASE hive OWNER hive ENCODING 'UTF8';""" """ALTER DATABASE hive SET standard_conforming_strings = off;""" )
#for SQL in "${SQLCMD[@]}"; do
#	psql -A -t -d scm -U cloudera-scm -h localhost -p 5432 -c "${SQL}" >> /tmp/initialize-cloudera-server.log
#done
while ! (exec 6<>/dev/tcp/$(hostname)/7180) ; do log 'Waiting for cloudera-scm-server to start...'; sleep 15; done
log "END: master node deployments"



# Set up python
rpm -ivh http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm >> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err
yum -y install python-pip >> /tmp/initialize-cloudera-server.log
pip install cm_api >> /tmp/initialize-cloudera-server.log

# trap file to indicate done
log "creating file to indicate finished"
touch /tmp/readyFile

# Execute script to deploy Cloudera cluster
log "BEGIN: CM deployment - starting"
log "Parameters: $ClusterName $mip $worker_ip $EMAILADDRESS $BUSINESSPHONE $FIRSTNAME $LASTNAME $JOBROLE $JOBFUNCTION $COMPANY $VMSIZE"
if $HA; then
    python cmxDeployOnIbiza.py -n "$ClusterName" -u $User -p $Password  -m "$mip" -w "$worker_ip" -a -c $cmUser -s $cmPassword -e -r "$EMAILADDRESS" -b "$BUSINESSPHONE" -f "$FIRSTNAME" -t "$LASTNAME" -o "$JOBROLE" -i "$JOBFUNCTION" -y "$COMPANY" -v "$VMSIZE">> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err
else
    python cmxDeployOnIbiza.py -n "$ClusterName" -u $User -p $Password  -m "$mip" -w "$worker_ip" -c $cmUser -s $cmPassword -e -r "$EMAILADDRESS" -b "$BUSINESSPHONE" -f "$FIRSTNAME" -t "$LASTNAME" -o "$JOBROLE" -i "$JOBFUNCTION" -y "$COMPANY" -v "$VMSIZE">> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err
fi
log "END: CM deployment ended"
