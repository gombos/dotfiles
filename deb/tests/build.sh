#!/bin/bash
# build.sh DISTRO : full build with only --distro: VM mode (stub qm on PATH),
# the distribution's default rootfs bootstrapped first, next free VMID (100),
# default name (the distribution); checks the VM config. The disks end up in
# /tmp/qm-DISTRO.
. "${0%/*}/lib.sh"
D=$1
case "$D" in debian) R=/tmp/rootfs ;; *) R=/tmp/rootfs-$D ;; esac
Q=/tmp/qm-$D
rm -rf "$R" "$Q" /tmp/work; mkdir -p "$R" /tmp/work
export PATH=$TESTS/stubs:$PATH QM_STATE=$Q
out=$(env -u ROOT_PASSWORD WORKDIR=/tmp/work "$T" "build-$D" --distro "$D" 2>&1 </dev/null); rc=$?
printf '%s\n' "$out" > "$OUT/build-$D-output.log"
ok build_rc [ $rc -eq 0 ]
[ $rc -eq 0 ] || printf '%s\n' "$out" | tail -n 5 | sed 's/^/INFO /'
ok build_bootstraps_empty_default has "$out" "$R is empty, bootstrapping it first"
ok build_rootfs [ -x "$R/usr/bin/bash" ]
ok build_defaults     has "$out" "building VM 100 ($D) from $R"
conf=$(cat "$Q/100.conf" 2>/dev/null)
ok vm_create_options has "$conf" "--machine q35 --bios ovmf --ostype l26"
ok vm_name           has "$conf" "--name $D"
ok vm_efidisk        has "$conf" "efidisk0: local-lvm:vm-100-disk-0,efitype=4m,pre-enrolled-keys=0"
ok vm_scsi0_esp      has "$conf" "scsi0: local-lvm:vm-100-disk-1"
ok vm_scsi1_root     has "$conf" "scsi1: local-lvm:vm-100-disk-2"
ok vm_scsi2_usr      has "$conf" "scsi2: local-lvm:vm-100-disk-3"
ok vm_scsi3_modules  has "$conf" "scsi3: local-lvm:vm-100-disk-4"
nok vm_unused_left   has "$conf" "unused"
nok vm_no_tags       has "$conf" "--tags"
ok vm_boot_order     grep -qx "boot: order=scsi0" "$Q/100.conf"
ok vm_started        [ -f "$Q/100.log" ]
ok images_imported   [ -s "$Q/vm-100-disk-1.raw" -a -s "$Q/vm-100-disk-2.raw" -a -s "$Q/vm-100-disk-3.raw" -a -s "$Q/vm-100-disk-4.raw" ]
ok workdir_removed   [ -z "$(ls -A /tmp/work)" ]
nok loop_left        eval 'losetup -a | grep -q /tmp/work'
nok mounts_left      eval 'grep -q /tmp/work /proc/mounts'
summary
