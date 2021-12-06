{
  description = "An optionated nixos installer";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-21.11";

  outputs = { self, nixpkgs }@inputs:
    let
      # System types to support.
      system = "x86_64-linux";

      # Nixpkgs instantiated for supported system types.
      nixpkgsForSystem = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
    in
    {

      # A Nixpkgs overlay.
      overlay = final: prev: {
        kexec = prev.callPackage ./installer/installer.nix {
          inherit nixpkgs system;
          inherit (self.nixosModules) installationEnvironment;
        };
      };

      # Provide some binary packages for selected system types.
      packages.${system} =
        {
          inherit (nixpkgsForSystem) hello kexec;
        };

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage.${system} = self.packages.${system}.hello;

      # A NixOS module, if applicable (e.g. if the package provides a system service).
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

                  systemd.services.writeAuthorizedKeys = {
                    wants = [ "run-keys.mount" ];
                    wantedBy = [ "sshd.target" ];
                    description = "Read SSH authorized keys from kernel cmdline and write them for SSHD";
                    serviceConfig.Type = "oneshot";
                    script = ''
                    if [ ! -f /var/run/keys/root-authorized-keys ]; then
                      # Write authorized key for root user in final system
                      ${readRuntimeInfoScript} | jq -r '.rootAuthorizedKeys[]' > /var/run/keys/root-authorized-keys
                      chown root:root /var/run/keys/root-authorized-keys
                      chmod 0600 /var/run/keys/root-authorized-keys
                    fi
                    '';
                  };
                  environment.systemPackages = [
                    pkgs.jq
                    pkgs.ethtool
                    readRuntimeInfoScript
                    nukeDiskScript
                    doInstallScript
                  ];
                };
          };
      };

      lib.makeSystem = flake: runtimeInfo:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = with self.nixosModules; [
            core
            ssh
            nix
            zfs
            hetzner
            ({ pkgs, lib, ... }: {
              runtimeInfo = builtins.trace runtimeInfo runtimeInfo;
              nix.registry.installed.flake = flake;
            })
          ];
        };


      # # Tests run by 'nix flake check' and by Hydra.
      # checks = forAllSystems
      #   (system:
      #     with nixpkgsFor.${system};

      #     {
      #       inherit (self.packages.${system}) hello;

      #       # Additional tests, if applicable.
      #       test = stdenv.mkDerivation {
      #         name = "hello-test-${version}";

      #         buildInputs = [ hello ];

      #         unpackPhase = "true";

      #         buildPhase = ''
      #           echo 'running some integration tests'
      #           [[ $(hello) = 'Hello Nixers!' ]]
      #         '';

      #         installPhase = "mkdir -p $out";
      #       };
      #     }

      #     // lib.optionalAttrs stdenv.isLinux {
      #       # A VM test of the NixOS module.
      #       vmTest =
      #         with import (nixpkgs + "/nixos/lib/testing-python.nix") {
      #           inherit system;
      #         };

      #         makeTest {
      #           nodes = {
      #             client = { ... }: {
      #               imports = [ self.nixosModules.hello ];
      #             };
      #           };

      #           testScript =
      #             ''
      #               start_all()
      #               client.wait_for_unit("multi-user.target")
      #               client.succeed("hello")
      #             '';
      #         };
      #     }
      #   );

    };
}
