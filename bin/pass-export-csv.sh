#!/usr/bin/env bash
# export pass database to standard out

shopt -s nullglob globstar
prefix=${PASSWORD_STORE_DIR:-$HOME/.password-store}

rm -rf pass.csv pass_sorted.csv chrome.csv chrome_sorted.csv

#printf "url,login,pass\n" > pass.csv
for file in "$prefix"/**/*.gpg; do                           
    file="${file/$prefix//}"
    pass "${file%.*}" | sed -n 1,3p | cut -d':' -f2- | tr  '\n' ',' | tr -d " " | cut -d',' -f1-3 | awk -F',' '{print $3 "," $2 "," $1}' >> pass.csv
done
cat pass.csv  | sort -t, -k1 > pass_sorted.csv
#printf ".separator ,\n.import pass_sorted.csv pass\n" | sqlite3 pass.sqlite

#printf "url,login,pass\n" > chrome.csv
sqlite3 -csv ~/.0-chrome/Default/Login\ Data "SELECT origin_url,username_value,password_value FROM logins" >> chrome.csv
cat chrome.csv  | sort -t, -k1 > chrome_sorted.csv
#printf ".separator ,\n.import chrome.csv pass\n" | sqlite3 chrome.sqlite

diff pass_sorted.csv chrome_sorted.csv
rm -rf pass.csv pass_sorted.csv chrome.csv chrome_sorted.csv
