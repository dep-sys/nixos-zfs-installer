let
  flake = builtins.getFlake(toString ./.);
  nixpkgs = flake.inputs.nixpkgs;
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  system = "x86_64-linux";
  lib = flake.inputs.nixpkgs.lib;
  installationEnvironment = flake.outputs.nixosModules.installationEnvironment;
  config = (import "${nixpkgs}/nixos" {
    inherit system;
    configuration = {
      imports = [
        "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
        installationEnvironment
      ];
    };
  }).config;
in
{ inherit flake nixpkgs pkgs lib config;
}
