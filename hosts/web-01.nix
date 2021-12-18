{ config, lib, pkgs, ... }: {
  config = {
    environment.systemPackages = [
      pkgs.jq
      pkgs.vim
      pkgs.tmux
      pkgs.rsync
    ];
  };
}
