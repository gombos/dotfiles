# Shared helpers for the test scripts (sourced). Environment from container.sh:
# TESTS (this directory), DEBIAN_COV (instrumented debian.sh), COV (coverage
# output), OUT (artifacts).
PASS=0 FAIL=0
T=$TESTS/traced
pass () { echo "PASS $*"; PASS=$((PASS + 1)); }
fail () { echo "FAIL $*"; FAIL=$((FAIL + 1)); }
ok ()  { local n=$1; shift; if "$@"; then pass "$n"; else fail "$n"; fi; }
nok () { local n=$1; shift; if "$@"; then fail "$n"; else pass "$n"; fi; }
has () { [[ "$1" == *"$2"* ]]; }
summary () { echo "== ${0##*/}: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }

# load_functions NAME : source the instrumented script without its final
# "main" call; lines run inside its functions are recorded as unit coverage
load_functions () {
	exec 9> >(exec gawk 'match($0, /debian\.sh:([0-9]+):([^:]*):/, m) && m[2] != "main" { k = m[1] " " m[2]; if (!seen[k]++) { print k; fflush() } }' > "$COV/unit-$1.lines")
	exec 3>&1 4>&1
	source <(sed '$d' "$DEBIAN_COV")
	set +e +x
}
# trace only the function under test
run () { set -x; "$@"; local rc=$?; set +x; return $rc; }
cap () { set -x; "$@" 2>&1 4>&1; local rc=$?; set +x; return $rc; }
