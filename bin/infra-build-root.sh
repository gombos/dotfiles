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

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  mkdir -p /nix
  rm -rf /nix/*

  # populate /nix and /nix/var/nix/profiles/default/ so that it is usrlocal compatible
  echo "nixbld:x:402:nobody" >> /etc/group
  rm -rf install
  #wget  https://nixos.org/nix/install
  #chmod +x install
  #USER=root ./install --no-daemon
  #. /root/.nix-profile/etc/profile.d/nix.sh
  #rm -rf install

  sudo usermod -aG sudo user

  git clone https://github.com/sgan81/apfs-fuse.git
  cd apfs-fuse
  git submodule init
  git submodule update

  mkdir build
  cd build
  cmake ..
  make

  make install

  wget https://github.com/phiresky/ripgrep-all/archive/refs/tags/v0.10.6.tar.gz
  gzip -d v0.10.6.tar.gz
  tar -xvf v0.10.6.tar
  cd ripgrep-all-0.10.6/
  cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
  export RUSTUP_TOOLCHAIN=stable
  export CARGO_TARGET_DIR=target
  cargo build --frozen --release --all-features
  install -Dm 755 target/release/rga /usr/bin/rga
  install -Dm 755 target/release/rga-preproc /usr/bin/rga-preproc
  install -Dm 755 target/release/rga-fzf /usr/bin/rga-fzf
  install -Dm 755 target/release/rga-fzf-open /usr/bin/rga-fzf-open
  cd ..
  rm -rf ripgrep-all* v0.10.6*

# export RIPGREP=0.10.6
# export AA=$(uname -m)

# if [ "$AA" = "x86_64" ]; then
#   wget --quiet https://github.com/phiresky/ripgrep-all/releases/download/v${RIPGREP}/ripgrep_all-v${RIPGREP}-${AA}-unknown-linux-musl.tar.gz
# else
#   wget --quiet https://github.com/phiresky/ripgrep-all/releases/download/v${RIPGREP}/ripgrep_all-v${RIPGREP}-arm-unknown-linux-gnueabihf.tar.gz
# fi
fi

#/usr/bin/pacman --noconfirm -Syu
# todo - install more packages to container

# configure flatpack
#rm -rf /var/lib/flatpak/repo
#flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# use this install script only during initial container creation
#rm -rf /usr/sbin/aur-install

# python venv
#apt-get install -y python3-venv
#/usr/bin/python3 -m venv /usr/local/
#/usr/local/bin/python3 -m pip install --upgrade pip
#/usr/local/bin/pip install --upgrade pip

# pipx
#/usr/local/bin/pip3 install pipx
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
