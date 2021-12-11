#!/bin/sh

# Option to run this when rootfs gets instantiated/initalized/booted
# Todo - maybe I can invoke rootfsoverlay at the end of this script to share some logic between the two scrips

# Soft goal - try to keep the wire size (compressed) under 2GB and uncompressed size under 5 GB

# Find out the OS running on

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

. ./infra-env.sh

cd /

export DEBIAN_FRONTEND=noninteractive

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

if [ -z "$RELEASE" ]; then
  RELEASE=$VERSION_CODENAME
  if [ -z "$RELEASE" ]; then
    RELEASE=$(echo $VERSION | sed -rn 's|.+\((.+)\).+|\1|p')
  fi
fi

# order of increased package lists
# container, base, extra
if ! [ -z "$1" ]; then
  TARGET="$1"
else
  TARGET="extra"
fi

install_my_package() {
  if [ -f /usr/bin/apt-get ]; then
    apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 "$@"
  else
    if [ -f usr/local/bin/pacapt ]; then
      if [ "$ID" = "alpine" ]; then
        usr/local/bin/pacapt -S "$@"
      else
        usr/local/bin/pacapt -S --noconfirm "$@"
      fi
    fi
  fi
}

remove_my_package() {
  if [ -f usr/local/bin/pacapt ]; then
    usr/local/bin/pacapt -R --noconfirm "$1"
  else
    apt-get purge -y -qq -o Dpkg::Use-Pty=0 "$1"
  fi
}

install_my_packages() {
#  cat $SCRIPTS/$1 | cut -d\# -f 1 | cut -d\; -f 1 | sed '/^$/d' | awk '{print $1;}' | while read in;
  P=`cat $SCRIPTS/$1 | cut -d\# -f 1 | cut -d\; -f 1 | sed '/^$/d' | awk '{print $1;}' | tr '\n' ' \0'`
  install_my_package $P
}

packages_update_db() {
  if [ -f usr/local/bin/pacapt ]; then
    usr/local/bin/pacapt -Sy
  fi

  apt-get update -y -qq -o Dpkg::Use-Pty=0
}

packages_upgrade() {
  if [ -f usr/local/bin/pacapt ]; then
    usr/local/bin/pacapt -Suy
  fi

  apt-get upgrade -y -qq -o Dpkg::Use-Pty=0
}

echo "Building $RELEASE $TARGET"

# Directory tree
# Allow per-machine/per-instance /boot /etc /usr /home /var

# Symlink some directories normally on / to /var to allow more per-machine/per-instance configuration

# Following packages are mandatory for all debian based systems
# base-files base-passwd bash bsdutils coreutils dash debconf debianutils diffutils dpkg e2fsprogs findutils grep gzip hostname init-system-helpers login lsb-base mawk mount logsave
# ncurses-base ncurses-bin passwd perl-base procps sed sensible-utils sysvinit-utils tar util-linux

# Additional packages installed after boostrap
# adduser apt apt-utils fdisk gcc-10-base gpg gpg-agent gpgconf gpgv locales pinentry-curses readline-common systemd systemd-sysv systemd-timesyncd ubuntu-keyring wget

if [ "$TARGET" = "container" ]; then
  packages_update_db
  packages_upgrade
  install_my_packages packages-packages.l
fi

# /var/tmp points to /tmp
rm -rf var/tmp
ln -sf /tmp var/tmp

# Symlink some directories normally on / to /usr to allow to share between machines/instances
mv opt usr
ln -sf usr/opt

if [ "$TARGET" = "base" ]; then
# Disable installing recommended and suggested packages by default
mkdir -p etc/apt/apt.conf.d/
printf "APT::Install-Recommends false;\nAPT::Install-Suggests false;\n" > etc/apt/apt.conf.d/99local

# Enable package updates before installing rest of packages
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} main universe" > etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security main universe" >> etc/apt/sources.list.d/updates.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-updates main universe" >> etc/apt/sources.list.d/updates.list

packages_update_db
packages_upgrade

install_my_packages packages-base.l
install_my_packages packages-base-optional.l

fi
# end of base packages

# rootfs customizations - both for base and full

install_my_package locales
locale-gen --purge en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

########## EXTRA

if [ "$TARGET" = "extra" ]; then
# Could run on my base image or other distro's base image
# Does not need to be bootable
echo "building extra"

# chrome
wget --no-check-certificate -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo 'deb http://dl.google.com/linux/chrome/deb stable main' > etc/apt/sources.list.d/google-chrome.list

wget --no-check-certificate -q -O - https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > etc/apt/sources.list.d/github-cli.list

if ! [ -z "${NVIDIA}" ]; then
  # Install nvidea driver - this is the only package from restricted source
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} restricted" > etc/apt/sources.list.d/restricted.list
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security restricted" >> etc/apt/sources.list.d/restricted.list
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-updates restricted" >> etc/apt/sources.list.d/restricted.list
fi

packages_update_db

if ! [ -z "${NVIDIA}" ]; then
  install_my_package xserver-xorg-video-nvidia-${NVIDIA}
fi

# Make sure that only restricted package installed is nvidia
rm etc/apt/sources.list.d/restricted.list

packages_update_db
packages_upgrade

install_my_packages packages-services.l
install_my_packages packages-x11.l
install_my_packages packages-x11apps.l

install_my_packages packages-filesystems.l
install_my_packages packages-packages.l

install_my_packages packages-extra.l

$SCRIPTS/infra-install-vmware-workstation.sh

fi

