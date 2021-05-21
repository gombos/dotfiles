# Script to check and print out what is not consistent according to
# condition/invariant trying to mainain.
# This script is not to fix, this is just check condition.
# Script should run on read-only directory

# Order the check based on how much time it takes to run them

if [ -z "$1" ]; then
  DST="/run/media/archive_media/archive_media/p/o"
else
  DST="$1"
fi

find $DST -empty
detox -r -n -s iso8859_1 $DST
find $DST -type f -not -perm 0444
find $DST -type d -not -perm 0775
#getfattr -R $DST

find $DST -type f -printf "%f\n" | grep '[_|-]' | grep '^20[0-9][0-9]' | grep -v '^20[0-9][0-9][_|-]' | grep -v '^20[0-9][0-9][0-9][0-9][0-9][0-9][_|-]'
find $DST -type f -printf "%f\n" | grep '[_|-]' | grep '^19[0-9][0-9]' | grep -v '^19[0-9][0-9][_|-]' | grep -v '^19[0-9][0-9][0-9][0-9][0-9][0-9][_|-]'

# to fox naming within a subtree
# shopt -s globstar && rename -v 's/IMG_//' **
find $DST -name "IMG_*"

# find . -type f -print0 | xargs -0 getfattr -d -m - | sed 's/^\#\ file\:\ //' | sed '/^$/d' | sed -z 's/\nu/,u/g'

# add dates to filename
# rename 's/(\d+\.JPG)/use File::stat; use POSIX; sprintf("%s_%s", strftime("%Y%m%d_%H%M%S", localtime(stat($&)->mtime)), $1)/e' * -v -n

rmlint -o pretty:stdout

#find $DST -type f ! \( -iname "*.jpg" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.crw" -o -iname "*.avi" -o -iname "*.png" -o -iname "*.mts" -o -iname "*.mpg" -o -iname "*.3gp" -o -iname "*.cpi" -o -iname "*.wmv" -o -iname "*.gif" -o -iname "*.webp" \) \
#| grep -v 2007 \
#| grep -v 2002 \
#| grep -v 2003 \
#| grep -v 2006 \
#| grep -v 2007 \
#| grep -v 2008 \
#| grep -v 2011 \
#| grep -v 2012 \
#| grep -v 2019

# Cut down on deep directory hierarchies

#find /mnt/p/ -mindepth 10 -type d -ls

#find /mnt/p/o/2018/ -type f -exec ~/.bin/my-picture-year.sh {} \; | grep -v year2018
#find /mnt/p/o/2019/ -type f -exec ~/.bin/my-picture-year.sh {} \; | grep -v year2019

#for i in $(seq 0 9);
#do
#  nohup find /mnt/p/o/200$i/ -type f -exec ~/.bin/my-picture-year.sh {} \; | grep -v year200$i  > ~/200$i &
#done

#for i in $(seq 0 9);
#do
#  nohup find /mnt/p/o/201$i/ -type f -exec ~/.bin/my-picture-year.sh {} \; | grep -v year201$i  > ~/201$i &
#done
