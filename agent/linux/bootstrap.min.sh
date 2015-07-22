#!/bin/sh

set +e

if [ ! `which wget` ]; then
  if [ `which apt-get` ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -q
    apt-get install -q -y -o Dpkg::Options::="--force-confold" wget 2>/dev/null
  
  else
    yum --nogpgcheck -y install wget 2>/dev/null
  fi
fi

wget -qO/tmp/runurl run.alestic.com/runurl
sh /tmp/runurl bootstrap.ecmanaged.com/agent/linux
