#!/usr/bin/env bash
# export pass database to standard out

shopt -s nullglob globstar
prefix=${PASSWORD_STORE_DIR:-$HOME/.password-store}

for file in "$prefix"/**/*.gpg; do                           
    file="${file/$prefix//}"
    printf "name: %s\npass: " "${file%.*}"
    pass "${file%.*}"
    printf "\n"
done


# export script using low level gpg instead of calling pass directly
# find ~/.password-store -iname \*.gpg | sed 's,.*\.password-store/,,' | sed 's,\.gpg,,' | xargs -n1 -I{} bash -c "echo -n {}:; cat ~/.password-store/{}.gpg | gpg2 -d 2>/dev/null"
