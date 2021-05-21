find /mnt/pictures/Pictures/ -type f -exec ~/my-picture-tags.sh {} \; | grep -v ^mr | sort | uniq   > ~/alltags


#find /mnt/pictures/Pictures/P2015/ -type f -exec basename {} \; > ~/1
#cat ~/1 | grep -E '[\-]' | cut -d'-' -f2- |  cut -f1 -d'.' | tr -s \- '\n' | tr -s \_ '\n' | sed 's/^[0-9]*$//g' | sort | uniq   > ~/2

#| tr -s \_ '\n' | tr -s \- '\n' | cut -f1 -d'.' | sed 's/^[0-9]*$//g' | sort | uniq > 2


#cat 1 | grep -E '[\_|\-]' | tr -d '0123456789' | tr -s \_ '\n' | tr -s \- '\n' | cut -f 1 -d '.' | sort | uniq > 2
