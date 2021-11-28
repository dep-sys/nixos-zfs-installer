{
  description = "An optionated nixos installer";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }@inputs:
    let

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 self.lastModifiedDate;

      # System types to support.
      system = "x86_64-linux";

      # Nixpkgs instantiated for supported system types.
      nixpkgsForSystem = import nixpkgs { inherit system; overlays = [ self.overlay ]; };

      rootSSHKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLopgIL2JS/XtosC8K+qQ1ZwkOe1gFi8w2i1cd13UehWwkxeguU6r26VpcGn8gfh6lVbxf22Z9T2Le8loYAhxANaPghvAOqYQH/PJPRztdimhkj2h7SNjP1/cuwlQYuxr/zEy43j0kK0flieKWirzQwH4kNXWrscHgerHOMVuQtTJ4Ryq4GIIxSg17VVTA89tcywGCL+3Nk4URe5x92fb8T2ZEk8T9p1eSUL+E72m7W7vjExpx1PLHgfSUYIkSGBr8bSWf3O1PW6EuOgwBGidOME4Y7xNgWxSB/vgyHx3/3q5ThH0b8Gb3qsWdN22ZILRAeui2VhtdUZeuf2JYYh8L phaer-yubikey"
      ];

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        kexec = prev.callPackage ./pkgs/installer.nix {
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
        nix = { pkgs, lib, ... }: {
          nix = {
            nixPath = [ "nixpkgs=${nixpkgs}" ];
            # Let 'nixos-version --json' know the Git revision of this flake.
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
        };


        ssh = { pkgs, lib, ... }: {
          users.users.root.openssh.authorizedKeys.keys = rootSSHKeys;
          services.openssh = {
            enable = true;
            passwordAuthentication = lib.mkForce false;
            permitRootLogin = lib.mkForce "without-password";
          };
        };

        zfs = { pkgs, lib, ... }: {
          boot.loader.grub.enable = true;
          boot.loader.grub.version = 2;
          boot.loader.grub.efiSupport = true;
          boot.loader.grub.devices = [ "nodev" ];
          boot.supportedFilesystems = [ "zfs" ];
          # TODO is somewhat dangerous, check if needed
          boot.loader.efi.canTouchEfiVariables = true;

          fileSystems."/" =
            { device = "rpool/local/root";
              fsType = "zfs";
            };

          fileSystems."/boot" =
            { # device = "/dev/disk/by-uuid/722A-9958";
              fsType = "vfat";
            };

          fileSystems."/nix" =
            { device = "rpool/local/nix";
              fsType = "zfs";
            };

          fileSystems."/home" =
            { device = "rpool/safe/home";
              fsType = "zfs";
            };

          fileSystems."/persist" =
            { device = "rpool/safe/persist";
              fsType = "zfs";
            };
          swapDevices = [ ];
        };


        installationEnvironment =
          { pkgs, lib, ... }:
          {
            imports = with self.nixosModules; [
              ssh
              nix
            ];

           networking = {
              firewall.allowedTCPPorts = [ 22 ];
              usePredictableInterfaceNames = true;
              useDHCP = true;
            };

            environment.systemPackages = [
              # TODO: temporary
              (pkgs.writeScriptBin "nuke-disks" (builtins.readFile ./pkgs/nuke-disk.sh))
            ];

         };
      };

      nixosConfigurations = {
        base = nixpkgs.lib.nixosSystem {
              inherit system;
              modules = with self.nixosModules; [
                ssh
                zfs
                ({ pkgs, lib, ... }: {
                  nixpkgs.overlays = [ self.overlay ];
                  i18n.defaultLocale = "en_US.UTF-8";
                  time.timeZone = "UTC";
                  networking = {
                    firewall.allowedTCPPorts = [ 22 ];
                    usePredictableInterfaceNames = true;
                    useDHCP = true;
                  };
                })
              ];
            };
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
