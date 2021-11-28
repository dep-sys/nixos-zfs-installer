{
  pkgs, lib, stdenv, nixpkgs, system, installationEnvironment
}:
let
  config = (import "${nixpkgs}/nixos" {
    inherit system;
    configuration = {
      imports = [
        "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
        installationEnvironment
      ];
    };
  }).config;
  inherit (config.system) build;
  # Adapted from https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97
  kexecScript = pkgs.writeScript "kexec-installer" ''
    #!/bin/sh
    if ! kexec -v >/dev/null 2>&1; then
      echo "kexec not found: please install kexec-tools" 2>&1
# apt update -y && apt install -y kexec-tools
      exit 1
    fi
    kexec --load ./bzImage \
      --initrd=./initrd.gz \
      --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
    if systemctl --version >/dev/null 2>&1; then
      systemctl kexec
    else
      kexec -e
    fi
  '';
in pkgs.linkFarm "kexec-installer" [
  { name = "initrd.gz"; path = "${build.netbootRamdisk}/initrd"; }
  { name = "bzImage";   path = "${build.kernel}/bzImage"; }
  { name = "kexec-installer"; path = kexecScript; }
]
