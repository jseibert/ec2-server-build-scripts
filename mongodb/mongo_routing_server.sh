#!/bin/bash -x
## Mongo Routing Server Build Script
##  Prerequisites:
##    - Create 64 bit EC2 instance using Ubuntu 9.10 EBS root AMI
##    - Configure 3 Configuration servers using the mongo_config_server.sh script
##    - Replace configA,configB,configC with the IP addresses of your 3 config servers

# Add Mongo repository
sed -i '$ a deb http://downloads.mongodb.org/distros/ubuntu 9.10 10gen' /etc/apt/sources.list
apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10

# Update and install MongoDB
aptitude update
aptitude safe-upgrade -y
aptitude install mongodb-stable -y

# Stop MongoDB to make configuration changes
service mongodb stop

# Change mongodb startup script to start a config server using our custom paths
rm /etc/init/mongodb.conf
cat > /etc/init/mongodb.conf << EOF
description "Mongos Routing Server"

pre-start script
    mkdir -p /data/db/mongodb/
    chown -R mongodb:mongodb /data
end script

start on startup
stop on shutdown

exec start-stop-daemon --start --quiet --chuid mongodb --exec  /usr/bin/mongos -- --configdb configA,configB,configC --logpath /data/db/mongodb.log --logappend --pidfilepath /data/db/mongodb/mongos.lock
EOF

# Install monit and monitor our MongoDB process
aptitude install monit;
sed -i '/startup/ c startup=1' /etc/default/monit;
rm /etc/monit/monitrc;
cat > /etc/monit/monitrc << EOF
set daemon 60
set logfile /var/log/monit.log
set httpd port 2812 and
  allow admin:monit
  
  check process mongodb with pidfile /data/db/mongodb/mongos.lock
    start program "/sbin/start mongodb"
    stop program "/sbin/stop mongodb"
    if failed port 27017 then restart
    if 5 restarts within 5 cycles then timeout
EOF

# Reboot the instance
reboot -h now