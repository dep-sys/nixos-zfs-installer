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
        kexec = prev.callPackage ./installer/installer.nix {
          inherit nixpkgs system;
          inherit (self.nixosModules) installationEnvironment;
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
      // self.lib.makeColmenaHosts (host: {
        imports = self.lib.gatherHostModules (self.lib.makeColmenaHost host);
      });

      nixosModules = {
        core = import ./modules/core.nix;
        ssh = import ./modules/ssh.nix;
        zfs = import ./modules/zfs.nix;
        hetzner = import ./modules/hetzner.nix;
        nix = { pkgs, lib, ... }: {
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
        };

        installationEnvironment =
          { pkgs, lib, ... }:
          {
            imports = with self.nixosModules; [
              core
              ssh
              nix
            ];

            config =
              let
                readRuntimeInfoScript = pkgs.writeScriptBin "read-runtime-info"  (builtins.readFile ./installer/scripts/read-runtime-info.sh);
                readDiskKeyScript = pkgs.writeScriptBin "read-disk-key"  (builtins.readFile ./installer/scripts/read-disk-key.sh);
                nukeDiskScript = pkgs.writeScriptBin "nuke-disk" (builtins.readFile ./installer/scripts/nuke-disk.sh);
                doInstallScript =
                  pkgs.writeScriptBin "do-install"
                    (builtins.readFile (pkgs.substituteAll {
                      src = ./installer/scripts/do-install.sh;
                      flakePath = self.outPath;
                    }));
              in
                {
                  networking = {
                    firewall.allowedTCPPorts = [ 22 ];
                    usePredictableInterfaceNames = true;
                    useDHCP = true;
                  };

                  systemd.services.write-authorized-keys = {
                    enable = true;
                    wants = [ "run-keys.mount" ];
                    wantedBy = [ "sshd.service" ];
                    description = "Read SSH authorized keys from kernel cmdline and write them for SSHD";
                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = "yes";
                    };
                    script = ''
                    if [ ! -f /var/run/keys/root-authorized-keys ]; then
                      # Write authorized key for root user in final system
                      PATH=${readRuntimeInfoScript}/bin:${pkgs.jq}/bin:${pkgs.gawk}/bin:$PATH
                      read-runtime-info \
                      | jq -r '.rootAuthorizedKeys[]' \
                      > /var/run/keys/root-authorized-keys
                      chown root:root /var/run/keys/root-authorized-keys
                      chmod 0600 /var/run/keys/root-authorized-keys
                    fi
                    '';
                  };
                  environment.systemPackages = [
                    pkgs.jq
                    pkgs.ethtool
                    readRuntimeInfoScript
                    readDiskKeyScript
                    nukeDiskScript
                    doInstallScript
                  ];
                };
          };
      };

      apps.${system}.colmena = colmena.defaultApp.${system};

      lib.gatherHostModules = { runtimeInfo, profile }:
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
                  runtimeInfo = runtimeInfo;
                };
            })
          profile
        ];

      lib.attrsFromFiles = dir: suffix: callback:
        with nixpkgs;
        lib.pipe
          (builtins.readDir dir)
          [
            (entry: lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix suffix n) entry)
            lib.attrNames
            (map (name:
              lib.nameValuePair
                (lib.strings.removeSuffix suffix name)
                (callback (dir + "/${name}"))))
            builtins.listToAttrs
          ];

      lib.loadHostsJSON = self.lib.attrsFromFiles
        ./hosts
        ".json"
        (filename: builtins.fromJSON (builtins.readFile filename));

      lib.loadHostsNix = self.lib.attrsFromFiles
        ./hosts
        ".nix"
        (filename: import filename);

      lib.makeColmenaHost = { runtimeInfo, profile }:
        {
          inherit runtimeInfo;
          profile.imports = [
            {
              deployment.targetHost = runtimeInfo.ipv6.address;
              deployment.tags = [ "hcloud" "env-test" ];
            }
            profile
          ];
        };

      lib.makeColmenaHosts = callback:
        with nixpkgs;
        let
          profiles = self.lib.loadHostsNix;
        in
        lib.mapAttrs (host: runtimeInfo:
          callback {
            inherit runtimeInfo;
            profile = (builtins.trace profiles (profiles.${host}));
          }
        ) self.lib.loadHostsJSON;

      lib.makeNixosSystem = { runtimeInfo, profile ? {} }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = self.lib.gatherHostModules { inherit profile runtimeInfo; };
        };
    };
}
