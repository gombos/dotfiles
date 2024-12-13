OS:
 - Reach: Linux
 - Preferred: MacOS
 - Avoid: Windows

Linux distro
 - Reach: Debian
 - Preferred: Ubuntu

dotfiles
homelab
Keep size around 1 MB

rootfs (current):
 - initramfs (alpine)
   - 1M

 - base (debian:12)
   - /etc and /usr
   - empty /var and /usr/local
   - no package manager installed (distroless), image based OS
   - includes systemd, networking, chroot and systemd-nspawn
   - can download another rootfs and boot into it
   - CLI only (no dbus, no desktop)
   - 50M squashed

 - sysext_1 (debian:12)
   - can update without reboot, but loads at reboot
   - container runtime
   - distrobox
   - qemu

 - container (ubuntu:24.04)
  - superset of everything else

rootfs (idea):
 - stay in initramfs (base)

how to utilize my rootfs (squashfs)
 - distrobox
 - kasm
 - colima
 - sysext
 - docker container
 - oci

kasm

cd /tmp
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.15.0.06fdc8.tar.gz
tar -xf kasm_release_1.15.0.06fdc8.tar.gz
sudo bash kasm_release/install.sh --proxy-port 8443 --skip-v4l2loopback --slim-images

cd /tmp
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.16.1.98d6fa.tar.gz
tar -xf kasm_release_1.16.1.98d6fa.tar.gz
sudo bash kasm_release/install.sh


https://www.kontrol.dev/#/zones
edit
Proxy Hostname: public hostname (not url) of the server
Proxy Port: 0

https://kasmweb.com/docs/latest/how_to/reverse_proxy.html
https://kasmweb.com/docs/latest/how_to.html
https://kasmweb.com/docs/latest/how_to/fixed_infrastructure.html#vnc

Packaging:
 - brew does not support arm linux
 - makedeb does not support arm linux

Install from (priority order):
 - pip --> /usr/local/bin/
  - https://pypi.org/

 - npm --> /usr/local/bin
   - https://www.npmjs.com/package

 - cargo --> /usr/local/bin
   - https://crates.io/crates

 - apt repositories for Debian archives (.deb) --> /usr/bin
  - http://deb.debian.org/debian

 - nix channels for Nix archives (.nar) --> /nix/var/nix/profiles/default/bin/
  - https://cache.nixos.org

 - flathub apps (for browser)
   - https://flathub.org

 - docker images
  - https://ghcr.io
  - docker.io

Package managers (in priority order)
 - pip - user, cross-platform
 - conda - user, cross-platform
 - brew - user and system, MacOS and Linux
 - docker - system only, cross-platform
 - nix - user and system, MacOS and Linux
 - apt - system only, MacOS and Linux
