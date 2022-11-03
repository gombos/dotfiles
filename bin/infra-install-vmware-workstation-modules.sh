# https://communities.vmware.com/thread/623768

KERNEL=$(cd /lib/modules; ls -1 | tail -1)

export VM_UNAME=$KERNEL
cd /tmp/
git clone https://github.com/mkubecek/vmware-host-modules.git
cd vmware-host-modules
git checkout workstation-15.5.7
make VM_UNAME=$KERNEL
make install VM_UNAME=$KERNEL
make clean VM_UNAME=$KERNEL
cd /
rm -rf /tmp/mware-host-modules
