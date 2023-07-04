# Find out the OS running on
if [ -z "$RELEASE" ]; then

  if [ -f /etc/os-release ]; then
   . /etc/os-release
  fi

  RELEASE=$VERSION_CODENAME
  if [ -z "$RELEASE" ]; then
    RELEASE=$(echo $VERSION | sed -rn 's|.+\((.+)\).+|\1|p')
  fi
fi

echo "Using $ID"

PATH=$PATH:.

if [ $ID == "arch" ]; then
echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
pacman -Syyu
#  useradd -m build
#  pacman --noconfirm -Syu base-devel git sudo cargo
#  su build -c 'cd && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -s --noconfirm'
#  pacman -U --noconfirm ~build/paru/*.pkg.tar.*
fi

packages_update_db.sh
install_my_packages.sh packages-packages.l packages-apps.l packages-*linux.l "packages*-$ID.l"

# use this install script only during initial container creation
rm -rf /usr/sbin/aur-install

# python venv
python3 -m venv  /usr/local/
python3 -m pip install --upgrade pip
/usr/local/bin/pip install --upgrade pip

# pipx
/usr/local/bin/pip3 install pipx

# borgbackup sshuttle linode-cli
