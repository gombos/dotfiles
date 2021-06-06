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


# initramfs for nfs
# sudo apt install --reinstall linux-image-5.4.0-52-generic overlayroot
# http://support.fccps.cz/download/adv/frr/nfs-root/nfs-root.htm#download
# sudo cp overlay.sh /etc/initramfs-tools/scripts/init-bottom/
# echo "overlay" >> /etc/initramfs-tools/modules
# sudo update-initramfs -k all -c
# sudo cp /boot/initrd.img /go/efi/kernel/initrd-nfs.img

mkdir /efi

rm -rf /tmp/initrd
mkdir -p /tmp/initrd
cd /tmp/initrd

#KERNEL=$(uname -r)
KERNEL=$(dpkg -l | grep linux-modules | head -1  | cut -d\- -f3- | cut -d ' ' -f1)
echo $KERNEL

DEBIAN_FRONTEND=noninteractive sudo apt-get update -y -qq -o Dpkg::Use-Pty=0
DEBIAN_FRONTEND=noninteractive sudo apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-5.4.0-52-generic overlayroot
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio iputils-arping build-essential asciidoc-base xsltproc docbook-xsl libkmod-dev pkg-config

rm -rf NFSroot_work.tgz
wget http://support.fccps.cz/download/adv/frr/nfs-root/NFSroot_work.tgz
tar -xzf NFSroot_work.tgz
cp ./NFSroot_work/debcfg-nfsroot/overlay.sh /etc/initramfs-tools/scripts/init-bottom
echo "overlay" >> /etc/initramfs-tools/modules
update-initramfs -k all -c
cp /boot/initrd.img /efi/initrd-nfs.img

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
# --verbose
# network-legacy
# --keep

dracut --force --no-hostonly --reproducible --omit-drivers "nvidia nvidia_drm nvidia_uvm nvidia_modeset" --add "bash busybox" --include /tmp/20-wired.network /etc/systemd/network/20-wired.network --include /tmp/rdexec /usr/lib/dracut/hooks/pre-pivot/99-exec.sh initrd.img $KERNEL

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

cp /tmp/initrd/initrd.img /efi

rm -rf /tmp/initrd
