FROM debian:forky
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
	util-linux e2fsprogs dosfstools gdisk gawk wget ca-certificates xz-utils zstd binutils dracut-core \
	shellcheck qemu-system-x86 ovmf expect >/dev/null && apt-get clean
