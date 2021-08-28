# Compute an rpi image that exposes bagoly via a wifi web interface

RASPIOS=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-05-28/2021-05-07-raspios-buster-armhf-lite.zip
IMG=2021-05-07-raspios-buster-armhf-lite.img

mkdir /tmp/rpi
cd /tmp/rpi
wget $RASPIOS
unzip *-lite.zip
rm *-lite.zip*
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
sudo umount /mnt

sudo losetup -d /dev/loop2

#curl https://getmic.ro | bash
#sudo mv micro /usr/local/bin/

#install
# nginx-light

#> nano
