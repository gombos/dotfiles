# Purpose: HW-only packages
# Can be booted with an EFI partition
# Allows to further setup and configure the system
# Not meant to change often

# Can be used:
# Boot on baremetal with bootloader and kernel in EFI
# lxc vs systemd-nspawn
# docker, podman, runc

# init
systemd-sysv
udev

# tools
sudo
wget
