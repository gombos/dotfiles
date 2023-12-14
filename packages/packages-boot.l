# Can be booted with or without an EFI partition
# Allows to further setup and configure the system
# Not meant to change often
# Optionally keep it in memory all the time (copytoram)

# Can be used:
# Boot on baremetal with bootloader and kernel in EFI

# init, networking, sysext
systemd

# optional for boot, but good to have it around
systemd-sysv # installs /sbin/init symlink to /lib/systemd/systemd
udev # load Linux kernel modules that are not built in
kmod # load Linux kernel modules that are not built in

# essential admin tools
sudo
nano

# systemd services needed to boot or good to have when sysext is unloaded
open-vm-tools # mount shared directories between host and VMware VM guest
openssh-server
docker.io
rsyslog
