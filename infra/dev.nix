# bin/nix/shell.nix
{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

pkgs.mkShell {
  buildInputs = [
    pkgs.git
    pkgs.docker
    pkgs.python3
    pkgs.uv
    pkgs.awscli
    pkgs.gh
    pkgs.man
    pkgs.coreutils
    pkgs.claude-code
    pkgs.bash
    pkgs.findutils
    pkgs.fio
    pkgs.iperf
    pkgs.jq
    pkgs.micro
    pkgs.pass
    pkgs.podman
    pkgs.rclone
    pkgs.ripgrep-all
    pkgs.rmlint
    pkgs.rsync
    pkgs.wget
  ];

  shellHook = ''
    echo "Welcome to the Nix development environment!"
  '';

  # Forces Nix to install the man outputs for packages listed above
  extraOutputsToInstall = [ "man" ];
}
