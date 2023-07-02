# Purpose: baremetal only packages

# debian system
apt-file
apt-transport-https
apt-utils
ca-certificates

# tools - should be first
locales
fuse3
wget
gpg
gpg-agent

# Full HW support
# device firmware
#linux-firmware
firmware-linux
firmware-iwlwifi

# boot
grub-common
efibootmgr
kexec-tools #soft reboot (without bootloader)

# networking
dnsmasq-base
ifupdown
isc-dhcp-client
ethtool
wakeonlan
openssh-server

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

# memory
procps
