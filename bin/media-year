# Preference order
# - #1 Filename
# - #2 smallest EXIF from Creation Date or Date Created or Create Date
# - #3 File creation time based on filesystem metadata

# todo - make it faster and/or look for more datapoints
#File Modification Date/Time     : 2008:09:07 18:45:34-04:00
#Date/Time Original              : 2005:02:17 18:45:27

YEAR=`basename $1 | grep '^20[0-9][0-9]' | sed -E 's/^(20[0-9][0-9])(.*)/\1/'`
YEARN=`echo "$YEAR" | bc`

if [ -z "$YEARN" ]; then
  YEAR=`exiftool $1  | grep -vi "extension " | grep -i "creat" | grep -i "date" | cut -d':' -f2 | sed -e 's/^[[:space:]]*//' | sort | head -1`
  YEARN=`echo "$YEAR" | bc`

  if [ -z "$YEARN" ] || [ "$YEARN" -le "1979" ]; then
    YEAR=`stat --printf='%y' -- $1 | cut -d\- -f1`
    if [ -z "$YEAR" ]; then
      YEAR=0
    fi
  fi
fi

echo $1 "year$YEAR"
