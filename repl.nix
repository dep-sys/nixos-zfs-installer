let
  flake = builtins.getFlake(toString ./.);
  pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; };
  lib = flake.inputs.nixpkgs.lib;
in
{ inherit flake pkgs lib;
}
