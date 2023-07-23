docker pull ghcr.io/gombos/linux
distrobox rm --force my-distrobox
distrobox create --name my-distrobox --image ghcr.io/gombos/linux --volume /run:/run  --volume /home:/home -Y --pre-init-hooks "sudo hostname $(uname -n)"
