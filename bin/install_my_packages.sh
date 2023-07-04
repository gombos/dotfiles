#!/bin/sh

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

filterpackage() {
if [ "$ID" = "debian" ]
then
  case "$1" in
    google-chrome)
      echo "google-chrome-stable";;
    *)
      echo "$1"
  esac
else
  echo "$1"
fi
}

# install packages all at once for better dependency management and to avoid that order of packages is significant
P=`cat /tmp/$@ | cut -d\# -f 1 | cut -d\; -f 1 | sed '/^$/d' | awk '{print $1;}' | while read in;
do
  Q=$(filterpackage "$in")
  echo -n " $Q "
done`

i $P
