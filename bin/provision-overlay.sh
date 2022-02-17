sudo dd if=/dev/zero of=/go/host/overlay.img bs=1M count=1024
sudo mkfs.ext4 /go/host/overlay.img
sudo mount /go/host/overlay.img /mnt
sudo mkdir /mnt/overlayfs /mnt/ovlwork
sudo umount /mnt
