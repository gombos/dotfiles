#!/bin/bash

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

# restricted multiverse

# ubuntu - universe
if [ "$ID" = "ubuntu" ]; then
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} main universe" > etc/apt/sources.list
  echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security main universe" >> etc/apt/sources.list
fi

# debian security updates
#if [ "$ID" = "debian" ]; then
#  echo "deb http://security.debian.org/debian-security ${RELEASE}-security main" >> etc/apt/sources.list
#fi

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

# latest tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# remove all package dependencies
sed -ni '/^Depends:/!p' /var/lib/dpkg/status
sed -ni '/^PreDepends:/!p' /var/lib/dpkg/status

# debian specific
apt-get purge -y --allow-remove-essential sensible-utils ucf util-linux-extra adduser passwd dmsetup runit-helper dbus dbus-bin dbus-daemon dbus-session-bus-common dbus-system-bus-common

# modern version of essential packages
apt-get purge -y --allow-remove-essential mawk # prefer gawk

# /bin/sh --> /bin/bash (so that we can remove dash)
cd bin && rm -rf sh && ln -s bash sh && cd -
rm var/lib/dpkg/info/dash.*rm
sed -i 's/\/bin\/sh/\/bin\/dash/' var/lib/dpkg/info/dash.list
apt-get purge -y --allow-remove-essential dash

cd bin &&
  ln -fs gawk awk &&
  ln -fs which.debianutils which &&
cd -

rm var/lib/dpkg/info/perl-base.*rm
apt-get purge -y --allow-remove-essential perl-base

# remove alternative symlinks from base
cd usr && ls -la | grep /etc/alternatives | cut -d\- -f1  | rev  | cut -d' ' -f2  | rev | xargs rm && cd -

# 64 bit only
rm -rf /lib*32 /usr/share/zsh /usr/share/bash-completion/ /usr/share/doc/

find /usr/share/ -empty -delete

# debug
dpkg -l

rm -rf /var/lib/dpkg/info/dpkg.*rm /var/lib/dpkg/info/apt.*rm
apt-get purge -y --allow-remove-essential dpkg apt

find $(cat /var/lib/dpkg/info/debconf.list) -type f -maxdepth 0 -delete

rm -rf /var/lib/dpkg /var/lib/apt /var/log/* /var/cache/* /etc/apt/

find /var


ls -la /usr/bin

# todo
# this removes python and apparmor-utils which likely break running distrobox

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
#mkdir -m 0755 -p /etc/apt/keyrings /etc/apt/sources.list.d
#curl -fsSL https://dl.google.com/linux/linux_signing_key.pub > /etc/apt/keyrings/google.asc
#echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google.asc] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

packages_update_db.sh
packages_upgrade.sh

# DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Use-Pty=0 google-chrome-stable

install_my_packages.sh packages-packages.l
install_my_packages.sh packages-linux.l

# desktop
install_my_packages.sh packages-desktop.l
install_my_packages.sh packages-desktop-linux.l

# tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# latest distrobox
curl -L -O -s https://raw.githubusercontent.com/89luca89/distrobox/main/install
chmod +x install
./install -P /usr
rm -rf ./install

if [ "$TARGET" = "container" ]; then
  install_my_packages.sh packages-container.l

  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/sudoers

  /usr/sbin/addgroup --gid 1000 user
  /usr/sbin/adduser --disabled-password --no-create-home --uid 1000 --shell "/bin/bash" --home /home --gecos "" user --gid 1000

  sed -i "s/^sudo:.*/&,1000/" /etc/group
  sed -i "s/^docker:.*/&,1000/" /etc/group
  sed -i "s/^adm:.*/&,1000/" /etc/group
  sed -i "s/^users:.*/&,1000/" /etc/group
  sed -i "s/^kvm:.*/&,1000/" /etc/group

  # flatpack
  #rm -rf /var/lib/flatpak/repo
  #flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  #flatpak repair

  # /usr/local

  # npm packages
  npm install -g @bitwarden/cli

  # cargo packages
  sh -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | RUSTUP_HOME=/usr/local CARGO_HOME=/usr/local sh -s -- -y --no-modify-path && rustup default stable'
  RUSTUP_HOME=/usr/local CARGO_HOME=/usr/local /usr/local/bin/cargo install ripgrep_all

  # nix
  mkdir -p /nix
  echo "nixbld:x:402:nobody" >> /etc/group
  curl -L -O  https://nixos.org/nix/install
  chmod +x install
  export NIX_CONFIG='filter-syscalls = false'
  USER=root ./install --no-daemon --yes --no-channel-add --no-modify-profile
  rm -rf install
  sh -c '. /nix/var/nix/profiles/per-user/root/profile/etc/profile.d/nix.sh'
  #  && /nix/var/nix/profiles/per-user/root/profile/bin/nix-env -iA nixpkgs.apfs-fuse && /nix/var/nix/profiles/per-user/root/profile/bin/nix-channel --update && /nix/var/nix/profiles/per-user/root/profile/bin/nix-collect-garbage -d && /nix/var/nix/profiles/per-user/root/profile/bin/nix-store --verify --check-contents && /nix/var/nix/profiles/per-user/root/profile/bin/nix-store --gc && /nix/var/nix/profiles/per-user/root/profile/bin/nix-store --optimise'

  rm -rf /root/.*

  git clone https://github.com/sgan81/apfs-fuse.git
  cd apfs-fuse
  git submodule init
  git submodule update
  mkdir build
  cd build
  cmake ..
  make
  make install

  # python, pip
  # make /usr/local an additional python env
  /usr/bin/python3 -m venv /usr/local/
  /usr/local/bin/python3 -m pip install --upgrade pip
  /usr/local/bin/pip3 install yt-dlp
  /usr/local/bin/pip3 install oci-cli

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

#DEBIAN_FRONTEND=noninteractive apt-get update -y -qq -o Dpkg::Use-Pty=0
#DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

apt-get -y -qq autoremove
#dpkg --list | grep "^rc" | cut -d " " -f 3 | grep . && xargs dpkg --purge
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg --configure --pending
apt-get clean

fi
