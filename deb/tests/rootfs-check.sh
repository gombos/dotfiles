#!/bin/bash
# rootfs-check.sh ROOTFS [PRINT_DEBS_LIST] : check a bootstrapped rootfs
. "${0%/*}/lib.sh"
R=$1 LIST=${2:-}
in_root () { chroot "$R" "$@"; }

ok rootfs_exists [ -x "$R/usr/bin/bash" ]
for d in bin sbin lib lib64; do ok "usrmerge_$d" [ "$(readlink "$R/$d")" = "usr/$d" ]; done
ok sh_is_bash   [ "$(readlink "$R/usr/bin/sh")" = bash ]
ok awk_is_gawk   [ "$(in_root readlink -f /usr/bin/awk)" = /usr/bin/gawk ]
for f in usr/bin/perl usr/bin/dash usr/bin/mawk usr/share/zoneinfo usr/share/doc usr/share/man usr/share/info \
	usr/share/dict usr/share/misc usr/local usr/src usr/games \
	usr/sbin/policy-rc.d usr/sbin/pam-auth-update debootstrap; do
	nok "absent_${f//\//_}" [ -e "$R/$f" ]
done
ok etc_default_locale grep -qx "LANG=C.UTF-8" "$R/etc/default/locale"
ok locale_en_only [ -z "$(ls "$R/usr/share/locale" 2>/dev/null | grep -v '^en' | grep -v '^locale.alias$')" ]
ok bootstrap_log  [ -s "$R/var/log/bootstrap.log" ]
nok mtab_regular  [ -f "$R/etc/mtab" -a ! -L "$R/etc/mtab" ]
ok no_mounts_left [ -z "$(awk -v r="$R" 'index($2, r) == 1' /proc/mounts)" ]
debs=$(find "$R/var/cache/apt/archives" -name '*.deb' | wc -l)
ok "no_debs_left_in_archives($debs)" [ "$debs" -eq 0 ]

ok sources_deb822 [ "$(cat "$R/etc/apt/sources.list.d/debian.sources")" = "$(printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: forky\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.pgp')" ]
nok sources_list_oneline [ -e "$R/etc/apt/sources.list" ]
ok signed_by_keyring [ -s "$R/usr/share/keyrings/debian-archive-keyring.pgp" ]
ok apt_minimal  grep -q 'APT::Install-Recommends "false"' "$R/etc/apt/apt.conf.d/00minimal"
nok apt_no_postinvoke grep -q Post-Invoke "$R/etc/apt/apt.conf.d/00minimal"
ok dpkg_minimal grep -q 'path-exclude /usr/share/doc/\*' "$R/etc/dpkg/dpkg.cfg.d/01-minimal"
ok debconf_frontend [ "$(readlink "$R/usr/share/debconf/frontend")" = /usr/lib/cdebconf/debconf ]
ok debconf_diverted has "$(in_root dpkg-divert --list /usr/share/debconf/frontend)" frontend.perl

status=$(in_root dpkg-query -W -f '${Package} ${db:Status-Abbrev}\n')
count=$(printf '%s\n' "$status" | grep -c ' ii ')
echo "INFO packages installed: $count; size: $(du -sxh "$R" | cut -f1)"
ok all_ii [ -z "$(printf '%s\n' "$status" | grep -v ' ii ')" ]
for p in perl-base init-system-helpers tzdata dash mawk; do
	nok "not_installed_$p" eval "printf '%s\n' \"\$status\" | grep -q '^$p '"
done
ok dpkg_audit [ -z "$(in_root dpkg --audit 2>&1)" ]
out=$(in_root apt-get check 2>&1); rc=$?
note=$(printf "%s\n" "$out" | grep -m1 -E "Depends|^E:")
ok "apt_get_check${note:+ ($note)}" [ $rc -eq 0 ]

if [ -n "$LIST" ]; then
	want=$(tr ' ' '\n' < "$LIST" | grep -vx -e perl-base -e init-system-helpers -e '' | sort)
	have=$(printf '%s\n' "$status" | cut -d' ' -f1 | sed 's/:.*//' | sort)
	ok installed_matches_print_debs [ "$want" = "$have" ]
	[ "$want" = "$have" ] || diff <(echo "$want") <(echo "$have") | sed 's/^/INFO /'
fi
echo "INFO build host files copied in: /etc/hostname=$(cat "$R/etc/hostname" 2>/dev/null), /etc/resolv.conf $(wc -l < "$R/etc/resolv.conf" 2>/dev/null) lines"
summary
