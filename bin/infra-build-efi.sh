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

mkdir /efi

rm -rf /tmp/initrd
mkdir -p /tmp/initrd
cd /tmp/initrd

if [ -z "$KERNEL" ]; then
  export KERNEL=$(dpkg -l | grep linux-modules | head -1  | cut -d\- -f3- | cut -d ' ' -f1)
fi

#KERNEL=$(uname -r)
echo $KERNEL

DEBIAN_FRONTEND=noninteractive sudo apt-get update -y -qq -o Dpkg::Use-Pty=0
DEBIAN_FRONTEND=noninteractive sudo apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL overlayroot
DEBIAN_FRONTEND=noninteractive sudo apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 grub-efi-amd64-bin grub-pc-bin grub-ipxe
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio iputils-arping build-essential asciidoc-base xsltproc docbook-xsl libkmod-dev pkg-config

mkdir -p /efi/kernel
rsync -av /boot/vmlinuz-$KERNEL /efi/kernel/vmlinuz

# grub efi monolith
mkdir -p /efi/EFI/BOOT/
cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi /efi/EFI/BOOT/BOOTX64.EFI
echo "source /dotfiles/boot/grub.cfg" > /efi/EFI/ubuntu/grub.cfg

# grub pc
mkdir -p /efi/grub/
rsync -av /usr/lib/grub/i386-pc /efi/grub/
echo "source /dotfiles/boot/grub.cfg" > /efi/grub/grub.cfg

# grub ipxe
mkdir -p /efi/ipxe/
cp /boot/ipxe.* /efi/ipxe/

# TCE
mkdir -p /efi/tce
mkdir -p /efi/tce/optional

mkdir -p /efi/syslinux
rsync -av /usr/lib/syslinux/modules/bios/*.c32 /efi/syslinux/
cat > /efi/syslinux/syslinux.cfg << 'EOF'
DEFAULT linux

LABEL linux
 LINUX /kernel/vmlinuz root=LABEL=linux rootflags=subvol=linux
 INITRD /kernel/initrd.img

INCLUDE /dotfiles/boot/syslinux.cfg
EOF

cat > /tmp/grub.cfg << 'EOF'
root=${cmdpath}
prefix=${cmdpath}/grub
configfile ${prefix}/grub.cfg
EOF

grub-mkstandalone --format=i386-pc --output=/efi/grub/i386-pc/core.img --install-modules="biosdisk part_msdos part_gpt configfile fat" --modules="biosdisk part_msdos part_gpt configfile fat" --locales="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub.cfg" -v

#grub-mkstandalone -d /usr/lib/grub/x86_64-efi/ -O x86_64-efi --install-modules="part_msdos part_gpt configfile fat" --modules="part_msdos part_gpt configfile fat" --locales="" --themes="" -o "/efi/EFI/BOOT/BOOTX64.EFI" --fonts="" "/boot/grub/grub.cfg=/tmp/grub.cfg" -v

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

rm -rf NFSroot_work.tgz
wget http://support.fccps.cz/download/adv/frr/nfs-root/NFSroot_work.tgz
tar -xzf NFSroot_work.tgz
cp ./NFSroot_work/debcfg-nfsroot/overlay.sh /etc/initramfs-tools/scripts/init-bottom
echo "overlay" >> /etc/initramfs-tools/modules
update-initramfs -k all -c
cp /boot/initrd.img /efi/kernel/initrd-nfs.img

rm -rf 055.zip dracut-055
wget https://github.com/dracutdevs/dracut/archive/refs/tags/055.zip
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
exec 1>/run/initramfs/rd.exec.log 2>&1

# TODO - do not hardcode EFI label
# Maybe make the argument more generic URL that curl understands - including file://

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
    if ! [ -z "$RDEXEC" ]; then
      # Mount EFI as that is where rd.exec scripts are executed from
      mp="/run/media/efi"
      mkdir -p "$mp"

      printf "[rd.exec] Mounting $configdrive to $mp\n"
      mount -o ro,fmask=0177,dmask=0077,noexec,nosuid,nodev "$configdrive" "$mp"

      # Execute the rd.exec script
      if [ -f "$mp/$RDEXEC" ]; then
        printf "[rd.exec] start executing $RDEXEC \n"
        scriptname="${RDEXEC##*/}"
        scriptpath=${RDEXEC%/*}
        configdir="$mp/$scriptpath"
        ( cd $configdir && . "./$scriptname" )
        printf "[rd.exec] stop executing $RDEXEC \n"
      fi

      # Umount EFI
      cd /
      umount "$mp"
      [ -d "$mp" ] && rmdir "$mp"
    fi
    ;;
  esac
done

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

dracut --verbose --force --no-hostonly --reproducible --omit "kernel-modules-extra" --omit-drivers "nvidia nvidia_drm nvidia_uvm nvidia_modeset" --add "btrfs nfs livenet bash busybox systemd-networkd" --include /tmp/20-wired.network /etc/systemd/network/20-wired.network --include /tmp/rdexec /usr/lib/dracut/hooks/pre-pivot/99-exec.sh initrd.img $KERNEL

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

cp /tmp/initrd/initrd.img /efi/kernel/

rm -rf /tmp/initrd

# Populate logs with the list of filenames
find /efi
