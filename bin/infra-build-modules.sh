if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

if [ -z "$RELEASE" ]; then
  RELEASE=$VERSION_CODENAME
  if [ -z "$RELEASE" ]; then
    RELEASE=$(echo $VERSION | sed -rn 's|.+\((.+)\).+|\1|p')
  fi
fi

if [ -z "$KERNEL" ]; then
  export KERNEL="5.11.0-34-generic"
fi

echo $KERNEL

export DEBIAN_FRONTEND=noninteractive

# Install nvidea driver - this is the only package from restricted source
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE} restricted" > /etc/apt/sources.list.d/restricted.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-security restricted" >> /etc/apt/sources.list.d/restricted.list
echo "deb http://archive.ubuntu.com/ubuntu ${RELEASE}-updates restricted" >> /etc/apt/sources.list.d/restricted.list

apt-get update -y -qq -o Dpkg::Use-Pty=0

apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 build-essential
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-modules-extra-$KERNEL linux-headers-$KERNEL

echo $RELEASE

cat /etc/apt/sources.list.d/restricted.list

apt-get --reinstall install -y nvidia-driver-460

# Make sure we have all the required modules built
$SCRIPTS/infra-install-vmware-workstation-modules.sh
