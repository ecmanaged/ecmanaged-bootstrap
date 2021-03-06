#!/bin/sh -x

set +e

LOG_FILE=/root/ecm_agent_install.log
ECAGENT_PKG=ecmanaged-ecagent
CLOUDINIT_PKG=cloud-init
ECAGENT_PATH=/opt/ecmanaged/ecagent
ECAGENT_INIT=/opt/ecmanaged/ecagent/init
UUID=
ACCOUNT=

exec > ${LOG_FILE} 2>&1

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
  apt-get ${APT_OPS} install --only-upgrade ${CLOUDINIT_PKG}

  # Install dependencies
  apt-get ${APT_OPS} install PackageKit gir1.2-packagekitglib-1.0
  
  # Install ECmanaged key
  wget -q -O- "http://apt.ecmanaged.com/key.asc" | apt-key add - >/dev/null 2>&1
  
  # Install ECM Agent
  apt-get ${APT_OPS} install ${ECAGENT_PKG}
}

__install_amazon() {
  RELEASE=6
  __install_redhat

  # Use twisted 2.6 (no support for psutil on 2.7)
  if [ ! `which twisted` ]; then
    sed -e 's/bin\/twistd}/bin\/twistd-2.6}/' -i ${ECAGENT_INIT} >/dev/null 2>&1
  fi
    
  # Use python 2.6 on agent plugins
  if [ `which python2.6` ]; then
    sed -e "s/python_interpreter_linux.*/python_interpreter_linux  = \/usr\/bin\/python2.6/" -i ${ECAGENT_PATH}/config/ecagent.init.cfg >/dev/null 2>&1
    /bin/rm /etc/alternatives/python
    ln -s /usr/bin/python2.6 /etc/alternatives/python
  fi
  
  # Restart
  ${ECAGENT_INIT} restart
}

__install_redhat() {
  SOURCE_YUM_EPEL="[ecmanaged-epel]\nname=Extra Packages for Enterprise Linux \$releasever - \$basearch\n#baseurl=http://download.fedoraproject.org/pub/epel/${RELEASE}/\$basearch\nmirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-${RELEASE}&arch=\$basearch\nfailovermethod=priority\nenabled=0\ngpgcheck=0\ngpgkey=http://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-\$releasever"
  SOURCE_YUM_ECM="[ecmanaged-stable]\nname=ECManaged stable Packages\nbaseurl=http://rpm.ecmanaged.com/epel/${RELEASE}\nenabled=1\ngpgcheck=0"
  SOURCE_YUM_CENTOS="[ecmanaged-centos]\nname=CentOS-Base\nmirrorlist=http://mirrorlist.centos.org/?release=${RELEASE}&arch=\$basearch&repo=os\ngpgcheck=0\nenabled=0\ngpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-${RELEASE}\n\n[ecmanaged-centos-updates]\nname=CentOS-Updates\nmirrorlist=http://mirrorlist.centos.org/?release=${RELEASE}&arch=\$basearch&repo=updates\ngpgcheck=0\nenabled=0\ngpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-${RELEASE}\n"

  echo -e ${SOURCE_YUM_ECM} > /etc/yum.repos.d/ecmanaged-stable.repo

  # Add centos repo to not subscribed Redhat
  if [ "${DISTRO}" == "Redhat" ]; then
      if subscription-manager list|grep ^Status|grep -q 'Not'; then
	echo -e ${SOURCE_YUM_CENTOS} > /etc/yum.repos.d/ecmanaged-centos.repo
        CENTOS_REPO="--enablerepo=ecmanaged-centos --enablerepo=ecmanaged-centos-updates"
      fi
  fi
      
  # Add epel repo if not is Fedora 
  if [ "${DISTRO}" != "Fedora" ]; then
      echo -e ${SOURCE_YUM_EPEL} > /etc/yum.repos.d/ecmanaged-epel.repo
      EPEL_REPO="--enablerepo=ecmanaged-epel"
  fi

  # install dependency
  yum install pygobject3 PolicyKit PackageKit -y

  # Install ECM Agent
  yum -y clean all

  if [ "${DISTRO}" != "Fedora" ]; then
    yum --enablerepo=ecmanaged-stable ${EPEL_REPO} ${CENTOS_REPO} --nogpgcheck -y install ${ECAGENT_PKG}
  else
    yum --enablerepo=ecmanaged-stable --nogpgcheck -y install ${ECAGENT_PKG}
  fi
}

__install_arch() {
  echo "Not supported"
}

__install_suse() {
    DISTRO_REPO="openSUSE_${DISTRO_MAJOR_VERSION}.${DISTRO_MINOR_VERSION}"

    # Is the repository already known
    $(zypper repos | grep devel_languages_python >/dev/null 2>&1)
    if [ $? -eq 1 ]; then
        # zypper does not yet know nothing about devel_languages_python
        zypper --non-interactive addrepo --refresh \
            http://download.opensuse.org/repositories/devel:/languages:/python/${DISTRO_REPO}/devel:languages:python.repo || return 1
    fi

    zypper --gpg-auto-import-keys --non-interactive refresh
    exitcode=$?
    if [ $? -ne 0 ] && [ $? -ne 4 ]; then
        # If the exit code is not 0, and it's not 4(failed to update a
        # repository) return a failure. Otherwise continue.
        return 1
    fi

    if [ $DISTRO_MAJOR_VERSION -eq 12 ] && [ $DISTRO_MINOR_VERSION -eq 3 ]; then
        # Because patterns-openSUSE-minimal_base-conflicts conflicts with python, lets remove the first one
        zypper --non-interactive remove patterns-openSUSE-minimal_base-conflicts
    fi
    
#    zypper --non-interactive install --auto-agree-with-licenses ${CLOUDINIT_PKG}

    zypper --non-interactive install --auto-agree-with-licenses libzmq3 python \
        python-Jinja2 python-M2Crypto python-PyYAML python-msgpack-python \
        python-pycrypto python-pyzmq python-xml || return 1
    return 0   
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
    RELEASE=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))

  elif [ -f /etc/centos-release ]; then
    DISTRO='Centos'
    RELEASE=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
    
  elif [ -f /etc/redhat-release ]; then
    DISTRO='Redhat'
    RELEASE=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
  
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

__resizefs() {
  # Try to resize filesystem
  echo " * Resizing ROOT filesystem..."
  resize2fs $(df -l /|grep dev|cut -f1 -d' ')
}

__ecagent_configure() {
  if [ ${UUID} ]; then
  echo " * Configure ECM Agent uuid..."
    ${ECAGENT_INIT} stop > /dev/null 2>&1
    ${ECAGENT_PATH}/configure.py --uuid ${UUID} --account ${ACCOUNT_ID} --server-groups {SERVER_GROUP_ID}
  fi
  
  if [ ${ACCOUNT} ]; then
  echo " * Configure ECM Agent account..."
    ${ECAGENT_PATH}/init stop > /dev/null 2>&1
    ${ECAGENT_PATH}/configure.py --account ${ACCOUNT}
    ${ECAGENT_PATH}/init start > /dev/null 2>&1
  fi
}

__userdata() {
# Placeholder for userdata
# @@PLACEHOLDER@@
  :
}

# main()

export LANG="C"
export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

# bug: http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=439763
        
unset PERL_DL_NONLAZY
unset DEBCONF_REDIR
unset DEBIAN_FRONTEND
unset DEBIAN_HAS_FRONTEND
unset DPKG_NO_TSTP

__userdata
__get_distrib

echo "Installing ${ECAGENT_PKG} on ${DISTRO} release ${RELEASE} ($ARCH bits)..."

for i in $(seq 1 60); do
  case ${DISTRO} in
    Debian|Ubuntu)
      __install_debian
      ;;
  
    Redhat|Centos|Fedora)
      __install_redhat
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

  [ -d /opt/ecmanaged/ecagent ] && break

  echo "Sleeping to try again..."
  sleep 30

done

__ecagent_configure
__resizefs

echo "Done."
