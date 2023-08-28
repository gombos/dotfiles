docker pull ghcr.io/gombos/linux:latest
distrobox rm --force linux
distrobox create --name linux --image ghcr.io/gombos/linux:latest --volume /run:/run  --volume /home:/home -Y --pre-init-hooks "sudo hostname $(uname -n)"
