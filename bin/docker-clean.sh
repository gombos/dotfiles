#sudo docker stop $(sudo docker ps -aq) 2>/dev/null
#sudo docker rm $(sudo docker system prune -af) 2>/dev/null
sudo docker rm $(sudo docker ps -a | grep -v "ghcr.io/gombos/linux" | grep -v "CONTAINER" | cut -d ' ' -f1)
