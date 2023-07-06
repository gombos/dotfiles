## nxmachine - needs rw to /usr
#echo "nx:x:401:nobody" >> /etc/group
#adduser --disabled-password --uid 401 --gid 401 --shell "/etc/NX/nxserver" --home "/var/NX/nx" --gecos "" nx
#
## see https://downloads.nomachine.com/linux/?id=1
#wget --no-verbose --no-check-certificate https://download.nomachine.com/download/8.6/Linux/nomachine_8.6.1_3_amd64.deb
#
#dpkg -i *.deb
#rm -rf *.deb /usr/NX/etc/keys /usr/NX/etc/sshstatus /usr/NX/etc/usb.db* /usr/NX/etc/*.lic /usr/NX/etc/nxdb /usr/NX/etc/uuid /usr/NX/etc/node.cfg /usr/NX/etc/server.cfg /var/NX/nx/.ssh
