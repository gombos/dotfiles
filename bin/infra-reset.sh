docker system prune -a -f
docker pull ghcr.io/gombos/linux:latest
distrobox rm --force linux
distrobox create --name linux --image ghcr.io/gombos/linux:latest --volume /run:/run  --volume /home:/home -Y
distrobox enter linux
# --pre-init-hooks "sudo hostname $(uname -n)"
#colima prune -f && colima delete -f && colima start
