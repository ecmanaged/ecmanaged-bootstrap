#!/bin/sh -x

set +e

apt-get --force-yes --yes install wget 2>/dev/null
yum --nogpgcheck -y install wget 2>/dev/null
wget -qO/tmp/runurl run.alestic.com/runurl
sh /tmp/runurl bootstrap.ecmanaged.com/agent/linux
