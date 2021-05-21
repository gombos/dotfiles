#md5, createtime, path, time human readable, file size

grep -vi /mnt/p/d/ |
grep -vi picasa.ini, |
grep -viF .AAE, |
grep -viF .MPL, |
grep -viF .LST, |
grep -viF .BDM, |
grep -viF .rss, |
grep -viF .url, |
grep -viF .ini, |
grep -viF .db, |
grep -viF .ABK, |
grep -viF .DPS, |
grep -viF .LCB, |
grep -vi dropbox.attr, |
grep -viF .CD, |
awk -F, '{ print $2","$4","$3","$5","$1 }' |
sort |
sed "s/\/mnt\/p\/o\///"

# Todo test the results.
# grep --color='auto' -P -n "[^\x00-\x7F]" main.md5.name
# This should return empty
# check also for space and otehr special characters
