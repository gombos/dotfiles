#!/bin/bash
# Unit tests of single functions, mostly for paths a normal build never takes.
. "${0%/*}/lib.sh"
load_functions unit
cd /tmp

r=$(run without "a b c a" "a d"); ok without_basic [ "$r" = "b c " ]
r=$(run without "x" "x");         ok without_all [ -z "${r// /}" ]
r=$(run list_name dists/forky/Release); ok list_name [ "$r" = "deb.debian.org_debian_dists_forky_Release" ]

out=$(printf 'status: libc6:amd64: half-installed\nstatus: libc6:amd64: unpacked\nstatus: bash: half-installed\n' | cap dpkg_progress UNPACKING)
ok dpkg_progress_unpack [ "$out" = $'I: Unpacking libc6:amd64...\nI: Unpacking bash...' ]
out=$(printf 'status: bash: half-configured\nstatus: bash: installed\nstatus: bash: half-installed\n' | cap dpkg_progress CONFIGURING)
ok dpkg_progress_configure [ "$out" = 'I: Configuring bash...' ]

echo hello > /tmp/f; sum=$(sha256sum < /tmp/f | cut -d' ' -f1); size=$(wc -c < /tmp/f)
ok  verify_ok   run verify_checksum /tmp/f "$sum" "$size"
nok verify_size run verify_checksum /tmp/f "$sum" 99
nok verify_sum  run verify_checksum /tmp/f 0000 "$size"
ok  get_cached  run get http://127.0.0.1:9/f /tmp/f "$sum" "$size"
rm -rf /tmp/g; mkdir -p /tmp/g/partial
out=$(cap get http://127.0.0.1:9/f /tmp/g/f "$sum" "$size" http://127.0.0.1:9/by-hash); rc=$?
ok get_fail_rc      [ $rc -ne 0 ]
ok get_fail_retries [ "$(printf '%s\n' "$out" | grep -c 'Retrying failed download')" -eq 10 ]
ok get_fail_msg     has "$out" "was corrupt"
ok get_fail_clean   [ -z "$(ls -A /tmp/g/partial)" -a ! -e /tmp/g/f ]
ok  repeatn_ok   run repeatn 3 true
nok repeatn_fail run repeatn 2 false

printf 'Origin: Debian\nMD5Sum:\n zzz 1 main/binary-amd64/Packages.gz\nSHA256:\n abc 123 main/binary-amd64/Packages.xz\n def 456 main/binary-amd64/Packages.gz\nSHA512:\n yyy 9 main/binary-amd64/Packages.gz\n' > /tmp/Release
r=$(run release_checksum /tmp/Release main/binary-amd64/Packages.gz); ok release_checksum [ "$r" = "def 456" ]
r=$(run release_checksum /tmp/Release nothing);                       ok release_checksum_none [ -z "$r" ]

cat > /tmp/Packages <<'PK'
Package: a
Priority: required
Version: 1:2.0-1
Architecture: amd64
Depends: b (>= 1), c | d, libx:any, virtual-only
Filename: pool/a.deb
SHA256: s1
Size: 10

Package: b
Priority: optional
Version: 1
Architecture: all
Pre-Depends: e
Filename: pool/b.deb
SHA256: s2
Size: 20

Package: c
Priority: required
Version: 1
Architecture: amd64

Package: d
Version: 1

Package: e
Version: 1

Package: libx
Version: 1
PK
PKGFILE=/tmp/Packages
r=$(run get_debs Priority required | tr '\n' ' '); ok get_debs     [ "$r" = "a c " ]
r=$(run resolve_deps a);                           ok resolve_deps [ "$r" = "a b c e libx " ]
r=$(run pkg_details a zz);                         ok pkg_details  [ "$r" = $'a 1:2.0-1 amd64 pool/a.deb s1 10\nzz -' ]
r=$(run pkg_stanzas c | head -n 1);                ok pkg_stanzas  [ "$r" = "Package: c" ]

TARGET=/tmp/dd; ARCHIVES=/var/cache/apt/archives; rm -rf $TARGET; mkdir -p $TARGET/debootstrap
out=$( ( cap download_debs zz ) ); ok download_debs_missing has "$out" "find these debs: zz"
declare -gA DEBPATH=([a]=/x/a.deb [c]=/x/c.deb)	# sourced inside a function, the script's declare -A was local
r=$(run debfor a nope c | tr '\n' ' '); ok debfor [ "$r" = "/x/a.deb /x/c.deb " ]

mkdir -p /tmp/cc/tmp; echo L > /tmp/lnksrc; ln -sf /tmp/lnksrc /tmp/lnk
run conditional_cp /tmp/lnk /tmp/cc;         ok conditional_cp_symlink [ -f /tmp/cc/tmp/lnk -a ! -L /tmp/cc/tmp/lnk ]
echo X > /tmp/cc/tmp/lnk; run conditional_cp /tmp/lnk /tmp/cc; ok conditional_cp_keep [ "$(cat /tmp/cc/tmp/lnk)" = X ]
ok conditional_cp_missing run conditional_cp /tmp/nonexistent /tmp/cc

TARGET=/tmp/broken; mkdir -p $TARGET/debootstrap
printf 'x\ndpkg: error processing package foo (--configure):\n' > $TARGET/debootstrap/debootstrap.log
out=$(cap in_target /bin/true); rc=$?
ok in_target_fail_rc [ $rc -ne 0 ]
ok in_target_hint    has "$out" "possibly the package foo is at fault"
ok in_target_nofail  run in_target_nofail /bin/true

# setup_devices: idempotent; without CAP_MKNOD it stops with a clear message
TARGET=/tmp/tdev; rm -rf $TARGET; mkdir -p $TARGET
run setup_devices
ok devices_null  [ -c $TARGET/dev/null ]
ok devices_ptmx  [ -c $TARGET/dev/ptmx ]
ok devices_fd    [ "$(readlink $TARGET/dev/fd)" = /proc/self/fd ]
ok devices_twice run setup_devices
rm -rf /tmp/tdevu
out=$(setpriv --bounding-set=-mknod bash -c 'exec 3>&1 4>&1; source <(sed "\$d" "$DEBIAN_COV"); set +e; TARGET=/tmp/tdevu; setup_devices' 2>&1)
ok devices_no_mknod has "$out" "cannot create /tmp/tdevu/dev/null"

TARGET=/tmp/tproc; rm -rf $TARGET; mkdir -p $TARGET; UMOUNT_DIRS=""
run setup_proc
ok setup_proc [ -e $TARGET/proc/self ]
ok setup_sys  mountpoint -q $TARGET/sys
run cleanup;  ok proc_cleanup [ -z "$(grep " $TARGET" /proc/mounts)" ]

out=$( ( cap wait_for_node /dev/does-not-exist ) ); ok wait_for_node_fail has "$out" "did not appear"

# vm_cleanup after a failure: unmount, detach, keep the work directory
W=$(mktemp -d); MNT=$W/mnt; mkdir "$MNT"; mount -t tmpfs t "$MNT"
truncate -s 10M "$W/img"; LOOP=$(losetup -f --show "$W/img")
out=$(set -x; (exit 3); vm_cleanup 2>&1); set +x
nok vm_cleanup_fail_umount mountpoint -q "$MNT"
nok vm_cleanup_fail_loop   eval 'losetup -a | grep -q "$W/img"'
ok  vm_cleanup_fail_keep   [ -d "$W" ]
ok  vm_cleanup_fail_msg    has "$out" "work directory kept"
LOOP=""; (set -x; (exit 0); vm_cleanup); set +x
ok  vm_cleanup_ok_removes  [ ! -d "$W" ]

exec 9>&-
summary
