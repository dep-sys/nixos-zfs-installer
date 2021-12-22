{
  description = "An optionated nixos installer";
  inputs.nixpkgs.url = "nixpkgs/nixos-21.11";
  inputs.colmena.url = "github:zhaofengli/colmena";
  inputs.colmena.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, colmena }@inputs:
    let
      # System types to support.
      system = "x86_64-linux";
      # Nixpkgs instantiated for supported system types.
      nixpkgsForSystem = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
    in
    {

      overlay = final: prev: {
        kexec = prev.callPackage ./installer/kexec.nix {
          inherit nixpkgs system;
          installerFlake = self;
        };
      };

      nixosModules = {
        core = import ./modules/core.nix;
        ssh = import ./modules/ssh.nix;
        zfs = import ./modules/zfs.nix;
        hetzner = import ./modules/hetzner.nix;
        nix = import ./modules/nix.nix;
      };


      lib =
        (import ./colmena.nix { lib = nixpkgs.lib; }) // {

        gatherHostModules = { runtimeInfo, profile }:
          with self.nixosModules; [
            core
            ssh
            nix
            zfs
            hetzner
            ({ pkgs, lib, ... }:
              {
                config =
                  {
                    nix = {
                      registry.installer.flake = self;
                      nixPath = [ "nixpkgs=${nixpkgs}" ];
                      registry.nixpkgs.flake = nixpkgs;
                    };
                    nixpkgs.overlays = [ self.overlay ];

                    runtimeInfo = runtimeInfo;
                  };
              })
            profile
          ];

        makeNixosSystem = { runtimeInfo, profile ? {} }:
          nixpkgs.lib.nixosSystem {
            inherit system;
            modules = self.lib.gatherHostModules { inherit profile runtimeInfo; };
          };

      };

      packages.${system} =
        {
          inherit (nixpkgsForSystem) kexec;
        };
      defaultPackage.${system} = self.packages.${system}.kexec;


      colmena = {
        meta = {
          nixpkgs = nixpkgsForSystem;
        };
      }
      // (self.lib.makeColmenaHosts (host: {
        imports = self.lib.gatherHostModules (self.lib.makeColmenaHost host);
      }));
      apps.${system}.colmena = colmena.defaultApp.${system};


    };
}
