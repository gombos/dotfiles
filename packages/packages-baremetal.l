# Purpose: HW-only packages
# Can be booted with an EFI partition
# Allows to further setup and configure the system

# boot
efibootmgr
kexec-tools # soft reboot (without bootloader)
friendly-recovery

# bootmanager, init
systemd-sysv
sudo

# networking
dnsmasq-base
ifupdown
isc-dhcp-client
network-manager
ethtool

# storage
hdparm
smartmontools
udisks2

# wireless
rfkill
wireless-tools
bluez

# devices
udev
uhubctl
usb-modeswitch
usbrelay
usbutils
libblockdev-crypto2
libu2f-udev

# laptop
thermald # monitors and controls temperature in laptops
tlp # tweaking kernel settings that affect power consumption.
tlp-rdw # disable radio (wifi, bluetooth) triggered by events to save power
