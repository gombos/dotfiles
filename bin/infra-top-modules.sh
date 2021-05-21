#!/bin/sh
lsmod | grep "  [0-9]$" | cut -d' ' -f1 | sort
