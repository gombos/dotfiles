# Minimal Debian / Arch Linux rootfs and Proxmox VM – working notes

`./linux.sh` (called `debian.sh` until 2026-10-31) does two things, and picks one
by checking for `qm` on the PATH:

- **Bootstrap mode** (no `qm`): builds a minimal Debian forky rootfs, or with
  `--distro arch` an Arch Linux rootfs (see [Arch Linux](#arch-linux)). The Debian part started as
  a reimplementation of upstream debootstrap 1.0.145
  (https://salsa.debian.org/installer-team/debootstrap), reduced to
  `LANG=C debootstrap --variant=minbase --components=main`, and has been customised since.
- **VM mode** (`qm` present, i.e. a Proxmox host): turns a rootfs from bootstrap mode
  into a bootable UEFI VM. Reference for the VM conventions: community-scripts
  `vm/debian-vm.sh`. Its `install/debian-install.sh` is an LXC script, so it was not used.

`--distro debian|arch` (default `debian`) selects the distribution; it may stand
anywhere among the arguments. On a Proxmox host, `./linux.sh` without other
arguments does both: it bootstraps the default rootfs (`/tmp/rootfs`, for Arch
`/tmp/rootfs-arch`) when empty and builds a VM from it, using the next free VMID
(`pvesh get /cluster/nextid`) and the distribution name as VM name. A leading option such as
`--print-debs` always means bootstrap mode.
`SCRIPT_MODE=bootstrap` or `SCRIPT_MODE=vm` overrides the automatic choice.

Contents: [Bootstrap mode](#bootstrap-mode) · [Arch Linux](#arch-linux) · [VM mode](#vm-mode) · [Status](#status) · [How it was tested](#how-it-was-tested) · [Resume checklist](#resume-checklist)

---

## Bootstrap mode

### Usage

```
sudo LANG=C ./linux.sh [--print-debs] <target>
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
  `APT::Keep-Downloaded-Packages "false"`. (A `DPkg::Post-Invoke` running
  `apt-get clean` was dropped: it could never get apt's archive lock.)
- `/etc/dpkg/dpkg.cfg.d/01-minimal`: `path-exclude` for `/usr/share/doc`, `man`, `info`
  and locales, keeping `en*` locales. It no longer keeps copyright files.

Caveat: the first stage unpacks the required debs with `tar`, not dpkg, so
the path rules do not apply to those files. They do apply to everything dpkg
installs afterwards.

Explicit cleanup: after the second stage, `/usr/share/man`, `/usr/share/info`,
`/usr/share/doc` (including copyright files) and all non-`en*` entries of
`/usr/share/locale` are removed, because the dpkg rules miss the tar-extracted
files. The empty base-files directories `/usr/share/dict`, `/usr/share/misc`,
`/usr/local`, `/usr/src` and `/usr/games` are removed too (a base-files upgrade
may recreate them). The downloaded `.deb`s are deleted from `/var/cache/apt/archives`.
`/etc/locale.conf` is written with `LANG=C.UTF-8`: `/etc/default/locale` is a
symlink to it, and pam_env logs an error at every login when it is missing.

Merged /usr is not done by the script: base-files ships the `/bin`, `/lib`,
`/lib64`, `/sbin` symlinks and the first stage only checks they are symlinks.
Device nodes are created with mknod; unprivileged containers are not supported.
The build host must be Debian 13 or later (dpkg-deb is required).

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
- Sources: the bootstrap writes `/etc/apt/sources.list.d/debian.sources` in
  deb822 format with `Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp`
  (no one-line `sources.list`, so apt does not suggest `apt modernize-sources`).

### Wanted packages not yet installed (from the user's target list)

From Debian main: btrfs-progs, ca-certificates, cryptsetup, curl, fuse3,
iproute2, kmod, libpam-systemd, openssh-server, qemu-guest-agent, sudo,
systemd-resolved, systemd-timesyncd, udev, xz-utils.
From third-party repos (not supported by the script yet): docker-ce, tailscale,
tailscale-archive-keyring.

---

## Arch Linux

### Usage

```
sudo ./linux.sh --distro arch [target]            # rootfs only (default /tmp/rootfs-arch)
sudo ./linux.sh --distro arch [[rootfs] vmid name] # on Proxmox: rootfs + VM
```

`--print-debs` is Debian only. The build host stays Debian 13 or later; it needs
`wget`, `zstd`, `sha256sum` and `chroot`.

### How the rootfs is built

Following the Arch wiki page "Install Arch Linux from existing Linux":

1. Download `sha256sums.txt` and `archlinux-bootstrap-x86_64.tar.zst` from
   `$MIRROR_ARCH/iso/latest/` (`http://geo.mirror.pkgbuild.com`, plain http like
   the Debian mirror) and check the tarball's SHA256 (no gpg on the host, like
   the unsigned Debian Release).
2. Extract it into a throwaway `.arch-bootstrap.*` directory next to the
   target, set the mirror in its `mirrorlist`, and add `NoExtract` for docs,
   man/info pages and non-English locales to its `pacman.conf` (the
   counterpart of Debian's dpkg `path-exclude`). Its pacman runs without the
   download sandbox (`DisableSandbox`, no `DownloadUser`): pacman 7 sandboxes
   downloads with Landlock and the `alpm` user, and the Proxmox kernel has no
   Landlock ("restricting filesystem access failed because Landlock is not
   supported by the kernel").
3. Bind-mount the bootstrap root onto itself and the target onto its `/mnt`,
   then in `arch-chroot`: `pacman-key --init`, `pacman-key --populate archlinux`,
   `pacstrap -K /mnt base`. pacman checks package signatures; `-K` gives the
   target its own keyring.
4. Unmount (leftover processes below the bootstrap root are stopped first; the
   directory is only removed when nothing is mounted below it, so a failed
   unmount can never delete the target through the bind mount).
5. In the target: same mirrorlist and `NoExtract`, empty package cache and sync
   databases, then the same trimming as Debian (`rootfs_trim`: docs, man/info,
   non-English locales, empty `/usr/local` etc., `/etc/locale.conf`).
   The log is in `/var/log/bootstrap.log`.

Result: `base` (about 137 packages, ~440 MB).

### VM differences

Same disks, UKI and configuration as Debian. Package steps use pacman:
`pacman -Sy`, then `archlinux-keyring` and a full `-Su` (a rootfs bootstrapped
earlier would otherwise meet packager keys it does not know, "unknown trust",
and Arch does not support partial upgrades); a local `no-initramfs` package (built with `bsdtar`, `provides =
initramfs`) so `linux` pulls in neither mkinitcpio nor any other generator;
`linux qemu-guest-agent` (udev and systemd-resolved are part of systemd); for
the UKI `dracut systemd-ukify`, removed again with `pacman -Rns`. Downloads go
to a tmpfs over `/var/cache/pacman/pkg` so the 512 MiB root disk is not used.
The build runs pacman with a temporary `/etc/pacman-build.conf` (no sandbox,
see above); the image keeps the stock `pacman.conf`, whose sandbox works with
the VM's Arch kernel. The tests run with a seccomp profile
(`tests/nolandlock.json`) that makes Landlock unavailable, as on Proxmox.
The kernel comes from `/usr/lib/modules/<kver>/vmlinuz`. VM mode checks the
rootfs's `os-release` `ID` against `--distro`.

---

## VM mode

### Usage

Run as root on the Proxmox host (needs `qm`, `pvesm`, `pvesh`, `sgdisk`, `losetup`,
`mkfs.ext4`, `mkfs.vfat`, `blkid`):

```
sudo ./linux.sh [[rootfs-dir] <vmid> <name>]
```

The rootfs is the output of bootstrap mode; it defaults to `ROOTFS_DEFAULT`
(`/tmp/rootfs`) and is bootstrapped first when empty or missing. Without
arguments the VMID is the next free one and the name is `VM_NAME_DEFAULT`
(`debian`). Storage is `local-lvm` (set in `vm_main`). Root, required commands,
the VMID and the storage are checked before the bootstrap,
so a mistake does not cost a bootstrap run.

Environment overrides: `ESP_DISK_MB` (64), `ROOT_DISK_MB` (512), `USR_DISK_GB` (4), `MEMORY` (1024), `CORES` (2),
`BRIDGE` (vmbr0), `WORKDIR` (/var/tmp), `START` (1), `ROOT_PASSWORD`
(default `ROOT_PASSWORD_DEFAULT`, `root`; never asked),
`REPLACE_VM` (1: replace an existing VM with the same VMID without asking).

If the VMID already exists, the script shows its name and status and asks
whether to stop and delete it. Deletion (`qm stop`, `qm destroy --purge 1
--destroy-unreferenced-disks 1`) happens only after the new image is built, just
before `qm create`. Without a terminal it refuses unless `REPLACE_VM=1`.

VM mode re-executes itself in a private mount namespace (`unshare --mount
--propagation private`). On systemd hosts, mounts otherwise propagate into the
namespaces of services or timers started during the build; such a copy can
survive the `umount` and keep the image busy (`e2fsck: /dev/loopNp2 is in use`).
`qm start` runs through `nsenter` in PID 1's mount namespace so QEMU does not
inherit the private one. If unmounting or `e2fsck` still fails, `debug:` lines
show which mount namespaces still have the filesystem mounted, which processes
use the mount point, and the block-device holders.

Console: `qm terminal <vmid>` (serial, `console=ttyS0,115200` on the kernel line).

`/usr` is mounted read-only. To install or upgrade packages in the VM, run
`mount -o remount,rw /usr` first (and `mount -o remount,ro /usr` afterwards).

On failure the work directory under `WORKDIR` is kept and its path is printed.

### What the script does

1. Re-runs itself in a private mount namespace. Checks: root, required
   commands, VMID (asks before replacing), storage (`pvesm status`);
   bootstraps the rootfs if needed; then rootfs shape and size.
2. Creates three sparse raw disks, each GPT with one partition: ESP
   (`ESP_DISK_MB`, 64 MiB, FAT32), root (`ROOT_DISK_MB`, 512 MiB, ext4 `/`, type
   "Linux x86-64 root") and `/usr` (`USR_DISK_GB`, 4 GiB, ext4, type "Linux x86-64
   /usr"). `/usr` and `/efi` are mounted before the copy, so their files land
   on their own disks; fstab lists them and the initramfs (dracut `usrmount`)
   mounts `/usr` before switching to the real root. The root filesystem label is
   `root` (the UKI command line uses `root=LABEL=root`).
3. Copies the rootfs in, mounts proc, rbind-mounts sys/dev as rslave (so the
   later `umount -R` cannot propagate to the host's /dev/pts, /sys/fs/cgroup...),
   mounts the ESP at /efi.
4. In the chroot:
   - `apt-get update` with normal signature checks (no overrides).
   - Installs `perl-base init-system-helpers` (temporarily, see caveats).
   - Installs a local `no-initramfs-tool` package (Provides `linux-initramfs-tool`)
     so the kernel pulls in no initramfs generator and no hook builds an initrd.
   - Installs `linux-image-cloud-amd64 qemu-guest-agent systemd-resolved`.
5. Writes fstab (UUIDs of root, `/usr` read-only, and ESP at `/efi`), hostname, hosts,
   systemd-networkd DHCP on `en* eth*`, enables networkd and resolved, sets the
   root password.
6. Builds the unified kernel image last (copy of `bin/uki.sh` and
   `bin/uki-dracut.sh`): installs `dracut-core dracut-network systemd-ukify
   systemd-boot-efi`, runs `dracut --no-hostonly` directly with the module list
   `usrmount kernel-modules-export bash rootfs-block kernel-modules qemu qemu-net
   virtfs virtiofs shutdown overlayfs` and `--drivers virtio-balloon`, then
   `ukify build` with the kernel, that initrd and the command line (`root=LABEL=root
   ro rd.driver.pre=...` plus the serial console) to `/efi/EFI/BOOT/BOOTX64.EFI`.
   The tools and their dependencies (python3, iproute2, ...) are purged again.
   No GRUB; `/boot` only keeps the kernel package files.
7. Purges `perl-base init-system-helpers` (`--force-depends
   --force-remove-essential`), points `/etc/resolv.conf` at the resolved stub,
   empties `machine-id`, cleans apt.
8. Stops processes still running inside the image, unmounts, runs `e2fsck`,
   detaches the loop device, deletes the old VM if it is being replaced, then
   `qm create` (q35, OVMF, virtio-scsi,
   agent, tablet off, onboot, serial socket, no tags), `qm set --efidisk0`
   (efitype=4m, pre-enrolled-keys=0), `qm importdisk` (raw) for each disk, reading
   the new `unusedN` volume from `qm config`: ESP as `scsi0`, root as `scsi1`,
   `/usr` as `scsi2`, `--boot order=scsi0`,
   and `qm start` if `START=1`.

### Tests

`tests/run.sh quick` (~2 min) or `tests/run.sh full [debian|arch|all]` (~10 min
per distribution, default all) runs the suite in a privileged Debian forky
container with stub `qm`/`pvesm`/`pvesh`: error paths (including `--distro`),
`--print-debs`, unit tests; then per distribution a bootstrap + VM build with
only `--distro`, rootfs and image checks (dpkg/apt or pacman specific parts)
and a QEMU/OVMF boot of the image (KVM when available); finally the unmount
tests in a systemd-like mount namespace, once. Logs and a line coverage report go to
`/tmp/linux-sh-tests`.

### Decisions (in order)

1. **UEFI, not BIOS.** Matches the reference (q35 + OVMF + efidisk).
2. **Unified kernel image at the removable path** (`\EFI\BOOT\BOOTX64.EFI`), no
   GRUB and no NVRAM entry. It replaced GRUB when the initramfs moved to a direct
   dracut call (copy of the repo's `bin/uki*.sh`).
3. **Kernel: `linux-image-cloud-amd64`** (asked for explicitly).
4. **initramfs: dracut, called directly, last.** Not installed as the kernel's
   initramfs tool; `--no-hostonly` makes the initrd generic (virtio drivers for any
   VM). dracut and ukify are removed again after the build.
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
- The VM image verifies the archive with the `Signed-By` keyring; the QEMU
  boot test runs `apt-get update` and checks for warnings and the modernize notice.
- The imported volume is read from `qm config` (`unusedN:`); if none is found the
  script fails with a clear message.
- `qm` options (`--machine`, `--bios`, `--efidisk0`, `--cpu host`) are untested on a
  real host. Only a stub `qm` was used.
- Test host detail: the partition nodes (`/dev/loopNp1`, `p2`) only appear when the
  host's `/dev` is visible (udev). The test container uses `-v /dev:/dev`, which
  matches a real Proxmox host.
- The script refuses sizes without headroom: the root disk needs 320 MiB free
  beyond the rootfs without `/usr` (kernel, initrd and apt lists during the
  build), the `/usr` disk 1 GiB beyond `/usr`.

---

## Status

- **Bootstrap, last full test (2026-10-24):** rc=0, no W:/E:, **83 packages**, all
  "install ok installed", `apt-get check` passes, `su` works, no `/usr/bin/perl`,
  no man/info/`usr/share/doc`, both apt/dpkg config files present. Not installed:
  dash, mawk, tzdata, udev. Purged at the end: perl-base, init-system-helpers.
- **`linux.sh` (combined), 2026-10-25:** `bash -n` passes. A fresh bootstrap build
  through the combined script returned rc=0 with the same results. Mode routing was
  checked with a fake `qm`: no `qm` runs bootstrap, `qm` present runs VM, and
  `SCRIPT_MODE` overrides it. An invalid `SCRIPT_MODE` is rejected.
- **VM mode, earlier build:** passed before the last three changes (signed apt,
  no-recommends file, cloud kernel + explicit dracut). The UEFI build completed, GRUB
  installed, and the image booted under QEMU (TCG, OVMF) to `testvm login:`.
- **VM mode, current build: not run.** The VM build has not been run through
  `linux.sh` on the current rootfs.
- **Not tested at all:** a real `qm`/`pvesm` on Proxmox; `apt-get update` inside the
  VM after boot.
- The old `scratchpad/vmtest/inner.sh` QEMU driver lived in a session scratchpad that
  is no longer available. Its boot check is described below.

## How it was tested

```
# rootfs (bootstrap mode, in a privileged container)
docker run --rm --privileged -v "$PWD":/w debian:trixie bash -c '
  apt-get update -qq && apt-get install -y -qq wget
  LANG=C /w/linux.sh /tmp/mine
  chroot /tmp/mine dpkg-query -W -f="\${Status}\n" | sort | uniq -c
  chroot /tmp/mine apt-get check'
```
(The user is in the `docker` group; sudo needs a password.)

VM mode is tested with a stub `qm`/`pvesm` on PATH, which copies the image on
`qm importdisk`, then a QEMU boot with `OVMF_CODE_4M.fd`. Look for `testvm login:`
in the boot log. The container needs `-v /dev:/dev` so the loop partition nodes appear.

## Resume checklist

1. Run the VM mode on a current rootfs: `linux.sh` with a stub `qm` and `pvesm`,
   then QEMU boot.
2. Confirm: cloud kernel installed, initrd contains virtio drivers (`lsinitrd`),
   boot reaches login, `apt-get check` passes.
3. If a container is stuck, `docker ps` and stop it (`docker kill <id>`).
4. Open decision: remove the rest of `/usr/share/doc` from the tar-extracted required
   set (done only for the paths above). Confirm with the user first.
5. Next steps: decide on cloud-init or an SSH key option, and run on a real Proxmox host.
