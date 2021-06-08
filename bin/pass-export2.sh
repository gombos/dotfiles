#!/usr/bin/env bash
# export pass database to standard out

# $1 - pass directory to export

# make sure you export to an encryped directory
# export.sh > export.md && pandoc export.md -o export.pdf && open export.pdf

shopt -s nullglob globstar
prefix=${PASSWORD_STORE_DIR:-$HOME/.password-store}

for file in "$prefix/$1"/**/*.gpg; do
  file="${file/$prefix/}"
  echo "# $file"
  text=$(pass "${file%.*}")

  linenum=0
  while IFS= read -r line
  do
    echo "$line" | sed "s|\(.*\):\(.*\)|\* \1:\2|g"
  done <<< "$text"

#    echo $text | sed "s|\(.*\):\(.*\)|\* \1:\2|g"
  echo '<div style="page-break-after: always;"></div>'
done
