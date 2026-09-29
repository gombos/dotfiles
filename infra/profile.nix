let
  pkgs = import <nixpkgs> { config.allowUnfree = true; };
in
pkgs.buildEnv {
  name = "my-profile";
  paths = with pkgs; [
    git
    docker
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
}
