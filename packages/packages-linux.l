# move some packages to container only

## Linux services
## ==============

# container services
containerd
uidmap

# power management
upower

# networking
dnsmasq
nfs-utils
hostapd
systemd

# storage
udisks2

## Linux tools
## ===========

# networking
networkd-dispatcher

systemd-ukify
python3-cryptography
systemd-timesyncd
bubblewrap
systemd-container
python3-all
python3-setuptools
python3-pytest
systemd-boot
acl
bubblewrap
ca-certificates
cpio
diffutils
dosfstools
e2fsprogs
mtools
openssl
socat
strace
swtpm
systemd
virtiofsd
xfsprogs
zstd
#mkosi

# wireless
rfkill
wireless-tools
bluez
wpa_supplicant

# laptop
#thermald # monitors and controls temperature in laptops (might not be available on arm)
tlp # kernel power management, disable radio (wifi, bluetooth) triggered by events to save power

# network
# networkmanager - make it container only

## Linux filesystems
## =================
fuse3
spice-vdagent
qemu-guest-agent
spice-webdavd
davfs2
jmtpfs
gdisk
btrfs-progs
bindfs
partclone
parted
sshfs
cryptsetup
zerofree
squashfs-tools

xorriso
dosfstools

sudo
adb
flatpak
debootstrap
powertop
psmisc
time
graphicsmagick-imagemagick-compat

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

# services
postfix

distrobox
# filesystems
open-vm-tools-desktop
spice-webdavd
gddrescue
gpg
gpg-agent
libnotify-bin
locales

# virtualization
#qemu-system-gui
qemu-system-x86
qemu-system-arm

# networking
iputils-ping
iputils-tracepath
bind9-dnsutils
