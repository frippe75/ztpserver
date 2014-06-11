#!/bin/sh -x

#enable delta rpms's to make yum faster
yum -y install deltarpm

#Grab updates and cleanup
yum -y update yum
yum -y update
yum -y clean all

#Install ztps-related related packages
yum -y install python-devel
yum -y install python-pip
yum -y install mod_wsgi
yum -y install gcc make gcc-c++
yum -y install tar
yum -y install wget
yum -y install libyaml libyaml-devel
yum -y install screen
yum -y install git
yum -y install net-tools
yum -y install tcpdump
yum -y install httpd
yum -y install httpd-devel
yum -y install dhcp
yum -y install bind bind-utils
yum -y install ejabberd
yum -y install rsyslog


######################################
# CONFIGURE FIREWALLd
######################################
#Disable firewalld
systemctl disable firewalld.service
systemctl stop firewalld.service
firewall-cmd --state
ifconfig

######################################
# CONFIGURE SCREEN
######################################
cp /tmp/packer/screenrc /home/ztpsadmin/.screenrc
cp /tmp/packer/screenrc /root/.screenrc

######################################
# CONFIGURE rsyslog
######################################
mv /etc/rsyslog.conf /etc/rsyslog.conf.bak
cp /tmp/packer/rsyslog.conf /etc/rsyslog.conf
systemctl restart rsyslog.service
netstat -tuplen | grep syslog

######################################
# CONFIGURE eJabberd
######################################
mv /etc/ejabberd/ejabberd.cfg /etc/ejabberd/ejabberd.cfg.bak
cp /tmp/packer/ejabberd.cfg /etc/ejabberd/ejabberd.cfg
#echo -e "#Generated by packer (EOS+)\nsearch localdomain ztps-test.com\nname-server 172.16.130.10" > /etc/resolv.conf
echo -e "127.0.0.1 ztps ztps.ztps-test.com" >> /etc/hosts
ejabberdctl start
sleep 5
ejabberdctl status
systemctl enable ejabberd.service
ejabberdctl register ztpsadmin im.ztps-test.com eosplus
systemctl restart ejabberd.service
ejabberdctl status

######################################
# CONFIGURE APACHE
######################################
mv /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
cp /tmp/packer/httpd.conf /etc/httpd/conf/httpd.conf
systemctl restart httpd.service
#Stopping httpd since ztps will manage this
systemctl stop httpd.service

######################################
# CONFIGURE BIND
######################################
mv /etc/named.conf /etc/named.conf.bak
cp /tmp/packer/named.conf /etc/named.conf
cp /tmp/packer/ztps-test.com.zone /var/named/
service named restart
systemctl enable named.service
systemctl status named.service

######################################
# CONFIGURE DHCP
######################################
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
cp /tmp/packer/dhcpd.conf /etc/dhcp/dhcpd.conf
systemctl restart dhcpd.service
systemctl enable dhcpd.service
systemctl status dhcpd.service

######################################
# INSTALL ZTPSERVER
######################################
#mkdir /etc
cd /home/ztpsadmin

#clone from GitHub
git clone https://github.com/arista-eosplus/ztpserver.git -b develop
cd ztpserver
git checkout v1.0.0

#build/install
python setup.py build
python setup.py install

mkdir /home/ztpsadmin/ztps-sampleconfig
cd /home/ztpsadmin/ztps-sampleconfig
git clone https://github.com/arista-eosplus/ztpserver-demo.git

cd ztpserver-demo/
cp -R ./definitions /usr/share/ztpserver/
cp -R ./files /usr/share/ztpserver/
cp -R ./nodes /usr/share/ztpserver/
cp -R ./resources /usr/share/ztpserver/
cp -R ./neighbordb /usr/share/ztpserver/
cp ztpserver.conf /etc/ztpserver/ztpserver.conf

cd /usr/share/ztpserver/files
mkdir images
cp -R /tmp/packer/files/images .
mkdir puppet
cp -R /tmp/packer/files/puppet .
