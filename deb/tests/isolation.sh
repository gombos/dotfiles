#!/bin/bash
# isolation.sh ROOTFS : VM build on a host-like mount namespace (shared
# propagation) while a "service" namespace is created mid-build, as systemd
# does for services and timers. That namespace gets a copy of the image mounts
# plus a mount of its own on top, so an unmount cannot reach it; the image must
# still detach cleanly. Run via "unshare -m --propagation unchanged".
. "${0%/*}/lib.sh"
mount --make-rshared /
export PATH=$TESTS/stubs:$PATH QM_STATE=/tmp/qm-iso
rm -rf /tmp/work-iso /tmp/spy.seen "$QM_STATE"; mkdir -p /tmp/work-iso

# spy: as soon as the image is mounted, start the "service" namespace
( for i in $(seq 3000); do
	m=$(awk '$5 ~ "^/tmp/work-iso/.*/mnt$" {print $5; exit}' /proc/self/mountinfo)
	if [ -n "$m" ] && [ -d "$m/tmp" ]; then
		echo "$m" > /tmp/spy.seen
		exec unshare -m --propagation slave bash -c "mount -t tmpfs spy '$m/tmp' && exec sleep 900"
	fi
	sleep 0.2
  done ) &
spy=$!

# an older VM 200 is running: answer "y" to replace it
mkdir -p "$QM_STATE"; printf "create: --name old\nname: old\n" > "$QM_STATE/200.conf"
touch "$QM_STATE/200.running" "$QM_STATE/vm-200-disk-5.raw"

out=$(printf "y\n" | ROOT_PASSWORD=test WORKDIR=/tmp/work-iso "$T" iso "$1" 200 iso 2>&1); rc=$?
printf '%s\n' "$out" > "$OUT/isolation-output.log"
ok  isolated_build_rc [ $rc -eq 0 ]
[ $rc -eq 0 ] || printf '%s\n' "$out" | tail -n 3 | sed 's/^/INFO /'
nok image_mounts_visible_outside [ -e /tmp/spy.seen ]
ok  vm_created  grep -qx "name: iso" "$QM_STATE/200.conf"
calls=$(grep -n -E "^(stop|destroy|create) 200" "$QM_STATE/calls" | cut -d: -f2 | cut -d" " -f1 | tr "\n" " ")
ok  old_vm_stopped_deleted_then_created [ "$calls" = "stop destroy create " ]
ok  old_vm_purged has "$(cat "$QM_STATE/calls")" "destroy 200 --purge 1 --destroy-unreferenced-disks 1"
nok old_vm_disk_left [ -e "$QM_STATE/vm-200-disk-5.raw" ]
ok  new_vm_started [ -f "$QM_STATE/200.running" ]

pkill -P $spy 2>/dev/null; kill $spy 2>/dev/null; pkill -f 'sleep 900' 2>/dev/null
wait 2>/dev/null
summary
