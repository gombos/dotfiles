#!/bin/sh

echo "==> Stop logging"
sudo service rsyslog stop

echo "==> Cleaning up apt cache"
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y autoremove
sudo apt-get -y purge
sudo apt-get -y clean
sudo rm -rf /var/lib/apt/lists/

sudo /bin/rm -rf /var/log/dpkg.log
sudo /bin/rm -rf /var/log/apt
sudo find /var -name "*-old" -exec rm {} \;

echo "==> Cleaning up leftover dhcp leases"
if [ -d "/var/lib/dhcp" ]; then
  sudo rm /var/lib/dhcp/*
fi

#  echo "==> Clear cache and log"
#  sudo find /var/cache /var/log -maxdepth 1 -type f -delete

echo "==> Restore some useful consistency"
sudo apt-get -y update
sudo mandb
sudo ldconfig -v
sudo fc-cache -v
sudo update-mime
sudo update-mime-database -V /usr/share/mime
sudo apt-file update
sudo update-command-not-found
sudo journalctl --update-catalog
sudo yes '' | update-alternatives --force --all

#  sudo ln -sf /dev/null /var/log/lastlog
#  sudo ln -sf /dev/null /var/log/Xorg.0.log
#  sudo ln -sf /dev/null /var/log/Xorg.0.log.old

echo "==> Cleaning up tmp"
sudo /bin/rm -rf /tmp/*
sudo /bin/rm -rf /var/tmp/*
sudo /bin/rm -rf /var/lib/update-notifier/

sudo rm -rf /var/cache/apt
#sudo rm -rf /var/lib/apt
#sudo rm -rf /var/cache/debconf
#sudo rm -rf /var/cache/ldconf

echo "==> Remove the root user’s shell history"
unset HISTFILE
sudo /bin/rm -f ~root/.bash_history

sync
