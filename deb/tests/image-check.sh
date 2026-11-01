#!/bin/bash
# image-check.sh ESP_IMAGE ROOT_IMAGE USR_IMAGE NAME : check the disk images
# built by VM mode (offline)
. "${0%/*}/lib.sh"
ESP_IMG=$1 IMG=$2 USR_IMG=$3 NAME=$4 M=/tmp/imgcheck
LE=$(losetup -f --show -P "$ESP_IMG")
L=$(losetup -f --show -P "$IMG")
LU=$(losetup -f --show -P "$USR_IMG")
for i in $(seq 50); do [ -b "${LE}p1" ] && [ -b "${L}p1" ] && [ -b "${LU}p1" ] && break; sleep 0.1; done
trap 'umount -R $M 2>/dev/null; losetup -d $LE $L $LU' EXIT

ok esp_disk_64M   [ "$(stat -c %s "$ESP_IMG")" -eq $((64 * 1024 * 1024)) ]
ok root_disk_512M [ "$(stat -c %s "$IMG")" -eq $((512 * 1024 * 1024)) ]
ok usr_disk_4G    [ "$(stat -c %s "$USR_IMG")" -eq $((4 * 1024 * 1024 * 1024)) ]
ok gpt_esp  eval 'sgdisk -i 1 "$ESP_IMG" | grep -q "EFI system partition"'
ok gpt_root eval 'sgdisk -i 1 "$IMG" | grep -q "Linux x86-64 root"'
ok gpt_usr  eval 'sgdisk -i 1 "$USR_IMG" | grep -q "Linux x86-64 /usr"'
ok fsck_esp  fsck.vfat -n "${LE}p1" >/dev/null
ok fsck_root e2fsck -fn "${L}p1" >/dev/null 2>&1
ok fsck_usr  e2fsck -fn "${LU}p1" >/dev/null 2>&1
mkdir -p $M; mount "${L}p1" $M
ok root_fs_usr_dir_empty  [ -d $M/usr -a -z "$(ls -A $M/usr)" ]
ok root_fs_esp_dir_empty  [ -d $M/boot/efi -a -z "$(ls -A $M/boot/efi)" ]
mount "${LU}p1" $M/usr; mount "${LE}p1" $M/boot/efi
mount -t proc proc $M/proc; mount --bind /dev $M/dev; mount --make-private $M/dev
ROOT_UUID=$(blkid -s UUID -o value "${L}p1") ESP_UUID=$(blkid -s UUID -o value "${LE}p1")
USR_UUID=$(blkid -s UUID -o value "${LU}p1")
echo "INFO used: / $(df -h --output=used $M | tail -n 1 | tr -d ' ') of 512M, /usr $(df -h --output=used $M/usr | tail -n 1 | tr -d ' '), ESP $(df -h --output=used $M/boot/efi | tail -n 1 | tr -d ' ')"

ok fstab_root grep -q "^UUID=$ROOT_UUID / ext4 " $M/etc/fstab
ok fstab_usr  grep -q "^UUID=$USR_UUID /usr ext4 " $M/etc/fstab
ok fstab_esp  grep -q "^UUID=$ESP_UUID /boot/efi vfat " $M/etc/fstab
ok efi_removable [ -s $M/boot/efi/EFI/BOOT/BOOTX64.EFI ]
ok grub_cfg_root    grep -q "root=UUID=$ROOT_UUID" $M/boot/grub/grub.cfg
ok grub_cfg_console grep -q 'console=ttyS0,115200' $M/boot/grub/grub.cfg
ok kernel [ -n "$(ls $M/boot/vmlinuz-*-cloud-amd64 2>/dev/null)" ]
initrd=$(ls $M/boot/initrd.img-* 2>/dev/null | head -n 1)
ok initrd [ -s "$initrd" ]
mods=$(chroot $M lsinitrd "${initrd#$M}" 2>/dev/null)
kver=${initrd##*initrd.img-}
for m in virtio_scsi sd_mod ext4; do
	ok "initrd_or_builtin_$m" eval "has \"\$mods\" \"/$m.ko\" || grep -q \"/$m.ko\" $M/usr/lib/modules/$kver/modules.builtin"
done
ok dracut_hostonly_no grep -qx 'hostonly="no"' $M/etc/dracut.conf.d/10-vm.conf

ok hostname [ "$(cat $M/etc/hostname)" = "$NAME" ]
ok hosts grep -q "127.0.1.1 $NAME" $M/etc/hosts
ok network_file grep -q 'DHCP=yes' $M/etc/systemd/network/10-wired.network
ok networkd_enabled [ -L $M/etc/systemd/system/multi-user.target.wants/systemd-networkd.service ]
ok resolved_enabled [ -n "$(find $M/etc/systemd/system -name systemd-resolved.service -type l)" ]
ok resolv_conf_stub [ "$(readlink $M/etc/resolv.conf)" = ../run/systemd/resolve/stub-resolv.conf ]
ok machine_id_empty [ -f $M/etc/machine-id -a ! -s $M/etc/machine-id ]
ok root_password_set eval "grep '^root:' $M/etc/shadow | cut -d: -f2 | grep -q '^\\\$'"
ok apt_lists_empty [ -z "$(ls -A $M/var/lib/apt/lists | grep -v -e '^lock$' -e '^partial$' -e '^auxfiles$')" ]
ok apt_archives_empty [ -z "$(find $M/var/cache/apt/archives -name '*.deb')" ]

status=$(chroot $M dpkg-query -W -f '${Package} ${db:Status-Abbrev}\n')
echo "INFO packages installed: $(printf '%s\n' "$status" | grep -c ' ii '); used: $(df -h --output=used $M | tail -n 1 | tr -d ' ')"
ok all_ii [ -z "$(printf '%s\n' "$status" | grep -v ' ii ')" ]
for p in linux-image-cloud-amd64 grub-efi-amd64-bin dracut qemu-guest-agent systemd-resolved; do
	ok "installed_$p" eval "printf '%s\n' \"\$status\" | grep -q '^$p '"
done
for p in perl-base init-system-helpers; do
	nok "not_installed_$p" eval "printf '%s\n' \"\$status\" | grep -q '^$p '"
done
nok no_perl [ -e $M/usr/bin/perl ]
ok dpkg_audit [ -z "$(chroot $M dpkg --audit 2>&1)" ]
out=$(chroot $M apt-get check 2>&1); rc=$?
note=$(printf "%s\n" "$out" | grep -m1 -E "Depends|^E:")
ok "apt_get_check${note:+ ($note)}" [ $rc -eq 0 ]
summary
