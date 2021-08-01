apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 libaio1

cd /

wget -q --no-verbose https://download3.vmware.com/software/wkst/file/VMware-Workstation-Full-15.5.6-16341506.x86_64.bundle
chmod +x ./VMware-Workstation-Full-15.5.6-16341506.x86_64.bundle
./VMware-Workstation-Full-15.5.6-16341506.x86_64.bundle
rm -rf /VMware-Workstation-Full-15.5.6-16341506.x86_64.bundle

# Workaround to support 5.8 kernel
rm /usr/bin/vmware-modconfig
ln -s /usr/bin/true /usr/bin/vmware-modconfig

# Add systemd service files for vmware to make it easier to enable/disable from kernel command line
cat <<EOF | tee lib/systemd/system/vmware.service > /dev/null
[Unit]
Description=VMware daemon
Requires=vmware-USBArbitrator.service
Before=vmware-USBArbitrator.service
After=network.target

[Service]
ExecStart=/etc/init.d/vmware start
ExecStop=/etc/init.d/vmware stop
PIDFile=/var/lock/subsys/vmware
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | tee lib/systemd/system/vmware-USBArbitrator.service > /dev/null
[Unit]
Description=VMware USB Arbitrator
Requires=vmware.service
After=vmware.service

[Service]
ExecStart=/usr/bin/vmware-usbarbitrator
ExecStop=/usr/bin/vmware-usbarbitrator --kill
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | tee lib/systemd/system/vmware-workstation-server.service > /dev/null
[Unit]
Description=VMware Workstation Server
Requires=vmware.service
After=vmware.service

[Service]
ExecStart=/etc/init.d/vmware-workstation-server start
ExecStop=/etc/init.d/vmware-workstation-server stop
PIDFile=/var/lock/subsys/vmware-workstation-server
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

DEBIAN_FRONTEND=noninteractive apt-get purge -y -q linux-headers-* 2>/dev/null >/dev/null
DEBIAN_FRONTEND=noninteractiv apt-get clean
