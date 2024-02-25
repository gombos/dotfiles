# stop all containers
#docker ps -aq | xargs docker stop | xargs docker rm

# prune all container images
#docker system prune -a -f

docker context use default

# pull in latest container
docker pull ghcr.io/gombos/linux:latest

# reinitialize distrobox
distrobox rm --force linux
distrobox create --name linux --image ghcr.io/gombos/linux:latest --volume /run:/run  --volume /home:/home -Y
distrobox enter linux
# --pre-init-hooks "sudo hostname $(uname -n)"
#colima prune -f && colima delete -f && colima start
