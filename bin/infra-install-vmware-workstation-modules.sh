# https://communities.vmware.com/thread/623768

if [ -z "$KERNEL" ]; then
  export KERNEL=$(dpkg -l | grep linux-modules | head -1  | cut -d\- -f3- | cut -d ' ' -f1)
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-headers-$KERNEL build-essential

cd /

export VM_UNAME=$KERNEL
cd /tmp/
git clone https://github.com/mkubecek/vmware-host-modules.git
cd vmware-host-modules
git checkout workstation-15.5.6
make VM_UNAME=$KERNEL
make install VM_UNAME=$KERNEL
make clean VM_UNAME=$KERNEL
cd /
rm -rf /tmp/mware-host-modules

#DEBIAN_FRONTEND=noninteractive apt-get purge -y -q linux-headers-$KERNEL
DEBIAN_FRONTEND=noninteractiv apt-get clean
