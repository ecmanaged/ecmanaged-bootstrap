#!/bin/sh

LOG_FILE=/root/ecm_agent_install.log
ECAGENT_PKG=ecmanaged-ecagent
ECAGENT_PATH=/opt/ecmanaged/ecagent
ECAGENT_INIT=/etc/init.d/ecagentd
UUID=

__install_debian() {
  SOURCE_APT_ECM="deb http://apt.ecmanaged.com stable stable"
  APT_OPS="--force-yes --yes --no-install-recommends -o DPkg::Options::=--force-confold"  
  
  export DEBIAN_FRONTEND=noninteractive

  if [ -d /etc/apt/sources.list.d ]; then
    echo ${SOURCE_APT_ECM}    > /etc/apt/sources.list.d/ecmanaged-stable.list
  else
    echo ${SOURCE_APT_ECM}    >> /etc/apt/sources.list
  fi
  
  # Update
  apt-get -y update
  apt-get ${APT_OPS} install wget
  
  # Install ECmanaged key
  wget -q -O- "http://apt.ecmanaged.com/key.asc" | apt-key add - >/dev/null 2>&1
  
  # Install ECM Agent
  apt-get ${APT_OPS} install ${ECAGENT_PKG}
}

__install_redhat() {
  SOURCE_YUM_EPEL="[ecmanaged-epel]\nname=Extra Packages for Enterprise Linux \$releasever - \$basearch\n#baseurl=http://download.fedoraproject.org/pub/epel/${RELEASE}/\$basearch\nmirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-${RELEASE}&arch=\$basearch\nfailovermethod=priority\nenabled=0\ngpgcheck=0\ngpgkey=http://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-\$releasever"
  __install_yum
}

__install_amazon() {
  RELEASE=6
  __install_redhat
}

__install_arch() {
  echo "Not supported"
}

__install_fedora() {
  if [ -d /etc/yum.repos.d ]; then
    echo -e ${SOURCE_YUM_ECM}    > /etc/yum.repos.d/ecmanaged-stable.repo
    
  else
    echo -e ${SOURCE_YUM_ECM}    >> /etc/yum.conf
  fi

  # Install ECM Agent
  yum -y clean all
  yum --nogpgcheck -y install ${ECAGENT_PKG}
}

__install_yum() {
  SOURCE_YUM_ECM="[ecmanaged-stable]\nname=ECManaged stable Packages\nbaseurl=http://rpm.ecmanaged.com\nenabled=1\ngpgcheck=1"
  
  if [ -d /etc/yum.repos.d ]; then
    echo -e ${SOURCE_YUM_ECM}    > /etc/yum.repos.d/ecmanaged-stable.repo
    echo -e ${SOURCE_YUM_EPEL}   > /etc/yum.repos.d/ecmanaged-epel.repo
    
  else
    echo -e ${SOURCE_YUM_ECM}    >> /etc/yum.conf
    echo -e ${SOURCE_YUM_EPEL}   >> /etc/yum.conf
  fi

  # Install ECM Agent
  yum -y clean all
  yum --enablerepo=ecmanaged-epel --nogpgcheck -y install ${ECAGENT_PKG}
}

__get_distrib() {
  ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

  if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    DISTRO=$DISTRIB_ID
    RELEASE=$DISTRIB_RELEASE

  elif [ -f /etc/debian_version ]; then
    DISTRO='Debian'
    RELEASE=$(cat /etc/debian_version)
    
  elif [ -f /etc/apt/sources.list ]; then
    DISTRO='Ubuntu'
    RELEASE=0

  elif [ -f /etc/fedora-release ]; then
    DISTRO='Fedora'
    RELEASE=$(rpm -qa|grep release|xargs rpm -q --queryformat '%{VERSION}' |cut -d'-' -f2)

  elif [ -f /etc/centos-release ]; then
    DISTRO='Centos'
    RELEASE=$(rpm -qa|grep release|xargs rpm -q --queryformat '%{VERSION}' |cut -c -1)
    
  elif [ -f /etc/redhat-release ]; then
    DISTRO='Redhat'
    RELEASE=$(rpm -qa|grep release|xargs rpm -q --queryformat '%{VERSION}' |cut -c -1)
  
  elif [ -f /etc/SuSE-release ] ; then
    DISTRO='Suse'
    RELEASE=$(cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//)

  elif [ -f /etc/mandrake-release ] ; then
    DISTRO='Mandrake'
    RELEASE=$(cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//)

  elif [ -f /etc/system-release ] ; then
    DISTRO='Amazon'
    RELEASE=$(cat /etc/system-release | sed s/.*release\ // | sed s/\ .*//)
  fi
}

__ecagent_check() {
  # Start agent if not installed
  echo " * Check ECAgent running..."
  /etc/init.d/ecagentd check
}

__resizefs() {
  # Try to resize filesystem
  echo " * Resizing ROOT filesystem..."
  resize2fs $(df -l /|grep dev|cut -f1 -d' ')
}

__ecagent_configure() {
  if [ $UUID ]; then
  echo " * Configure ECM Agent uuid..."
    ${ECAGENT_INIT} stop > /dev/null 2>&1
    pkill -f ecagent > /dev/null 2>&1
    ${ECAGENT_PATH}/configure.py $UUID
  fi
}

# main()
__get_distrib
echo "Installing ${ECAGENT_PKG} on ${DISTRO} release ${RELEASE} ($ARCH bits)..."
case ${DISTRO} in
	Debian|Ubuntu)
		__install_debian
		;;

	Redhat|Centos)
		__install_redhat
		;;

	Fedora)
		__install_fedora
		;;

	Amazon)
		__install_amazon
		;;

	Suse)
		__install_suse
		;;

	Arch)
		__install_arch
		;;

	*)
		echo "Sorry, no supported distribution"
		exit
esac

__ecagent_configure
__ecagent_check
__resizefs

echo "Done."
