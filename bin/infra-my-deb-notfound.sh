#!/bin/bash

export LC_ALL=C; comm -23 <(find "$@" -xdev -type f 2>/dev/null | sort | grep -v ^/usr/lib/modules  ) <(sort -u /var/lib/dpkg/info/*.list);
