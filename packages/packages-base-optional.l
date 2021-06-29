# Purpose: HW-only packages
# firware
linux-firmware

# boot
efibootmgr
kexec-tools #soft reboot (without bootloader)
cloud-init # to make the image compatible with cloud providers

# networking
dnsmasq-base
ifupdown
isc-dhcp-client
network-manager
ethtool
wakeonlan

# storage
hdparm
smartmontools
udisks2
scsitools

# wireless
rfkill
wireless-tools
bluez

# devices
uhubctl
usb-modeswitch
usbrelay
usbutils
libblockdev-crypto2
libu2f-udev
cpufreq-info
lm-sensors
dmidecode
open-vm-tools-desktop

# laptop
thermald # monitors and controls temperature in laptops
tlp # tweaking kernel settings that affect power consumption.
tlp-rdw # disable radio (wifi, bluetooth) triggered by events to save power

# tools
wget
gpg
gpg-agent

# debian system
apt-file
apt-transport-https
apt-utils
