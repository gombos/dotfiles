  P=`cat /tmp/$1 | cut -d\# -f 1 | cut -d\; -f 1 | sed '/^$/d' | awk '{print $1;}' | tr '\n' ' \0'`
  install_my_package.sh $P
