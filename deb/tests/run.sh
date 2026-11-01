#!/bin/bash
# run.sh [quick|full] [debian|arch|all] : test linux.sh in a privileged Debian
# forky container.
#   quick  shellcheck, error paths, --print-debs, unit tests        (~2 min)
#   full   also, per distribution (default all): bootstrap + VM build with
#          stub qm/pvesm/pvesh, rootfs and image checks, QEMU boot of the
#          image; then the unmount tests once      (~10 min per distribution)
# Needs docker; the boot test uses /dev/kvm when available.
# Logs and the coverage report end up in $OUT (default /tmp/linux-sh-tests).
set -eu
here=$(cd "${0%/*}" && pwd)
mode=${1:-quick} distros=${2:-all}
out=${OUT:-/tmp/linux-sh-tests}
name=linux-sh-test-$$
docker build -q -t linux-sh-test "$here" >/dev/null
trap 'docker rm -f "$name" >/dev/null 2>&1' EXIT
rc=0
docker run --name "$name" --privileged -v /dev:/dev -v "$here/..:/src:ro" \
	linux-sh-test bash /src/tests/container.sh "$mode" "$distros" || rc=$?
rm -rf "$out"
docker cp "$name:/tmp/out" "$out" >/dev/null && echo "logs and coverage report: $out"
exit $rc
