# Rootfs design guidelines
# Included:
# - Basic cli apps
# - Basic gui apps
# - Language runtimes, python, go, java
# - container orchestration
# - VM orchestration
# - all packages that is required for rescue and pincer and bagoly vm use-cases

# Not Included:
# - secrets, unique identifiers
# - special containers

# Avoid if possible
# - non-free/restricted software (3 exceptions: vmware and nvidia, chrome)
# - software needs frequent updates
# - packages that will not update with apt update
# - star processes/daemons automatically

mnt-linux
DIR=$MNTDIR/linux/linux-dev

RELEASE=focal

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>rootfs.log 2>&1

# Make sure we do not pick up hostname from the host that generates the image
sudo hostnamectl set-hostname localhost

sudo btrfs property set -ts $DIR ro false
sudo btrfs subvolume delete $DIR 2>/dev/null
sudo btrfs subvolume create $DIR

# Deboostrap
sudo LANG=C  debootstrap --variant=minbase --components=main,universe $RELEASE $DIR
sudo cp ~/.dotfiles/bin/* ~/.dotfiles/packages/* $DIR/tmp/

sudo mount -t proc proc $DIR/proc/
sudo mount --rbind /dev $DIR/dev/
sudo mount -t sysfs sys $DIR/sys/

# Enable package updates before installing rest of packages
sudo chroot $DIR sh -c "./infra-build-root.sh"

# Install vmware manually if needed by running infra-rootfs and executing infra-install-vmware-workstation.sh line-by-line

sudo umount $DIR/proc/ $DIR/sys/
sudo mount --make-rslave $DIR/dev/
sudo umount -R $DIR/dev/

infra-clean-linux.sh $DIR

sudo rm -rf $DIR/*.sh $DIR/*.l

# Make it read only
sudo btrfs property set -ts $DIR ro true
