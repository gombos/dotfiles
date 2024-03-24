# Can be booted with or without an EFI partition
# Allows to further setup and configure the system
# Not meant to change often
# Optionally keep it in memory all the time (copytoram)

# Can be used:
# Boot on baremetal with bootloader and kernel in EFI

# Not for inside containers

systemd # init, networking, sysext
udev               # hotplug events
openssh-server     # remote login
wpasupplicant      # wifi authentication
systemd-resolved   # DNS resolver
systemd-timesyncd  # synchronize local time with NTP servers
