# Purpose: HW-only packages
# Can be booted with an EFI partition
# Allows to further setup and configure the system
# Does not change often

# firware
# NEO needs this for networking
linux-firmware

# init
systemd-sysv
udev

# tools
sudo
wget

# --- below packages are all optional

# boot
efibootmgr
kexec-tools #soft reboot (without bootloader)

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

# laptop
thermald # monitors and controls temperature in laptops
tlp # tweaking kernel settings that affect power consumption.
tlp-rdw # disable radio (wifi, bluetooth) triggered by events to save power
