#!/bin/bash
# run.sh [quick|full] : test debian.sh in a privileged Debian forky container.
#   quick  shellcheck, error paths, --print-debs, unit tests        (~2 min)
#   full   also bootstrap + VM build with stub qm/pvesm, rootfs and image
#          checks, unmount tests, QEMU boot of the image             (~10 min)
# Needs docker; the boot test uses /dev/kvm when available.
# Logs and the coverage report end up in $OUT (default /tmp/debian-sh-tests).
set -eu
here=$(cd "${0%/*}" && pwd)
mode=${1:-quick}
out=${OUT:-/tmp/debian-sh-tests}
name=debian-sh-test-$$
docker build -q -t debian-sh-test "$here" >/dev/null
trap 'docker rm -f "$name" >/dev/null 2>&1' EXIT
rc=0
docker run --name "$name" --privileged -v /dev:/dev -v "$here/..:/src:ro" \
	debian-sh-test bash /src/tests/container.sh "$mode" || rc=$?
rm -rf "$out"
docker cp "$name:/tmp/out" "$out" >/dev/null && echo "logs and coverage report: $out"
exit $rc
