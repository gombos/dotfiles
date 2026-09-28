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
    gocryptfs
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
    pkg-config
    go
  ];

  shellHook = ''
    export VIRTUAL_ENV=/home/venv
    export VIRTUAL_ENV_DISABLE_PROMPT=1
    go install github.com/4ier/notion-cli@latest
    if [ -e /home/venv/bin/activate ]; then
      source /home/venv/bin/activate;
    fi
    export PATH="$HOME/go/bin:$PATH"
  '';

  # Forces Nix to install the man outputs for packages listed above
  extraOutputsToInstall = [ "man" ];
}
