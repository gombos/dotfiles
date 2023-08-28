docker pull ghcr.io/gombos/linux:latest
distrobox rm --force my-distrobox
distrobox rm --force linux
distrobox create --name linux --image ghcr.io/gombos/linux:linux --volume /run:/run  --volume /home:/home -Y --pre-init-hooks "sudo hostname $(uname -n)"
