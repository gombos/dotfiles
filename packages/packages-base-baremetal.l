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


systemd-sysv # installs /sbin/init symlink to /lib/systemd/systemd
kmod         # loading, inserting, and removing kernel modules
sudo         # super user privileges
nano         # editor
curl         # get stuff from the network
bash
mount
util-linux
coreutils
tar
sed
grep
e2fsprogs
findutils
diffutils
procps
openssl
gawk
gzip
efibootmgr


# core runtimes
bash
perl
python3

# core tools
git
less
micro
rsync
curl
distrobox
gnupg

# networking
openssh-server
ethtool

pass



newuidmap
