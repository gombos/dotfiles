#!/bin/bash

cd /tmp

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0
apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

# bootloader
# mtools - efi iso boot

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 \
  grub-efi-amd64-bin grub-pc-bin grub2-common \
  syslinux-common \
  isolinux mtools dosfstools wget

# for grub root variable is set to memdisk initially
# grub_cmdpath is the location from which core.img was loaded as an absolute directory name

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
# fat ext2 ntfs iso9660 hfsplus - search by fs labels and read files from fs
# linux - boot linux kernel
# linux16 - boot linux kernel 16 bit for netboot-xyz
# ntldr - boot windows
# loadenv - read andd write grub file used for boot once configuration
# test - conditionals in grub config file
# regexp - regexp, used to remove path part from a variable
# smbios - detect motherboard ID
# loopback - boot iso files
# chain - chain boot
# search - find partitions (by label or uuid, but no suport for part_label)

# configfile - is this really needed

# minicmd ls cat - interactive debug in grub shell

GRUB_MODULES="normal part_msdos part_gpt fat ext2 iso9660 ntfs hfsplus linux linux16 loadenv test regexp smbios loopback chain search configfile minicmd ls cat"

# for more control, consider just invoking grub-mkimage directly
# grub-mkstandalone just a wrapper on top of grub-mkimage

grub-mkstandalone --format=i386-pc --output="$LEGACYDIR/core.img" --install-modules="$GRUB_MODULES biosdisk ntldr" --modules="$GRUB_MODULES biosdisk" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_bios.cfg"
grub-mkstandalone --format=x86_64-efi --output="/efi/EFI/BOOT/bootx64.efi" --install-modules="$GRUB_MODULES linuxefi" --modules="$GRUB_MODULES linuxefi" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_efi.cfg"

cp /usr/lib/grub/i386-pc/boot_hybrid.img $ISODIR/

# bios boot for booting from a CD-ROM drive
cat /usr/lib/grub/i386-pc/cdboot.img $LEGACYDIR/core.img > $ISODIR/bios.img

# EFI boot partition - FAT16 disk image
dd if=/dev/zero of=$ISODIR/efiboot.img bs=1M count=10 && \
mkfs.vfat $ISODIR/efiboot.img && \
LC_CTYPE=C mmd -i $ISODIR/efiboot.img efi efi/boot && \
LC_CTYPE=C mcopy -i $ISODIR/efiboot.img /efi/EFI/BOOT/bootx64.efi ::efi/boot/

# TCE binary
mkdir -p /efi/tce
mkdir -p /efi/tce/optional
wget --no-check-certificate --no-verbose https://distro.ibiblio.org/tinycorelinux/12.x/x86_64/release/CorePure64-current.iso -O tce.iso
wget --no-verbose http://www.tinycorelinux.net/12.x/x86_64/tcz/openssl-1.1.1.tcz
wget --no-verbose http://www.tinycorelinux.net/12.x/x86_64/tcz/openssh.tcz
mv tce.iso /efi/tce
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
