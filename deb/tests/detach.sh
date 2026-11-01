#!/bin/bash
# detach.sh ROOTFS : vm_make_disk + vm_detach on a host-like mount namespace
# (shared propagation, as systemd sets up on Proxmox). Run via
# "unshare -m --propagation unchanged".
. "${0%/*}/lib.sh"
mount --make-rshared /
load_functions detach
ROOTFS=$1 DISK_GB=2
host_mounts () { awk '$5 ~ "^/(dev|sys)(/|$)" {print $5}' /proc/self/mountinfo | sort; }
before=$(host_mounts)

new_disk () {
	W=$(mktemp -d /tmp/detach.XXXXXX); IMG=$W/disk.raw MNT=$W/mnt LOOP=""
	run vm_make_disk >/dev/null
}

# a process left running inside the chroot is stopped, then the image detaches cleanly
new_disk
chroot "$MNT" sleep 600 & sleeper=$!
sleep 0.5
out=$( (cap vm_detach) ); rc=$?
ok  detach_busy_rc       [ $rc -eq 0 ]
ok  detach_busy_message  has "$out" "stopping processes left in the image"
state=$(awk '{print $3}' /proc/$sleeper/stat 2>/dev/null)
ok  detach_busy_killed   [ -z "$state" -o "$state" = Z ]
nok detach_unmounted     mountpoint -q "$MNT"
ok  detach_loop_released [ -z "$(losetup -j "$IMG")" ]
L2=$(losetup -f --show -P "$IMG"); sleep 0.5
ok  detach_fs_clean      e2fsck -fn "${L2}p2" >/dev/null 2>&1
losetup -d "$L2"
after=$(host_mounts)
ok  host_mounts_intact   [ "$before" = "$after" ]
[ "$before" = "$after" ] || diff <(echo "$before") <(echo "$after") | sed 's/^/INFO host mount lost: /' | grep '<'
rm -rf "$W"

# a process whose working directory (not root) is inside the image is not
# found by vm_kill_chroot_procs: vm_detach must then fail with a clear message
new_disk
(cd "$MNT/tmp" && exec sleep 600) & holder=$!
sleep 0.5
out=$( (cap vm_detach) ); rc=$?
ok detach_cwd_fails_cleanly eval '[ $rc -ne 0 ] && has "$out" "could not unmount"'
kill $holder; wait $holder 2>/dev/null
umount -R "$MNT" 2>/dev/null; [ -n "$LOOP" ] && losetup -d "$LOOP"; rm -rf "$W"

exec 9>&-
summary
