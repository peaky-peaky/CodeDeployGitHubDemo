#!/bin/bash

PWD=$(dirname $0)
echo "start openstack configuration"
PREV_IFS=$IFS
IFS="
"
OPEYML=$(ls *ope.yml)

. $PWD/keystonerc



for yml in $OPEYML
do
YMLORDER=$(echo $yml | cut -c 1-3)
if [ -e ~/openstackope/${yml} ]; then
 echo "${YMLORDER}ope Start!"
 ansible-playbook -i inventory/hosts ${yml}
else
 echo "prepare${YMLORDER}yml.."
 exit 1
fi
case $(echo "$YMLORDER" | sed -e 's/[^0-9]//g') in
 "1" ) openstack project list > /root/openstackope/roles/keystone/tasks/prolist
       cat ~/openstackope/roles/keystone/tasks/prolist | grep service

       if [ $? -ne 0 ]; then
        openstack project create --domain default --description "Service Project" service
       fi 
       openstack user list > /root/openstackope/roles/keystone/tasks/userlist
       cat ~/openstackope/roles/keystone/tasks/userlist | grep glance

       if [ $? -ne 0 ]; then
        echo "start create glance user"
        for g in $(cat ~/openstackope/glance-user)
        do
        IFS=$PREV_IFS
        $g
        if [ $? -eq 0 ]; then
         echo $g "is ok"
        else
         echo "error.."
        exit 1
        fi
        done
       fi

       openstack user list > /root/openstackope/roles/keystone/tasks/userlist ;;
 "2" ) openstack user list > /root/openstackope/roles/keystone/tasks/userlist
       cat ~/openstackope/roles/keystone/tasks/userlist | grep nova

       if [ $? -ne 0 ]; then
        echo "start create nova user"
        for n in $(cat ~/openstackope/nova-user)
        do
        IFS=$PREV_IFS
        $n
        if [ $? -eq 0 ]; then
         echo $n "is ok"
        else
         echo "error.."
        exit 1
        fi
        done
       fi

       openstack user list > /root/openstackope/roles/keystone/tasks/userlist ;;
 "3" ) sleep 12
       openstack compute service list > /root/openstackope/roles/novauser/tasks/nova-result ;;
 "4" ) sleep 12
       openstack compute service list > /root/openstackope/roles/novauser/tasks/nova-result

       for service in api conductor scheduler novncproxy
       do
       systemctl stop nova-$service
       done

       openstack user list > /root/openstackope/roles/keystone/tasks/userlist
       cat ~/openstackope/roles/keystone/tasks/userlist | grep neutron

       if [ $? -ne 0 ]; then
        echo "start create neutron user"
        for j in $(cat ~/openstackope/neutron-user)
        do
        IFS=$PREV_IFS
        $j
        if [ $? -eq 0 ]; then
         echo $j "is ok"
        else
         echo "error.."
        exit 1
        fi
        done
       fi

       mysql -u root -h localhost -e "show databases;" > ~/openstackope/roles/mariadb/tasks/sqlresult
       cat ~/sqlresult | grep neutron_ml2

       if [ $? -ne 0 ]; then
        sh ~/openstackope/neutron-register.sh
       fi

       mysql -u root -h localhost -e "show databases;" > ~/openstackope/roles/mariadb/tasks/sqlresult ;; 
 "5" ) openstack network agent list  > /root/openstackope/roles/neutron/tasks/neutron-result

       for service in api conductor scheduler novncproxy
       do
       systemctl stop nova-$service
       done ;
 "6" ) openstack network list > ~/network-result
       cat ~/network-result | grep sharednet1

       if [ $? -ne 0 ]; then
        sh ~/openstackope/network-register.sh
       fi

       openstack subnet list > ~/subnet-result
       sh ~/openstackope/subnet-register.sh

       cat ~/openstackope/roles/keystone/tasks/prolist | grep hiroshima

       if [ $? -ne 0 ]; then
        sh ~/openstackope/hiroshima.sh
       fi ;;
 "7" ) openstack user list > /root/openstackope/roles/keystone/tasks/userlist
       cat ~/openstackope/roles/keystone/tasks/userlist | grep cinder

       if [ $? -ne 0 ]; then
        echo "start create cinder user"
        sh cinder-user.sh
       fi

       mysql -u root -h localhost -e "show databases;" > ~/openstackope/roles/mariadb/tasks/sqlresult
       cat ~/sqlresult | grep cinder

       if [ $? -ne 0 ]; then
        sh ~/openstackope/cinder-register.sh
       fi ;;
 "8" ) mysql -u root -h localhost -e "show databases;" > ~/openstackope/roles/mariadb/tasks/sqlresult
       openstack volume service list   > /root/openstackope/roles/cinder/tasks/cinder-result

       openstack user list > /root/openstackope/roles/keystone/tasks/userlist ;;
esac
done
