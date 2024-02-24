dotfiles
homelab
Keep size around 1 MB

rootfs (current):
 - initramfs (alpine)
 - base (debian:stable)
 - sysext_1 (debian:sid)
 - container (debian:sid)

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


https://www.kontrol.dev/#/zones
edit
Proxy Hostname: public hostname (not url) of the server
Proxy Port: 0

https://kasmweb.com/docs/latest/how_to/reverse_proxy.html