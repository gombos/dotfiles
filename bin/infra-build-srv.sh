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

ID=$(/usr/bin/cloud-id)

git clone https://github.com/gombos/dotfiles.git


install_my_package () {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 "$1"
}

install_my_packages() {
  cat $1 | sed '/^$/d' | grep -v ^\# | grep -v ^\; | awk '{print $1;}' | while read in;

  do
    install_my_package "$in"
  done
}

DEBIAN_FRONTEND=noninteractive apt-get update -y -qq -o Dpkg::Use-Pty=0

install_my_packages packages-srv.l
sudo service docker start

if [ "$ID" != "aws" ]; then

./infra-clean-linux.sh /
mv /*.sh /*.l tmp/

 ---- Integrity
./tmp/infra-integrity.sh /var/integrity/

rm -rf /tmp/*
fi
