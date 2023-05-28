mkdir /mnt/iphone
apt update
apt install usbmuxd ifuse
#apt install ideviceinstaller python3-imobiledevice libimobiledevice-utils python3-plist libusbmuxd-tools
sudo usbmuxd
sudo ifuse /mnt/iphone
