echo `hashdeep -c md5 -- "$1" | tail -n +6`,`stat --printf='%Y,%y' -- "$1"`
