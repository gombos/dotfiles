# Requirements:
# - Does not need /home
# - Does not need /etc or /usr rw
# - Does not need to run as root or sudo
# - Does not use the network

# initramfs and most tools generating initramfs are designed to be host specific

# In general each kernel version will have to have its own initramfs
# but with a bit of work it is possible to make initramfs generic (not HW or host SW specific)

# drakut-network to enable nfsroot - https://fai-project.org/
# This is also way more powerful (systemd volatile)

# A read-only /etc is increasingly common on embedded devices.
# A rarely-changing /etc is also increasingly common on desktop and server installations, with files like /etc/mtab and /etc/resolv.conf located on another filesystem and symbolically linked in /etc (so that files in /etc need to be modified when installing software or when the computer's configuration changes, but not when mounting a USB drive or connecting in a laptop to a different network).
# The emerging standard is to have a tmpfs filesystem mounted on /run and symbolic links in /etc like

# Create a temporary file called rdexec and copy it into initramfs to be executed
# This solution only requires dropping one single hook file into initramfs
# This argument allows calling out to EFI parition from within initramfs to execute arbitrary code
# Future goal - instead of executing arbitrary code, try to just create additional files and drop them
# For user management switch to homectl and portable home directories

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi


if [ -z "$RELEASE" ]; then
  RELEASE=$VERSION_CODENAME
  if [ -z "$RELEASE" ]; then
    RELEASE=$(echo $VERSION | sed -rn 's|.+\((.+)\).+|\1|p')
  fi
fi

if [ -z "$KERNEL" ]; then
  export KERNEL=$(dpkg -l | grep linux-modules | head -1  | cut -d\- -f3- | cut -d ' ' -f1)
fi

if [ -z "$KERNEL" ]; then
  export KERNEL="5.4.0-52-generic"
fi

echo $KERNEL

if [ -z "$CMDLINE" ]; then
  CMDLINE="root=LABEL=linux rootfstype=btrfs ro net.ifnames=0 systemd.volatile=overlay quiet"
fi

mkdir -p /efi

export DEBIAN_FRONTEND=noninteractive

# Install nvidea driver - this is the only package from restricted source
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} restricted" > /etc/apt/sources.list.d/restricted.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security restricted" >> /etc/apt/sources.list.d/restricted.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-updates restricted" >> /etc/apt/sources.list.d/restricted.list

apt-get update -y -qq -o Dpkg::Use-Pty=0

apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 grub-efi-amd64-bin grub-pc-bin grub-ipxe syslinux-common grub2-common unzip overlayroot shim dmidecode
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio iputils-arping build-essential asciidoc-base xsltproc docbook-xsl libkmod-dev pkg-config wget btrfs-progs busybox

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-modules-extra-$KERNEL linux-headers-$KERNEL

echo $RELEASE

cat /etc/apt/sources.list.d/restricted.list

apt-get --reinstall install -y nvidia-driver-460

# kernel binary
mkdir -p /efi/kernel
cp -rv /boot/vmlinuz-$KERNEL /efi/kernel/vmlinuz

## systemd-boot binary
#mkdir -p /efi/EFI/systemd
#cp -v /usr/lib/systemd/boot/efi/systemd-bootx64.efi /efi/EFI/systemd/
## systemd-boot config
#mkdir -p /efi/loader/entries
## Default boot is first in alphabetical order
#cat << EOF | tee -a /efi/loader/loader.conf
#default grub
#EOF
#cat << EOF | tee -a /efi/loader/entries/grub.conf
#title   grub
#efi /EFI/ubuntu/grubx64.efi
#EOF
#cat << EOF | tee -a /efi/loader/entries/linux.conf
#title   linux
#linux   /kernel/vmlinuz
#initrd  /kernel/initrd.img
#options $CMDLINE
#EOF

# grub efi binary
mkdir -p /efi/EFI/boot/

# grub efi config - has a dependency on dotfiles

# remove path part of the variable to determine the root
cat > /efi/EFI/boot/grub.cfg << 'EOF'
regexp --set base "(.*)/" $cmdpath
regexp --set base "(.*)/" $base
set root=$base
configfile /dotfiles/boot/grub.cfg
EOF

# Make grub the default EFI boot mechanism, I had better luck on some HW
#cp -v /efi/EFI/ubuntu/grubx64.efi /efi/EFI/boot/bootx64.efi

# grub pc binary
mkdir -p /efi/grub/i386-pc/
cp -rv /usr/lib/grub/i386-pc/lnxboot.img /efi/grub/i386-pc/

# grub pc config
echo "source /dotfiles/boot/grub.cfg" > /efi/grub/grub.cfg

# grub ipxe binary
mkdir -p /efi/ipxe/
cp /boot/ipxe.* /efi/ipxe/

# syslinux binary
mkdir -p /efi/syslinux
cp -v /usr/lib/syslinux/mbr/gptmbr.bin /efi/syslinux
cp -v /usr/lib/syslinux/modules/bios/ldlinux.c32 /efi/syslinux/

# syslinux config - chainload grub
cat > /efi/syslinux/syslinux.cfg <<EOF
DEFAULT grub
LABEL grub
 LINUX /grub/i386-pc/lnxboot.img
 INITRD /grub/i386-pc/core.img
EOF

cat > /tmp/grub_bios.cfg << 'EOF'
prefix=
root=$cmdpath
source $cmdpath/grub/grub.cfg
EOF

cat > /tmp/grub_efi.cfg << 'EOF'
source $cmdpath/grub.cfg
EOF

GRUB_MODULES="normal part_msdos part_gpt configfile fat smbios linux minicmd search chain test regexp ls cat"

# for more control, consider just invoking grub-mkimage directly
# grub-mkstandalone just a wrapper on top of grub-mkimage

mkdir -p /efi/EFI/test/
grub-mkstandalone --format=i386-pc    --output="/efi/grub/i386-pc/core.img" --install-modules="$GRUB_MODULES biosdisk" --modules="$GRUB_MODULES biosdisk" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_bios.cfg" -v
grub-mkstandalone --format x86_64-efi --output="/efi/EFI/boot/bootx64.efi"  --install-modules="$GRUB_MODULES"          --modules="$GRUB_MODULES"          --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_efi.cfg" -v

# Make sure we have all the required modules built
$SCRIPTS/infra-install-vmware-workstation-modules.sh

rm -rf /tmp/initrd
mkdir -p /tmp/initrd
cd /tmp/initrd

cp -rv /usr/lib/modules /efi/

# TCE binary
mkdir -p /efi/tce
mkdir -p /efi/tce/optional
wget --no-check-certificate https://distro.ibiblio.org/tinycorelinux/12.x/x86/release/Core-current.iso
wget http://www.tinycorelinux.net/12.x/x86/tcz/openssl-1.1.1.tcz
wget http://www.tinycorelinux.net/12.x/x86/tcz/openssh.tcz

mv Core-current.iso /efi/tce
mv openssh*.tcz openssl*.tcz  /efi/tce/optional/
echo "openssl-1.1.1.tcz " >> /efi/tce/onboot.lst
echo "openssh.tcz" >> /efi/tce/onboot.lst

mkdir -p tce/opt
cd tce
echo "opt" > opt/.filetool.lst

cat > opt/bootsync.sh << 'EOF'
#!/bin/sh
# runs at boot
touch /usr/local/etc/ssh/sshd_config
sed -ri "s/^tc:[^:]*:(.*)/tc:\$6\$3fjvzQUNxD1lLUSe\$6VQt9RROteCnjVX1khTxTrorY2QiJMvLLuoREXwJX2BwNJRiEA5WTer1SlQQ7xNd\.dGTCfx\.KzBN6QmynSlvL\/:\1/" etc/shadow
/usr/local/etc/init.d/openssh start &
EOF

chmod +x opt/bootsync.sh

tar -czvf /efi/tce/mydata.tgz opt
cd ..

# Only needed for nfs
#rm -rf NFSroot_work.tgz
#wget http://support.fccps.cz/download/adv/frr/nfs-root/NFSroot_work.tgz
#tar -xzf NFSroot_work.tgz
#cp ./NFSroot_work/debcfg-nfsroot/overlay.sh /etc/initramfs-tools/scripts/init-bottom
#echo "overlay" >> /etc/initramfs-tools/modules
#update-initramfs -k all -c
#cp /boot/initrd.img /efi/kernel/initrd-nfs.img

rm -rf 055.zip dracut-055
wget --no-check-certificate https://github.com/dracutdevs/dracut/archive/refs/tags/055.zip
unzip -q 055.zip
cd dracut-055
./configure
make
make install
cd ..

cat > /tmp/rdexec << 'EOF'
#!/bin/sh

# Script executed during ram disk phase (rd.exec = ram disk execute)

. /lib/dracut-lib.sh

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/run/initramfs/rd.exec.log 2>&1

printf "ggomvi"

printf "$0"

me=`basename "$0"`

printf "$me"

printf "ggomvi2"


echo "# arguments called with ---->  ${@}     "
echo "# \$1 ---------------------->  $1       "
echo "# \$2 ---------------------->  $2       "
echo "# path to me --------------->  ${0}     "
echo "# parent path -------------->  ${0%/*}  "
echo "# my name ------------------>  ${0##*/} "

lsmod

# TODO - do not hardcode EFI label
# Maybe make the argument more generic URL that curl understands - including file://
# calling curl is easy.. making sure networking is up is the hard part and also do you really want to make boot dependent on network

# rd.exec should not used in the LIVE disk
# disk that contains the executable code

# EFI label has priority over EFI_* labels
configdrive=""

if [ -L /dev/disk/by-label/EFI ]; then
  configdrive="/dev/disk/by-label/EFI"
else
  for f in /dev/disk/by-label/EFI_*; do
    if [ -z "$configdrive" ]; then
      configdrive="$f"
    fi
  done
fi

for x in $(cat /proc/cmdline); do
  case $x in
  rd.dev=*)
    printf "[rd.dev] $x \n"
    RDDEV=${x#rd.dev=}
    configdrive="/dev/disk/$RDDEV"
    printf "[rd.dev] mount target set to $configdrive\n"
  ;;
  rd.exec=*)
    printf "[rd.exec] $x \n"
    RDEXEC=${x#rd.exec=}
  ;;
  esac
done

# EFI needs to be mounted as early as possible and needs to stay mounted for modules to load properly
mp="/run/media/efi"
mkdir -p "$mp"

printf "[rd.exec] Mounting $configdrive to $mp\n"
mount -o ro,noexec,nosuid,nodev,umask=0077 "$configdrive" "$mp"

printf "[rd.exec] Mounted $configdrive to $mp\n"

# default init included in the initramfs
if [ -z "$RDEXEC" ]; then
  RDEXEC="/sbin/infra-init.sh"
else
  RDEXEC="$mp/$RDEXEC"
fi

printf "[rd.exec] About to run $RDEXEC \n"

if [ -f "$RDEXEC" ]; then
  # Execute the rd.exec script in a sub-shell
  printf "[rd.exec] start executing $RDEXEC \n"
  scriptname="${RDEXEC##*/}"
  scriptpath=${RDEXEC%/*}
  configdir="$scriptpath"
  ( cd $configdir && . "./$scriptname" )
  printf "[rd.exec] stop executing $RDEXEC \n"
fi

exit 0
EOF

chmod +x /tmp/rdexec


cat > /tmp/20-wired.network << 'EOF'
[Match]
Name=eth0

[Network]
DHCP=ipv4

[DHCP]
CriticalConnection=true
EOF

# TODO - add dmidecode to initramfs so that I can autodiscover HW in the rootfs script  -s bios-version
# ifcfg aufs overlay-root
# consider --omit ifcfg

# --add-drivers "loop squashfs overlay iso9660 btrfs" --add "squash"

# nfs livenet

dracut --keep --verbose --force --no-hostonly --reproducible  --kernel-cmdline "$CMDLINE" \
  --omit "kernel-modules-extra" --add-drivers "nls_iso8859_1"  --omit-drivers "nvidia nvidia_drm nvidia_uvm nvidia_modeset" \
  --add "btrfs bash busybox systemd-networkd" \
  --include /tmp/20-wired.network /etc/systemd/network/20-wired.network \
  --include /tmp/infra-init.sh /sbin/infra-init.sh \
  --include /tmp/rdexec /usr/lib/dracut/hooks/pre-pivot/99-exec.sh \
  --include /tmp/rdexec /usr/lib/dracut/hooks/cmdline/90-exec.sh \
  initrd.img $KERNEL

rm -r /tmp/rdexec

# Uncompress
#gunzip -c -S img initrd.img | cpio -idmv 2>/dev/null

# Clean some files
#rm initrd.img
#rm -f usr/lib/modprobe.d/nvidia-graphics-drivers.conf
#rm -f usr/lib/dracut/build-parameter.txt
#rm -rf usr/lib/modules/$KERNEL/kernel/drivers/net/ethernet/nvidia/*

#rm usr/sbin/ifup
#cp /usr/lib/dracut/modules.d/35network-legacy/ifup.sh usr/sbin/ifup

# Recompress
#find . -print0 | cpio --null --create --format=newc | gzip --best > /tmp/initrd.img
#cd /tmp/

cp initrd.img /efi/kernel/

rm -rf /tmp/initrd

# Populate logs with the list of filenames
find /efi

# use syslinux only for booting legacy/non-ufi systems - for uefi system, no need to introduce an extra complexity into booting
