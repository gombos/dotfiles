#!/bin/bash
# detach.sh ROOTFS : vm_make_disk + vm_detach on a host-like mount namespace
# (shared propagation, as systemd sets up on Proxmox). Run via
# "unshare -m --propagation unchanged".
. "${0%/*}/lib.sh"
mount --make-rshared /
load_functions detach
ROOTFS=$1 ROOT_DISK_MB=512 USR_DISK_GB=4 ESP_DISK_MB=64 MODULES_DISK_MB=512 MODULES_LABEL=modules
host_mounts () { awk '$5 ~ "^/(dev|sys)(/|$)" {print $5}' /proc/self/mountinfo | sort; }
before=$(host_mounts)

new_disk () {
	W=$(mktemp -d /tmp/detach.XXXXXX); ESP_IMG=$W/esp.raw IMG=$W/root.raw USR_IMG=$W/usr.raw MODULES_IMG=$W/modules.raw MNT=$W/mnt LOOP="" LOOP_USR="" LOOP_ESP="" LOOP_MOD=""
	run vm_make_disk >/dev/null
}

# a process left running inside the chroot is stopped, then the image detaches cleanly
new_disk
chroot "$MNT" sleep 600 & sleeper=$!
sleep 0.5
out=$( (cap vm_detach) ); rc=$?
ok  detach_busy_rc       [ $rc -eq 0 ]
ok  detach_busy_message  has "$out" "stopping processes left in $MNT"
state=$(awk '{print $3}' /proc/$sleeper/stat 2>/dev/null)
ok  detach_busy_killed   [ -z "$state" -o "$state" = Z ]
nok detach_unmounted     mountpoint -q "$MNT"
ok  detach_loop_released [ -z "$(losetup -j "$IMG")$(losetup -j "$USR_IMG")$(losetup -j "$ESP_IMG")$(losetup -j "$MODULES_IMG")" ]
L2=$(losetup -f --show -P "$IMG"); sleep 0.5
ok  detach_fs_clean      e2fsck -fn "${L2}p1" >/dev/null 2>&1
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
ok detach_cwd_debug_names_process has "$out" "(sleep) uses $MNT/tmp"
kill $holder; wait $holder 2>/dev/null
umount -R "$MNT" 2>/dev/null; losetup -d $LOOP $LOOP_USR $LOOP_ESP $LOOP_MOD 2>/dev/null; rm -rf "$W"

# a namespace created while the image is mounted (as systemd does for
# services) keeps a copy the unmount cannot reach: e2fsck finds the device in
# use; the debug output must name that namespace. vm_main avoids this case by
# running in a private mount namespace.
new_disk
unshare -m --propagation slave bash -c "mount -t tmpfs spy '$MNT/tmp' && exec sleep 600" & spy=$!
sleep 0.5
out=$( (cap vm_detach) ); rc=$?
ok detach_nscopy_fails_cleanly eval '[ $rc -ne 0 ] && has "$out" "root filesystem check failed"'
ok detach_nscopy_debug_names_ns has "$out" "debug: mounted in mnt:["
kill $spy; wait $spy 2>/dev/null
umount -R "$MNT" 2>/dev/null; losetup -d $LOOP $LOOP_USR $LOOP_ESP $LOOP_MOD 2>/dev/null; rm -rf "$W"

exec 9>&-
summary
