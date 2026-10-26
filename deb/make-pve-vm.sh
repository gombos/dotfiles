#!/bin/bash
# Turns a rootfs made by ./debootstrap into a bootable Proxmox VM (UEFI).
#
# Run as root on the Proxmox host:
#   ./make-pve-vm.sh <rootfs-dir> <vmid> <storage> <name>
#
# Optional env: DISK_GB (8), MEMORY (2048), CORES (2), BRIDGE (vmbr0),
#               WORKDIR (/var/tmp), START (1), ROOT_PASSWORD (asked if unset).
#
# Layout follows the community-scripts Proxmox VM defaults: q35 + OVMF,
# separate EFI disk, virtio-scsi, serial console. Disk: GPT with a 512 MiB
# ESP (FAT32) and an ext4 root partition. GRUB is installed to the removable
# path \EFI\BOOT\BOOTX64.EFI, so no NVRAM entry is needed.

set -e

die () { echo "error: $*" >&2; exit 1; }

[ $# -eq 4 ] || die "usage: $0 <rootfs-dir> <vmid> <storage> <name>"
ROOTFS="$1"; VMID="$2"; STORAGE="$3"; NAME="$4"
DISK_GB="${DISK_GB:-8}"
MEMORY="${MEMORY:-2048}"
CORES="${CORES:-2}"
BRIDGE="${BRIDGE:-vmbr0}"
WORKDIR="${WORKDIR:-/var/tmp}"
START="${START:-1}"

[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -x "$ROOTFS/usr/bin/bash" ] || die "$ROOTFS does not look like a rootfs"
for cmd in qm pvesm sgdisk losetup mkfs.ext4 mkfs.vfat blkid chroot mountpoint; do
	command -v "$cmd" >/dev/null || die "missing command: $cmd"
done
qm status "$VMID" >/dev/null 2>&1 && die "VM $VMID already exists"

STYPE=$(pvesm status | awk -v s="$STORAGE" '$1==s {print $2}')
[ -n "$STYPE" ] || die "unknown storage: $STORAGE"
case "$STYPE" in
	dir|nfs|cifs) FORMAT=qcow2 ;;
	*) FORMAT=raw ;;
esac

USED_MB=$(du -sxm "$ROOTFS" | cut -f1)
[ "$USED_MB" -lt $(( DISK_GB * 1024 - 1024 )) ] \
	|| die "rootfs needs ${USED_MB} MiB, leave 1 GiB headroom: raise DISK_GB"

if [ -z "${ROOT_PASSWORD:-}" ]; then
	read -rsp "root password for $NAME: " ROOT_PASSWORD; echo
fi
[ -n "$ROOT_PASSWORD" ] || die "empty root password"

W=$(mktemp -d "$WORKDIR/make-pve-vm.XXXXXX")
IMG="$W/disk.raw"
MNT="$W/mnt"
LOOP=""

cleanup () {
	local rc=$?
	set +e
	mountpoint -q "$MNT" && umount -R "$MNT"
	[ -n "$LOOP" ] && losetup -d "$LOOP"
	if [ $rc -eq 0 ]; then
		rm -rf "$W"
	else
		echo "failed; work directory kept for inspection: $W" >&2
	fi
}
trap cleanup EXIT

wait_for_node () {
	local i
	for i in $(seq 50); do [ -b "$1" ] && return 0; sleep 0.1; done
	die "$1 did not appear"
}

echo "creating ${DISK_GB} GiB disk image"
truncate -s "${DISK_GB}G" "$IMG"
sgdisk -Z -n1:0:+512M -t1:ef00 -c1:esp -n2:0:0 -t2:8300 -c2:root "$IMG" >/dev/null
LOOP=$(losetup -f --show -P "$IMG")
wait_for_node "${LOOP}p1"
wait_for_node "${LOOP}p2"
mkfs.vfat -F 32 -n ESP "${LOOP}p1" >/dev/null
mkfs.ext4 -q -L rootfs "${LOOP}p2"
mkdir -p "$MNT"
mount "${LOOP}p2" "$MNT"

echo "copying rootfs"
cp -a "$ROOTFS/." "$MNT/"
mkdir -p "$MNT/boot/efi" "$MNT/proc" "$MNT/sys" "$MNT/dev"
mount "${LOOP}p1" "$MNT/boot/efi"
mount -t proc proc "$MNT/proc"
mount --rbind /sys "$MNT/sys"
mount --rbind /dev "$MNT/dev"
cp /etc/resolv.conf "$MNT/etc/resolv.conf"

echo "installing kernel, bootloader and guest agent"
chroot "$MNT" apt-get update
# The rootfs has no Perl and no init-system-helpers, but the kernel and service
# packages need them (dpkg-preconfigure, update-rc.d, deb-systemd-helper). Both
# are put back for this install and purged again below, like the bootstrap does.
DEBIAN_FRONTEND=noninteractive chroot "$MNT" apt-get install -y \
	--no-install-recommends perl-base init-system-helpers
mkdir -p "$MNT/etc/dracut.conf.d"
echo 'hostonly="no"' > "$MNT/etc/dracut.conf.d/10-vm.conf"
DEBIAN_FRONTEND=noninteractive chroot "$MNT" apt-get install -y \
	--no-install-recommends dracut linux-image-cloud-amd64 grub-efi-amd64-bin qemu-guest-agent systemd-resolved
chroot "$MNT" dpkg --purge --force-depends --force-remove-essential perl-base init-system-helpers

ROOT_UUID=$(blkid -s UUID -o value "${LOOP}p2")
ESP_UUID=$(blkid -s UUID -o value "${LOOP}p1")

echo "installing bootloader"
cp "$MNT/usr/share/grub/default/grub" "$MNT/etc/default/grub"
sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200"/' \
	"$MNT/etc/default/grub"
chroot "$MNT" grub-install --target=x86_64-efi --efi-directory=/boot/efi \
	--bootloader-id=debian --removable --no-nvram
chroot "$MNT" update-grub

echo "configuring system"
cat > "$MNT/etc/fstab" <<EOF
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$ESP_UUID /boot/efi vfat umask=0077 0 2
EOF
echo "$NAME" > "$MNT/etc/hostname"
cat > "$MNT/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 $NAME
EOF
mkdir -p "$MNT/etc/systemd/network"
cat > "$MNT/etc/systemd/network/10-wired.network" <<'EOF'
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF
chroot "$MNT" systemctl enable systemd-networkd.service systemd-resolved.service
rm -f "$MNT/etc/resolv.conf"
ln -s ../run/systemd/resolve/stub-resolv.conf "$MNT/etc/resolv.conf"
: > "$MNT/etc/machine-id"
printf 'root:%s\n' "$ROOT_PASSWORD" | chroot "$MNT" chpasswd
unset ROOT_PASSWORD

chroot "$MNT" apt-get clean
rm -rf "$MNT/var/lib/apt/lists/"*

sync
umount -R "$MNT"
losetup -d "$LOOP"
LOOP=""

echo "creating VM $VMID"
qm create "$VMID" --name "$NAME" --memory "$MEMORY" --cores "$CORES" \
	--machine q35 --bios ovmf --ostype l26 --cpu host \
	--net0 "virtio,bridge=$BRIDGE" --scsihw virtio-scsi-pci \
	--agent enabled=1 --tablet 0 --onboot 1 --serial0 socket \
	--tags debian-minimal
qm set "$VMID" --efidisk0 "$STORAGE:1,efitype=4m,pre-enrolled-keys=0" >/dev/null
OUT=$(qm importdisk "$VMID" "$IMG" "$STORAGE" --format "$FORMAT" 2>&1) \
	|| { echo "$OUT" >&2; die "importdisk failed"; }
echo "$OUT"
VOLID=$(printf '%s\n' "$OUT" | sed -n "s/.*as 'unused[0-9]*:\([^']*\)'.*/\1/p")
[ -n "$VOLID" ] || die "could not find the imported disk in importdisk output"
qm set "$VMID" --scsi0 "$VOLID" --boot order=scsi0

if [ "$START" = 1 ]; then
	qm start "$VMID"
fi

echo "VM $VMID ($NAME) is ready. Console: qm terminal $VMID"
