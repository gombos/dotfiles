#!/bin/sh

apt-mark hold linux-image-virtual
apt-get update -y && apt-get upgrade -y
PATH=$PATH:$1/bin/
install_my_packages.sh $1/packages/packages-boot.l
install_my_packages.sh $1/packages/packages-essential.l
install_my_packages.sh $1/packages/packages-desktop.l
curl -fsSL https://tailscale.com/install.sh | sh
apt autoremove -y
apt clean -y
sh -c "rm -rf /var/lib/apt/lists/* /var/cache/apt/*"
sed -i "s|\# session.*|session=/usr/bin/openbox-session|g" etc/lxdm/lxdm.conf
sed -i "s|\#\ autologin=.*|autologin=user|g" etc/lxdm/lxdm.conf
usermod -p `openssl passwd lima` lima
