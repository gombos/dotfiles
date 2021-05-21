mnt-linux
sudo kpartx -av linux-flat.vmdk
sudo mount /dev/mapper/loop0p1 /mnt
cd /mnt/dotfiles
git pull
cd -
sudo umount /mnt
sudo mount /dev/mapper/loop0p3 /mnt
cd mnt
rw linux
sudo rm -rf linux/
sudo btrfs send go/linux/linux/ | sudo btrfs receive .
cd /
sudo umount /mnt
