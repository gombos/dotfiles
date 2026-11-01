#!/bin/bash
# Full build without arguments: VM mode (stub qm on PATH), default rootfs
# bootstrapped first, next free VMID (100), default name; checks the VM config.
. "${0%/*}/lib.sh"
rm -rf /tmp/rootfs /tmp/qm /tmp/work; mkdir -p /tmp/rootfs /tmp/work
export PATH=$TESTS/stubs:$PATH QM_STATE=/tmp/qm
out=$(ROOT_PASSWORD=test WORKDIR=/tmp/work "$T" build 2>&1 </dev/null); rc=$?
printf '%s\n' "$out" > "$OUT/build-output.log"
ok build_rc [ $rc -eq 0 ]
ok build_bootstraps_empty_default has "$out" "/tmp/rootfs is empty, bootstrapping it first"
ok build_rootfs [ -x /tmp/rootfs/usr/bin/bash ]
ok build_defaults     has "$out" "building VM 100 (debian) from /tmp/rootfs"
conf=$(cat /tmp/qm/100.conf 2>/dev/null)
ok vm_create_options has "$conf" "--machine q35 --bios ovmf --ostype l26"
ok vm_name            has "$conf" "--name debian"
ok vm_efidisk        has "$conf" "efidisk0: local-lvm:vm-100-disk-0,efitype=4m,pre-enrolled-keys=0"
ok vm_scsi0          has "$conf" "scsi0: local-lvm:vm-100-disk-1"
nok vm_unused_left   has "$conf" "unused"
ok vm_boot_order     has "$conf" "boot: order=scsi0"
ok vm_started        [ -f /tmp/qm/100.log ]
ok image_imported    [ -s /tmp/qm/vm-100-disk-1.raw ]
ok workdir_removed   [ -z "$(ls -A /tmp/work)" ]
nok loop_left        eval 'losetup -a | grep -q /tmp/work'
nok mounts_left      eval 'grep -q /tmp/work /proc/mounts'
summary
