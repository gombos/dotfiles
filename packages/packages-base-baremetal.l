# Purpose: baremetal only packages

# tools - should be first
locales
fuse3
wget
gpg
gpg-agent

# boot
grub-common
kexec-tools #soft reboot (without bootloader)

# networking
ca-certificates
dnsmasq-base
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

# memory
procps

# video
xserver-xorg-video-amdgpu
xserver-xorg-video-ati
xserver-xorg-video-intel
xserver-xorg-video-nouveau
xserver-xorg-video-radeon
xserver-xorg-video-vmware
xserver-xorg-input-libinput
