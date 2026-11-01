#!/bin/bash
# Argument, mode and precondition errors, plus --print-debs.
. "${0%/*}/lib.sh"
cd /

mkdir -p /tmp/fake/usr/bin /tmp/notroot
cp /bin/bash /tmp/fake/usr/bin/bash
mkdir -p /tmp/fake/usr/lib; echo ID=debian > /tmp/fake/usr/lib/os-release
touch /tmp/notroot/x
export PATH=$TESTS/stubs:$PATH QM_STATE=/tmp/qm-err ROOT_PASSWORD=test
NOBODY="setpriv --reuid=65534 --regid=65534 --clear-groups"

# expect NAME "message" cmd... : command fails and its output contains message
expect () {
	local name=$1 msg=$2 out rc; shift 2
	out=$("$@" 2>&1 </dev/null); rc=$?
	if [ $rc -ne 0 ] && has "$out" "$msg"; then pass "$name"
	else fail "$name (rc=$rc, last line: $(printf '%s' "$out" | tail -n 1))"; fi
}

expect mode_invalid     "SCRIPT_MODE must be vm or bootstrap"  env SCRIPT_MODE=bad "$T" E-mode
expect distro_invalid   "--distro must be debian or arch"     env SCRIPT_MODE=bootstrap "$T" E-distro --distro fedora
expect distro_no_value  "--distro needs"                       env SCRIPT_MODE=bootstrap "$T" E-distro2 --distro
expect arch_print_debs  "not supported for --distro arch"      env SCRIPT_MODE=bootstrap "$T" E-archpd --distro arch --print-debs
expect arch_too_many    "usage:"                               env SCRIPT_MODE=bootstrap "$T" E-archmany --distro arch a b
expect arch_not_root    "the bootstrap needs root" $NOBODY env SCRIPT_MODE=bootstrap "$T" E-archroot --distro=arch /tmp/nr
expect vm_distro_mismatch "is a 'debian' rootfs, not arch"  env SCRIPT_MODE=vm "$T" E-mismatch --distro arch /tmp/fake 101 x
expect vm_distro_last   "is a 'debian' rootfs, not arch"    env SCRIPT_MODE=vm "$T" E-mismatch2 /tmp/fake 101 x --distro arch
expect bs_bad_option    "unrecognized or invalid option --foo" env SCRIPT_MODE=bootstrap "$T" E-opt --foo
expect bs_too_many      "too many arguments"                   env SCRIPT_MODE=bootstrap "$T" E-many a b
expect bs_not_root      "can only run as root" $NOBODY env SCRIPT_MODE=bootstrap "$T" E-bsroot /tmp/nr
# qm is on PATH: no arguments means VM mode with defaults (which needs root)
expect noargs_vm_mode   "must run as root" $NOBODY "$T" E-noargs
expect vm_one_arg       "usage:"                               env SCRIPT_MODE=vm "$T" E-vm1 101
expect vm_four_args     "usage:"                               env SCRIPT_MODE=vm "$T" E-vm4 a b c d
expect vm_not_root      "must run as root" $NOBODY env SCRIPT_MODE=vm "$T" E-vmroot /tmp/fake 101 x
expect vm_not_rootfs    "does not look like a rootfs"          env SCRIPT_MODE=vm "$T" E-notfs /tmp/notroot 101 x
mv /usr/sbin/sgdisk /usr/sbin/sgdisk.hidden
expect vm_missing_cmd   "missing command: sgdisk"              env SCRIPT_MODE=vm "$T" E-cmd /tmp/fake 101 x
mv /usr/sbin/sgdisk.hidden /usr/sbin/sgdisk
mkdir -p "$QM_STATE"; : > "$QM_STATE/300.conf"
expect vm_exists        "VM 300 already exists"                env SCRIPT_MODE=vm "$T" E-exists /tmp/fake 300 x
expect vm_exists_answer_no "VM 300 already exists" \
	bash -c 'printf "n\n" | SCRIPT_MODE=vm "$0" E-existsn /tmp/fake 300 x' "$T"
# <vmid> <name> uses the default rootfs; the VM check comes before any bootstrap
expect vm_exists_first  "VM 300 already exists"                env SCRIPT_MODE=vm "$T" E-exists2 300 x
nok vm_exists_no_bootstrap [ -e /tmp/rootfs ]
expect vm_no_storage    "unknown storage: local-lvm"  env SCRIPT_MODE=vm STUB_NO_LVM=1 "$T" E-stor /tmp/fake 101 x
expect vm_usr_too_small "raise USR_DISK_GB" env SCRIPT_MODE=vm STUB_STORAGE_TYPE=dir USR_DISK_GB=1 "$T" E-small /tmp/fake 101 x
expect vm_root_too_small "raise ROOT_DISK_MB" env SCRIPT_MODE=vm ROOT_DISK_MB=300 "$T" E-rootsmall /tmp/fake 101 x
mkdir -p /tmp/fakemod/usr/bin /tmp/fakemod/usr/lib/modules/1; cp /bin/bash /tmp/fakemod/usr/bin/; cp /tmp/fake/usr/lib/os-release /tmp/fakemod/usr/lib/
expect vm_modules_too_small "raise MODULES_DISK_MB" env SCRIPT_MODE=vm MODULES_DISK_MB=60 "$T" E-modsmall /tmp/fakemod 101 x
# no ROOT_PASSWORD and no terminal: no prompt, the default is used and the run
# goes on to the rootfs check
expect vm_no_password_prompt "does not look like a rootfs"     env SCRIPT_MODE=vm ROOT_PASSWORD= "$T" E-nopw /tmp/notroot 101 x

# --print-debs: as non-root from the xz index, then from the gz index with a
# relative target (ignored); both lists must match
before=$(ls -d /tmp/tmp.* 2>/dev/null | wc -l)
$NOBODY "$T" P-xz --print-debs > /tmp/pd-xz 2>/tmp/pd-xz.err
ok print_debs_nonroot [ $? -eq 0 -a -s /tmp/pd-xz ]
ok print_debs_xz_index grep -q 'Retrieving Packages.xz' /tmp/pd-xz.err
mv /usr/bin/unxz /usr/bin/unxz.hidden
(cd /tmp && SCRIPT_MODE=bootstrap "$T" P-gz --print-debs rel/dir > /tmp/pd-gz 2>/tmp/pd-gz.err)
ok print_debs_gz_rc [ $? -eq 0 ]
mv /usr/bin/unxz.hidden /usr/bin/unxz
ok print_debs_gz_index grep -q 'Retrieving Packages.gz' /tmp/pd-gz.err
ok print_debs_same cmp -s <(tr ' ' '\n' < /tmp/pd-xz | sort) <(tr ' ' '\n' < /tmp/pd-gz | sort)
ok print_debs_no_tmp_left [ "$(ls -d /tmp/tmp.* 2>/dev/null | wc -l)" -eq "$before" ]
ok print_debs_no_target [ ! -e /tmp/rel ]
pd=" $(tr -s ' \n' '  ' < /tmp/pd-xz) "
for p in gawk bash apt cdebconf systemd-sysv perl-base init-system-helpers; do
	ok "print_debs_has_$p" has "$pd" " $p "
done
for p in mawk dash tzdata gpgv; do
	nok "print_debs_lacks_$p" has "$pd" " $p "
done
cp /tmp/pd-xz "$OUT/print-debs.txt"

summary
