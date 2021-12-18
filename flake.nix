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
      // self.lib.makeColmenaHosts;

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

      lib.attrsFromFiles = dir: suffix: callback:
        with nixpkgs.lib;
        pipe
          (builtins.readDir dir)
          [
            (entry: filterAttrs (n: v: v == "regular" && hasSuffix suffix n) entry)
            attrNames
            (map (name:
              nameValuePair
                (strings.removeSuffix suffix name)
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

      lib.gatherHostModules = { profile, runtimeInfo }:
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
                  runtimeInfo = builtins.trace runtimeInfo runtimeInfo;
                };
            })
          profile
        ];

      lib.makeColmenaHost = { runtimeInfo, profile ? {} }:
        {
          imports = self.lib.gatherHostModules {
            inherit runtimeInfo;
            profile.imports = [
                {
                  deployment.targetHost = runtimeInfo.ipv6.address;
                  deployment.tags = [ "hcloud" "env-test" ];
                }
                profile
              ];
          };
        };

      lib.makeColmenaHosts =
        with nixpkgs;
        let
          profiles = self.lib.loadHostsNix;
        in
        lib.mapAttrs (host: runtimeInfo:
          self.lib.makeColmenaHost { inherit runtimeInfo; profile = (builtins.trace profiles (profiles.${host} or {})); }
        ) self.lib.loadHostsJSON;

      lib.makeNixosSystem = { profile ? {}, runtimeInfo }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = self.lib.gatherHostModules { inherit profile runtimeInfo; };
        };
    };
}
