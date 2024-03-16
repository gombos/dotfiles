#!/bin/sh

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

filterpackage() {
if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]
then
  case "$1" in
    wpa_supplicant)
      echo wpasupplicant ;;
    networkmanager)
      echo network-manager ;;
    openssh)
      echo openssh-server ;;
    nfs-utils)
      echo nfs-kernel-server ;;
    apparmor)
      echo apparmor-utils ;;
    docker)
      echo docker.io ;;
    qemu)
      echo qemu-system-x86 ;;
    systemd)
      echo systemd-timesyncd systemd-resolved systemd-container ;;
    tailscale|inetutils)
      ;;
    *)
      echo "$1" ;;
  esac
elif  [ "$ID" = "arch" ]
then
 case "$1" in
    gh)
      echo github-cli ;;
    qemu)
      echo qemu-system-x86 ;;
    wireless-tools)
      echo wireless_tools ;;
    spice-webdavd)
      echo phodav ;;
    libblockdev-crypto2|uidmap)
      ;;
    *)
      echo "$1" ;;
  esac
else
  echo "$1"
fi
}

cd /tmp
cat $@ > allpackages

# install packages all at once for better dependency management and to avoid that order of packages is significant
P=`cat allpackages | cut -d\# -f 1 | cut -d\; -f 1 | sed '/^$/d' | awk '{print $1;}' | while read in;
do
  Q=$(filterpackage "$in")
  echo -n " $Q "
done`

pi $P
