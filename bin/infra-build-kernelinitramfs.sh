set -x

. ./infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0

cd /tmp/

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 systemd

ls -la /usr/lib/systemd/boot/efi/linuxx64.efi.stub

which objcopy

#objcopy \
#--add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
#--add-section .linux="vmlinuz-linux" --change-section-vma .linux=0x40000 \
#--add-section .initrd="initramfs-linux.img" --change-section-vma .initrd=0x3000000 \
#/usr/lib/systemd/boot/efi/linuxx64.efi.stub kernel.efi

#+#objcopy \
#+#--add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
#+#--add-section .cmdline="cmdline.txt" --change-section-vma .cmdline=0x30000 \
#+#--add-section .linux="vmlinuz-linux" --change-section-vma .linux=0x40000 \
#+#--add-section .initrd="initramfs-linux.img" --change-section-vma .initrd=0x3000000 \
#+#/usr/lib/systemd/boot/efi/linuxx64.efi.stub kernel.efi
