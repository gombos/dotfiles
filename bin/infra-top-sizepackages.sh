dpkg-query --show --showformat='${Installed-Size}\t${Package}\n' | sort -rh | head -80 | awk '{print $1/1024, $2}'
