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

PATH=$SCRIPTS:$PATH

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
  packages_update_db.sh
  packages_upgrade.sh
  install_my_packages.sh packages-packages.l
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

packages_update_db.sh
packages_upgrade.sh

install_my_packages.sh packages-base.l
install_my_packages.sh packages-base-optional.l

fi
# end of base packages

# rootfs customizations - both for base and full

#install_my_package.sh locales
#locale-gen --purge en_US.UTF-8
#update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

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

packages_update_db.sh

if ! [ -z "${NVIDIA}" ]; then
  install_my_package.sh xserver-xorg-video-nvidia-${NVIDIA}
fi

# Make sure that only restricted package installed is nvidia
rm etc/apt/sources.list.d/restricted.list

packages_update_db.sh
packages_upgrade.sh

install_my_packages.sh packages-services.l
install_my_packages.sh packages-x11.l
install_my_packages.sh packages-x11apps.l

install_my_packages.sh packages-filesystems.l
install_my_packages.sh packages-packages.l

install_my_packages.sh packages-extra.l

$SCRIPTS/infra-install-vmware-workstation.sh

fi
