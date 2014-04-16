#!/bin/sh -x

set +e

apt-get --force-yes --yes install wget
yum --nogpgcheck -y install wget
wget -qO/tmp/runurl run.alestic.com/runurl
sh /tmp/runurl bootstrap.ecmanaged.com/agent/linux

