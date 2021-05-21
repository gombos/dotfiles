#!/bin/bash

# Creates a base image (aka rootfs)


# Configuration options:
# - architecture
# - distribution
# - bootable or not (bootloader, kernel)

# Requirements
# bash, sudo, debootstrap, docker-ce, virtualbox, multistrap, qemu-user-static

# For inspiration and swiss-army knife - see vagrant and https://www.packer.io/  - todo use them for vmware, aws exports

# Predefined list of targets/templates
case "$1" in
  base-container)
    TARGET=chroot
    PROVISION=no
    ;;
  base-dev)
    PROVISION=no
    IMGSIZE=512
    FILE=rootfs.raw
    ;;
  chroot-dev)
    TARGET=chroot
    PROVISION=yes
    HOST=dev
    ;;
  dev)
    PROVISION=yes
    HOST=dev
    FILE=out/rootfs.raw
    ;;
  docker-dev)
    TARGET=docker
    PROVISION=no
    ;;
  virtualbox-dev)
    TARGET=virtualbox
    PROVISION=no
    ;;
  vmware-dev)
    HOST=dev
    TARGET=vmware
    PROVISION=no
    ;;
  bagoly)
    TARGET=vmware
    HOST=bagoly
    PROVISION=yes
    FILE=rootfs.raw
    CLEANUP=yes
    ;;
  srv)
    TARGET=virtualbox
    IMGSIZE=4096
    HOST=srv
    ;;
  bestia-dev)
    TARGET=virtualbox
    IMGSIZE=4096
    HOST=bestia
    FILE=rootfs.raw
    RELEASE=${RELEASE:=disco}
    ;;
  bestia)
    TARGET=baremetal
    IMGSIZE=4096
    HOST=bestia
    LOG_FILE=${LOG_FILE:=$HOST.log}
    FILE=rootfs.raw
    RELEASE=${RELEASE:=disco}
    ;;
  taska)
    TARGET=virtualbox
    IMGSIZE=4096
    HOST=taska
    FILE=rootfs.raw
    PROVISION=yes
    ;;
  oldpincer)
    TARGET=pi
    HOST=pincer
    FLAVOUR=raspbian
    FILE=rootfs.raw
    PROVISION=yes
    CLEANUP=yes
    ;;
  *)
    # default
    ;;
esac

# Defaults
# Configs overwritable via environment variables

#Debian 8 - jessie
#Debian 9 - stretch
#Debian 10 - buster
#Debian (unstable) - sid

#Raspbian 8 - jessie
#Raspbian 9 - stretch

#Ubuntu 16.04 - xenial
#Ubuntu 18.04 - bionic
#Ubuntu 18.10 - cosmic
#Ubuntu 19.04 - disco
#Ubuntu 19.10 - eoan

OUT_DIR=${OUT_DIR:=out}

if [ "$TARGET" = "pi" ]; then
  VIRT=${VIRT:=qemu-system-arm}
  FLAVOUR=${FLAVOUR:=raspbian}
fi

# Default RELEASE based on FLAVOUR
if [ "$FLAVOUR" == "debian" ]; then
  RELEASE=${RELEASE:=buster}
elif [ "$FLAVOUR" == "raspbian" ]; then
  RELEASE=${RELEASE:=stretch}
else
  RELEASE=${RELEASE:=bionic}
fi

case "$RELEASE" in
  xenial|bionic|cosmic|disco|eoan)
      FLAVOUR=${FLAVOUR:=ubuntu}
      ;;
  *)
      # default
      FLAVOUR=${FLAVOUR:=debian}
      ;;
esac

# Default ARCH based on FLAVOUR
if [ "$FLAVOUR" == "raspbian" ]; then
  ARCH=${ARCH:=armhf}
else
  ARCH=${ARCH:=amd64}
fi

TARGET=${TARGET:=qemu}

# condition for this should be headless
#  KERNEL=virtual

# Only if KERNEL is set to non-default, add it to the base image name
if [ -z "$KERNEL" ]; then
  BASE_FILE=${BASE_FILE:=$OUT_DIR/base-$RELEASE-$ARCH.img}
else
  BASE_FILE=${BASE_FILE:=$OUT_DIR/base-$RELEASE-$ARCH-$KERNEL.img}
fi

#todo - make Filename optional, so that it can work in a dir not just image file
CLEANUP=${CLEANUP:=no}
FNAME=${FNAME:=rootfs}
HOST=${HOST:=$1}
VIRT=${VIRT:=$TARGET}
VIRT=${VIRT:=qemu-system-x86_64}
PROVISION=${PROVISION:=yes}
MNT_DIR=${MNT_DIR:=$OUT_DIR/${FNAME}}
VMNAME=${VMNAME:=_$HOST}
VMDKFILE=${FNAME}-${HOST}.vmdk

#FILE=rootfs.raw

if [ "$LOG_FILE" != "" ]; then
  # Close STDOUT file descriptor
  exec 1<&-
  # Close STDERR FD
  exec 2<&-

  # Open STDOUT as $LOG_FILE file for read and write.
  exec 1<>$LOG_FILE

  # Redirect STDERR to STDOUT
  exec 2>&1
fi

#set -e

# source extranal script
. image-clean.sh

clean_rootfs() {
    MNT_DIR=$1
    MNT_DIR=${MNT_DIR:=~/infratmp/rootfs}

    cd $MNT_DIR

    image_clean_function

    sudo cat etc/shadow | awk 'BEGIN { FS=OFS=":" } /1/ { $3 = "0" ; print }' | sudo sh -c "tee > etc/shadow.new"
    sudo sh -c "mv etc/shadow.new etc/shadow"

    echo "nameserver 1.1.1.1" | sudo tee etc/resolv.conf

    cd -

#/var/lib/systemd/random-seed
#/etc/fake-hwclock.data
#/etc/ld.so.cache
#/etc/mailcap
#/var/cache/debconf/config.dat
#/var/cache/debconf/templates.dat
#/var/cache/ldconfig/aux-cache
#/var/lib/apt/extended_states
#/var/cache/fontconfig
#find . -name '*.pyc' -delete
}

clean_debian() {
  [ "$MNT_DIR" != "" ] && sudo umount $MNT_DIR/boot $MNT_DIR/proc $MNT_DIR/sys $MNT_DIR/dev 2>/dev/null
  sleep 1s
  [ "$MNT_DIR" != "" ] && sudo umount $MNT_DIR 2>/dev/null
  sleep 1s
  [ "$DISK" != "" ] && sudo losetup -d $DISK 2>/dev/null
  sleep 1s
  [ "$DISK2" != "" ] && sudo losetup -d $DISK2 2>/dev/null
}

umount_image() {
  for d in dev sys run proc; do sudo umount $MNT_DIR/$d 2>/dev/null; done

  sudo umount /dev/nbd* 2>/dev/null
  sudo umount /dev/loop* 2>/dev/null
  sudo umount /dev/loop* 2>/dev/null
  sudo umount $MNT_DIR 2>/dev/null
  sudo losetup -d /dev/loop* 2>/dev/null
}

fail() {
  umount_image
  echo ""
  echo "FAILED: $1"
  exit 1
}

cancel() {
  fail "CTRL-C detected"
}

trap cancel INT

mount_image() {
  if ! [ -z "$FILE" ]; then
    # Todo - key this off from partition table of the image and not VIRT
    if [ "$VIRT" == qemu-system-arm ]; then
      # todo - this often fails with losetup: rootfs.raw: failed to set up loop device: Device or resource busy
      # when losetup -l is not empty
      sudo losetup -P /dev/loop0 $FILE
      mkdir -p $MNT_DIR
      sudo mount /dev/loop0p2 $MNT_DIR
    else
      sudo losetup -P /dev/loop0 $FILE
      mkdir -p $MNT_DIR
      sudo mount /dev/loop0p1 $MNT_DIR
      sudo mkdir -p $MNT_DIR $MNT_DIR/dev $MNT_DIR/proc $MNT_DIR/sys
    fi
  fi

  for d in dev sys run proc; do sudo mount -o bind /$d $MNT_DIR/$d; done
}

run_inside_image() {
  # Mount
  mount_image

  # Execute argument inside the mount
  sudo sh -c "$1"

  # Sync/umount
  umount_image
}

create-virtualbox() {
  echo "Create VirtualBox VM..."
  rm -rf ~/VirtualBox\ VMs/${VMNAME} 2>/dev/null || true
  rm $VMDKFILE  2>/dev/null || true

  VBoxManage internalcommands createrawvmdk -filename $VMDKFILE -rawdisk $FILE

  VBoxManage createvm --name ${VMNAME} --ostype Linux_64 --register
  VBoxManage storagectl ${VMNAME} --name "SATA" --add sata --controller IntelAHCI --portcount 4
  VBoxManage storageattach ${VMNAME} --storagectl "SATA" --port 0 --device 0 --type hdd --medium $VMDKFILE
  VBoxManage modifyvm ${VMNAME} --memory 1024 --vram 128
  VBoxManage modifyvm ${VMNAME} --natpf1 "guestssh,tcp,127.0.0.1,2222,,22"
  VBoxManage modifyvm ${VMNAME} --clipboard bidirectional
  VBoxManage modifyvm ${VMNAME} --rtcuseutc on
  VBoxManage modifyvm ${VMNAME} --boot1 disk
  VBoxManage modifyvm ${VMNAME} --boot2 none
  VBoxManage modifyvm ${VMNAME} --boot3 none
  VBoxManage modifyvm ${VMNAME} --boot4 none
  VBoxManage modifyvm ${VMNAME} --audio none
  VBoxManage modifyvm ${VMNAME} --accelerate3d on
  VBoxManage modifyvm ${VMNAME} --biosbootmenu disabled
}

create_img_file() {
echo "Installing $RELEASE into $FILE..."

# Variables local to this script
IMGSIZE=${IMGSIZE:=2048} # in megabytes

if [ "$ARCH" == "armhf" ]; then
  #unmount_image "${FILE}"
  rm -f "${FILE}"
  rm -rf "${MNT_DIR}"
  mkdir -p "${MNT_DIR}"

  BOOT_SIZE=41943040
  #TOTAL_SIZE=192937984 --> 1GB
  TOTAL_SIZE=1266679808 # 2GB
  ROUND_SIZE="$((4 * 1024 * 1024))"
  ROUNDED_ROOT_SECTOR=$(((2 * BOOT_SIZE + ROUND_SIZE) / ROUND_SIZE * ROUND_SIZE / 512 + 8192))
  IMG_SIZE=$(((BOOT_SIZE + TOTAL_SIZE + (800 * 1024 * 1024) + ROUND_SIZE - 1) / ROUND_SIZE * ROUND_SIZE))

  truncate -s "${IMG_SIZE}" "${FILE}"
  printf "o\nn\n\n\n8192\n+$((BOOT_SIZE * 2 /512))\np\nt\nc\nn\n\n\n${ROUNDED_ROOT_SECTOR}\n\n\np\nw\n" | fdisk -H 255 -S 63 "${FILE}"

  PARTED_OUT=$(parted -s "${FILE}" unit b print)
  BOOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 1'| xargs echo -n \
  | cut -d" " -f 2 | tr -d B)
  BOOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 1'| xargs echo -n \
  | cut -d" " -f 4 | tr -d B)

  ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 2'| xargs echo -n \
  | cut -d" " -f 2 | tr -d B)
  ROOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 2'| xargs echo -n \
  | cut -d" " -f 4 | tr -d B)

  BOOT_DEV=$(sudo losetup --show -f -o "${BOOT_OFFSET}" --sizelimit "${BOOT_LENGTH}" "${FILE}")
  ROOT_DEV=$(sudo losetup --show -f -o "${ROOT_OFFSET}" --sizelimit "${ROOT_LENGTH}" "${FILE}")
  echo "/boot: offset $BOOT_OFFSET, length $BOOT_LENGTH"
  echo "/:     offset $ROOT_OFFSET, length $ROOT_LENGTH"

  ROOT_FEATURES="^huge_file"
  for FEATURE in metadata_csum 64bit; do
    if grep -q "$FEATURE" /etc/mke2fs.conf; then
        ROOT_FEATURES="^$FEATURE,$ROOT_FEATURES"
    fi
  done

  sudo mkdosfs -n boot -F 32 -i '2e24ec82' "$BOOT_DEV" > /dev/null
  sudo mkfs.ext4 -L rootfs -U '76e94507-14c7-4d4a-9154-e70a4c7f8441' -O "$ROOT_FEATURES" "$ROOT_DEV" > /dev/null

  DISK=$BOOT_DEV
  DISK2=$ROOT_DEV
  sudo mount -v "$ROOT_DEV" "${MNT_DIR}" -t ext4
  sudo mkdir -p "${MNT_DIR}/boot"
  sudo mount -v "$BOOT_DEV" "${MNT_DIR}/boot" -t vfat
else

  if [ -f $FILE ]; then
    sudo rm -rf $FILE
  fi

  if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    sudo dd if=/dev/zero of=$FILE bs=1024k seek=${IMGSIZE} count=0
    # for non-raw imaages or if you prefer qemu-img
    # qemu-img create -f raw $FILE ${IMGSIZE}M
  fi

  mkdir -p $MNT_DIR

  # Assigning loopback device to the image file
  # modprobe nbd max_part=16 || fail "failed to load nbd module into kernel"
  DISK=
  for i in /dev/loop* # or /dev/nbd*
  do
    if sudo losetup $i $FILE # or qemu-nbd -c $i $FILE
    then
      DISK=$i
      break
    fi
  done
  [ "$DISK" == "" ] && fail "no loop device available"

  echo "Connected $FILE to $DISK"

  # Partition device
  echo "Partitioning $DISK..."

  printf "label: dos\n;\n" | sudo sfdisk $DISK -q || fail "cannot partition $FILE"
  sudo partprobe $DISK

  echo "Creating root partition..."
  sudo mkfs.ext4 -L rootfs -U '76e94507-14c7-4d4a-9154-e70a4c7f8441' ${DISK}p1 || fail "cannot create / ext4"

  # Mount device
  echo "Mounting root partition..."
  sudo mount ${DISK}p1 $MNT_DIR || fail "cannot mount /"
fi
}

base_image_bootable() {
  # Goals
  # Some of these goals are conflicting, so lets list them in priority order
  # Output images are bootable that can be just dd's/flashed/bare, boots in virtualbox, vmware, qemu, chroot, docker, aws
  # Output images support dhcp
  # base image fiels are reproducible, such that between 2 runs the output should be as simialr as possible to previous runs, not yet
  # support all debian based distros
  # Include dhclient in the base image for networking (as that what upstream uses, instead of some of the otehr alternatives that e.g. raspbian is using)

  # but keep the base image as vanilla as possible as long as it is bootable
  # Try to make these reproduceable builds - it shoudl roduce the same base image even years later
  # as it does not update packages

  # deboosrap to prepare chroot
  # chroot into directory
  # install grub, kernel, etc..

  if [ $FLAVOUR == "debian" ]; then
      MIRROR=${MIRROR:="http://deb.debian.org/debian"}
  elif [ $FLAVOUR == "ubuntu" ]; then
      MIRROR=${MIRROR:="http://archive.ubuntu.com/ubuntu/"}
  elif [ $FLAVOUR == "raspbian" ]; then
      MIRROR=${MIRROR:="http://raspbian.raspberrypi.org/raspbian/"}
  fi

  if [ "$FILE" != "" ]; then
    create_img_file
  fi

  echo "Stage - 1 - Debootsrap rootfs..."
  if [ "$ARCH" == "armhf" ]; then
    if ! [ -d pi-gen ]; then
      git clone https://github.com/RPi-Distro/pi-gen.git
    fi
    sudo debootstrap --arch $ARCH --foreign --keyring pi-gen/stage0/files/raspberrypi.gpg --variant=minbase $RELEASE $MNT_DIR $MIRROR
  else
    sudo debootstrap --variant=minbase $RELEASE $MNT_DIR $MIRROR || fail "cannot install into $MNT_DIR"
  fi

  if ! [ "$TARGET" == "chroot" ]; then
    echo "Stage - 2 - Make it bootable...- bootloader + kernel"
      if [ "$ARCH" == "armhf" ]; then
      sudo cp /usr/bin/qemu-arm-static $MNT_DIR/usr/bin
      sudo LANG=C chroot $MNT_DIR /debootstrap/debootstrap --second-stage

      wget -q -O - http://archive.raspberrypi.org/debian/raspberrypi.gpg.key | sudo chroot $MNT_DIR apt-key add -

      sudo mkdir -p $MNT_DIR/etc/apt/sources.list.d/

      # todo - what to do with these other sources
      # contrib non-free
      sudo sh -c "echo \"deb http://raspbian.raspberrypi.org/raspbian/ $RELEASE main\" > $MNT_DIR/etc/apt/sources.list"

      # todo - what to do with these packe sources
      # ui - pixel desktop
      # e.g. for raspberrypi-kernel
      sudo sh -c "echo \"deb http://archive.raspberrypi.org/debian/ $RELEASE main\" > $MNT_DIR/etc/apt/sources.list.d/${FLAVOUR}.list"

      sudo cp pi-gen/stage1/00-boot-files/files/config.txt $MNT_DIR/boot/

      # kernel cmdline
      # todo - do we really need console=serial0,115200 ?
      sudo sh -c "echo \"dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait\" > $MNT_DIR/boot/cmdline.txt"

      # fstab
      sudo sh -c "printf \"LABEL=boot /boot vfat noauto,ro 0 2\nLABEL=rootfs / ext4 noatime 0 1\n\" > $MNT_DIR/etc/fstab"

      KERNEL="raspberrypi-kernel"
      BOOT_LOADER="raspberrypi-bootloader"
      BOOT_PKG+=" $KERNEL $BOOT_LOADER"
    else
      # fstab
      sudo chroot $MNT_DIR sh -c "echo \"/dev/disk/by-label/rootfs /                   ext4    errors=remount-ro 0 1\" > /etc/fstab"

      #kernel
      if [ $FLAVOUR == "debian" ]; then
        KERNEL=${KERNEL:="$ARCH"}
      elif [ -z "$KERNEL" ]; then
        KERNEL=${KERNEL:="generic"}
      fi

      ## Build up /boot
      BOOT_LOADER="grub-pc"
      BOOT_PKG+=" linux-image-$KERNEL $BOOT_LOADER initramfs-tools"

      # For grub installation
      sudo mount --bind /dev/ $MNT_DIR/dev || fail "cannot bind /dev"
      sudo mount -t proc none $MNT_DIR/proc || fail "cannot mount /proc"
      sudo mount -t sysfs none $MNT_DIR/sys || fail "cannot mount /sys"
    fi

    # Empty root password - please change this during provisioning
    sudo sed -i -e "s/^root:[^:]\+:/root::/" $MNT_DIR/etc/shadow

    # init system (PID 1)
    BOOT_PKG+=" systemd-sysv"

    # DHCP support
    BOOT_PKG+=" isc-dhcp-client"

    # Note - we intentionally do not update and install latest packages here
    # so that base images do not change over time

    sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get update -y -q
    sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get install -y -q --no-install-recommends $BOOT_PKG || fail "cannot install $BOOT_PKG"
    sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get clean

    if [ "$FLAVOUR" == "raspbian" ]; then
      sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get purge -y -q gcc-4.6-base gcc-4.7-base gcc-4.8-base gcc-4.9-base gcc-5-base libdbus-1-3 libnih-dbus1 libplymouth4 libpng16-16 mountall plymouth tzdata initramfs-tools initramfs-tools-core
      sudo rm $MNT_DIR/usr/bin/qemu-arm-static
    else
      sudo chroot $MNT_DIR grub-install $DISK || fail "cannot install grub"
      # todo
      # https://superuser.com/questions/1399463/grub2-not-loading-modules
      # apt install grub2-common grub-efi-amd64-bin grub-pc-bin  --no-install-recommends
      # grub-install --target=x86_64-efi --recheck --removable --no-uefi-secure-boot --efi-directory=/mnt/efi --boot-directory=/mnt/efi --install-modules="part_gpt part_msdos ntfs ntfscomp hfsplus fat ext2 btrfs normal chain boot configfile linux video all_video ls reboot search"
      # grub-install --target=i386-pc    --recheck --removable /dev/sdX --boot-directory=/mnt/efi                                       --install-modules="part_gpt part_msdos ntfs ntfscomp hfsplus fat ext2 btrfs normal chain boot configfile linux video all_video ls reboot search"
      sudo chroot $MNT_DIR update-grub || fail "cannot update grub"
      sudo sed -i "s|${DISK}p1|/dev/disk/by-label/rootfs|g" $MNT_DIR/boot/grub/grub.cfg

      ## now that /boot hasb een built up, some packages are no longer needed to actually boot/run going forward
      sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get purge -y --allow-remove-essential initramfs-tools initramfs-tools-core busybox-initramfs cpio initramfs-tools-bin klibc-utils libklibc grub-pc gettext-base grub-common grub-pc-bin grub2-common libfreetype6 libfuse2 libpng16-16 ucf udev
    fi
    sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get autoremove -y -q
fi

  clean_rootfs $MNT_DIR
  clean_debian
  echo "SUCCESS!"
}

# Cleanup from previous runs for convinience
umount_image
#sudo rm -rf $MNT_DIR
mkdir -p $MNT_DIR

if [ "$VIRT" == docker ]; then
  # Remove old docker image
  sudo docker rmi -f $(sudo docker images --filter=reference="base:*" -q)
fi

if [ "$VIRT" == virtualbox ]; then
  # Remove old VM, this will delete rootfs.raw as well
  VBoxManage unregistervm ${VMNAME} --delete 2>/dev/null
fi

if [ ! -f $BASE_FILE ]; then
  echo "Full build"

  # Create base
  if [ "$VIRT" == docker ]; then
    sudo multistrap -f multistrap.conf

    # backup base
    #sudo rm -rf $MNT_DIR
    #mkdir -p $MNT_DIR
    #rsync -av $MNT_DIR /tmp/base/
  else
    base_image_bootable

    if [ "$FILE" != "" ]; then
      sudo chown $UID $FILE

      # backup base
      cp $FILE $BASE_FILE
    fi
  fi
fi

if [ "$PROVISION" == "no" ]; then
  exit
fi

echo "HOST=$HOST" > $OUT_DIR/provisioning-env
echo "RELEASE=$RELEASE" >> $OUT_DIR/provisioning-env
echo "FLAVOUR=$FLAVOUR" >> $OUT_DIR/provisioning-env
echo "FNAME=$FNAME" >> $OUT_DIR/provisioning-env
echo "VIRT=$VIRT" >> $OUT_DIR/provisioning-env
echo "CLEANUP=$CLEANUP" >> $OUT_DIR/provisioning-env

# restore base for faster test cycle - todo for docker
if [ "$VIRT" == docker ] || [ "$VIRT" == chroot ]; then
  sudo cp provision-system.sh $MNT_DIR/root/provision-system.sh
  sudo cp $OUT_DIR/provisioning-env $MNT_DIR/root/provisioning-env
  # Create a flat tar.gz if needed
  # tar --one-file-system --sort=name -C $MNT_DIR -caf rootfs.tar.gz .
  # docker import rootfs.tar.gz base
  #sudo tar -C $MNT_DIR -c . | sudo docker import - base
else
  # restore base for faster test cycle
  cp $BASE_FILE $FILE

  run_inside_image "mkdir -p $MNT_DIR/root/.ssh/ &&mkdir -p $MNT_DIR/root/.secrets/ && cp ~/.ssh/config $MNT_DIR/root/.ssh/config && cp ~/.ssh/known_hosts $MNT_DIR/root/.ssh/known_hosts && cp ~/.secrets/key_ssh $MNT_DIR/root/.secrets/key_ssh"

  # Todo - what about the distro's original rc.local, save original rc.local
  # Add provisinging script to image and provision during first run - option 1
  run_inside_image "cp provision-system.sh $MNT_DIR/etc/rc.local && cp $OUT_DIR/provisioning-env $MNT_DIR/root/provisioning-env"

  # todo
  #mount_image && clean_rootfs $MNT_DIR; clean_debian

  # Provision in chroot - option 2
  #run_inside_image "cp -f provision.sh $MNT_DIR && chroot $MNT_DIR /provision.sh chroot"
fi

# Create startup scripts
echo "MNT_DIR=$MNT_DIR" > $OUT_DIR/runme.sh
declare -f mount_image >> $OUT_DIR/runme.sh
declare -f umount_image >> $OUT_DIR/runme.sh
chmod +x $OUT_DIR/runme.sh

if [ "$VIRT" == "chroot" ]; then
  echo "mount_image && sudo chroot $MNT_DIR \$*; umount_image" >> $OUT_DIR/runme.sh
fi

if [ "$VIRT" == "virtualbox" ] || [ "$VIRT" == "vmware" ]; then
  create-virtualbox
  echo "VBoxManage startvm ${VMNAME}" >> $OUT_DIR/runme.sh
fi

if [ "$VIRT" == "qemu" ]; then
  echo "qemu-system-x86_64 -m 1024 -drive format=raw,file=$FILE -serial mon:stdio" >> $OUT_DIR/runme.sh
  # -net user,hostfwd=tcp::5022-:22 -net nic
  # -net nic -net user -serial stdio
fi

if [ "$VIRT" == qemu-system-arm ]; then
  ./runme-pi.sh $FILE
fi

$OUT_DIR/runme.sh /root/provision-system.sh chroot

# Start virtualization
#if [ "$VIRT" == "docker" ]; then
#  sudo docker run -i -t --rm base /root/provision-system.sh
#fi

# Flash image to a drive
#sudo dd if=rootfs.raw of=/dev/sdX bs=64K conv=noerror,sync status=progress

# Mark vmdk immutable
#VBoxManage storageattach host --storagectl "SATA" --port 0  --medium none
#VBoxManage modifyhd $VMDKFILE --type immutable
#VBoxManage storageattach host --storagectl "SATA" --port 0  --type hdd --medium $VMDKFILE

# Create a flat tar.gz if needed for docker
# tar --one-file-system --sort=name -C $MNT_DIR -caf rootfs.tar.gz .
# docker import rootfs.tar.gz base

# Tips to create a bootable drive
# mount /dev/sdX1 /mnt
# rsync -aAXv  $MNT_DIR /mnt/
# mount --bind /dev  /mnt/dev
# mount --bind /proc /mnt/proc
# mount --bind /sys /mnt/sys
# chroot /mnt
# grub-install /dev/sdX
# update-grub
# passwd

# ssh into the box using local NAT
#ssh-keygen -f "/home/user/.ssh/known_hosts" -R [localhost]:2222; ssh -X user@localhost -p 2222
