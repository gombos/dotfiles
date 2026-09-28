# bin/nix/shell.nix
{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    docker
    python3
    python3Packages.pip
    python3Packages.virtualenv
    uv
    awscli
    gh
    man
    coreutils
    claude-code
    bash
    findutils
    fio
    iperf
    jq
    micro
    pass
    podman
    rclone
    ripgrep-all
    rmlint
    rsync
    wget
    openssh
    go
    pkg-config
  ];

  shellHook = ''
    export VIRTUAL_ENV=/home/venv
    export VIRTUAL_ENV_DISABLE_PROMPT=1
    export PIP_PREFIX="$(pwd)/.venv/pip_packages"
    export PATH="$PIP_PREFIX/bin:$PATH"
    export GOPATH="$HOME/go"
    export PATH="$GOPATH/bin:$PATH"
    if [ -e /home/venv/bin/activate ]; then
      source /home/venv/bin/activate;
    fi
    go install github.com/4ier/notion-cli@latest
  '';

  # Forces Nix to install the man outputs for packages listed above
  extraOutputsToInstall = [ "man" ];
}
