# bin/nix/shell.nix
{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    docker
    python3
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
    export GOPATH="$HOME/go"
    export PATH="$GOPATH/bin:$PATH"

    go install github.com/4ier/notion-cli@latest

    echo "Nix environment!"
  '';

  # Forces Nix to install the man outputs for packages listed above
  extraOutputsToInstall = [ "man" ];
}
