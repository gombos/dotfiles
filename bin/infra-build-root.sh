#!/bin/sh

# Option to run this when rootfs gets instantiated/initalized/booted
# Todo - maybe I can invoke rootfsoverlay at the end of this script to share some logic between the two scrips

# Soft goal - try to keep the wire size (compressed) under 2GB and uncompressed size under 5 GB

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

if [ "$TARGET" = "container" ]; then
  #/usr/bin/pacman --noconfirm -Syu
  packages_update_db.sh
  packages_upgrade.sh
  install_my_packages.sh packages-packages.l packages-container.l packages-core.l packages-distrobox.l
  # todo - install more packages to container
  # packages-apps.l packages-*linux.l "packages*-$ID.l"
fi

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

install_my_packages.sh packages-boot.l packages-core.l

# tailscale
curl -fsSL https://tailscale.com/install.sh | sh

cd bin && rm -rf sh && ln -s bash sh && cd -

rm var/lib/dpkg/info/dash.*rm

#dpkg --remove --force-remove-essential dash
#rm -rf var/lib/dpkg/triggers/
#dpkg -P --force-remove-essential --force-all --no-triggers debianutils

apt-get remove -y --allow-remove-essential mawk # prefer gawk
apt-get remove -y --allow-remove-essential dash # prefer bash

cd bin &&
  rm -rf 1sh 1awk 1which &&
  ln -fs bash sh &&
  ln -fs gawk awk &&
  ln -fs which.debianutils which &&
cd -

# remove alternative symlinks from base
cd usr/bin && ls -la | grep /etc/alternatives | cut -d\- -f1  | rev  | cut -d' ' -f2  | rev | xargs rm && cd -

# debug
#dpkg -l
cd usr/bin && ls -la && cd -
fi

########## EXTRA

if [ "$TARGET" = "extra" ]; then
# Could run on my base image or other distro's base image
# Does not need to be bootable
# todo - make this a systemextension squashfs image

packages_update_db.sh

install_my_packages.sh packages-base-baremetal.l

wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
sh -c 'echo "deb [arch=$(dpkg --print-architecture)] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'

packages_update_db.sh

install_my_packages.sh packages-apps.l packages-*linux.l "packages*-$ID.l" packages-x11-debian.l packages-container.l packages-packages.l

infra-install-vmware-workstation.sh

# tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# configure flatpack
rm -rf /var/lib/flatpak/repo
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

fi

# container only....

if [ "$TARGET" = "container" ]; then

echo "Using $ID"

PATH=$PATH:.

if [ "$ID" = "arch" ]; then
  echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
  pacman -Syyu
#  useradd -m build
#  pacman --noconfirm -Syu base-devel git sudo cargo
#  su build -c 'cd && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -s --noconfirm'
#  pacman -U --noconfirm ~build/paru/*.pkg.tar.*
fi

packages_update_db.sh
install_my_packages.sh packages-packages.l packages-apps.l packages-*linux.l "packages*-$ID.l" packages-distrobox.l packages-core.l packages-packages-extra.l

# use this install script only during initial container creation
rm -rf /usr/sbin/aur-install

# python venv
apt-get install -y python3-venv
/usr/bin/python3 -m venv /usr/local/
/usr/local/bin/python3 -m pip install --upgrade pip
/usr/local/bin/pip install --upgrade pip

# pipx
/usr/local/bin/pip3 install pipx
#pip install osxphotos

# appimage - digikam
mkdir -p /usr/local/bin/
wget --quiet https://download.kde.org/stable/digikam/${DIGIKAM}/digiKam-${DIGIKAM}-x86-64.appimage -O /usr/local/bin/digikam
chmod +x /usr/local/bin/digikam

if [ "$ID" = "arch" ]; then
  /usr/bin/pacman --noconfirm -Syu

  # make i point to pacapt
  curl -Lo /usr/local/bin/pacapt https://github.com/icy/pacapt/raw/ng/pacapt && chmod 755 /usr/local/bin/pacapt
  mv /usr/bin/pacman /usr/local/bin/
  mv /usr/bin/paru /usr/bin/pacman
fi

fi
