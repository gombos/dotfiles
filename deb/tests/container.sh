#!/bin/bash
# container.sh quick|full : runs inside the test container (see run.sh)
set -u
mode=${1:-quick}
cp -a /src /tmp/src; chmod -R a+rX /tmp/src	# readable for the non-root tests
export TESTS=/tmp/src/tests COV=/tmp/cov OUT=/tmp/out DEBIAN_COV=/tmp/src/debian.cov.sh
mkdir -p $COV $OUT; chmod 1777 $COV /tmp
# instrumented copy: the shebang line becomes the xtrace setup, so line numbers
# stay the same; tests run it as "bash $DEBIAN_COV"
sed "1s/.*/PS4='+debian.sh:\${LINENO}:\${FUNCNAME[0]:-main}: '; BASH_XTRACEFD=9; set -x/" \
	/tmp/src/debian.sh > $DEBIAN_COV

suite () {	# NAME cmd... : run a test script, keep its log, show results
	echo; echo "### $1"
	local name=$1; shift
	"$@" > "$OUT/$name.log" 2>&1 || grep -q "^FAIL" "$OUT/$name.log" ||
		echo "FAIL $name exited with an error, see $name.log" >> "$OUT/$name.log"
	grep -E '^(PASS|FAIL|INFO|==)' "$OUT/$name.log"
}

echo "### shellcheck"
shellcheck -s bash -f gcc /tmp/src/debian.sh > $OUT/shellcheck.txt
sed -n 's/.*\[\(SC[0-9]*\)\]$/\1/p' $OUT/shellcheck.txt | sort | uniq -c | sed 's/^/INFO /'
{ grep -q ': error:' $OUT/shellcheck.txt && echo "FAIL shellcheck_errors" || echo "PASS shellcheck_no_errors"; } | tee $OUT/shellcheck.log

suite errors bash $TESTS/errors.sh
suite unit   bash $TESTS/unit.sh
if [ "$mode" = full ]; then
	suite build  bash $TESTS/build.sh
	suite rootfs bash $TESTS/rootfs-check.sh /tmp/rootfs $OUT/print-debs.txt
	for d in 1:esp 2:root 3:usr; do cp --sparse=always /tmp/qm/vm-100-disk-${d%:*}.raw /tmp/boot-${d#*:}.raw; done
	suite image  bash $TESTS/image-check.sh /tmp/qm/vm-100-disk-1.raw /tmp/qm/vm-100-disk-2.raw /tmp/qm/vm-100-disk-3.raw debian
	suite detach unshare -m --propagation unchanged bash $TESTS/detach.sh /tmp/rootfs
	suite isolation unshare -m --propagation unchanged bash $TESTS/isolation.sh /tmp/rootfs
	suite boot   expect -f $TESTS/boot.exp /tmp/boot-esp.raw /tmp/boot-root.raw /tmp/boot-usr.raw debian test
	cp /tmp/boot-console.log $OUT/ 2>/dev/null
fi

echo; echo "### coverage ($mode)"
bash $TESTS/coverage.sh /tmp/src/debian.sh $COV > $OUT/coverage.txt
sed -n '/^executable lines/p' $OUT/coverage.txt

pass=$(cat $OUT/*.log | grep -c '^PASS') fail=$(cat $OUT/*.log | grep -c '^FAIL')
echo; echo "### total: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
