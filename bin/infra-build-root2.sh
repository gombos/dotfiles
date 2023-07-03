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

#if [ $ID == "arch" ]; then
#  useradd -m build
#  pacman --noconfirm -Syu base-devel git sudo cargo
#  su build -c 'cd && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -s --noconfirm'
#  pacman -U --noconfirm ~build/paru/*.pkg.tar.*
##  curl -Lo /usr/local/bin/pacapt https://github.com/icy/pacapt/raw/ng/pacapt && chmod 755 /usr/local/bin/pacapt
#fi

packages_update_db.sh
install_my_packages.sh packages-packages.l
install_my_packages.sh packages-linux.l
install_my_packages.sh  "packages*-$ID.l"

#install_my_packages.sh packages-core.l
#install_my_packages.sh packages-services.l
#install_my_packages.sh packages-x11core.l
#install_my_packages.sh packages-x11apps.l
