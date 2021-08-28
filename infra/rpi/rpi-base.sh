# Compute an rpi image that exposes bagoly via a wifi web interface

RASPIOS=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-05-28/2021-05-07-raspios-buster-armhf-lite.zip
IMG=2021-05-07-raspios-buster-armhf-lite.img

mkdir /tmp/rpi
cd /tmp/rpi
#wget $RASPIOS
unzip -o *-lite.zip
#rm *-lite.zip*
#docker run -it -v /home/user/$IMG:/sdcard/filesystem.img lukechilds/dockerpi:vm

wget ftp://110.10.189.172/ComfilePi/Scripts/overlayRoot.sh

sudo losetup -P /dev/loop2 $IMG

sudo mount /dev/loop2p1 /mnt
echo "dtoverlay=dwc2" | sudo tee /mnt/config.txt
echo "start_x=0" | sudo tee -a /mnt/config.txt
echo "dtparam=audio=off" | sudo tee -a /mnt/config.txt
echo "gpu_mem=16" | sudo tee -a /mnt/config.txt

echo "console=tty1 root=PARTUUID=9730496b-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait modules-load=dwc2,g_ether systemd.wants=ssh systemd.mask=cron systemd.mask=bluetooth systemd.mask=rsyslog systemd.mask=triggerhappy systemd.mask=hciuart systemd.mask=dhcpcd systemd.mask=dphys-swapfile module_blacklist=i2c_dev,ipv6,bcm2835_codec,bcm2835_v4l2,bcm2835_isp init=/sbin/overlayRoot.sh" | sudo tee /mnt/cmdline.txt
sudo umount /mnt

sudo mount /dev/loop2p2 /mnt
sudo cp overlayRoot.sh /mnt/sbin
sudo chmod +x /mnt/sbin/overlayRoot.sh
printf "\nallow-hotplug usb0\niface usb0 inet static\n  address 192.168.2.2\n  netmask 255.255.255.0\n  network 192.168.2.0\n  broadcast 192.168.2.255\n  gateway 192.168.2.1\n  dns-nameservers 8.8.8.8\n" | sudo tee -a /mnt/etc/network/interfaces

printf "\nallow-hotplug wlan0\niface wlan0 inet static\n  address 192.168.3.2\n  netmask 255.255.255.0\n  network 192.168.3.0\n  broadcast 192.168.3.255\n  gateway 192.168.3.1\n  dns-nameservers 8.8.8.8\n" | sudo tee -a /mnt/etc/network/interfaces

#printf "\nauto br0\niface br0 inet dhcp\nbridge_ports usb0 wlan0\n"

PKGS="pigz python python-colorzero python-gpiozero python-minimal python-pkg-resources python-rpi.gpio python-spidev libpython-stdlib libpython2-stdlib libpython2.7-stdlib python2 python2-minimal python2.7 python2.7-minimal python3-rpi.gpio rpi.gpio-common python3-gpiozero python3-colorzero python3-spidev triggerhappy binutils-common binutils binutils-arm-linux-gnueabihf build-essential dpkg-dev g++ g++-8 gcc gcc-8 libbinutils rpi-eeprom rpi-update fakeroot flashrom libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libasan5 libcc1-0 libfakeroot libfl2 libftdi1-2 libgcc-8-dev libstdc++-8-dev libubsan1 libusb-0.1-4 libraspberrypi-doc libdpkg-perl libfile-fcntllock-perl libperl5.28 perl perl-modules-5.28 pkg-config libgdbm-compat4 make patch cpp cpp-8 libisl19 libmpc3 libmpfr6 pi-bluetooth bluez-firmware gdb libbabeltrace1 libc6-dbg libpython3.7 libc6-dev libfreetype6-dev libpng-dev zlib1g-dev libc-dev-bin libfreetype6 libpng-tools libpng16-16 linux-libc-dev   libmnl-dev libraspberrypi-dev manpages-dev man-db manpages geoip-database iso-codes shared-mime-info file libmagic-mgc libmagic1 console-setup console-setup-linux keyboard-configuration xkb-data rsyslog gcc-4.9-base cron logrotate dmidecode gcc-5-base gcc-6-base gcc-7-base gdbm-l10n xxd vim-common vim-tiny ncdu v4l-utils libjpeg62-turbo libv4l-0 libv4l2rds0 libv4lconvert0 dphys-swapfile busybox initramfs-tools initramfs-tools-core raspi-config alsa-utils dc klibc-utils libfftw3-single3 libgomp1 libklibc libsamplerate0 linux-base dhcpcd5 raspberrypi-net-mods apt-listchanges distro-info-data lsb-release python-apt-common python3-apt python3-debconf libboost-iostreams1.58.0 libfribidi0 libglib2.0-data libgpm2 libident liblognorm5 libmtp-runtime libpipeline1 libsigc++-1.2-5c2  libmtp-common libmtp9  libpam-chksshpwd libnss-mdns libudev0 libluajit-5.1-2 libluajit-5.1-common luajit make ntfs-3g fuse libfuse2 libntfs-3g883 perl libgdbm-compat4 libperl5.28 perl-modules-5.28 info strace tasksel tasksel-data paxctld raspi-gpio raspinfo xdg-user-dirs xauth libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxext6 libxmuu1 fbset bluez libasound2 libasound2-data libdw1 libpython2.7-minimal python3 python3-certifi python3-chardet python3-idna python3-pkg-resources python3-requests python3-six python3-urllib3 ssh-import-id libmpdec2 libpython3-stdlib libpython3.7-minimal libpython3.7-stdlib mime-support python3-minimal python3.7 python3.7-minimal"

sudo cp $(which qemu-arm-static) /mnt/usr/bin

sudo chroot /mnt qemu-arm-static /bin/bash -c "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen --purge && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8"

# micro editor (copy paste from outside of the editor does not seem to work well)
#sudo chroot /mnt qemu-arm-static /bin/bash -c "curl https://getmic.ro | bash"
#sudo chroot /mnt qemu-arm-static /bin/bash -c "sudo mv micro /usr/local/bin/"

# purge packages I do not need
sudo chroot /mnt qemu-arm-static /bin/bash -c "apt-get update -y"
sudo chroot /mnt qemu-arm-static /bin/bash -c "rm -rf /var/lib/dpkg/info/bluez.prerm"
sudo chroot /mnt qemu-arm-static /bin/bash -c "apt-get purge -y -qq -o Dpkg::Use-Pty=0 $PKGS"

# upgrade
sudo chroot /mnt qemu-arm-static /bin/bash -c "apt-mark hold raspberrypi-bootloader raspberrypi-kernel"
sudo chroot /mnt qemu-arm-static /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Use-Pty=0"

# nginx
sudo chroot /mnt qemu-arm-static /bin/bash -c "apt-get install -y -qq -o Dpkg::Use-Pty=0 nginx-light"

# wifi access point
sudo chroot /mnt qemu-arm-static /bin/bash -c "apt-get install -y -qq -o Dpkg::Use-Pty=0 hostapd dnsmasq"
# bridge-utils"

cd /mnt

key=DAEMON_CONF
value="/etc/hostapd/hostapd.conf"
sed "/^$key/ { s/^#//; s%=.*%=\"$value\"%; }" etc/default/hostapd

cat <<EOF | sudo tee etc/dhcpcd.conf > /dev/null
interface wlan0
#static ip_address=192.168.3.1/24
#denyinterfaces eth0
EOF

cat <<EOF | sudo tee etc/dnsmasq.conf > /dev/null
interface=wlan0
  dhcp-range=192.168.3.10,192.168.3.30,255.255.255.0,24h
EOF

cat <<EOF | sudo tee etc/hostapd/hostapd.conf > /dev/null
interface=wlan0
driver=nl80211
#bridge=br0
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
ssid=pi
wpa_passphrase=12345678
EOF

#sudo chroot /mnt qemu-arm-static /bin/bash -c "sudo brctl addbr br0"

#cleanup
sudo rm -rf var/lib/apt/lists/
sudo rm -rf var/log/apt
sudo rm -rf var/cache/apt
sudo rm -rf etc/init.d/resize2fs_once

sudo ln -sf /dev/null etc/systemd/system/timers.target.wants/apt-daily-upgrade.timer
sudo ln -sf /dev/null etc/systemd/system/timers.target.wants/apt-daily.timer

cd -
sudo umount /mnt

sudo losetup -d /dev/loop2
