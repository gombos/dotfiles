#!/bin/sh

# Todo - make this invokable as an aws launch script as well
# e.g. https://docs.aws.amazon.com/cli/latest/reference/lightsail/create-instances.html user-data argument

#sudo apt-get install -y apt-transport-https ca-certificates
#sudo apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list
#sudo apt-get update
#sudo apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
#sudo apt-get install -y docker-engine
#sudo service docker start

#sudo docker pull php:5.6-apache
#sudo docker run --name apachephp -d --restart=always -p 80:80 php:5.6-apache

# sudo docker images |grep -v REPOSITORY|awk '{print $1}'|xargs -L1 sudo docker pull

#sudo docker pull 0gombi0/homelab

CLOUDID=$(/usr/bin/cloud-id)
USERN=$(getent passwd 1000 | cut -d: -f1)
USERHOME=$(getent passwd 1000 | cut -d: -f6)

cd $USERHOME

if ! [ -d .dotfiles ]; then
  runuser -u www-data -- git clone https://github.com/gombos/dotfiles.git .dotfiles
  ln -sf .dotfiles/bin/infra-provision-user.sh .bash_profile
  sudo chown -R 1000 .dotfiles
else
 cd .dotfiles && git pull && cd ..
fi

source .dotfiles/.bashrc
update-me

sudo mkdir -p /home/www/
echo "helloka" > /home/www/index.html
sudo chown -R 1000:1000 /home/www/

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -qq -o Dpkg::Use-Pty=0
sudo apt-get install -y docker.io docker-compose

sudo service docker start

# Reduce peak memory usage
sleep 5

cd $USERHOME/.dotfiles/infra/
sudo docker-compose up -d
