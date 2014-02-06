#!/bin/sh

LOG_FILE=/root/ecm_agent_install.log
ECAGENT_PKG="ecmanaged-ecagent"
ECAGENT_PATH=/opt/ecmanaged/ecagent
ECAGENT_INIT=/etc/init.d/ecagentd
UUID=

_install_debian() {
  SOURCE_APT_ECM="deb http://apt.ecmanaged.com stable stable"
  
  export DEBIAN_FRONTEND=noninteractive

  if [ -d /etc/apt/sources.list.d ]; then
    echo ${SOURCE_APT_ECM}    > /etc/apt/sources.list.d/ecmanaged-stable.list
    
  else
    echo ${SOURCE_APT_ECM}    >> /etc/apt/sources.list
  fi
  
  # Install ECmanaged key
  wget -q -O- "http://apt.ecmanaged.com/key.asc" | apt-key add - >/dev/null 2>&1
  
  # Install Agent and update PuppetLabs repos
  apt-get -y update
  apt-get install --force-yes --yes --no-install-recommends -o DPkg::Options::=--force-confold ${ECAGENT_PKG}
  apt-get install --force-yes --yes --no-install-recommends -o DPkg::Options::=--force-confold puppetlabs-release
  /bin/rm -f /etc/apt/sources.list.d/puppetlabs-stable.list
}

_install_redhat() {
  SOURCE_YUM_EPEL="[ecmanaged-epel]\nname=Extra Packages for Enterprise Linux \$releasever - \$basearch\n#baseurl=http://download.fedoraproject.org/pub/epel/${RELEASE}/\$basearch\nmirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-debug-${RELEASE}&arch=\$basearch\nfailovermethod=priority\nenabled=0\ngpgcheck=0\ngpgkey=http://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-\$releasever"
  _install_yum
}

_install_fedora() {
  _install_yum
}

_install_amazon() {
  RELEASE=6
  _install_redhat
}

_install_yum() {
  SOURCE_YUM_ECM="[ecmanaged-stable]\nname=ECManaged stable Packages\nbaseurl=http://rpm.ecmanaged.com\nenabled=1\ngpgcheck=1"
  
  if [ -d /etc/yum.repos.d ]; then
    echo -e ${SOURCE_YUM_ECM}    > /etc/yum.repos.d/ecmanaged-stable.repo
    echo -e ${SOURCE_YUM_EPEL}   > /etc/yum.repos.d/ecmanaged-epel.repo
    
  else
    echo -e ${SOURCE_YUM_ECM}    >> /etc/yum.conf
    echo -e ${SOURCE_YUM_EPEL}   >> /etc/yum.conf
  fi

  # Install ECmanaged Agent
  yum -y clean all
  yum --enablerepo=ecmanaged-epel --nogpgcheck -y install ${ECAGENT_PKG}
}

_get_distrib() {
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

_ecagent_check() {
  # Start agent if not installed
  echo "Check ECAgent running..."
  /etc/init.d/ecagentd check
}

_resizefs() {
  # Try to resize filesystem
  echo "Resizing ROOT filesystem..."
  resize2fs $(df -l /|grep dev|cut -f1 -d' ')
}

_configure_agent() {
  if [ $UUID ]; then
    ${ECAGENT_INIT} stop > /dev/null 2>&1
    pkill -f ecagent > /dev/null 2>&1
    ${ECAGENT_PATH}/configure.py $UUID
  fi
}

# main()
_get_distrib
echo "Installing ${ECAGENT_PKG} on ${DISTRO} release ${RELEASE} ($ARCH bits)"
case ${DISTRO} in
	Debian|Ubuntu)
		_install_debian
		;;
	Redhat|Centos)
		_install_redhat
		;;
	Fedora)
		_install_fedora
		;;
	Amazon)
		_install_amazon
		;;
	Suse)
		_install_suse
		;;
	Arch)
		_install_arch
		;;
	*)
		echo "Sorry, no supported distribution"
		exit
esac

_configure_agent
_ecagent_check
_resizefs