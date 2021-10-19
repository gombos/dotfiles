# Requirements:
# - Does not need /home
# - Does not need /etc or /usr rw
# - Does not need to run as root or sudo
# - Does not use the network

# initramfs and most tools generating initramfs are designed to be host specific

# In general each kernel version will have to have its own initramfs
# but with a bit of work it is possible to make initramfs generic (not HW or host SW specific)

# https://fai-project.org/
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
  export KERNEL="5.11.0-34-generic"
fi

echo $KERNEL

mkdir -p /efi

export DEBIAN_FRONTEND=noninteractive

# Install nvidea driver - this is the only package from restricted source
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} restricted" > /etc/apt/sources.list.d/restricted.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security restricted" >> /etc/apt/sources.list.d/restricted.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-updates restricted" >> /etc/apt/sources.list.d/restricted.list

apt-get update -y -qq -o Dpkg::Use-Pty=0

# workaround for dracut
# todo - upstream patch
apt-get purge -y -qq -o Dpkg::Use-Pty=0 fuse3

apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL

# bootloader
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 grub-efi-amd64-bin grub-pc-bin syslinux-common grub2-common unzip mtools

# dracut/initrd
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio iputils-arping build-essential asciidoc-base xsltproc docbook-xsl libkmod-dev pkg-config wget btrfs-progs ntfs-3g fuse

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-modules-extra-$KERNEL linux-headers-$KERNEL

echo $RELEASE

cat /etc/apt/sources.list.d/restricted.list

apt-get --reinstall install -y nvidia-driver-460

# kernel binary
mkdir -p /efi/kernel
cp -r /boot/vmlinuz-$KERNEL /efi/kernel/vmlinuz

# grub efi binary
mkdir -p /efi/EFI/BOOT/
cp /tmp/grub.cfg /efi/EFI/BOOT/

# use regexp to remove path part to determine the root
cat > /tmp/grub_efi.cfg << EOF
regexp --set base "(.*)/" \$cmdpath
regexp --set base "(.*)/" \$base
set root=\$base
configfile \$cmdpath/grub.cfg
EOF

cat > /tmp/grub_bios.cfg << EOF
prefix=
root=\$cmdpath
configfile \$cmdpath/EFI/BOOT/grub.cfg
EOF

LEGACYDIR="/efi/syslinux"
ISODIR="/efi/isolinux"
mkdir -p $LEGACYDIR
mkdir -p $ISODIR

# syslinux binary
cp /usr/lib/syslinux/mbr/gptmbr.bin $LEGACYDIR
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 $LEGACYDIR

# grub pc binary
cp -r /usr/lib/grub/i386-pc/lnxboot.img $LEGACYDIR/

# syslinux config - chainload grub
cat > $LEGACYDIR/syslinux.cfg <<EOF
DEFAULT grub
LABEL grub
 LINUX lnxboot.img
 INITRD core.img
EOF

# normal - loaded by default
# part_msdos part_gpt - mbr and gpt partition table support
# fat btrfs ext2 ntfs iso9660 hfsplus - search by fs labels and read files from fs
# linux - boot linux kernel
# linux16 - boot linux kernel 16 bit for netboot-xyz
# ntldr - boot windows
# loadenv - read andd write grub file used for boot once configuration
# test - conditionals in grub config file
# regexp - regexp, used to remove path part from a variable
# smbios - detect motherboard ID
# loopback - boot iso files
# chain - chain boot
# search - finfd partitions (by label or uuid, but no suport for part_label)

# configfile - is this really needed

# minicmd ls cat - interactive debug in grub shell

GRUB_MODULES="normal part_msdos part_gpt fat btrfs ext2 ntfs iso9660 hfsplus linux linux16 loadenv test regexp smbios loopback chain search configfile minicmd ls cat"

# for more control, consider just invoking grub-mkimage directly
# grub-mkstandalone just a wrapper on top of grub-mkimage

grub-mkstandalone --format=i386-pc    --output="$LEGACYDIR/core.img" --install-modules="$GRUB_MODULES biosdisk ntldr" --modules="$GRUB_MODULES biosdisk" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_bios.cfg"
grub-mkstandalone --format x86_64-efi --output="/efi/EFI/BOOT/bootx64.efi"  --install-modules="$GRUB_MODULES"          --modules="$GRUB_MODULES"          --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_efi.cfg"

cp /usr/lib/grub/i386-pc/boot_hybrid.img $ISODIR/

# bios boot for booting from a CD-ROM drive
cat /usr/lib/grub/i386-pc/cdboot.img $LEGACYDIR/core.img > $ISODIR/bios.img

# EFI boot partition - FAT16 disk image
dd if=/dev/zero of=$ISODIR/efiboot.img bs=1M count=10 && \
sudo mkfs.vfat $ISODIR/efiboot.img && \
LC_CTYPE=C mmd -i $ISODIR/efiboot.img efi efi/boot && \
LC_CTYPE=C mcopy -i $ISODIR/efiboot.img /efi/EFI/BOOT/bootx64.efi ::efi/boot/

# Make sure we have all the required modules built
$SCRIPTS/infra-install-vmware-workstation-modules.sh

rm -rf /tmp/initrd
mkdir -p /tmp/initrd
cd /tmp/initrd

mksquashfs /usr/lib/modules /efi/kernel/modules

# TCE binary
mkdir -p /efi/tce
mkdir -p /efi/tce/optional
wget --no-check-certificate --no-verbose https://distro.ibiblio.org/tinycorelinux/12.x/x86/release/Core-current.iso
wget --no-verbose http://www.tinycorelinux.net/12.x/x86/tcz/openssl-1.1.1.tcz
wget --no-verbose http://www.tinycorelinux.net/12.x/x86/tcz/openssh.tcz

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

# netboot-xyz
wget --no-verbose --no-check-certificate https://boot.netboot.xyz/ipxe/netboot.xyz.lkrn
wget --no-verbose --no-check-certificate https://boot.netboot.xyz/ipxe/netboot.xyz.efi
mkdir -p /efi/netboot
mv netboot.xyz* /efi/netboot/

# dracut
rm -rf 055.zip dracut-055
wget --no-verbose --no-check-certificate https://github.com/dracutdevs/dracut/archive/refs/tags/055.zip
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

echo "stage ${0##*/} "

# Maybe make the argument more generic URL that curl understands - including file://
# calling curl is easy.. making sure networking is up is the hard part and also do you really want to make boot dependent on network

# todo - add support loopback mount a file

# EFI label has priority over EFI_* labels
configdrive=""

if [ -L /dev/disk/by-label/EFI ]; then
  configdrive="/dev/disk/by-label/EFI"
else



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

drive=$(readlink -f $configdrive)

printf "[rd.exec] Mounting $configdrive = $drive to $mp\n"
mount -o ro,noexec,nosuid,nodev,umask=0077 "$drive" "$mp"
printf "[rd.exec] Mounted config\n"

# Restrict only root process to load kernel modules. This is a reasonable system hardening
# todo - mount modules earlier in the dracut lifecycle so that initramfs does not need to include any modules at all
# todo - so build and test dracut with --no-kernel

# todo - does not work for isoboot
if [ -f /run/media/efi/kernel/modules ]; then
  mkdir -p /run/media/modules
  printf "[rd.exec] Mounting modules \n"
  mount /run/media/efi/kernel/modules /run/media/modules
  if [ -d $NEWROOT/lib/modules ]; then
    mv $NEWROOT/lib/modules $NEWROOT/lib/modules.root
  fi
  ln -sf /run/media/modules $NEWROOT/lib/
  printf "[rd.exec] Mounted modules \n"
fi

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

# Keep initramfs simple and do not require networking

# fedora
# --nomdadmconf --nolvmconf --xz --add 'livenet dmsquash-live dmsquash-live-ntfs convertfs pollcdrom qemu qemu-net' --omit 'plymouth' --no-hostonly --debug --no-early-microcode --force

# todo --no-kernel --omit 'plymouth'  --debug --no-early-microcode --nomdadmconf --nolvmconf
# todo qemu qemu-net convertfs pollcdrom
# livenet - seems useful

# todo  - systemd-sysusers seems useful
# --modules 'bash systemd systemd-initrd btrfs kernel-modules rootfs-block udev-rules dracut-systemd base fs-lib dmsquash-live dmsquash-live-ntfs dm img-lib' \
# systemd-sysusers seems useful

# usrmount - seems useful

# todo - it shoudl not be needed to excluce net explicitly
# qemu-net

dracut --keep --verbose --force --no-hostonly --reproducible \
  --add 'dmsquash-live-ntfs' \
  --omit 'nvdimm qemu kernel-modules-extra kernel-network-modules systemd-networkd qemu-net lunmask modsign systemd-sysusers crypt usrmount' \
  --add-drivers 'nls_iso8859_1' \
  --omit-drivers 'nvidia nvidia_drm nvidia_uvm nvidia_modeset' \
  --include /tmp/infra-init.sh /sbin/infra-init.sh \
  --include /tmp/rdexec /usr/lib/dracut/hooks/pre-pivot/99-exec.sh \
  --include /usr/bin/cut /usr/bin/cut \
  --include /usr/bin/head /usr/bin/head \
  --include /usr/bin/grep /usr/bin/grep \
  --include /usr/bin/touch /usr/bin/touch \
  --include /usr/bin/chmod /usr/bin/chmod \
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
#find /efi

# use syslinux only for booting legacy/non-ufi systems - for uefi system, no need to introduce an extra complexity into booting
