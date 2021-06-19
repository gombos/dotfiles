# Purpose: HW-only packages
# Can be booted with an EFI partition
# Allows to further setup and configure the system
# Does not change often

# init
systemd-sysv
udev
sudo

# --- below packages are optional for boot

# boot
efibootmgr
kexec-tools # soft reboot (without bootloader)
friendly-recovery

# networking
dnsmasq-base
ifupdown
isc-dhcp-client
network-manager
ethtool
wakeonlan
wget

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

# laptop
thermald # monitors and controls temperature in laptops
tlp # tweaking kernel settings that affect power consumption.
tlp-rdw # disable radio (wifi, bluetooth) triggered by events to save power
