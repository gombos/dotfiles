#!/bin/sh

# three rootfs
# initramfs with systemd - base
# sysext - extra
# docker container - container

if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cp $REPO/packages/* /tmp/
  cd /tmp
fi

. ./infra-env.sh

cd /

if [ -f /etc/os-release ]; then
 . /etc/os-release

  RELEASE=$VERSION_CODENAME
  if [ -z "$RELEASE" ]; then
    RELEASE=$(echo $VERSION | sed -rn 's|.+\((.+)\).+|\1|p')
  fi
fi

export DEBIAN_FRONTEND=noninteractive

PATH=/tmp:$PATH

# order of increased package lists
# container, base, extra
if ! [ -z "$1" ]; then
  TARGET="$1"
else
  TARGET="extra"
fi

echo "Building $RELEASE $TARGET on $ID"

########## BASE

# bootable on baremetal
# supports https://www.freedesktop.org/software/systemd/man/systemd-sysext.html

if [ "$TARGET" = "base" ]; then
# Disable installing recommended and suggested packages by default
mkdir -p etc/apt/apt.conf.d/
printf "APT::Install-Recommends false;\nAPT::Install-Suggests false;\n" > etc/apt/apt.conf.d/99local

# ubuntu - universe
#echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} main universe" > etc/apt/sources.list
#echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security main universe" >> etc/apt/sources.list

# debian security updates
if [ "$ID" = "debian" ]; then
  echo "deb https://deb.debian.org/debian ${RELEASE} main" > etc/apt/sources.list
  echo "deb https://security.debian.org/debian-security stable-security/updates main" >> etc/apt/sources.list
fi

## docker-ce
#packages_update_db.sh
#pi ca-certificates curl gnupg
#
#install -m 0755 -d etc/apt/keyrings
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o etc/apt/keyrings/docker.gpg
#chmod a+r etc/apt/keyrings/docker.gpg
##echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. etc/os-release && echo "$RELEASE") stable" | tee etc/apt/sources.list.d/docker.list > /dev/null
#echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. etc/os-release && echo "$RELEASE") stable" | tee etc/apt/sources.list.d/docker.list > /dev/null

packages_update_db.sh
packages_upgrade.sh

# services that are REQUIRED to start at boot
# sysext is not ready at boot

install_my_packages.sh packages-boot.l
install_my_packages.sh packages-essential.l

# tailscale
curl -fsSL https://tailscale.com/install.sh | sh

cd bin && rm -rf sh && ln -s bash sh && cd -

rm var/lib/dpkg/info/dash.*rm

#dpkg --remove --force-remove-essential dash
#rm -rf var/lib/dpkg/triggers/
#dpkg -P --force-remove-essential --force-all --no-triggers debianutils

# modern version of essential packages
apt-get remove -y --allow-remove-essential mawk # prefer gawk
apt-get remove -y --allow-remove-essential dash # prefer bash

cd bin &&
  ln -fs bash sh &&
  ln -fs gawk awk &&
  ln -fs which.debianutils which &&
cd -

# remove alternative symlinks from base
cd usr && ls -la | grep /etc/alternatives | cut -d\- -f1  | rev  | cut -d' ' -f2  | rev | xargs rm && cd -

# 64 bit only
rm -rf lib*32

# debug
#dpkg -l
#cd usr/bin && ls -la && cd -
fi

########## EXTRA

if [ "$TARGET" = "extra" ] || [ "$TARGET" = "container" ]; then
# Could run on my base image or other distro's base image
# Does not need to be bootable
# todo - make this a systemextension squashfs image

#PATH=$PATH:.

#if [ "$ID" = "arch" ]; then
#  echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
#  pacman -Syyu
##  useradd -m build
##  pacman --noconfirm -Syu base-devel git sudo cargo
##  su build -c 'cd && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -s --noconfirm'
##  pacman -U --noconfirm ~build/paru/*.pkg.tar.*
#fi

# order is significant
packages_update_db.sh
install_my_packages.sh packages-boot.l
install_my_packages.sh packages-essential.l

# configure google repository
mkdir -m 0755 -p /etc/apt/keyrings /etc/apt/sources.list.d
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub > /etc/apt/keyrings/google.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google.asc] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

packages_update_db.sh
packages_upgrade.sh

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Use-Pty=0 google-chrome-stable

install_my_packages.sh packages-packages.l
install_my_packages.sh packages-linux.l
#install_my_packages.sh packages-debian.l

# desktop
install_my_packages.sh packages-desktop.l
install_my_packages.sh packages-desktop-linux.l

# tailscale
curl -fsSL https://tailscale.com/install.sh | sh

if [ "$TARGET" = "container" ]; then
  install_my_packages.sh packages-container.l

  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/sudoers

  /usr/sbin/adduser --disabled-password --no-create-home --uid 1000 --shell "/bin/bash" --home /home --gecos "" user --gid 1000

  sed -i "s/^sudo:.*/&,1000/" /etc/group
  sed -i "s/^docker:.*/&,1000/" /etc/group
  sed -i "s/^adm:.*/&,1000/" /etc/group
  sed -i "s/^users:.*/&,1000/" /etc/group
  sed -i "s/^kvm:.*/&,1000/" /etc/group

  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1065510
  if [ -e /lib/aarch64-linux-gnu ]; then
    mv /lib/x86_64-linux-gnu/* /lib/aarch64-linux-gnu/
  fi

  # python venv, pip, pipx
  #wget --quiet -O - https://bootstrap.pypa.io/get-pip.py | python3
  #/usr/local/bin/pip3 install pipx networkx

  # flatpack
  rm -rf /var/lib/flatpak/repo
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak repair

  # npm packages
  npm install -g @bitwarden/cli

  # nix packages
  mkdir -p /nix
  echo "nixbld:x:402:nobody" >> /etc/group
  curl -L -O  https://nixos.org/nix/install
  chmod +x install
  export NIX_CONFIG='filter-syscalls = false'
  USER=root ./install --no-daemon --yes
  rm -rf install
  /nix/var/nix/profiles/per-user/root/profile
  sh -c '. /nix/var/nix/profiles/per-user/root/profile/etc/profile.d/nix.sh  && /nix/var/nix/profiles/per-user/root/profile/bin/nix-env -iA nixpkgs.ripgrep-all nixpkgs.apfs-fuse'

  # let uid 1000 manage /nix and /usr/local
  chown -R 1000:1000 /nix /usr/local
fi

#/usr/bin/pacman --noconfirm -Syu
# todo - install more packages to container

#pip install osxphotos

# appimage - digikam
#mkdir -p /usr/local/bin/
#wget --quiet https://download.kde.org/stable/digikam/${DIGIKAM}/digiKam-${DIGIKAM}-x86-64.appimage -O /usr/local/bin/digikam
#chmod +x /usr/local/bin/digikam

#if [ "$ID" = "arch" ]; then
#  /usr/bin/pacman --noconfirm -Syu

  # make i point to pacapt
#  curl -Lo /usr/local/bin/pacapt https://github.com/icy/pacapt/raw/ng/pacapt && chmod 755 /usr/local/bin/pacapt
#  mv /usr/bin/pacman /usr/local/bin/
#  mv /usr/bin/paru /usr/bin/pacman
#fi

DEBIAN_FRONTEND=noninteractive apt-get update -y -qq -o Dpkg::Use-Pty=0
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

apt-get -y -qq autoremove
dpkg --list | grep "^rc" | cut -d " " -f 3 | grep . && xargs dpkg --purge
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg --configure --pending
apt-get clean

fi
