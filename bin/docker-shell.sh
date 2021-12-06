sudo docker run --tty --interactive --rm --volume /home/:/home --workdir "$PWD" $1 /bin/sh
