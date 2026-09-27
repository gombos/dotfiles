# bin/nix/shell.nix
{ pkgs ? import <nixpkgs> {} }:

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
  ];

  shellHook = ''
    echo "Welcome to the Nix development environment!"
  '';

  # Forces Nix to install the man outputs for packages listed above
  extraOutputsToInstall = [ "man" ];
}
