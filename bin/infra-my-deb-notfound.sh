#!/bin/bash

export LC_ALL=C; comm -23 <(find "$@" -xdev -type f | sort) <(sort -u /var/lib/dpkg/info/*.list);
