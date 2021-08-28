# Compute an rpi image that exposes bagoly via a wifi web interface

RASPIOS=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-05-28/2021-05-07-raspios-buster-armhf-lite.zip
IMG=2021-05-07-raspios-buster-armhf-lite.img

mkdir /tmp/rpi
cd /tmp/rpi
wget $RASPIOS
unzip *-lite.zip
rm *-lite.zip*
#docker run -it -v /home/user/$IMG:/sdcard/filesystem.img lukechilds/dockerpi:vm

sudo losetup -P /dev/loop2 $IMG

sudo mount /dev/loop2p1 /mnt
echo "dtoverlay=dwc2" | sudo tee /mnt/config.txt
echo "start_x=0" | sudo tee -a /mnt/config.txt
echo "dtparam=audio=off" | sudo tee -a /mnt/config.txt
echo "gpu_mem=16" | sudo tee -a /mnt/config.txt

echo "console=tty1 root=PARTUUID=9730496b-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait modules-load=dwc2,g_ether systemd.wants=ssh systemd.mask=cron systemd.mask=bluetooth systemd.mask=rsyslog systemd.mask=triggerhappy systemd.mask=hciuart systemd.mask=dhcpcd systemd.mask=dphys-swapfile module_blacklist=i2c_dev,ipv6,bcm2835_codec,bcm2835_v4l2,bcm2835_isp init=/sbin/overlayRoot.sh" | sudo tee /mnt/cmdline.txt
sudo umount /mnt

sudo mount /dev/loop2p2 /mnt
printf "\nallow-hotplug usb0\niface usb0 inet static\n  address 192.168.2.2\n  netmask 255.255.255.0\n  network 192.168.2.0\n  broadcast 192.168.2.255\n  gateway 192.168.2.1\n  dns-nameservers 8.8.8.8\n" | sudo tee -a /mnt/etc/network/interfaces
sudo umount /mnt

sudo losetup -d /dev/loop2

#apt purge
#pigz
#python python-colorzero python-gpiozero python-minimal python-pkg-resources python-rpi.gpio python-spidev
#libpython-stdlib libpython2-stdlib libpython2.7-minimal libpython2.7-stdlib python2 python2-minimal python2.7 python2.7-minimal
#python3-rpi.gpio rpi.gpio-common python3-gpiozero python3-colorzero python3-spidev
#triggerhappy
#binutils-common binutils binutils-arm-linux-gnueabihf build-essential dpkg-dev g++ g++-8 gcc gcc-8 libbinutils rpi-eeprom rpi-update
#fakeroot flashrom libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libasan5 libcc1-0 libfakeroot libfl2 libftdi1-2 libgcc-8-dev libstdc++-8-dev libubsan1 libusb-0.1-4
#libraspberrypi-doc
#libdpkg-perl libfile-fcntllock-perl libperl5.28 perl perl-modules-5.28 pkg-config libgdbm-compat4 make patch
#cpp cpp-8 libisl19 libmpc3 libmpfr6
#bluez pi-bluetooth bluez-firmware
#gdb libbabeltrace1 libc6-dbg libdw1 libpython3.7
#libc6-dev libfreetype6-dev libpng-dev zlib1g-dev libc-dev-bin libfreetype6 libpng-tools libpng16-16 linux-libc-dev   libmnl-dev libraspberrypi-dev manpages-dev man-db manpages
#geoip-database iso-codes shared-mime-info
#file libmagic-mgc libmagic1
#console-setup console-setup-linux keyboard-configuration xkb-data
#rsyslog gcc-4.9-base cron logrotate
#dmidecode gcc-5-base gcc-6-base gcc-7-base gdbm-l10n libpci3 xxd vim-common vim-tiny ncdu
#v4l-utils libjpeg62-turbo libv4l-0 libv4l2rds0 libv4lconvert0
#dphys-swapfile
#busybox initramfs-tools initramfs-tools-core raspi-config alsa-utils dc klibc-utils libasound2 libasound2-data libfftw3-single3 libgomp1 libklibc libsamplerate0 linux-base
#dhcpcd5 raspberrypi-net-mods
#apt-listchanges distro-info-data lsb-release python-apt-common python3-apt python3-debconf
#libboost-iostreams1.58.0 libfribidi0 libglib2.0-data libgpm2 libident liblognorm5 libmtp-runtime libpipeline1 libsigc++-1.2-5c2  libmtp-common libmtp9  libpam-chksshpwd libnss-mdns libudev0
#libluajit-5.1-2 libluajit-5.1-common luajit make
#ntfs-3g fuse libfuse2 libntfs-3g883
#python3-pip python-pip-whl python3-crypto python3-dbus python3-entrypoints python3-keyring python3-keyrings.alt python3-secretstorage python3-wheel python3-xdg
#python3-setuptools python3-distutils python3-lib2to3
#perl libgdbm-compat4 libperl5.28 perl-modules-5.28
#info strace
#tasksel tasksel-data paxctld
#raspi-gpio raspinfo xdg-user-dirs
#xauth libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxext6 libxmuu1 fbset
#publicsuffix

#curl https://getmic.ro | bash
#sudo mv micro /usr/local/bin/

#install
# nginx-light

#wget ftp://110.10.189.172/ComfilePi/Scripts/overlayRoot.sh
#sudo cp overlayRoot.sh /sbin/
#sudo chmod +x /sbin/overlayRoot.sh


#> nano
