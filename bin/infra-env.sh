# stable
export RELEASE="focal"
export KERNEL="5.11.0-34-generic"
export NVIDIA="460"

# staging
export RELEASE="hirsute"
export NVIDIA="470"

#export RELEASE="impish"
#export KERNEL="5.13.0-19-generic"
# todo - bgfiler - kernel bug
# todo - systemd or some other rootfs update does not like the vmware service files, so vmware modules load but service does not start
