# Can be booted with or without an EFI partition
# Allows to further setup and configure the system
# Not meant to change often
# Optionally keep it in memory all the time (copytoram)

# Can be used:
# Boot on baremetal with bootloader and kernel in EFI

# init, networking, sysext
# this is the only package that is strictly mandatory
systemd

# essential tools
systemd-sysv # installs /sbin/init symlink to /lib/systemd/systemd
kmod         # loading, inserting, and removing kernel modules
sudo         # super user privileges
nano         # editor

# services to start at boot (or good to have when sysext is unloaded)
udev                  # hotplug events
open-vm-tools-desktop # mount shared directories between host and VMware VM guest
openssh-server        # remote login
rsyslog               # remote logging (in case can not remote log in)
wpasupplicant         # wifi authentication
systemd-resolved      # DNS resolver
systemd-timesyncd     # synchronize local time with NTP servers
docker.io             # containers
