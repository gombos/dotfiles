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
# libblockdev-crypto2, missing from sid

## Linux tools
## ===========

systemd-ukify
ovmf
python3-cryptography
systemd-timesyncd
bubblewrap
systemd-container
python3-all
python3-setuptools
python3-pytest
systemd-boot
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
ovmf
# qemu-user-static - large package
graphicsmagick-imagemagick-compat
