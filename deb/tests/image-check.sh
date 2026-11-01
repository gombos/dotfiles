#!/bin/bash
# image-check.sh DISTRO ESP_IMAGE ROOT_IMAGE USR_IMAGE MODULES_IMAGE NAME : check
# the disk images built by VM mode (offline)
. "${0%/*}/lib.sh"
D=$1 ESP_IMG=$2 IMG=$3 USR_IMG=$4 MOD_IMG=$5 NAME=$6 M=/tmp/imgcheck
LE=$(losetup -f --show -P "$ESP_IMG")
L=$(losetup -f --show -P "$IMG")
LU=$(losetup -f --show -P "$USR_IMG")
LM=$(losetup -f --show -P "$MOD_IMG")
for i in $(seq 50); do [ -b "${LE}p1" ] && [ -b "${L}p1" ] && [ -b "${LU}p1" ] && [ -b "${LM}p1" ] && break; sleep 0.1; done
trap 'umount -R $M 2>/dev/null; losetup -d $LE $L $LU $LM' EXIT

ok esp_disk_64M      [ "$(stat -c %s "$ESP_IMG")" -eq $((64 * 1024 * 1024)) ]
ok root_disk_512M    [ "$(stat -c %s "$IMG")" -eq $((512 * 1024 * 1024)) ]
ok usr_disk_4G       [ "$(stat -c %s "$USR_IMG")" -eq $((4 * 1024 * 1024 * 1024)) ]
ok modules_disk_512M [ "$(stat -c %s "$MOD_IMG")" -eq $((512 * 1024 * 1024)) ]
ok gpt_esp     eval 'sgdisk -i 1 "$ESP_IMG" | grep -q "EFI system partition"'
ok gpt_root    eval 'sgdisk -i 1 "$IMG" | grep -q "Linux x86-64 root"'
ok gpt_usr     eval 'sgdisk -i 1 "$USR_IMG" | grep -q "Linux x86-64 /usr"'
ok gpt_modules eval 'sgdisk -i 1 "$MOD_IMG" | grep -q "Linux filesystem"'
ok fsck_esp     fsck.vfat -n "${LE}p1" >/dev/null
ok fsck_root    e2fsck -fn "${L}p1" >/dev/null 2>&1
ok fsck_usr     e2fsck -fn "${LU}p1" >/dev/null 2>&1
ok fsck_modules e2fsck -fn "${LM}p1" >/dev/null 2>&1
ok modules_fs_label [ "$(blkid -s LABEL -o value "${LM}p1")" = modules ]
mkdir -p $M; mount "${L}p1" $M
ok root_fs_usr_dir_empty  [ -d $M/usr -a -z "$(ls -A $M/usr)" ]
ok root_fs_esp_dir_empty  [ -d $M/efi -a -z "$(ls -A $M/efi)" ]
mount "${LU}p1" $M/usr
ok usr_fs_has_modules [ -n "$(ls $M/usr/lib/modules/*/modules.dep 2>/dev/null)" ]
mkdir -p /tmp/modcheck; mount -o ro "${LM}p1" /tmp/modcheck
ok modules_disk_same_as_usr diff -r -x lost+found $M/usr/lib/modules /tmp/modcheck
umount /tmp/modcheck
mount "${LM}p1" $M/usr/lib/modules; mount "${LE}p1" $M/efi
mount -t proc proc $M/proc; mount --bind /dev $M/dev; mount --make-private $M/dev
ROOT_UUID=$(blkid -s UUID -o value "${L}p1") ESP_UUID=$(blkid -s UUID -o value "${LE}p1")
USR_UUID=$(blkid -s UUID -o value "${LU}p1") MOD_UUID=$(blkid -s UUID -o value "${LM}p1")
echo "INFO used: / $(df -h --output=used $M | tail -n 1 | tr -d ' ') of 512M, /usr $(df -h --output=used $M/usr | tail -n 1 | tr -d ' '), modules $(df -h --output=used $M/usr/lib/modules | tail -n 1 | tr -d ' '), ESP $(df -h --output=used $M/efi | tail -n 1 | tr -d ' ')"

ok fstab_root grep -q "^UUID=$ROOT_UUID / ext4 " $M/etc/fstab
ok fstab_usr  grep -q "^UUID=$USR_UUID /usr ext4 ro " $M/etc/fstab
ok fstab_modules grep -qxF "UUID=$MOD_UUID /usr/lib/modules ext4 x-systemd.before=systemd-modules-load.service,nofail 0 2" $M/etc/fstab
ok usr_and_modules_different_disks [ -n "$USR_UUID" -a -n "$MOD_UUID" -a "$USR_UUID" != "$MOD_UUID" ]
ok fstab_esp  grep -q "^UUID=$ESP_UUID /efi vfat " $M/etc/fstab
ok modules_on_modules_disk [ -n "$(ls $M/usr/lib/modules/*/modules.dep 2>/dev/null)" ]
uki=$M/efi/EFI/BOOT/BOOTX64.EFI
ok uki_present [ -s "$uki" ]
echo "INFO unified kernel image: $(du -h "$uki" | cut -f1)"
sections=$(objdump -h "$uki" 2>/dev/null)
for s in .linux .initrd .cmdline .osrel .uname; do ok "uki_section_$s" has "$sections" " $s "; done
cmdline=$(objcopy -O binary -j .cmdline "$uki" /dev/stdout 2>/dev/null | tr -d '\0')
ok uki_cmdline_root    has "$cmdline" "root=LABEL=root"
ok uki_cmdline_console has "$cmdline" "console=ttyS0,115200"
ok root_fs_label [ "$(blkid -s LABEL -o value "${L}p1")" = root ]
ok usr_fs_label  [ "$(blkid -s LABEL -o value "${LU}p1")" = usr ]
objcopy -O binary -j .initrd "$uki" /tmp/uki.initrd 2>/dev/null
# lsinitrd lists all concatenated archives (early cpio + compressed parts)
files=$(lsinitrd /tmp/uki.initrd 2>/dev/null)
ok uki_initrd_switch_root has "$files" "bin/switch_root"
kver=$(cd $M/usr/lib/modules && for d in *; do [ -e "$d/modules.dep" ] && echo "$d"; done | head -n 1)
ok uki_initrd_usrmount has "$files" "mount-usr.sh"
for m in virtio_scsi sd_mod ext4 virtio_net virtio_balloon autofs4 vfat; do
	ok "uki_initrd_or_builtin_$m" eval "has \"\$files\" \"/$m.ko\" || grep -q \"/$m.ko\" $M/usr/lib/modules/$kver/modules.builtin"
done
nok kernel_in_boot [ -n "$(ls $M/boot/vmlinuz-* 2>/dev/null)" ]
nok initrd_in_boot [ -n "$(ls $M/boot/initrd.img-* $M/boot/initramfs-* 2>/dev/null)" ]
nok grub_left [ -e $M/boot/grub ]

ok hostname [ "$(cat $M/etc/hostname)" = "$NAME" ]
ok hosts grep -q "127.0.1.1 $NAME" $M/etc/hosts
ok network_file grep -q 'DHCP=yes' $M/etc/systemd/network/10-wired.network
ok networkd_enabled [ -L $M/etc/systemd/system/multi-user.target.wants/systemd-networkd.service ]
ok resolved_enabled [ -n "$(find $M/etc/systemd/system -name systemd-resolved.service -type l)" ]
ok resolv_conf_stub [ "$(readlink $M/etc/resolv.conf)" = ../run/systemd/resolve/stub-resolv.conf ]
ok machine_id_empty [ -f $M/etc/machine-id -a ! -s $M/etc/machine-id ]
ok root_password_set eval "grep '^root:' $M/etc/shadow | cut -d: -f2 | grep -q '^\\\$'"
case "$D" in
debian)
	ok apt_lists_empty [ -z "$(ls -A $M/var/lib/apt/lists | grep -v -e '^lock$' -e '^partial$' -e '^auxfiles$')" ]
	ok apt_archives_empty [ -z "$(find $M/var/cache/apt/archives -name '*.deb')" ]
	status=$(chroot $M dpkg-query -W -f '${Package} ${db:Status-Abbrev}\n')
	pkgs=$(printf '%s\n' "$status" | cut -d' ' -f1 | sed 's/:.*//')
	ok all_ii [ -z "$(printf '%s\n' "$status" | grep -v ' ii ')" ]
	want="kmod udev qemu-guest-agent systemd-resolved"
	gone="linux-image-cloud-amd64 no-initramfs-tool perl-base init-system-helpers dracut dracut-core
		dracut-network systemd-ukify systemd-boot-efi python3 iproute2 util-linux-extra grub-efi-amd64-bin
		initramfs-tools"
	nok no_kernel_packages eval 'printf "%s\n" "$pkgs" | grep -qE "^linux-(image|binary|modules)-"'
	nok autoremove_kernels_left [ -e $M/etc/apt/apt.conf.d/01autoremove-kernels ]
	ok dpkg_audit [ -z "$(chroot $M dpkg --audit 2>&1)" ]
	out=$(chroot $M apt-get check 2>&1); rc=$?
	note=$(printf "%s\n" "$out" | grep -m1 -E "Depends|^E:")
	ok "apt_get_check${note:+ ($note)}" [ $rc -eq 0 ]
	;;
arch)
	ok pacman_sync_empty  [ -z "$(ls -A $M/var/lib/pacman/sync)" ]
	ok pacman_cache_empty [ -z "$(ls -A $M/var/cache/pacman/pkg)" ]
	ok pacman_sandbox_stock eval 'grep -qx "DownloadUser = alpm" $M/etc/pacman.conf && ! grep -q "^DisableSandbox" $M/etc/pacman.conf'
	nok pacman_build_conf_left [ -e $M/etc/pacman-build.conf ]
	pkgs=$(chroot $M pacman -Qq)
	want="kmod qemu-guest-agent systemd base"
	gone="linux dracut systemd-ukify no-initramfs mkinitcpio python perl grub"
	out=$(chroot $M pacman -Dk 2>&1); rc=$?
	ok "pacman_dk${out:+ ($(printf '%s' "$out" | head -n 1))}" [ $rc -eq 0 ]
	;;
esac
echo "INFO packages installed: $(printf '%s\n' "$pkgs" | wc -l); used: $(df -h --output=used $M | tail -n 1 | tr -d ' ')"
for p in $want; do ok "installed_$p" eval "printf '%s\n' \"\$pkgs\" | grep -qx '$p'"; done
for p in $gone; do nok "not_installed_$p" eval "printf '%s\n' \"\$pkgs\" | grep -qx '$p'"; done
nok no_perl [ -e $M/usr/bin/perl ]
summary
