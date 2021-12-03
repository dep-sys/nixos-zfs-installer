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
  writeRuntimeInfoScript = pkgs.writeScript "write-runtime-info" (builtins.readFile ./write-runtime-info.sh);
  runInstallerScript = pkgs.writeScript "run-installer" ''
    #!/usr/bin/env bash
    set -euxo pipefail

    TO_INSTALL=""
    command -v kexec || TO_INSTALL="kexec-tools $TO_INSTALL"
    command -v jq || TO_INSTALL="jq $TO_INSTALL"
    command -v ethtool || TO_INSTALL="ethtool $TO_INSTALL"

    test -n "$TO_INSTALL" && apt update -y && apt install -y $TO_INSTALL

    ./write-runtime-info > runtime-info.json

    echo "Gathered the following configuration parameters from existing linux"
    jq . runtime-info.json

    # We base64 encode the runtime data and pass it via linux kernel parameter
    # to our nixos kexec environment to configure our flake there.
    RUNTIME_KERNEL_PARAMETER="$(jq -c . runtime-info.json | base64 -w0)"

    # Adapted from https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97
    kexec --load ./bzImage \
      --initrd=./initrd.gz \
      --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} runtime_info=\"$RUNTIME_KERNEL_PARAMETER\""
    if systemctl --version >/dev/null 2>&1; then
      systemctl kexec
    else
      kexec -e
    fi
    '';
in pkgs.linkFarm "kexec-installer" [
  { name = "initrd.gz"; path = "${build.netbootRamdisk}/initrd"; }
  { name = "bzImage";   path = "${build.kernel}/bzImage"; }
  { name = "run-installer"; path = runInstallerScript; }
  { name = "write-runtime-info"; path = writeRuntimeInfoScript; }
]
