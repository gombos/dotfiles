#!/bin/bash
# coverage.sh SCRIPT COVDIR : line coverage report of SCRIPT.
# COVDIR/run-*.lines come from real invocations, unit-*.lines from unit tests.
src=$1 dir=$2
cat "$dir"/run-*.lines 2>/dev/null | cut -d' ' -f1 | sort -un > /tmp/cov.run
cat "$dir"/unit-*.lines 2>/dev/null | cut -d' ' -f1 | sort -un > /tmp/cov.unit
gawk -v runf=/tmp/cov.run -v unitf=/tmp/cov.unit -f "${0%/*}/coverage.awk" "$src"
