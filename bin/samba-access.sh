#!/bin/bash

# Description: Script to install and configure Samba

#
# How to use:
#   samba-access.sh PATH_TO_SHARED_DIRECTORY  PERMISSIONS
#
# $1 = path , e.g. /home/myuser/publicdir
# $2 = permissions  ,  e.g  755
#

if [ -z "$1" ];then
  echo "samba-acess.sh  PATH_TO_SHARED_DIRECTORY  PERMISSIONS"
  exit 0
fi

if [ -z "$2" ];then
  PERM='777'
else
  PERM=$2
fi

# Install Samba

samba_not_installed=$(dpkg -s samba 2>&1 | grep "not installed")
if [ -n "$samba_not_installed" ];then
  echo "Installing Samba"
  sudo apt-get update -y
  sudo apt-get install samba -y
fi

# Configure directory that will be accessed with Samba

echo "

[global]
  security = user
  guest account = nobody

[global]
workgroup = WORKGROUP
server string = Samba Server %v
netbios name = ubuntu
security = user
map to guest = bad user
name resolve order = bcast host
dns proxy = no
bind interfaces only = yes


[public]
  comment = My Public Folder
  path = $1
  public = yes
  writable = yes
  create mask = $PERM
  browseable = yes
  force user = nobody
  force group = nogroup
  guest ok = yes
  guest only = yes
  read only = no
  create mode = 0777
  directory mode = 0777  

" | sudo tee -a /etc/samba/smb.conf


# Give persmissions to shared directory
sudo mkdir -p $1
sudo chmod -R $PERM $1
sudo chown -R nobody:nogroup $1

# Restart Samba service
sudo /etc/init.d/smbd restart
