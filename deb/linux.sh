#!/bin/bash
# Builds a minimal Debian rootfs, or turns one into a UEFI Proxmox VM.
#
#   sudo ./linux.sh [--print-debs] [target]              build a rootfs
#   sudo ./linux.sh [[rootfs-dir] <vmid> <name>]         build a VM
#
# rootfs-dir and target default to ROOTFS_DEFAULT (/tmp/rootfs); VM mode
# bootstraps it first when it is empty. Without arguments VM mode uses the next
# free VMID and the name VM_NAME_DEFAULT (debian).
#
# With no SCRIPT_MODE set, VM mode is used when qm is available (a Proxmox
# host) and the bootstrap mode otherwise; a leading option always means the
# bootstrap. SCRIPT_MODE=bootstrap or SCRIPT_MODE=vm overrides this.
#
# VM disks: scsi0 ESP ESP_DISK_MB (64, boot disk), scsi1 root ROOT_DISK_MB (512),
#           scsi2 /usr USR_DISK_GB (4).
# VM env: MEMORY (1024), CORES (2), BRIDGE (vmbr0),
#         WORKDIR (/var/tmp), START (1), ROOT_PASSWORD (ROOT_PASSWORD_DEFAULT: root),
#         REPLACE_VM (1: delete an existing VM with the same VMID without asking).
# The VM storage is local-lvm (set in vm_main).
#
# Notes: NOTES.md. Tests: tests/run.sh [quick|full].

die () { echo "error: $*" >&2; exit 1; }

set -e

unset TMP TEMP TMPDIR || true
export PATH
export LANG=C
umask 022

MIRROR="http://deb.debian.org/debian"
SUITE=forky
COMPONENT=main
ARCH=amd64
PRINT_DEBS=""
ROOTFS_DEFAULT=/tmp/rootfs
VM_NAME_DEFAULT=debian
ROOT_PASSWORD_DEFAULT=root

############################################################### messages
info ()    { local fmt="$1"; shift; printf "I: $fmt\n" "$@" >&4; }
warning () { local fmt="$1"; shift; printf "W: $fmt\n" "$@" >&4; }
error ()   { local fmt="$1"; shift; printf "E: $fmt\n" "$@" >&4; exit 1; }

in_path () { command -v "$1" >/dev/null 2>&1; }

# endless answers on dpkg's stdin, so no prompt can block the bootstrap
smallyes () { while echo "${1-y}" 2>/dev/null; do :; done; }

# without "a b c" "a d" -> "b c"   (sorted, deduplicated)
without () {
	(echo "$1" | tr ' ' '\n' | sort -u
	 echo "$2" "$2" | tr ' ' '\n') | sort | uniq -u | grep -v '^$' | tr '\n' ' '
	echo
}

# repeatn N cmd... : retry, as debootstrap does around dpkg runs
repeatn () {
	local n="$1"; shift
	while [ "$n" -gt 0 ]; do
		if "$@"; then return 0; fi
		n=$((n - 1)); sleep 1
	done
	return 1
}

usage () {
	cat <<EOF
Usage: ${0##*/} [--print-debs] [target]
EOF
}


############################################################### cleanup

# mounts below $TARGET, newest first, unmounted by the EXIT trap
UMOUNT_DIRS=""
umount_on_exit () { UMOUNT_DIRS="$1 $UMOUNT_DIRS"; }

cleanup () {
	local dir
	for dir in $UMOUNT_DIRS; do
		if mountpoint -q "$TARGET$dir" 2>/dev/null; then
			if [ "$dir" = /proc ]; then
				umount --lazy "$TARGET$dir" || true
			else
				umount "$TARGET$dir" || true
			fi
		fi
	done
}

############################################################### downloading

# apt's file naming in lists/: strip scheme, '/' -> '_'
list_name () { echo "${MIRROR}_$1" | sed -e 's,^[^:]\+://,,' -e 's,/,_,g'; }

just_get () {
	# from dest
	mkdir -p "${2%/*}"
	if wget -nv --timeout=60 -O "$2" "$1"; then
		return 0
	fi
	rm -f "$2"
	return 1
}

verify_checksum () {
	# file sha256 size
	[ "$(wc -c < "$1")" -eq "$3" ] &&
	[ "$(sha256sum < "$1" | sed 's/ .*//')" = "$2" ]
}

# Download into partial/ and move into place only once size and SHA256 match.
# The by-hash URL is tried first when offered: it cannot change while the
# mirror updates, unlike the plain file name.
get () {
	# from dest sha256 size [byhash-url]
	local from="$1" dest="$2" sum="$3" size="$4" byhash="${5-}" tries=0
	local part="${dest%/*}/partial/${dest##*/}"
	[ -d "${dest%/*}/partial" ] || part="$dest.part"

	if [ -e "$dest" ] && verify_checksum "$dest" "$sum" "$size"; then
		return 0
	fi
	rm -f "$dest"
	while [ "$tries" -lt 10 ]; do
		info "Retrieving %s" "${from##*/}"
		if { [ -n "$byhash" ] && just_get "$byhash" "$part"; } || just_get "$from" "$part"; then
			info "Validating %s" "${from##*/}"
			if verify_checksum "$part" "$sum" "$size"; then
				mv "$part" "$dest"
				return 0
			fi
		fi
		rm -f "$part"
		warning "Retrying failed download of %s" "$from"
		tries=$((tries + 1))
	done
	warning "%s was corrupt" "$from"
	return 1
}

# print "sha256 size" of $2 from the SHA256 section of Release file $1
release_checksum () {
	sed -n '/^[Ss][Hh][Aa]256:/,/^[^ ]/p' "$1" |
		while read -r a b c; do
			if [ "$c" = "$2" ]; then echo "$a $b"; fi
		done | head -n 1
}

PKGFILE=""

# Release, then the Packages index it lists (checked against the Release
# SHA256), unpacked to $PKGFILE in the target's apt lists directory.
download_indices () {
	local rel path ent byhash hashurl ext unpack
	rel="$LISTS/$(list_name "dists/$SUITE/Release")"

	# the Release file is trusted as is: no signature verification
	just_get "$MIRROR/dists/$SUITE/Release" "$rel" ||
		error "Failed getting release file %s" "$MIRROR/dists/$SUITE/Release"


	byhash="$(grep -q '^Acquire-By-Hash: yes$' "$rel" && echo yes || true)"

	# prefer Packages.xz, fall back to Packages.gz
	if in_path unxz; then ext=xz; unpack=unxz; else ext=gz; unpack=gunzip; fi

	path="dists/$SUITE/$COMPONENT/binary-$ARCH/Packages"
	PKGFILE="$LISTS/$(list_name "$path")"
	ent="$(release_checksum "$rel" "$COMPONENT/binary-$ARCH/Packages.$ext")"
	[ -n "$ent" ] || error "Invalid Release file, no entry for %s" "$COMPONENT/binary-$ARCH/Packages.$ext"
	hashurl=""
	[ -n "$byhash" ] && hashurl="$MIRROR/dists/$SUITE/$COMPONENT/binary-$ARCH/by-hash/SHA256/${ent% *}"
	get "$MIRROR/$path.$ext" "$PKGFILE.$ext" ${ent% *} ${ent#* } $hashurl ||
		error "Couldn't download %s" "$MIRROR/$path.$ext"
	rm -f "$PKGFILE"
	$unpack "$PKGFILE.$ext"
}

############################################################### Packages parsing
# All helpers read the Packages index in awk paragraph mode (one stanza
# per record). They replace upstream's perl "pkgdetails".

# packages whose <field> equals <value>, e.g. get_debs Priority required
get_debs () {
	awk -v field="$1" -v value="$2" 'BEGIN { RS = ""; FS = "\n"; field = tolower(field) ":" }
	{
		pkg = ""; val = ""
		for (i = 1; i <= NF; i++) {
			split($i, kv, ":")
			f = tolower(kv[1]) ":"
			v = substr($i, length(kv[1]) + 2); sub(/^[ \t]+/, "", v)
			if (f == "package:") pkg = v
			else if (f == field) val = v
		}
		if (val == value) print pkg
	}' "$PKGFILE" | sort -u
}

# transitive closure over Depends/Pre-Depends (first alternative only,
# real packages only) -- like resolve_deps
resolve_deps () {
	awk -v want="$*" 'BEGIN { RS = ""; FS = "\n" }
	{
		pkg = ""; deps = ""
		for (i = 1; i <= NF; i++) {
			if ($i ~ /^Package:/) { pkg = $i; sub(/^Package:[ \t]*/, "", pkg) }
			else if ($i ~ /^(Pre-)?Depends:/) { d = $i; sub(/^[^:]*:[ \t]*/, "", d); deps = deps "," d }
		}
		real[pkg] = 1
		depends[pkg] = depends[pkg] deps
	}
	END {
		qn = split(want, q, " ")
		for (i = 1; i <= qn; i++) seen[q[i]] = 1
		for (qi = 1; qi <= qn; qi++) {
			dn = split(depends[q[qi]], ds, ",")
			for (j = 1; j <= dn; j++) {
				d = ds[j]
				sub(/\|.*/, "", d); sub(/\(.*\)/, "", d); sub(/:.*/, "", d)
				gsub(/[ \t]/, "", d)
				if (d == "" || !(d in real) || (d in seen)) continue
				seen[d] = 1; q[++qn] = d
			}
		}
		for (p in seen) print p
	}' "$PKGFILE" | sort -u | tr '\n' ' '
}

# "pkg version arch filename sha256 size" for each requested package
pkg_details () {
	awk -v want="$*" 'BEGIN { RS = ""; FS = "\n"
		n = split(want, w, " "); for (i = 1; i <= n; i++) wanted[w[i]] = 1 }
	{
		pkg = ver = arc = fil = sum = siz = ""
		for (i = 1; i <= NF; i++) {
			v = $i; sub(/^[^:]*:[ \t]*/, "", v)
			if ($i ~ /^Package:/) pkg = v
			else if ($i ~ /^Version:/) ver = v
			else if ($i ~ /^Architecture:/) arc = v
			else if ($i ~ /^Filename:/) fil = v
			else if ($i ~ /^SHA256:/) sum = v
			else if ($i ~ /^Size:/) siz = v
		}
		if (pkg in wanted) out[pkg] = pkg " " ver " " arc " " fil " " sum " " siz
	}
	END {
		for (p in wanted) print ((p in out) ? out[p] : p " -")
	}' "$PKGFILE" | sort
}

# full stanzas of the given packages (for /var/lib/dpkg/available)
pkg_stanzas () {
	awk -v want="$*" 'BEGIN { RS = ""; FS = "\n"
		n = split(want, w, " "); for (i = 1; i <= n; i++) wanted[w[i]] = 1 }
	{
		pkg = $1; sub(/^Package:[ \t]*/, "", pkg)
		if (pkg in wanted) { print; print "" }
	}' "$PKGFILE"
}

############################################################### .deb download

declare -A DEBPATH	# package -> path of .deb inside $TARGET

# Fetch the .debs into the target's apt archive (epoch ':' stored as %3a, like
# apt) and record "package path" in debootstrap/debpaths for debfor.
download_debs () {
	local p ver arc fil sum siz debdest missing=""
	while read -r p ver arc fil sum siz; do
		if [ "$ver" = "-" ]; then missing="$missing $p"; continue; fi
		debdest="$(echo "$ARCHIVES/${p}_${ver}_${arc}.deb" | sed 's/:/%3a/')"
		get "$MIRROR/$fil" "$TARGET$debdest" "$sum" "$siz" ||
			error "Couldn't download package %s (ver %s arch %s) at %s" "$p" "$ver" "$arc" "$MIRROR/$fil"
		echo "$p $debdest" >> "$TARGET/debootstrap/debpaths"
	done < <(pkg_details "$@")
	[ -z "$missing" ] || error "Couldn't find these debs:%s" "$missing"
	while read -r p debdest; do DEBPATH[$p]="$debdest"; done < "$TARGET/debootstrap/debpaths"
}

debfor () {
	local p
	for p in "$@"; do
		[ -n "${DEBPATH[$p]-}" ] && echo "${DEBPATH[$p]}"
	done
	return 0
}

############################################################### first stage
# Unpack the required packages' files with tar (no maintainer scripts yet) and
# prepare just enough of /etc and /dev for chroot + dpkg to work.

extract_deb_data () { dpkg-deb --fsys-tarfile "$1" | tar -k -xf -; }

extract () { (
	cd "$TARGET"
	local deb
	for deb in $(debfor "$@"); do
		info "Extracting %s..." "$(echo "$deb" | sed 's,^.*/,,;s,_.*$,,')"
		extract_deb_data ".$deb" || error "Tried to extract package, but tar failed. Exit..."
	done
); }

# device nodes for the chroot; mknod needs a real root (not an unprivileged container)
setup_devices () {
	local node
	mkdir -p "$TARGET/dev/pts" "$TARGET/dev/shm"
	for node in "null 1 3" "zero 1 5" "full 1 7" "random 1 8" "urandom 1 9" \
	            "tty 5 0" "console 5 1" "ptmx 5 2"; do
		set -- $node
		[ -e "$TARGET/dev/$1" ] || mknod -m 666 "$TARGET/dev/$1" c "$2" "$3" ||
			error "cannot create %s (unprivileged container?)" "$TARGET/dev/$1"
	done
	ln -sfT /proc/self/fd  "$TARGET/dev/fd"
	ln -sf /proc/self/fd/0 "$TARGET/dev/stdin"
	ln -sf /proc/self/fd/1 "$TARGET/dev/stdout"
	ln -sf /proc/self/fd/2 "$TARGET/dev/stderr"
}

conditional_cp () {
	if [ ! -e "$2/$1" ]; then
		if [ -L "$1" ] && [ -e "$1" ]; then
			cat "$1" > "$2/$1"
		elif [ -e "$1" ]; then
			cp "$1" "$2/$1"
		fi
	fi
	return 0
}

first_stage_install () {
	extract $required
	# merged /usr: base-files ships these as symlinks; a package with files in
	# /bin etc. unpacked before it would have made a real directory instead
	local dir
	for dir in bin lib lib64 sbin; do
		[ -L "$TARGET/$dir" ] || error "/%s is not a symlink to usr/%s" "$dir" "$dir"
	done

	# without dash nothing ships /bin/sh
	[ -e "$TARGET/usr/bin/sh" ] || ln -s bash "$TARGET/usr/bin/sh"

	mkdir -p "$TARGET/var/lib/dpkg"
	: > "$TARGET/var/lib/dpkg/status"
	: > "$TARGET/var/lib/dpkg/available"

	mkdir -p "$TARGET/etc"
	conditional_cp /etc/resolv.conf "$TARGET"
	conditional_cp /etc/hostname "$TARGET"

	mkdir -p "$TARGET/etc/apt/apt.conf.d" "$TARGET/etc/dpkg/dpkg.cfg.d"
	cat > "$TARGET/etc/apt/apt.conf.d/00minimal" <<'EOF'
APT::Install-Recommends "false";
Acquire::Languages "none";
APT::Keep-Downloaded-Packages "false";
EOF
	cat > "$TARGET/etc/dpkg/dpkg.cfg.d/01-minimal" <<'EOF'
# Drop all documentation
path-exclude /usr/share/doc/*

# Drop manual pages and info files
path-exclude /usr/share/man/*
path-exclude /usr/share/info/*

# Drop global translations (Keep only what you need, e.g., English)
path-exclude /usr/share/locale/*
path-include /usr/share/locale/en*
EOF

	if [ ! -e "$TARGET/etc/fstab" ]; then
		cat > "$TARGET/etc/fstab" <<EOF
# UNCONFIGURED FSTAB FOR BASE SYSTEM
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
EOF
		chown 0:0 "$TARGET/etc/fstab"; chmod 644 "$TARGET/etc/fstab"
	fi

	setup_devices
}

# deb822 format: a one-line sources.list makes apt suggest "apt modernize-sources"
setup_apt_sources () {
	mkdir -p "$TARGET/etc/apt/sources.list.d"
	rm -f "$TARGET/etc/apt/sources.list"
	cat > "$TARGET/etc/apt/sources.list.d/debian.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: $SUITE
Components: $COMPONENT
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
EOF
}

############################################################### second stage
# Inside the chroot: bring up dpkg by hand, then unpack and configure the
# required packages, then the base packages (debootstrap's minbase order).

# chroot with a sane PATH; on failure point at the package dpkg blamed
in_target () {
	if ! PATH=/sbin:/usr/sbin:/bin:/usr/bin chroot "$TARGET" "$@"; then
		warning "Failure trying to run: chroot \"%s\" %s" "$TARGET" "$*"
		local pkg
		pkg="$(grep '^dpkg: error processing ' "$TARGET/debootstrap/debootstrap.log" | head -n 1 |
			sed 's/\(error processing \)\(package \|archive \)/\1/' | cut -d ' ' -f 4)"
		warning "See %s for details%s" "$TARGET/debootstrap/debootstrap.log" \
			"${pkg:+ (possibly the package $pkg is at fault)}"
		return 1
	fi
}

# like in_target, but silent and never fails
in_target_nofail () {
	PATH=/sbin:/usr/sbin:/bin:/usr/bin chroot "$TARGET" "$@" 2>/dev/null || true
}

# reads "dpkg --status-fd" lines and prints Unpacking/Configuring messages
dpkg_progress () {
	local action="$1" status pkg qstate expect
	case "$action" in
		UNPACKING)   expect=half-installed ;;
		CONFIGURING) expect=half-configured ;;
	esac
	while read -r status pkg qstate; do
		[ "$qstate" = "$expect" ] || continue
		case $qstate in
			half-installed)  info "Unpacking %s..." "${pkg%:}"; expect=unpacked ;;
			unpacked)        expect=half-installed ;;
			half-configured) info "Configuring %s..." "${pkg%:}"; expect=installed ;;
			installed)       expect=half-configured ;;
		esac
	done
}

# dpkg_run UNPACKING|CONFIGURING <dpkg args...>
# dpkg reports state changes on fd 8, turned into I: lines by dpkg_progress
dpkg_run () {
	local action="$1"; shift
	in_target dpkg --status-fd 8 "$@" < <(smallyes '') 8> >(dpkg_progress "$action")
}

setup_proc () {
	umount_on_exit /proc
	umount_on_exit /sys
	umount "$TARGET/proc" 2>/dev/null || true
	mkdir -p "$TARGET/proc" "$TARGET/sys"
	mount -t proc proc "$TARGET/proc"
	mountpoint -q "$TARGET/sys" || mount -t sysfs sysfs "$TARGET/sys"
}

# register a package as installed without running dpkg (bootstraps dpkg itself)
x_feign_install () {
	local pkg="$1" ver
	ver="$(in_target dpkg-deb -f "$(debfor "$pkg")" Version)"
	mkdir -p "$TARGET/var/lib/dpkg/info"
	printf 'Package: %s\nVersion: %s\nMaintainer: unknown\nStatus: install ok installed\n' \
		"$pkg" "$ver" >> "$TARGET/var/lib/dpkg/status"
	touch "$TARGET/var/lib/dpkg/info/${pkg}.list"
}

x_core_install () {
	in_target dpkg --force-depends --install $(debfor "$@") < <(smallyes '')
}

second_stage_install () {
	local predep done_predeps=""

	in_target /bin/true

	# make dpkg believe it is installed so it can install itself
	x_feign_install dpkg

	setup_proc
	in_target /sbin/ldconfig

	export DEBIAN_FRONTEND=noninteractive
	export DEBCONF_NONINTERACTIVE_SEEN=true

	info "Installing core packages..."
	# base-files needs awk before the awk alternative exists
	ln -sf gawk "$TARGET/usr/bin/awk"
	x_core_install base-passwd
	x_core_install base-files
	x_core_install dpkg

	# no tzdata, so no /etc/localtime (glibc then defaults to UTC)

	x_core_install libc6
	x_core_install perl-base
	rm "$TARGET/usr/bin/awk"
	x_core_install gawk

	info "Unpacking required packages..."
	repeatn 5 dpkg_run UNPACKING --force-depends --unpack $(debfor $required) ||
		error "Failure while unpacking required packages."

	info "Configuring required packages..."
	# exit 101: maintainer scripts must not start services in the chroot
	printf '#!/bin/sh\nexit 101\n' > "$TARGET/usr/sbin/policy-rc.d"
	chmod 755 "$TARGET/usr/sbin/policy-rc.d"

	dpkg_run CONFIGURING --configure --pending --force-configure-any --force-depends ||
		error "Failure while configuring required packages."

	info "Unpacking the base system..."

	pkg_stanzas $required $base > "$TARGET/var/lib/dpkg/available"
	for p in $required $base; do echo "$p install"; done | in_target dpkg --set-selections

	# dpkg --predep-package doesn't resolve dependencies of pre-depends,
	# so install those first, one by one
	while predep="$(in_target_nofail dpkg --predep-package | sed -n 's/^Package: *//p')" &&
	      [ -n "$predep" ]; do
		predep="$(without "$(without "$(resolve_deps $predep)" "$required")" "$done_predeps")"
		in_target dpkg --force-overwrite --force-confold --skip-same-version --install $(debfor $predep) < <(smallyes '')
		base="$(without "$base" "$predep")"
		done_predeps="$done_predeps $predep"
	done

	if [ -n "${base// /}" ]; then
		repeatn 5 dpkg_run UNPACKING --force-overwrite --force-confold --skip-same-version --unpack $(debfor $base) ||
			error "Failure while installing base packages."

		info "Configuring the base system..."
		repeatn 5 dpkg_run CONFIGURING --force-confold --skip-same-version --configure -a ||
			error "Failure while configuring base packages."
	fi

	rm -f "$TARGET/usr/sbin/policy-rc.d"

	# perl-base is only needed while bootstrapping (debconf's frontend is
	# Perl), so remove it now, together with init-system-helpers
	# (update-rc.d etc. are Perl). libpam-runtime stays for /etc/pam.d,
	# only its Perl pam-auth-update is deleted.
	# The debconf package stays (its shell confmodule and the package
	# dependencies on it), but questions are answered by cdebconf (C):
	# confmodule uses cdebconf when /usr/share/debconf/frontend is not a
	# regular file, so divert the Perl frontend away and symlink cdebconf.
	info "Removing init-system-helpers and perl-base..."
	in_target dpkg --purge --force-depends --force-remove-essential init-system-helpers
	in_target dpkg --purge --force-depends --force-remove-essential perl-base
	rm -f "$TARGET/usr/sbin/pam-auth-update"

	info "Switching debconf to cdebconf..."
	in_target dpkg-divert --local --rename \
		--divert /usr/share/debconf/frontend.perl --add /usr/share/debconf/frontend
	ln -s /usr/lib/cdebconf/debconf "$TARGET/usr/share/debconf/frontend"

	info "Base system installed successfully."
}

bootstrap_main () {
	# fd 4 = I:/W:/E: messages (terminal), fd 3 = original stdout;
	# stdout/stderr go to $TARGET/debootstrap/debootstrap.log
	exec 3>&1 4>&1

	############################################################### arguments

	while [ $# -gt 0 ]; do
		case "$1" in
		    --print-debs) PRINT_DEBS=true ;;
		    -*) error "unrecognized or invalid option %s" "$1" ;;
		    *) break ;;
		esac
		shift
	done

	[ $# -le 1 ] || { usage >&2; error "too many arguments"; }
	TARGET="${1:-$ROOTFS_DEFAULT}"
	TARGET="${TARGET%/}"
	case "$TARGET" in
		/*) ;;
		*) TARGET="$(pwd)/$TARGET" ;;
	esac
	# --print-debs only needs a scratch area for the indices
	if [ -n "$PRINT_DEBS" ]; then
		TARGET="$(mktemp -d)"
		exec 4>&2
	fi

	in_path wget || error "You must install wget to download packages."
	in_path chroot || error "Cannot find chroot executable in \$PATH"
	in_path sha256sum || error "sha256sum is required"
	in_path dpkg-deb || error "dpkg-deb is required"
	if [ -z "$PRINT_DEBS" ] && [ "$(id -u)" -ne 0 ]; then
		error "debootstrap can only run as root"
	fi

	APTSTATE="var/lib/apt"
	LISTS="$TARGET/$APTSTATE/lists"
	ARCHIVES="/var/cache/apt/archives"	# relative to $TARGET

	mkdir -p "$TARGET/debootstrap" "$LISTS/partial" "$TARGET$ARCHIVES/partial"
	exec >>"$TARGET/debootstrap/debootstrap.log" 2>&1

	trap cleanup EXIT
	# ERR only fires for commands directly in this function (no set -E)
	trap 'error "Command failed (line %s), see %s" "$LINENO" "$TARGET/debootstrap/debootstrap.log"' ERR
	trap 'exit 129' HUP
	trap 'error "Interrupt caught ... exiting"' INT
	trap 'exit 143' TERM

	download_indices

	# work_out_debs (scripts/debian-common, variant minbase)
	required="$(get_debs Priority required | tr '\n' ' ')"
	# use gawk as the awk implementation instead of mawk, and bash as the
	# only shell (no dash; /bin/sh -> bash is created in first_stage_install).
	# tzdata is not installed at all.
	required="$(without "$required" "mawk dash tzdata") gawk"
	base="apt cdebconf systemd-sysv"

	info "Resolving dependencies of required packages..."
	required="$(resolve_deps $required)"
	info "Resolving dependencies of base packages..."
	base="$(resolve_deps $base)"
	base="$(without "$base" "$required")"

	if [ -n "$PRINT_DEBS" ]; then
		echo $required $base >&3
		rm -rf "$TARGET"
		exit 0
	fi

	: > "$TARGET/debootstrap/debpaths"
	download_debs $required $base

	first_stage_install
	setup_apt_sources
	second_stage_install

	# docs: the first stage unpacked with tar, which ignores dpkg's path-exclude
	# rules; the rest are empty directories from base-files
	rm -rf "$TARGET/usr/share/doc" "$TARGET/usr/share/man" "$TARGET/usr/share/info" \
		"$TARGET/usr/share/dict" "$TARGET/usr/share/misc" \
		"$TARGET/usr/local" "$TARGET/usr/src" "$TARGET/usr/games"
	[ ! -d "$TARGET/usr/share/locale" ] ||
		find "$TARGET/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} +
	rm -f "$TARGET$ARCHIVES"/*.deb

	# /etc/default/locale is shipped as a symlink to ../locale.conf; without
	# the target pam_env logs an error at every login (C.UTF-8 is in glibc)
	[ -e "$TARGET/etc/locale.conf" ] || echo 'LANG=C.UTF-8' > "$TARGET/etc/locale.conf"

	mv "$TARGET/debootstrap/debootstrap.log" "$TARGET/var/log/bootstrap.log"
	sync
	rm -rf "$TARGET/debootstrap"
}

############################################################### vm
# Copy the rootfs onto three disk images (ESP, root, /usr), add kernel and
# guest agent through chroot, configure it, build a unified kernel image with
# dracut + ukify, then import the disks into a new Proxmox VM.

# partition nodes of a fresh loop device show up asynchronously (udev)
wait_for_node () {
	local i
	for i in $(seq 50); do [ -b "$1" ] && return 0; sleep 0.1; done
	die "$1 did not appear"
}

vm_cleanup () {
	local rc=$?
	set +e
	mountpoint -q "$MNT" && umount -R "$MNT"
	[ -n "$LOOP" ] && losetup -d "$LOOP"
	[ -n "$LOOP_USR" ] && losetup -d "$LOOP_USR"
	[ -n "$LOOP_ESP" ] && losetup -d "$LOOP_ESP"
	if [ $rc -eq 0 ]; then
		rm -rf "$W"
	else
		echo "failed; work directory kept for inspection: $W" >&2
	fi
}

# checks that do not need the rootfs, so they run before a bootstrap
vm_check () {
	[ "$(id -u)" -eq 0 ] || die "must run as root"
	local cmd
	for cmd in qm pvesm sgdisk losetup mkfs.ext4 mkfs.vfat e2fsck blkid chroot mountpoint; do
		command -v "$cmd" >/dev/null || die "missing command: $cmd"
	done
	# an existing VM is only deleted in vm_create, once the new image is built
	if qm status "$VMID" >/dev/null 2>&1 && [ "${REPLACE_VM:-}" != 1 ]; then
		local answer=""
		echo "VM $VMID already exists: $(qm config "$VMID" | sed -n 's/^name: //p'), $(qm status "$VMID")" >&2
		read -rp "stop and delete VM $VMID and its disks after the new image is built? [y/N] " answer || true
		case "$answer" in
			[yY]|[yY][eE][sS]) REPLACE_VM=1 ;;
			*) die "VM $VMID already exists" ;;
		esac
	fi

	STYPE=$(pvesm status | awk -v s="$STORAGE" '$1==s {print $2}')
	[ -n "$STYPE" ] || die "unknown storage: $STORAGE"
	# raw is accepted by every storage type
	FORMAT=raw
}

vm_check_rootfs () {
	[ -x "$ROOTFS/usr/bin/bash" ] || die "$ROOTFS does not look like a rootfs"
	USED_MB=$(du -sxm "$ROOTFS" | cut -f1)
	USR_MB=$(du -sxm "$ROOTFS/usr" | cut -f1)
	# apt's lists and caches are not copied into the image (apt-get update
	# renews them); the root disk also holds the kernel, initrd and, during the
	# build, apt's lists and downloads
	APT_MB=$(du -sxmc "$ROOTFS/var/lib/apt/lists" "$ROOTFS/var/cache/apt" 2>/dev/null | tail -n 1 | cut -f1)
	ROOT_MB=$(( USED_MB - USR_MB - APT_MB ))
	[ "$ROOT_MB" -lt $(( ROOT_DISK_MB - 320 )) ] \
		|| die "rootfs without /usr needs ${ROOT_MB} MiB, leave 320 MiB headroom: raise ROOT_DISK_MB"
	[ "$USR_MB" -lt $(( USR_DISK_GB * 1024 - 1024 )) ] \
		|| die "/usr needs ${USR_MB} MiB, leave 1 GiB headroom: raise USR_DISK_GB"
}

# vm_new_disk IMAGE SIZE TYPE LABEL : sparse image with GPT and one partition;
# prints the loop device
vm_new_disk () {
	local loop
	truncate -s "$2" "$1"
	sgdisk -Z -n1:0:0 -t1:"$3" -c1:"$4" "$1" >/dev/null
	loop=$(losetup -f --show -P "$1")
	wait_for_node "${loop}p1"
	echo "$loop"
}

# Three disks, each GPT with one partition: the ESP (FAT32), root (ext4 /)
# and /usr (ext4, "Linux x86-64 /usr" type). The initramfs mounts /usr from
# /etc/fstab before switching to the real root.
vm_make_disk () {
	echo "creating disk images: ESP ${ESP_DISK_MB} MiB, root ${ROOT_DISK_MB} MiB, /usr ${USR_DISK_GB} GiB"
	LOOP_ESP=$(vm_new_disk "$ESP_IMG" "${ESP_DISK_MB}M" ef00 esp)
	LOOP=$(vm_new_disk "$IMG" "${ROOT_DISK_MB}M" 8304 root)
	LOOP_USR=$(vm_new_disk "$USR_IMG" "${USR_DISK_GB}G" 8314 usr)
	mkfs.vfat -F 32 -n ESP "${LOOP_ESP}p1" >/dev/null
	mkfs.ext4 -q -L "$ROOT_LABEL" "${LOOP}p1"
	mkfs.ext4 -q -L "$USR_LABEL" "${LOOP_USR}p1"
	mkdir -p "$MNT"
	mount "${LOOP}p1" "$MNT"
	mkdir "$MNT/usr"
	mount "${LOOP_USR}p1" "$MNT/usr"

	echo "copying rootfs"
	cp -a "$ROOTFS/." "$MNT/"
	rm -rf "$MNT/var/lib/apt/lists/"* "$MNT/var/cache/apt/"*
	mkdir -p "$MNT/efi" "$MNT/proc" "$MNT/sys" "$MNT/dev"
	mount "${LOOP_ESP}p1" "$MNT/efi"
	mount -t proc proc "$MNT/proc"
	# rslave: with shared propagation (systemd hosts) umount -R would otherwise
	# also unmount the host's /dev/pts, /sys/fs/cgroup, ...
	mount --rbind /sys "$MNT/sys"
	mount --make-rslave "$MNT/sys"
	mount --rbind /dev "$MNT/dev"
	mount --make-rslave "$MNT/dev"
	cp /etc/resolv.conf "$MNT/etc/resolv.conf"
}

vm_apt () { DEBIAN_FRONTEND=noninteractive chroot "$MNT" apt-get -y --no-install-recommends "$@"; }

vm_install_packages () {
	echo "installing kernel and guest agent"
	chroot "$MNT" apt-get update
	# The rootfs has no Perl and no init-system-helpers, but the kernel and service
	# packages need them (dpkg-preconfigure, update-rc.d, deb-systemd-helper). Both
	# are put back for the build and purged again in vm_finish.
	vm_apt install perl-base init-system-helpers
	# A local package providing linux-initramfs-tool satisfies the kernel's
	# "dracut | initramfs-tools | linux-initramfs-tool" dependency, so no
	# initramfs generator is installed and no kernel hook builds an initrd;
	# vm_build_uki builds it once, at the end, by calling dracut directly.
	mkdir -p "$W/no-initramfs-tool/DEBIAN"
	cat > "$W/no-initramfs-tool/DEBIAN/control" <<EOF
Package: no-initramfs-tool
Version: 1
Architecture: all
Maintainer: linux.sh <root@localhost>
Provides: linux-initramfs-tool
Description: initramfs is built by linux.sh (dracut + ukify, unified kernel image)
EOF
	dpkg-deb --root-owner-group --build "$W/no-initramfs-tool" "$MNT/tmp/no-initramfs-tool.deb" >/dev/null
	chroot "$MNT" dpkg -i /tmp/no-initramfs-tool.deb
	rm -f "$MNT/tmp/no-initramfs-tool.deb"
	# udev explicitly: otherwise it only comes in as a dependency of dracut and
	# leaves again with it
	vm_apt install linux-image-cloud-amd64 udev qemu-guest-agent systemd-resolved
}

vm_configure () {
	echo "configuring system"
	ROOT_UUID=$(blkid -s UUID -o value "${LOOP}p1")
	ESP_UUID=$(blkid -s UUID -o value "${LOOP_ESP}p1")
	USR_UUID=$(blkid -s UUID -o value "${LOOP_USR}p1")
	cat > "$MNT/etc/fstab" <<EOF
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$USR_UUID /usr ext4 ro 0 2
UUID=$ESP_UUID /efi vfat umask=0077 0 2
EOF
	echo "$NAME" > "$MNT/etc/hostname"
	cat > "$MNT/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 $NAME
EOF
	mkdir -p "$MNT/etc/systemd/network"
	cat > "$MNT/etc/systemd/network/10-wired.network" <<'EOF'
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF
	chroot "$MNT" systemctl enable systemd-networkd.service systemd-resolved.service
	printf 'root:%s\n' "${ROOT_PASSWORD:-$ROOT_PASSWORD_DEFAULT}" | chroot "$MNT" chpasswd
	unset ROOT_PASSWORD
}

# Unified kernel image (kernel + initrd + command line in one EFI binary) at
# the removable path \EFI\BOOT\BOOTX64.EFI, which OVMF boots without GRUB or an
# NVRAM entry. Copy of bin/uki.sh and bin/uki-dracut.sh: dracut builds a
# generic initrd that mounts /usr from /etc/fstab (usrmount); ukify combines
# it with the kernel. dracut, ukify and their dependencies are only installed
# for this step.
vm_build_uki () {
	local kver
	echo "building the unified kernel image"
	vm_apt install dracut-core dracut-network systemd-ukify systemd-boot-efi util-linux-extra
	kver=$(ls "$MNT/usr/lib/modules")
	chroot "$MNT" dracut --no-hostonly --force --kver "$kver" \
		--modules 'usrmount kernel-modules-export bash rootfs-block kernel-modules qemu qemu-net virtfs virtiofs shutdown overlayfs' \
		--drivers 'virtio-balloon' /tmp/initrd
	# rd.driver.pre: disks (sd_mod, virtio_scsi) for / and /usr; virtio_net and
	# autofs4 so they are there right after switch_root
	mkdir -p "$MNT/efi/EFI/BOOT"
	chroot "$MNT" ukify build --linux="/boot/vmlinuz-$kver" --initrd=/tmp/initrd --uname="$kver" \
		--cmdline="root=LABEL=$ROOT_LABEL ro rd.driver.pre=sd_mod rd.driver.pre=virtio_scsi rd.driver.pre=virtio_net rd.driver.pre=autofs4 rd.driver.pre=virtio-balloon quiet console=tty0 console=ttyS0,115200" \
		--output=/efi/EFI/BOOT/BOOTX64.EFI
	echo "unified kernel image: $(du -h "$MNT/efi/EFI/BOOT/BOOTX64.EFI" | cut -f1)"
	rm -f "$MNT/tmp/initrd"
	vm_apt purge --autoremove dracut-core dracut-network systemd-ukify systemd-boot-efi util-linux-extra
}

vm_finish () {
	chroot "$MNT" dpkg --purge --force-depends --force-remove-essential perl-base init-system-helpers
	# the host's resolv.conf was only needed for apt during the build
	rm -f "$MNT/etc/resolv.conf"
	ln -s ../run/systemd/resolve/stub-resolv.conf "$MNT/etc/resolv.conf"
	# empty machine-id: systemd generates a unique one on first boot
	: > "$MNT/etc/machine-id"
	chroot "$MNT" apt-get clean
	rm -rf "$MNT/var/lib/apt/lists/"*
}

# Daemons started by package scripts inside the chroot keep the mounts busy.
# Only processes whose root is in the image are found, not ones whose
# working directory is there.
vm_kill_chroot_procs () {
	local p root pids=""
	for p in /proc/[0-9]*; do
		root=$(readlink "$p/root" 2>/dev/null) || continue
		case "$root" in
			"$MNT"|"$MNT"/*) pids="$pids ${p#/proc/}" ;;
		esac
	done
	[ -n "$pids" ] || return 0
	echo "stopping processes left in the image:$pids"
	kill -TERM $pids 2>/dev/null || true
	sleep 2
	kill -KILL $pids 2>/dev/null || true
}

# vm_debug_busy DEV : debug output when an image partition cannot be released:
# which mount namespaces still have it mounted, who uses $MNT, holders.
vm_debug_busy () {
	local dev="$1" mm p ns seen="" where
	mm=$(cat "/sys/class/block/${dev##*/}/dev" 2>/dev/null)
	echo "debug: $dev (dev $mm) is still in use" >&2
	for p in /proc/[0-9]*; do
		where=$(awk -v mm="$mm" '$3 == mm {printf "%s ", $5}' "$p/mountinfo" 2>/dev/null)
		[ -n "$where" ] || continue
		ns=$(readlink "$p/ns/mnt" 2>/dev/null)
		case " $seen " in *" $ns "*) continue ;; esac
		seen="$seen $ns"
		echo "debug: mounted in $ns (pid ${p#/proc/} $(cat "$p/comm" 2>/dev/null)) at $where" >&2
	done
	for p in /proc/[0-9]*; do
		where=$( { readlink "$p/cwd"; readlink "$p/root"; ls -l "$p/fd" 2>/dev/null | sed 's/.* -> //'; } 2>/dev/null |
			grep -E -m 1 "^($MNT(/|$)|$dev$)")
		[ -z "$where" ] || echo "debug: pid ${p#/proc/} ($(cat "$p/comm" 2>/dev/null)) uses $where" >&2
	done
	echo "debug: holders of $dev: $(ls "/sys/class/block/${dev##*/}/holders" 2>/dev/null | tr '\n' ' ')" >&2
	losetup -l "${dev%p*}" >&2 2>/dev/null
}

vm_detach () {
	sync
	vm_kill_chroot_procs
	echo "unmounting image"
	umount -R "$MNT" || { vm_debug_busy "${LOOP}p1"; die "could not unmount $MNT"; }
	echo "checking filesystems"
	# e2fsck exit code 1: errors were corrected
	e2fsck -fp "${LOOP}p1" || [ $? -eq 1 ] || { vm_debug_busy "${LOOP}p1"; die "root filesystem check failed"; }
	e2fsck -fp "${LOOP_USR}p1" || [ $? -eq 1 ] || { vm_debug_busy "${LOOP_USR}p1"; die "/usr filesystem check failed"; }
	losetup -d "$LOOP_ESP" "$LOOP" "$LOOP_USR"
	LOOP_ESP="" LOOP="" LOOP_USR=""
}

# vm_import_disk IMAGE : import into the VM and print the volume ID.
# importdisk attaches it as unusedN; its name (vm-ID-disk-N) depends on the
# disks the VM already has, so read it back from the config.
vm_import_disk () {
	local out vol
	out=$(qm importdisk "$VMID" "$1" "$STORAGE" --format "$FORMAT" 2>&1) \
		|| { echo "$out" >&2; die "importdisk of $1 failed"; }
	echo "$out" >&2
	vol=$(qm config "$VMID" | sed -n 's/^unused[0-9]*: //p' | head -n 1)
	[ -n "$vol" ] || die "could not find the imported disk in the VM config"
	echo "$vol"
}

vm_create () {
	if [ "${REPLACE_VM:-}" = 1 ] && qm status "$VMID" >/dev/null 2>&1; then
		echo "deleting existing VM $VMID"
		if qm status "$VMID" | grep -q running; then qm stop "$VMID"; fi
		qm destroy "$VMID" --purge 1 --destroy-unreferenced-disks 1
	fi
	echo "creating VM $VMID"
	qm create "$VMID" --name "$NAME" --memory "$MEMORY" --cores "$CORES" \
		--machine q35 --bios ovmf --ostype l26 --cpu host \
		--net0 "virtio,bridge=$BRIDGE" --scsihw virtio-scsi-pci \
		--agent enabled=1 --tablet 0 --onboot 1 --serial0 socket
	qm set "$VMID" --efidisk0 "$STORAGE:1,efitype=4m,pre-enrolled-keys=0" >/dev/null
	ESP_VOLID=$(vm_import_disk "$ESP_IMG")
	qm set "$VMID" --scsi0 "$ESP_VOLID"
	VOLID=$(vm_import_disk "$IMG")
	qm set "$VMID" --scsi1 "$VOLID"
	USR_VOLID=$(vm_import_disk "$USR_IMG")
	qm set "$VMID" --scsi2 "$USR_VOLID"
	qm set "$VMID" --boot order=scsi0

	if [ "$START" = 1 ]; then
		# QEMU must not inherit our private mount namespace (see vm_main)
		nsenter --mount=/proc/1/ns/mnt -- qm start "$VMID"
	fi

	echo "VM $VMID ($NAME) is ready. Console: qm terminal $VMID"
}

vm_main () {
	# Re-run in a private mount namespace. On systemd hosts mounts propagate
	# into the namespaces of services started meanwhile; such a copy can
	# survive our umount and keep the image busy (e2fsck: "in use").
	if [ -z "${LINUX_SH_PRIVATE_NS:-}" ] && [ "$(id -u)" -eq 0 ]; then
		LINUX_SH_PRIVATE_NS=1 exec unshare --mount --propagation private -- bash "$0" "$@"
	fi
	case $# in
		0) in_path pvesh || die "missing command: pvesh"
		   ROOTFS="$ROOTFS_DEFAULT"; VMID=$(pvesh get /cluster/nextid | tr -d '"')
		   NAME="$VM_NAME_DEFAULT" ;;
		2) ROOTFS="$ROOTFS_DEFAULT"; VMID="$1"; NAME="$2" ;;
		3) ROOTFS="$1"; VMID="$2"; NAME="$3" ;;
		*) die "usage: ${0##*/} [[rootfs-dir] <vmid> <name>]" ;;
	esac
	ROOT_DISK_MB="${ROOT_DISK_MB:-512}"
	USR_DISK_GB="${USR_DISK_GB:-4}"
	ESP_DISK_MB="${ESP_DISK_MB:-64}"
	ROOT_LABEL=root	# filesystem label, also root=LABEL= on the kernel command line
	USR_LABEL=usr	# fstab mounts /usr by UUID
	MEMORY="${MEMORY:-1024}"
	STORAGE='local-lvm'
	CORES="${CORES:-2}"
	BRIDGE="${BRIDGE:-vmbr0}"
	WORKDIR="${WORKDIR:-/var/tmp}"
	START="${START:-1}"
	LOOP="" LOOP_USR="" LOOP_ESP=""

	vm_check
	if [ ! -e "$ROOTFS" ] || [ -z "$(ls -A "$ROOTFS")" ]; then
		echo "$ROOTFS is empty, bootstrapping it first"
		# subshell: keeps bootstrap's traps and log redirection out of VM mode
		( bootstrap_main "$ROOTFS" )
	fi
	vm_check_rootfs
	echo "building VM $VMID ($NAME) from $ROOTFS"

	W=$(mktemp -d "$WORKDIR/make-pve-vm.XXXXXX")
	ESP_IMG="$W/esp.raw"
	IMG="$W/root.raw"
	USR_IMG="$W/usr.raw"
	MNT="$W/mnt"
	trap vm_cleanup EXIT

	vm_make_disk
	vm_install_packages
	vm_configure
	vm_build_uki
	vm_finish
	vm_detach
	vm_create
}

############################################################### main

main () {
	local mode="${SCRIPT_MODE:-}"
	if [ -z "$mode" ]; then
		# only the bootstrap takes options
		if [ "${1#-}" != "${1-}" ]; then mode=bootstrap
		elif in_path qm; then mode=vm
		else mode=bootstrap; fi
	fi
	case "$mode" in
		vm) vm_main "$@" ;;
		bootstrap) bootstrap_main "$@" ;;
		*) die "SCRIPT_MODE must be vm or bootstrap, not '$mode'" ;;
	esac
}

main "$@"
