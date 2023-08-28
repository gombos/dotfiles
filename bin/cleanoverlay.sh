# only remove files not directories
sudo find /run/overlayfs/usr/ /run/overlayfs/var/lib/apt/ /run/overlayfs/var/lib/dpkg/ /run/overlayfs/var/log/ /run/overlayfs/var/cache/ -type f -delete
sudo mount -o remount /
#sudo systemctl daemon-reload
