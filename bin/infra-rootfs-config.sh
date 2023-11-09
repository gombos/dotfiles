#!/bin/sh

# rootfs customizations - both for base and full
# only runs for iso and not for container

if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cd /tmp
fi

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

. ./infra-env.sh

if [ -z "$USR" ]; then
  USR=usr
fi

if [ -z "$GID" ]; then
  USR=usr
fi

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

PATH=$SCRIPTS:$PATH

cd /

# Symlink some directories normally on / to /usr to allow to share between machines/instances
mv opt usr
ln -sf usr/opt

# For convinience
# todo - remove nix from here and install it inside container instead

#mkdir -p nix
ln -sf /run/media go

# ---- Configure etc

# Make etc/default/locale deterministic between runs
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
/sbin/locale-gen
/sbin/update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
sort -o etc/default/locale etc/default/locale

echo "nixbld:x:402:nobody" >> etc/group

# rootfs customizations

# networking - IP
mkdir -p etc/network/interfaces.d
printf "auto lo\niface lo inet loopback\n" > etc/network/interfaces.d/loopback

# If wired is connected, this will wait to get an IP via DHCP by default
# Make sure to mask this line for static IPs
printf "allow-hotplug eth0\niface eth0 inet dhcp\n" > $R/etc/network/interfaces.d/eth0

# default admin user to log in (instead of root)
#  --uid 1000 -gid 1000
adduser --disabled-password --no-create-home --shell "/bin/bash" --home /home --gecos "" $USR
usermod -aG sudo $USR
usermod -aG adm $USR
usermod -aG netdev $USR
usermod -aG kvm $USR

chown $USR:$USR /home
chmod g+w /home

# make the salt deterministic, reproducible builds
sed -ri "s/^$USR:[^:]*:(.*)/$USR:\$6\$3fjvzQUNxD1lLUSe\$6VQt9RROteCnjVX1khTxTrorY2QiJMvLLuoREXwJX2BwNJRiEA5WTer1SlQQ7xNd\.dGTCfx\.KzBN6QmynSlvL\/:\1/" etc/shadow

# set timezone
ln -sf /usr/share/zoneinfo/US/Eastern etc/localtime

# disable motd
[ -f etc/default/motd-news ] && sed -i 's|^ENABLED=.*|ENABLED=0|g' etc/default/motd-news

# disable starting some systemd timers by default
ln -sf /dev/null etc/systemd/system/timers.target.wants/motd-news.timer
ln -sf /dev/null etc/systemd/system/timers.target.wants/apt-daily-upgrade.timer
ln -sf /dev/null etc/systemd/system/timers.target.wants/apt-daily.timer

# Defaults are optimized for vm/container use

# LXDM should use openbox
[ -f etc/lxdm/lxdm.conf ] && sed -i "s|\# session.*|session=/usr/bin/openbox-session|g" etc/lxdm/lxdm.conf
[ -f etc/lxdm/lxdm.conf ] && sed -i "s|^bottom_pane=.*|bottom_pane=0|g" etc/lxdm/lxdm.conf

[ -f etc/xdg/autostart/lxpolkit.desktop ] && sed -i "s|^Hidden=.*|Hidden=false|g" etc/xdg/autostart/lxpolkit.desktop

# disable starting some systemd timers by default
ln -sf /dev/null etc/systemd/system/timers.target.wants/man-db.timer

# Disable autoloading some modules
rm -rf usr/lib/modules-load.d/open-vm-tools-desktop.conf

# Disable some services by default
[ -f etc/systemd/system/multi-user.target.wants/dnsmasq.service ] && rm etc/systemd/system/multi-user.target.wants/dnsmasq.service
[ -f etc/systemd/system/multi-user.target.wants/autosuspend.service ] && rm etc/systemd/system/multi-user.target.wants/autosuspend.service
[ -f etc/systemd/system/multi-user.target.wants/apcupsd.service ] && rm etc/systemd/system/multi-user.target.wants/apcupsd.service
[ -f etc/systemd/system/multi-user.target.wants/open-vm-tools.service ] && rm etc/systemd/system/multi-user.target.wants/open-vm-tools.service
[ -f etc/systemd/system/multi-user.target.wants/rpcbind.service ] && rm etc/systemd/system/multi-user.target.wants/rpcbind.service
[ -f etc/systemd/system/multi-user.target.wants/nfs-server.service ] && rm etc/systemd/system/multi-user.target.wants/nfs-server.service
[ -f etc/systemd/system/multi-user.target.wants/cron.service ] && rm etc/systemd/system/multi-user.target.wants/cron.service
[ -f etc/systemd/system/multi-user.target.wants/containerd.service ] && rm etc/systemd/system/multi-user.target.wants/containerd.service
[ -f etc/systemd/system/multi-user.target.wants/docker.service ] && rm etc/systemd/system/multi-user.target.wants/docker.service

[ -f etc/systemd/system/remote-fs.target.wants/nfs-client.target ] && rm etc/systemd/system/remote-fs.target.wants/nfs-client.target
[ -f etc/systemd/system/multi-user.target.wants/nfs-client.target ] && rm etc/systemd/system/multi-user.target.wants/nfs-client.target

[ -f etc/systemd/system/multi-user.target.wants/nginx.service ] && rm etc/systemd/system/multi-user.target.wants/nginx.service
[ -f etc/systemd/system/multi-user.target.wants/caddy.service ] && rm etc/systemd/system/multi-user.target.wants/caddy.service
[ -f etc/systemd/system/multi-user.target.wants/smartmontools.service ] && rm etc/systemd/system/multi-user.target.wants/smartmontools.service

# disable dunst - will start anyway for proper x11 sessions
[ -f etc/systemd/user/default.target.wants/dunst.service ] && rm etc/systemd/user/default.target.wants/dunst.service

# disable pulseaudio - will start anyway for proper x11 sessions
[ -f etc/systemd/user/default.target.wants/pulseaudio.service ] && rm etc/systemd/user/default.target.wants/pulseaudio.service

# disable dpkg state backup
[ -f etc/systemd/system/timers.target.wants/dpkg-db-backup.timer ] && rm etc/systemd/system/timers.target.wants/dpkg-db-backup.timer

# hostapd
[ -f etc/systemd/system/multi-user.target.wants/hostapd.service ] && rm etc/systemd/system/multi-user.target.wants/hostapd.service

# ssh-keygen.service
cat > /lib/systemd/system/ssh-keygen.service << 'EOF'
[Unit]
Description=Regenerate SSH host keys
Before=ssh.service
ConditionFileIsExecutable=/usr/bin/ssh-keygen
ConditionFileNotEmpty=!/etc/ssh/ssh_host_ed25519_key

[Service]
Type=oneshot
ExecStartPre=-/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
ExecStartPre=-/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*"
ExecStart=/usr/bin/ssh-keygen -A -v
ExecStartPost=/bin/systemctl --no-reload disable %n

[Install]
WantedBy=multi-user.target
EOF

mkdir -p etc/systemd/system/multi-user.target.wants
ln -sf /lib/systemd/system/ssh-keygen.service /etc/systemd/system/multi-user.target.wants/ssh-keygen.service

# home.service
cat > /lib/systemd/system/home.service << 'EOF'
[Unit]
Description=Mount /home
After=sys-fs-fuse-connections.mount

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c \
 'if [[ -e /dev/disk/by-label/home ]]; then \
    mount /dev/disk/by-label/home /home; \
    exit; \
  fi; \
  virt=$(systemd-detect-virt); \
  if [[ "$virt" == "vmware" ]]; then \
    mount -t fuse.vmhgfs-fuse -o defaults,allow_other,uid=1000,gid=1000,nosuid,nodev .host:/home /home && \
    mount -t fuse.vmhgfs-fuse -o defaults,allow_other,uid=1000,gid=1000,nosuid,nodev .host:/host /home/host; \
    exit; \
  fi; \
  if [[ -e /run/initramfs/live/home.img ]]; then \
    mkdir -p /run/initramfs/home/lower /run/initramfs/home/upper /run/initramfs/home/work && \
    mount /run/initramfs/live/home.img /run/initramfs/home/lower && \
    mount -t overlay overlay -o lowerdir=/run/initramfs/home/lower,upperdir=/run/initramfs/home/upper,workdir=/run/initramfs/home/work /home && \
    chown -R 1000:0 /home; \
  fi;'
EOF

mkdir -p etc/systemd/system/local-fs.target.wants
ln -sf /lib/systemd/system/home.service /etc/systemd/system/local-fs.target.wants/

# swap
cat > /lib/systemd/system/swap.service << 'EOF'
[Unit]
Description=Mount swap
After=blockdev@dev-disk-by\x2dlabel-swap.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c \
 'if [[ -e /dev/disk/by-label/swap ]]; then \
    /sbin/swapon /dev/disk/by-label/swap; \
  fi;'
EOF

ln -sf /lib/systemd/system/swap.service /etc/systemd/system/local-fs.target.wants/

echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> etc/sudoers.d/sudoers

# usrlocal.service
#cat > /lib/systemd/system/nix.service << 'EOF'

#[Unit]
#Description=Mount usrlocal.img file if exists
#ConditionPathExists=/run/initramfs/live/usrlocal.img

#[Service]
#Type=oneshot
#RemainAfterExit=yes
#ExecStart=/bin/sh -c \
# 'rm -rf /usr/local && \
#  mkdir -p /usr/local && \
#  mount /run/initramfs/live/usrlocal.img /usr/local'
#
#[Install]
#WantedBy=local-fs.target
#EOF

#mkdir -p etc/systemd/system/local-fs.target.wants
#ln -sf /lib/systemd/system/nix.service /etc/systemd/system/local-fs.target.wants/

# Autologin
sed -i "s|\#\ autologin=.*|autologin=$USR|g" etc/lxdm/lxdm.conf

rm -rf boot
rm -rf var/www
find var/lib -empty -delete

rm -rf var/cache var/lib/apt var/lib/systemd
mkdir -p var/cache/apt/archives/partial
mkdir -p var/lib/dhcp
mkdir -p var/lib/nfs/sm

# ---- Cleanup
# Booting up with systemd with read-only /etc is only supported if machine-id exists and empty
rm -rf etc/machine-id /var/lib/dbus/machine-id
touch etc/machine-id

# Empty fstab
rm -rf etc/fstab
touch etc/fstab

find  etc/rc*.d/ -name "S*nxserver*" -delete

# change the date of last time password was set back to 1970 to have reproducible builds
sed -ri "s/([^:]+:[^:]+:)([^:]+)(.*)/\11\3/" etc/shadow

# Only the following directories should be non-empty
# etc (usually attached to root volume), usr (could be separate subvolume), var (could be separate subvolume)

# Following directories should exists but should be empty
# boot, home, media, run

rm -rf /etc/ssh/ssh_host*
rm -rf /var/log/journal/*

[ -f etc/hostname ] && rm -f etc/hostname 2>/dev/null || true

# -- common
DEBIAN_FRONTEND=noninteractive apt-get update -y -qq -o Dpkg::Use-Pty=0
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

# Todo - this should not be required
DEBIAN_FRONTEND=noninteractive apt purge network-manager libbluetooth* libmm-glib* libndp* libnewt* libnm* libteamdctl* tailscale-archive-keyring -y -qq -o Dpkg::Use-Pty=0
apt-get -y -qq autoremove
dpkg --list |grep "^rc" | cut -d " " -f 3 | xargs dpkg --purge
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg --configure --pending
apt-get clean
rm -rf etc/apt/sources.list.d

# cleanup
infra-clean-linux.sh /
rm -rf tmp/*
rm -rf usr/local/*

# exerimental
#rm -rf var/*

echo 'd     /var/lib/apt/lists/partial        0755 root root -' >> usr/lib/tmpfiles.d/debian.conf
echo 'd     /var/cache/apt/archives/partial        0755 root root -' >> usr/lib/tmpfiles.d/debian.conf
echo 'd     /var/lib/dpkg        0755 root root -' >> usr/lib/tmpfiles.d/debian.conf

mkdir -p var/lib/dpkg
touch var/lib/dpkg/lock-frontend

cat usr/lib/tmpfiles.d/debian.conf
ls -la var/lib/dpkg/lock-frontend

echo gombi

cat etc/lxdm/lxdm.conf
cat etc/shadow
cat etc/passwd
