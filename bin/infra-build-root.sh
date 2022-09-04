#!/bin/sh

# Option to run this when rootfs gets instantiated/initalized/booted
# Todo - maybe I can invoke rootfsoverlay at the end of this script to share some logic between the two scrips

# Soft goal - try to keep the wire size (compressed) under 2GB and uncompressed size under 5 GB

. ./infra-env.sh

# Find out the OS running on
if [ -z "$RELEASE" ]; then

  if [ -f /etc/os-release ]; then
   . /etc/os-release
  fi

  RELEASE=$VERSION_CODENAME
  if [ -z "$RELEASE" ]; then
    RELEASE=$(echo $VERSION | sed -rn 's|.+\((.+)\).+|\1|p')
  fi
fi

cd /

export DEBIAN_FRONTEND=noninteractive

PATH=/tmp:$PATH

# order of increased package lists
# container, base, extra
if ! [ -z "$1" ]; then
  TARGET="$1"
else
  TARGET="extra"
fi

echo "Building $RELEASE $TARGET"

if [ "$TARGET" = "container" ]; then
  packages_update_db.sh
  packages_upgrade.sh
  install_my_packages.sh packages-packages.l
fi

########## BASE

# bootable on baremetal
if [ "$TARGET" = "base" ]; then
# Disable installing recommended and suggested packages by default
mkdir -p etc/apt/apt.conf.d/
printf "APT::Install-Recommends false;\nAPT::Install-Suggests false;\n" > etc/apt/apt.conf.d/99local

# Enable package updates before installing rest of packages
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} main universe" > etc/apt/sources.list

mkdir -p etc/apt/sources.list.d
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security main universe" >> etc/apt/sources.list.d/security.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-updates main universe" >> etc/apt/sources.list.d/updates.list

packages_update_db.sh
packages_upgrade.sh

install_my_packages.sh packages-boot.l
install_my_packages.sh packages-base-baremetal.l
fi

########## EXTRA

if [ "$TARGET" = "extra" ]; then
# Could run on my base image or other distro's base image
# Does not need to be bootable

#wget --no-check-certificate -q -O - https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
#echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > etc/apt/sources.list.d/github-cli.list

if ! [ -z "${NVIDIA}" ]; then
  # Install nvidea driver - this is the only package from restricted source
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} restricted" > etc/apt/sources.list.d/restricted.list
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security restricted" >> etc/apt/sources.list.d/restricted.list
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-updates restricted" >> etc/apt/sources.list.d/restricted.list
fi

packages_update_db.sh

if ! [ -z "${NVIDIA}" ]; then
  install_my_package.sh xserver-xorg-video-nvidia-${NVIDIA}

  # Make sure that only restricted package installed is nvidia
  rm etc/apt/sources.list.d/restricted.list
fi

packages_update_db.sh
packages_upgrade.sh

install_my_packages.sh packages-core.l
install_my_packages.sh packages-services.l
install_my_packages.sh packages-x11.l
install_my_packages.sh packages-x11apps.l
install_my_packages.sh packages-filesystems.l
install_my_packages.sh packages-packages.l
install_my_packages.sh packages-extra.l

infra-install-vmware-workstation.sh

# nxmachine
echo "nx:x:401:nobody" >> /etc/group
adduser --disabled-password --uid 401 --gid 401 --shell "/etc/NX/nxserver" --home "/var/NX/nx" --gecos "" nx

wget --no-verbose --no-check-certificate https://download.nomachine.com/download/7.7/Linux/nomachine_7.7.4_1_amd64.deb

dpkg -i *.deb
rm -rf *.deb /usr/NX/etc/keys /usr/NX/etc/sshstatus /usr/NX/etc/usb.db* /usr/NX/etc/*.lic /usr/NX/etc/nxdb /usr/NX/etc/uuid /usr/NX/etc/node.cfg /usr/NX/etc/server.cfg /var/NX/nx/.ssh

# caddy
wget --no-verbose --no-check-certificate https://github.com/caddyserver/caddy/releases/download/v2.4.6/caddy_2.4.6_linux_amd64.deb
dpkg -i *.deb
rm -rf *.deb /etc/systemd/system/multi-user.target.wants/caddy.service

# tailscale
curl -fsSL https://tailscale.com/install.sh | sh

fi
