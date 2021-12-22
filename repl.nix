let
  flake = builtins.getFlake(toString ./.);
  nixpkgs = flake.inputs.nixpkgs;
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  system = "x86_64-linux";
  lib = flake.inputs.nixpkgs.lib;
in { inherit flake nixpkgs pkgs lib; }
