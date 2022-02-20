if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

cd /tmp

. ./infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

mkdir -p /efi/kernel

export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0
apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

# TODO - remove bash dependency


# TODO - get kernel without apt, so that I can use any distro as a base, including alpine, do not rely on package manager
apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-modules-extra-$KERNEL

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-headers-$KERNEL apt-utils ca-certificates git

if ! [ -z "${NVIDIA}" ]; then
  apt-get --reinstall install -y nvidia-driver-${NVIDIA}
fi

# kernel binary
cp -r /boot/vmlinuz-$KERNEL /efi/kernel/vmlinuz

# Make sure we have all the required modules built
$SCRIPTS/infra-install-vmware-workstation-modules.sh


# modules file

#find /usr/lib/modules/ -print0 | cpio --null --create --format=newc | gzip --fast > /efi/kernel/modules.img

#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 busybox zstd

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 squashfs-tools

# try ot install busybox on rootfs or pick another compression algorithm that kmod supports
#find /usr/lib/modules/ -name '*.ko' -exec zstd {} \;
#find /usr/lib/modules/ -name '*.ko' -delete
# busybox depmod

mksquashfs /usr/lib/modules /efi/kernel/modules
rm -rf /tmp/initrd /tmp/cleanup /tmp/updates

# Build custom kernel that has isofs built in
#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 build-essential libncurses5-dev gcc libssl-dev bc libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf fakeroot

#apt-get build-dep -y linux-image-$KERNEL
#apt-get build-dep -y linux-image-unsigned-$KERNEL
#apt-get source linux-image-unsigned-$KERNEL

#cd linux-5.13.0
#make oldconfig
#scripts/diffconfig .config{.old,}
#make deb-pkg

# dracut-install hack
#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 squashfs-tools kmod cpio build-essential libkmod-dev pkg-config dash udev coreutils mount unzip wget ca-certificates git
#cd /efi
#git clone https://github.com/LaszloGombos/dracut.git dracutdir
#cd dracutdir
#bash -c "./configure --disable-documentation"
#make dracut-install
