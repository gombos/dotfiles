# only remove files not directories
sudo find /run/overlayfs/usr/ /run/overlayfs/var/lib/ /run/overlayfs/var/cache/ -type f -delete
sudo mount -o remount /
sudo systemctl daemon-reload
