# avoid HW packages
# avoid distro specific packages
# The idea is that these pacages are always available when Linux is available
# available on Linux and MacOS
# installed only into sysext on Linux not at boot

# core runtimes
perl
python3

# core tools
git
less
micro
rsync
gnupg

# networking
openssh-server
ethtool

pass

# power management
# apcupsd - this shoulw work from sysext

# virtualization
swtpm
ovmf

#ifupdown
#isc-dhcp-client
