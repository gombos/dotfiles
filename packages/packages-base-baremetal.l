# Purpose: baremetal only packages

# tools - should be first
locales
fuse3
wget
gpg
gpg-agent

# boot
grub-common
efibootmgr
kexec-tools #soft reboot (without bootloader)

# networking
ca-certificates
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
