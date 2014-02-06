#!/usr/bin/env bash

set -e

if [ "${EUID}0" -ne "00" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if which puppet > /dev/null 2>&1; then
  echo "Puppet is already installed."
  exit 0
fi

_install_arch() {
  # Update the pacman repositories
  pacman -Sy

  # Install Ruby
  pacman -S --noconfirm --needed ruby

  # Install Puppet and Facter
  gem install puppet facter --no-ri --no-rdoc --no-user-install
}

_install_ubuntu() {
  export DEBIAN_FRONTEND=noninteractive
  
  # Load up the release information
  . /etc/lsb-release

  REPO_DEB_URL="http://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"

  # Install via APT using REPO
  _install_apt
}

_install_debian() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update >/dev/null

  # Older versions of Debian don't have lsb_release by default, so 
  # install that if we have to.
  which lsb_release || apt-get -y install lsb-release

  # Load up the release information
  DISTRIB_CODENAME=$(lsb_release -c -s)
  REPO_DEB_URL="http://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"

  # Install via APT using REPO
  _install_apt
}

_install_apt() {
  APT_OPS='--force-yes --yes --no-install-recommends -o DPkg::Options::=--force-confold'

  # Do the initial apt-get update
  echo "Initial apt-get update..."
  apt-get update >/dev/null

  # Install wget if we have to (some older Debian versions)
  echo "Installing wget..."
  apt-get ${APT_OPTS} install wget >/dev/null

  # Install the PuppetLabs repo
  echo "Configuring PuppetLabs repo..."
  repo_deb_path=$(mktemp)
  wget --output-document="${repo_deb_path}" "${REPO_DEB_URL}" 2>/dev/null

  dpkg -i "${repo_deb_path}" >/dev/null
  apt-get update >/dev/null

  # Install Puppet
  echo "Installing Puppet..."
  apt-get ${APT_OPTS} install puppet >/dev/null
}

_install_yum() {
  # Install puppet labs repo
  echo "Configuring PuppetLabs repo..."
  repo_path=$(mktemp)
  
  yum -y clean all
  yum --nogpgcheck -y install wget
  
  wget --output-document="${repo_path}" "${REPO_URL}" 2>/dev/null
  rpm -i "${repo_path}" >/dev/null
    
  # Install Puppet...
  echo "Installing puppet"
  yum --nogpgcheck -y install puppet > /dev/null
}

_install_centos5() {
  REPO_URL="http://yum.puppetlabs.com/el/5/products/i386/puppetlabs-release-5-7.noarch.rpm"
  _install_yum
}

_install_centos6() {
  REPO_URL="http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm"
  _install_yum
}

_install_freebsd() {
  have_pkg=`grep -sc '^WITH_PKGNG' /etc/make.conf`

  echo "Installing Puppet & dependencies..."
  if [ "$have_pkg" = 1 ]
  then
    export ASSUME_ALWAYS_YES=yes
    pkg install sysutils/puppet
    unset ASSUME_ALWAYS_YES
  else
    pkg_add -r puppet
  fi
}

_install_suse() {
  echo "Not supported yet"
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

# main()
_get_distrib
echo "Installing puppet on ${DISTRO} release ${RELEASE} ($ARCH bits)"
case ${DISTRO} in
  Debian)
    _install_debian
    ;;
    
  Ubuntu)
    _install_ubuntu
    ;;

  Redhat|Centos)
    case ${RELEASE} in
      5)
	_install_centos5
	;;
      6)
        _install_centos6
	;;
    esac
    ;;

  Fedora)
    _install_fedora
    ;;

  Amazon)
    _install_centos6
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

