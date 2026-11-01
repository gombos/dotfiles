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
ok vm_scsi0_esp      has "$conf" "scsi0: local-lvm:vm-100-disk-1"
ok vm_scsi1_root     has "$conf" "scsi1: local-lvm:vm-100-disk-2"
ok vm_scsi2_usr      has "$conf" "scsi2: local-lvm:vm-100-disk-3"
nok vm_unused_left   has "$conf" "unused"
nok vm_no_tags        has "$conf" "--tags"
ok vm_boot_order     grep -qx "boot: order=scsi0" /tmp/qm/100.conf
ok vm_started        [ -f /tmp/qm/100.log ]
ok images_imported   [ -s /tmp/qm/vm-100-disk-1.raw -a -s /tmp/qm/vm-100-disk-2.raw -a -s /tmp/qm/vm-100-disk-3.raw ]
ok workdir_removed   [ -z "$(ls -A /tmp/work)" ]
nok loop_left        eval 'losetup -a | grep -q /tmp/work'
nok mounts_left      eval 'grep -q /tmp/work /proc/mounts'
summary
