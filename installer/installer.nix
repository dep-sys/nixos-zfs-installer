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
  writeRuntimeInfoScript = pkgs.writeScript "write-runtime-info" (builtins.readFile ./scripts/write-runtime-info.sh);
  runInstallerScript = pkgs.writeScript "run-installer"
    (builtins.readFile (pkgs.substituteAll {
      src = ./scripts/run-installer.sh;
      kernelParams = "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}";
    }));
in pkgs.linkFarm "kexec-installer" [
  { name = "initrd.gz"; path = "${config.system.build.netbootRamdisk}/initrd"; }
  { name = "bzImage";   path = "${config.system.build.kernel}/bzImage"; }
  { name = "run-installer"; path = runInstallerScript; }
  { name = "write-runtime-info"; path = writeRuntimeInfoScript; }
]
