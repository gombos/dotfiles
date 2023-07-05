#!/bin/sh

if [ "$2" = "debian" ]; then
  case "$1" in
    google-chrome )
      echo "google-chrome-stable" ;;
    * )
      echo "$1"
  esac
else
  echo "$1"
fi

#while read line; do
#    for word in $line; do
#        echo "word = '$word'"
#    done
#done <"myfile.txt"
