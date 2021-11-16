# Purpose: baremetal only packages

# debian system
apt-file
apt-transport-https
apt-utils

# tools - should be first
fuse3
wget
gpg
gpg-agent

# boot
efibootmgr
kexec-tools #soft reboot (without bootloader)
archivemount

# networking
dnsmasq-base
ifupdown
isc-dhcp-client
ethtool
wakeonlan

# storage
hdparm
smartmontools
scsitools
eject

# devices
uhubctl
usbrelay
usbutils
libu2f-udev
cpufrequtils
laptop-detect
lm-sensors
dmidecode

