# Can be booted with or without an EFI partition
# Allows to further setup and configure the system
# Not meant to change often
# Optionally keep it in memory all the time (copytoram)

# Can be used:
# Boot on baremetal with bootloader and kernel in EFI

# init
systemd

# optional
systemd-sysv # installs /sbin/init symlink to /lib/systemd/systemd
udev # load Linux kernel modules that are not built in
kmod # load Linux kernel modules that are not built in
open-vm-tools # mount shared directories between host and VMware VM guest
