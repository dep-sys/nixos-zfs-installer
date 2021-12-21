{ pkgs, lib, ... }: {
  config = {
    nix = {
      package = pkgs.nix_2_4;
      extraOptions = "experimental-features = nix-command flakes";
      gc = {
        automatic = true;
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
    };
  };
}
