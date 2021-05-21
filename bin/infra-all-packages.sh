#!/bin/sh
cat ~/.home/infra/top/* ~/.home/infra/dpkg/* ~/.dotfiles/infra/packages-* | grep -v \# | sed 's/^;//'| sort | uniq
