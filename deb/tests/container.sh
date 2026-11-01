#!/bin/bash
# container.sh quick|full [debian|arch|all] : runs inside the test container (see run.sh)
set -u
mode=${1:-quick} distros=${2:-all}
[ "$distros" = all ] && distros="debian arch"
cp -a /src /tmp/src; chmod -R a+rX /tmp/src	# readable for the non-root tests
export TESTS=/tmp/src/tests COV=/tmp/cov OUT=/tmp/out LINUX_COV=/tmp/src/linux.cov.sh
mkdir -p $COV $OUT; chmod 1777 $COV /tmp
# instrumented copy: the shebang line becomes the xtrace setup, so line numbers
# stay the same; tests run it as "bash $LINUX_COV"
sed "1s/.*/PS4='+linux.sh:\${LINENO}:\${FUNCNAME[0]:-main}: '; BASH_XTRACEFD=9; set -x/" \
	/tmp/src/linux.sh > $LINUX_COV

suite () {	# NAME cmd... : run a test script, keep its log, show results
	echo; echo "### $1"
	local name=$1; shift
	"$@" > "$OUT/$name.log" 2>&1 || grep -q "^FAIL" "$OUT/$name.log" ||
		echo "FAIL $name exited with an error, see $name.log" >> "$OUT/$name.log"
	grep -E '^(PASS|FAIL|INFO|==)' "$OUT/$name.log"
}

echo "INFO seccomp: $(awk '/^Seccomp:/ {print $2}' /proc/self/status) (2: Landlock blocked as on Proxmox)"
echo "### shellcheck"
shellcheck -s bash -f gcc /tmp/src/linux.sh > $OUT/shellcheck.txt
sed -n 's/.*\[\(SC[0-9]*\)\]$/\1/p' $OUT/shellcheck.txt | sort | uniq -c | sed 's/^/INFO /'
{ grep -q ': error:' $OUT/shellcheck.txt && echo "FAIL shellcheck_errors" || echo "PASS shellcheck_no_errors"; } | tee $OUT/shellcheck.log

suite errors bash $TESTS/errors.sh
suite unit   bash $TESTS/unit.sh
if [ "$mode" = full ]; then
	for D in $distros; do
		case "$D" in debian) R=/tmp/rootfs ;; *) R=/tmp/rootfs-$D ;; esac
		Q=/tmp/qm-$D
		suite "build-$D"  bash $TESTS/build.sh "$D"
		suite "rootfs-$D" bash $TESTS/rootfs-check.sh "$D" "$R" $([ "$D" = debian ] && echo $OUT/print-debs.txt)
		for d in 1:esp 2:root 3:usr; do cp --sparse=always $Q/vm-100-disk-${d%:*}.raw /tmp/boot-${d#*:}.raw; done
		suite "image-$D"  bash $TESTS/image-check.sh "$D" $Q/vm-100-disk-1.raw $Q/vm-100-disk-2.raw $Q/vm-100-disk-3.raw "$D"
		suite "boot-$D"   expect -f $TESTS/boot.exp "$D" /tmp/boot-esp.raw /tmp/boot-root.raw /tmp/boot-usr.raw "$D" root
		cp /tmp/boot-console.log "$OUT/boot-$D-console.log" 2>/dev/null
		first=${first:-$D} first_rootfs=${first_rootfs:-$R}
	done
	# mount handling does not depend on the distribution: run once
	suite detach    unshare -m --propagation unchanged bash $TESTS/detach.sh "$first_rootfs"
	suite isolation unshare -m --propagation unchanged bash $TESTS/isolation.sh "$first" "$first_rootfs"
fi

echo; echo "### coverage ($mode)"
bash $TESTS/coverage.sh /tmp/src/linux.sh $COV > $OUT/coverage.txt
sed -n '/^executable lines/p' $OUT/coverage.txt

pass=$(cat $OUT/*.log | grep -c '^PASS') fail=$(cat $OUT/*.log | grep -c '^FAIL')
echo; echo "### total: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
