sudo docker pull ghcr.io/gombos/linux
distrobox rm --force linux
distrobox create --name linux --image ghcr.io/gombos/linux --volume /home:/home -Y
