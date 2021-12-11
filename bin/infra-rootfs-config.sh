#!/bin/sh

# rootfs customizations - both for base and full

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

. ./infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

PATH=$SCRIPTS:$PATH

cd /

# Directory tree
# Allow per-machine/per-instance /boot /etc /usr /home /var

# Symlink some directories normally on / to /var to allow more per-machine/per-instance configuration

# /var/tmp points to /tmp
rm -rf var/tmp
ln -sf /tmp var/tmp

# Symlink some directories normally on / to /usr to allow to share between machines/instances
mv opt usr
ln -sf usr/opt

# For convinience
mkdir -p nix
ln -sf /run/media go

# ---- Configure etc

# Make etc/default/locale deterministic between runs
locale-gen --purge en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
sort -o etc/default/locale etc/default/locale

# todo - vmware fix
rm -rf etc/network/if-down.d/resolved etc/network/if-up.d/resolved

# rootfs customizations - both for base and full

mkdir -p etc/network/interfaces.d
printf "auto lo\niface lo inet loopback\n" > etc/network/interfaces.d/loopback
printf "127.0.0.1 localhost\n" > etc/hosts

# default admin user to log in (instead of root)
adduser --disabled-password --no-create-home --uid 99 --shell "/bin/bash" --home /home --gecos "" admin --ingroup adm && usermod -aG sudo,netdev admin
chown admin:adm /home
chmod g+w /home

# make the salt deterministic, reproducible builds
sed -ri "s/^admin:[^:]*:(.*)/admin:\$6\$3fjvzQUNxD1lLUSe\$6VQt9RROteCnjVX1khTxTrorY2QiJMvLLuoREXwJX2BwNJRiEA5WTer1SlQQ7xNd\.dGTCfx\.KzBN6QmynSlvL\/:\1/" etc/shadow

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

# disable dunst - will start anyway for proper x11 sessions
[ -f etc/systemd/user/default.target.wants/dunst.service ] && rm etc/systemd/user/default.target.wants/dunst.service

# disable pulseaudio - will start anyway for proper x11 sessions
[ -f etc/systemd/user/default.target.wants/pulseaudio.service ] && rm etc/systemd/user/default.target.wants/pulseaudio.service

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

# home-vmware.service
cat > /lib/systemd/system/home-vmware.service << 'EOF'
[Unit]
Description=Mount VMware shared folders - home
After=sys-fs-fuse-connections.mount
ConditionVirtualization=vmware

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=mount -t fuse.vmhgfs-fuse -o defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty .host:/home /home

[Install]
WantedBy=local-fs.target
EOF

mkdir -p etc/systemd/system/local-fs.target.wants
ln -sf /lib/systemd/system/home-vmware.service /etc/systemd/system/local-fs.target.wants/

# home-host-vmware.service
cat > /lib/systemd/system/home-host-vmware.service << 'EOF'
[Unit]
Description=Mount VMware shared folders - host
After=sys-fs-fuse-connections.mount
After=home-vmware.service
ConditionVirtualization=vmware

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=mount -t fuse.vmhgfs-fuse -o defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty .host:/host /home/host

[Install]
WantedBy=local-fs.target
EOF

mkdir -p etc/systemd/system/local-fs.target.wants
ln -sf /lib/systemd/system/home-host-vmware.service /etc/systemd/system/local-fs.target.wants/

# home-img.service
cat > /lib/systemd/system/home-img.service << 'EOF'

[Unit]
Description=Mount home.img file as /home if exists
ConditionPathExists=/run/initramfs/live/home.img

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=mkdir -p /run/initramfs/home/lower /run/initramfs/home/upper /run/initramfs/home/work
ExecStart=mount /run/initramfs/live/home.img /run/initramfs/home/lower
ExecStart=mount -t overlay overlay -o lowerdir=/run/initramfs/home/lower,upperdir=/run/initramfs/home/upper,workdir=/run/initramfs/home/work /home
ExecStart=chown -R 99:0 /home

[Install]
WantedBy=local-fs.target
EOF

mkdir -p etc/systemd/system/local-fs.target.wants
ln -sf /lib/systemd/system/home-img.service /etc/systemd/system/local-fs.target.wants/

echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> etc/sudoers.d/sudoers

printf "allow-hotplug eth0\niface eth0 inet dhcp\n" > etc/network/interfaces.d/eth0

# Autologin
sed -i "s|\#\ autologin=.*|autologin=admin|g" etc/lxdm/lxdm.conf

#mkdir -p usr/bin/
#cp $SCRIPTS/infra-boot.sh usr/bin/infra-init.sh
#cp /tmp/boot.service usr/lib/systemd/system/

#mkdir -p etc/systemd/system/path.target.wants/ usr/lib/systemd/system/
#ln -sf /lib/systemd/system/boot.service etc/systemd/system/path.target.wants/boot.service

#mkdir -p etc/systemd/system/first-boot-complete.target.wants/ usr/lib/systemd/system/
#ln -sf /lib/systemd/system/boot.service etc/systemd/system/first-boot-complete.target.wants/boot.service

#rm etc/systemd/system/basic.target.wants/boot.service
# Disable all the preinstaled cron jobs (except cron.d/ jobs)
#> $R/etc/crontab

rm -rf boot
rm -rf usr/local
rm -rf etc/apt/sources.list.d/*
rm -rf var/www
find var/lib -empty -delete

rm -rf var/cache var/lib/apt var/lib/systemd
mkdir -p var/cache/apt/archives/partial

# ---- Cleanup
# Booting up with systemd with read-only /etc is only supported if machine-id exists and empty
rm -rf etc/machine-id /var/lib/dbus/machine-id
touch etc/machine-id

# Empty fstab
rm -rf etc/fstab
touch etc/fstab

# change the date of last time password was set back to 1970 to have reproducible builds
sed -ri "s/([^:]+:[^:]+:)([^:]+)(.*)/\11\3/" etc/shadow

# Cleanup packages only needed during building the rootfs
apt-get purge -y -qq linux-*headers-* fuse libllvm11 2>/dev/null >/dev/null
apt-get clean

# Only the following directories should be non-empty
# etc (usually attached to root volume), usr (could be separate subvolume), var (could be separate subvolume)

# Following directories should exists but should be empty
# boot, home, media, run

infra-clean-linux.sh /

# ---- Integrity
infra-integrity.sh /var/integrity/

rm -rf tmp/*
