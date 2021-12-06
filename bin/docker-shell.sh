i=$1

if [ -z "$i" ]; then
  i="0gombi0/homelab"
fi

b=$(docker run $i sh -c "test -f /bin/bash && echo bash")

if [ "$b" = "bash" ]; then
  sudo docker run --tty --interactive --rm --volume /home/:/home --workdir "$PWD" $i /bin/bash
else
  sudo docker run --tty --interactive --rm --volume /home/:/home --workdir "$PWD" $i /bin/sh
fi
