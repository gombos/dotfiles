sudo docker stop $(sudo docker ps -aq) 2>/dev/null
sudo docker rm $(sudo docker system prune -af) 2>/dev/null


