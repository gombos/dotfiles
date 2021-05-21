mkdir /mnt/iphone
apt update
apt install usbmuxd ifuse 
sudo usbmuxd
sudo ifuse /mnt/iphone
