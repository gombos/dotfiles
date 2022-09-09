#!/bin/bash

if ! command -v bw &> /dev/null; then
  echo "The Bitwarden CLI is not installed."
  exit 1
elif ! command -v jq &> /dev/null; then
  echo "The jq utility is not installed."
  exit 1
fi

catch()
{
eval "$({
__2="$(
  { __1="$("${@:3}")"; } 2>&1;
  ret=$?;
  printf '%q=%q\n' "$1" "$__1" >&2;
  exit $ret
  )";
ret="$?";
printf '%s=%q\n' "$2" "$__2" >&2;
printf '( exit %q )' "$ret" >&2;
} 2>&1 )";
}

ORIG_MSG_FILE="$1"  # Grab the current template

TEMP=`mktemp /tmp/git-msg-XXXXX` # Create a temp file
trap "rm -f $TEMP" exit # Remove temp file on exit

# todo, maybe use this ?
# bw list items --search github

wrap_bw() {
  bw get item $ORIG_MSG_FILE
}

catch ITEM stderr wrap_bw

retVal=$?
if [ $retVal -ne 0 ]; then
    printf "$stderr\n"
    exit $retVal
fi

ID=$(echo "$ITEM" | jq -r ".id")

echo "$ITEM" | jq -r ".notes" > "$TEMP" # print all to temp file

micro "$TEMP"

# re-encode note to json
NEWNOTE=$(cat "$TEMP")
ANOTE=\""$NEWNOTE"\"
AANOTE=$(echo $ANOTE | awk '{printf "%s\\n", $0}')

# upload the new note
echo "$ITEM" | jq ".notes=$ANOTE" | bw encode | bw edit item $ID
