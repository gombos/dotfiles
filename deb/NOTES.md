# Debian minimal rootfs and Proxmox VM – working notes

`./debian.sh` does two things, and picks one by checking for `qm` on the PATH:

- **Bootstrap mode** (no `qm`): builds a minimal Debian forky rootfs. It started as
  a reimplementation of upstream debootstrap 1.0.145
  (https://salsa.debian.org/installer-team/debootstrap), reduced to
  `LANG=C debootstrap --variant=minbase --components=main`, and has been customised since.
- **VM mode** (`qm` present, i.e. a Proxmox host): turns a rootfs from bootstrap mode
  into a bootable UEFI VM. Reference for the VM conventions: community-scripts
  `vm/debian-vm.sh`. Its `install/debian-install.sh` is an LXC script, so it was not used.

`SCRIPT_MODE=bootstrap` or `SCRIPT_MODE=vm` overrides the automatic choice.

Contents: [Bootstrap mode](#bootstrap-mode) · [VM mode](#vm-mode) · [Status](#status) · [How it was tested](#how-it-was-tested) · [Resume checklist](#resume-checklist)

---

## Bootstrap mode

### Usage

```
sudo LANG=C ./debian.sh [--print-debs] <target>
```

- `--print-debs` prints the package list (before the final purge) and exits;
  it needs no root.
- Everything else is hardcoded at the top: `MIRROR=http://deb.debian.org/debian`,
  `SUITE=forky`, `COMPONENT=main`, `ARCH=amd64`.

### Decisions (in order)

1. Kept only what minbase/main needs: no foreign/second-stage, tarballs, cache
   dir, extra suites, d-i protocol, non-Linux hosts.
2. Removed options: mirror argument, `--components`, `--variant`, `--keyring`,
   `--no-check-sig`, `--help`, `--version`, and the suite argument. Removed the
   `VERSION` variable (wget sends its default user agent).
3. **No Release signature check** (no gpgv/sqv). The unsigned `Release` file is
   downloaded. Packages.xz/.gz and every .deb are still SHA256-checked against
   it. Never switches to https.
4. wget uses `--timeout=60`.
5. awk: **gawk** replaces mawk (installed early, `/usr/bin/awk -> gawk` while bootstrapping).
6. Shell: **bash only**, no dash. `/usr/bin/sh -> bash` is created after unpacking.
7. **tzdata is never installed**, so there is no `/etc/localtime` (UTC).
8. `EXCLUDE_DEPENDENCY` and its code were removed (usrmerge/dash/tzdata
   exclusions made no difference). dash, mawk and tzdata are dropped via
   `without "$required" "mawk dash tzdata"`.
9. **No Perl in the final image.** perl-base is needed during the bootstrap
   (debconf's frontend is Perl), then purged at the end together with
   **init-system-helpers** (update-rc.d etc. are Perl; it stays installed during
   the bootstrap so the dpkg/apt systemd timers get enabled).
10. libpam-runtime is kept (for /etc/pam.d, so su/login work). Only its Perl
    `/usr/sbin/pam-auth-update` is deleted.
11. **cdebconf** answers debconf questions: the debconf package stays (it keeps
    the dependencies satisfied), `/usr/share/debconf/frontend` is moved aside
    with `dpkg-divert --local` to `frontend.perl` and replaced by a symlink to
    `/usr/lib/cdebconf/debconf`. Result: `apt-get check` passes.
12. Base packages: `base="apt cdebconf systemd-sysv"`. This pulls in systemd and
    gives `/sbin/init -> systemd`. udev was tried first and then swapped for
    systemd-sysv.

### Minimal apt/dpkg config

Written by `first_stage_install` into the rootfs:

- `/etc/apt/apt.conf.d/00minimal`: no recommends, `Acquire::Languages "none"`,
  `APT::Keep-Downloaded-Packages "false"`, `DPkg::Post-Invoke` running `apt-get clean`.
- `/etc/dpkg/dpkg.cfg.d/01-minimal`: `path-exclude` for `/usr/share/doc`, `man`, `info`
  and locales, keeping `en*` locales. It no longer keeps copyright files.

Caveat: the first stage unpacks the required debs with `tar`, not dpkg, so
the path rules do not apply to those files. They do apply to everything dpkg
installs afterwards.

Explicit cleanup: after the second stage, `/usr/share/man`, `/usr/share/info` and
`/usr/share/doc` (including copyright files) are removed with `rm -rf`, because the
dpkg rules miss the tar-extracted files.

### Known caveats

- With no terminal, apt needs `DEBIAN_FRONTEND=noninteractive`, because cdebconf
  doesn't fall back to noninteractive by itself. cdebconf stores answers in
  `/var/lib/cdebconf/`.
- Run `apt-get update` in the image before installing anything: the bootstrap's
  lists come from the unsigned Release, so apt treats them as unauthenticated.
- debconf's Perl tools (dpkg-reconfigure, debconf-set-selections) are broken;
  C versions live in `/usr/lib/cdebconf/`.
- Future upgrades of debconf/libpam-runtime may run scripts needing Perl or
  pam-auth-update.
- No udev: booting on real hardware/VMs probably needs it back.
- `deb-systemd-helper: command not found` would appear if init-system-helpers
  were excluded entirely (that was tried and reverted).
- Forky is testing: package sets change daily.
- Sources: the bootstrap writes `deb http://deb.debian.org/debian forky main`
  without `signed-by`.

### Wanted packages not yet installed (from the user's target list)

From Debian main: btrfs-progs, ca-certificates, cryptsetup, curl, fuse3,
iproute2, kmod, libpam-systemd, openssh-server, qemu-guest-agent, sudo,
systemd-resolved, systemd-timesyncd, udev, xz-utils.
From third-party repos (not supported by the script yet): docker-ce, tailscale,
tailscale-archive-keyring.

---

## VM mode

### Usage

Run as root on the Proxmox host (needs `qm`, `pvesm`, `sgdisk`, `losetup`,
`mkfs.ext4`, `mkfs.vfat`, `blkid`):

```
sudo ./debian.sh <rootfs-dir> <vmid> <storage> <name>
```

The rootfs is the output of bootstrap mode.

Environment overrides: `DISK_GB` (8), `MEMORY` (2048), `CORES` (2),
`BRIDGE` (vmbr0), `WORKDIR` (/var/tmp), `START` (1), `ROOT_PASSWORD` (asked
on the terminal if unset).

Console: `qm terminal <vmid>` (serial, `console=ttyS0,115200` on the kernel line).

On failure the work directory under `WORKDIR` is kept and its path is printed.

### What the script does

1. Checks: root, rootfs shape, required commands, VMID free, storage type
   (`pvesm status`), rootfs size fits `DISK_GB`.
2. Creates a sparse raw disk: GPT, p1 = 512 MiB ESP (FAT32), p2 = ext4 root.
3. Copies the rootfs in, bind-mounts proc/sys/dev, mounts the ESP at /boot/efi.
4. In the chroot:
   - `apt-get update` with normal signature checks (no overrides).
   - Installs `perl-base init-system-helpers` (temporarily, see caveats).
   - Writes `/etc/dracut.conf.d/10-vm.conf` with `hostonly="no"`.
   - Installs `dracut linux-image-cloud-amd64 grub-efi-amd64-bin qemu-guest-agent systemd-resolved`.
   - Purges `perl-base init-system-helpers` again with `--force-depends --force-remove-essential`.
   - Copies `/usr/share/grub/default/grub` to `/etc/default/grub`, sets the serial console,
     runs `grub-install --target=x86_64-efi --removable --no-nvram`, then `update-grub`.
5. Writes fstab (UUIDs of root and ESP), hostname, hosts, systemd-networkd DHCP
   on `en* eth*`, enables networkd and resolved, points `/etc/resolv.conf` at the
   resolved stub, empties `machine-id`, sets the root password, cleans apt.
6. Unmounts, detaches the loop device, then `qm create` (q35, OVMF, virtio-scsi,
   agent, tablet off, onboot, serial socket, tag `debian-minimal`), `qm set --efidisk0`
   (efitype=4m, pre-enrolled-keys=0), `qm importdisk` (qcow2 for dir/nfs/cifs
   storage, raw otherwise), `qm set --scsi0 <volid> --boot order=scsi0`, and
   `qm start` if `START=1`.

### Decisions (in order)

1. **UEFI, not BIOS.** Matches the reference (q35 + OVMF + efidisk).
2. **GRUB to the removable path** (`\EFI\BOOT\BOOTX64.EFI`) so no NVRAM entry is needed.
3. **Kernel: `linux-image-cloud-amd64`** (asked for explicitly).
4. **initramfs: dracut**, requested explicitly. It was already pulled in as a
   kernel dependency; the explicit install plus `hostonly="no"` makes the initrd
   contain the virtio drivers for any VM, not just the build host.
5. **Signature checks stay on** in the image. No `AllowInsecureRepositories`,
   no `AllowUnauthenticated`. The rootfs already has `apt`, `sqv` and
   `debian-archive-keyring` (apt depends on them), so nothing extra is needed.
   gpgv is not used and is not installed (the user asked for that).
6. **Minimal apt/dpkg config** comes from bootstrap mode (see above), so it is
   already in the rootfs this script copies. The rootfs also has no
   `/usr/share/doc` (copyright files included), `man` or `info`.
7. **No cloud-init, no SSH.** Only a root password is set.
8. **Network via systemd-networkd + systemd-resolved** (both in the rootfs package set
   or added here). `resolv.conf` is a symlink to the resolved stub.
9. **Start the VM after creation by default** (`START=1`), like the reference.

### Caveats

- **Perl and init-system-helpers are back during the install.** The kernel
  postinst (`dpkg-preconfigure`) needs Perl, and dbus, udev and
  qemu-guest-agent need `update-rc.d` and `deb-systemd-helper`. Both are
  purged again before the image is finished, so the final image has neither,
  as the bootstrap intends. This temporarily breaks the earlier "no Perl" rule
  inside the build step only.
- The VM mode relies on apt's default trusted keyrings (`/usr/share/keyrings`)
  for the bootstrap's `sources.list`. Not yet confirmed by a test.
- `qm importdisk` output is parsed with `sed` (`as 'unused0:<volid>'`). If the
  Proxmox output format changes, the script fails with a clear message.
- `qm` options (`--machine`, `--bios`, `--efidisk0`, `--cpu host`) are untested on a
  real host. Only a stub `qm` was used.
- Test host detail: the partition nodes (`/dev/loopNp1`, `p2`) only appear when the
  host's `/dev` is visible (udev). The test container uses `-v /dev:/dev`, which
  matches a real Proxmox host.
- The script refuses a `DISK_GB` that leaves less than 1 GiB of headroom above
  the rootfs size, because the kernel, modules and initramfs need room.

---

## Status

- **Bootstrap, last full test (2026-10-24):** rc=0, no W:/E:, **83 packages**, all
  "install ok installed", `apt-get check` passes, `su` works, no `/usr/bin/perl`,
  no man/info/`usr/share/doc`, both apt/dpkg config files present. Not installed:
  dash, mawk, tzdata, udev. Purged at the end: perl-base, init-system-helpers.
- **`debian.sh` (combined), 2026-10-25:** `bash -n` passes. A fresh bootstrap build
  through the combined script returned rc=0 with the same results. Mode routing was
  checked with a fake `qm`: no `qm` runs bootstrap, `qm` present runs VM, and
  `SCRIPT_MODE` overrides it. An invalid `SCRIPT_MODE` is rejected.
- **VM mode, earlier build:** passed before the last three changes (signed apt,
  no-recommends file, cloud kernel + explicit dracut). The UEFI build completed, GRUB
  installed, and the image booted under QEMU (TCG, OVMF) to `testvm login:`.
- **VM mode, current build: not run.** The VM build has not been run through
  `debian.sh` on the current rootfs.
- **Not tested at all:** a real `qm`/`pvesm` on Proxmox; `apt-get update` inside the
  VM after boot.
- The old `scratchpad/vmtest/inner.sh` QEMU driver lived in a session scratchpad that
  is no longer available. Its boot check is described below.

## How it was tested

```
# rootfs (bootstrap mode, in a privileged container)
docker run --rm --privileged -v "$PWD":/w debian:trixie bash -c '
  apt-get update -qq && apt-get install -y -qq wget
  LANG=C /w/debian.sh /tmp/mine
  chroot /tmp/mine dpkg-query -W -f="\${Status}\n" | sort | uniq -c
  chroot /tmp/mine apt-get check'
```
(The user is in the `docker` group; sudo needs a password.)

VM mode is tested with a stub `qm`/`pvesm` on PATH, which copies the image on
`qm importdisk`, then a QEMU boot with `OVMF_CODE_4M.fd`. Look for `testvm login:`
in the boot log. The container needs `-v /dev:/dev` so the loop partition nodes appear.

## Resume checklist

1. Run the VM mode on a current rootfs: `debian.sh` with a stub `qm` and `pvesm`,
   then QEMU boot.
2. Confirm: cloud kernel installed, initrd contains virtio drivers (`lsinitrd`),
   boot reaches login, `apt-get check` passes.
3. If a container is stuck, `docker ps` and stop it (`docker kill <id>`).
4. Open decision: remove the rest of `/usr/share/doc` from the tar-extracted required
   set (done only for the paths above). Confirm with the user first.
5. Next steps: decide on cloud-init or an SSH key option, and run on a real Proxmox host.
