{ pkgs, lib, ... }: {
  config = {
    nix = {
      nixPath = [ "nixpkgs=${nixpkgs}" ];
      registry.nixpkgs.flake = nixpkgs;
      registry.installer.flake = self;

      package = pkgs.nixUnstable;
      extraOptions = "experimental-features = nix-command flakes";
      gc = {
        automatic = true;
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
    };

    nixpkgs.overlays = [ self.overlay ];
  };
}
