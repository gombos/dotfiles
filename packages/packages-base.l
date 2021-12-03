# Can be booted with or without an EFI partition
# Allows to further setup and configure the system
# Not meant to change often
# Optionally keep it in memory all the time (copytoram)

# Can be used:
# Boot on baremetal with bootloader and kernel in EFI
# lxc vs systemd-nspawn
# docker, podman, runc

# init
systemd-sysv
udev

# tools
sudo
