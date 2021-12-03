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

      sshRootKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLopgIL2JS/XtosC8K+qQ1ZwkOe1gFi8w2i1cd13UehWwkxeguU6r26VpcGn8gfh6lVbxf22Z9T2Le8loYAhxANaPghvAOqYQH/PJPRztdimhkj2h7SNjP1/cuwlQYuxr/zEy43j0kK0flieKWirzQwH4kNXWrscHgerHOMVuQtTJ4Ryq4GIIxSg17VVTA89tcywGCL+3Nk4URe5x92fb8T2ZEk8T9p1eSUL+E72m7W7vjExpx1PLHgfSUYIkSGBr8bSWf3O1PW6EuOgwBGidOME4Y7xNgWxSB/vgyHx3/3q5ThH0b8Gb3qsWdN22ZILRAeui2VhtdUZeuf2JYYh8L phaer-yubikey"
      ];

      sshInitrdHostKey = ''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDYZao32W32dDPFFmJ2N5TIv0CHs3H43i8YgbXGYcBCswAAAJhxDCK/cQwi
vwAAAAtzc2gtZWQyNTUxOQAAACDYZao32W32dDPFFmJ2N5TIv0CHs3H43i8YgbXGYcBCsw
AAAEDROyjqG0s5Gh/nIovEI8P0qZwDgdmtBtdj6CBZld36bthlqjfZbfZ0M8UWYnY3lMi/
QIezcfjeLxiBtcZhwEKzAAAAE3Jvb3RAaW5zdGFsbGVyLXRlc3QBAg==
-----END OPENSSH PRIVATE KEY-----
     '';

      # disk to NUKE EVERYTHING on, before installing Nixos
      diskToFormat = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0";

      hostName = "test-installation";
      # unique host identifier. Should be dynamic, e.g. /etc/machine-id contents.
      # how to nixos-install flake with runtime parameter?
      hostId = "12345678";

      # See <https://major.io/2015/08/21/understanding-systemds-predictable-network-device-names/#picking-the-final-name>
      # for a description on how to find out the network card name reliably.
      networkInterface = "ens3";
      # This was derived from `sudo lshw -C network`, for me it says `driver=igb`.
      # Needed to load the right driver before boot for the initrd SSH session.
      networkInterfaceModule = "virtio-pci";
      # From the Hetzner control panel
      ipv4 = {
        address = "116.203.101.184"; # the ip address
        gateway = "172.31.1.1"; # the gateway ip address
        netmask = "255.255.255.255";
        prefixLength = 32;
      };
      ipv6 = {
        address = "2a01:4f8:c2c:c058::1"; # the ipv6 addres
        gateway = "fe80::1"; # the ipv6 gateway
        prefixLength = 64; # shown in the control panel
      };
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
          users.users.root.openssh.authorizedKeys.keys = sshRootKeys;
          services.openssh = {
            enable = true;
            passwordAuthentication = lib.mkForce false;
            permitRootLogin = lib.mkForce "without-password";
          };
        };

        zfs = { pkgs, lib, ... }: {
          boot.loader.grub.enable = true;
          boot.loader.grub.version = 2;
          boot.loader.grub.efiSupport = false;
          boot.loader.grub.devices = [ diskToFormat ];
          boot.supportedFilesystems = [ "zfs" ];
          boot.zfs.requestEncryptionCredentials = true;
          boot.zfs.devNodes = "/dev/disk/by-partuuid";

          boot.initrd.network = {
            enable = true;
            ssh = {
              enable = true;
              # To prevent ssh clients from freaking out because a different host key is used,
              # a different port for ssh is useful (assuming the same host has also a regular sshd running)
              port = 2222;
              # hostKeys paths must be unquoted strings, otherwise you'll run into issues
              # with boot.initrd.secrets the keys are copied to initrd from the path specified;
              # multiple keys can be set you can generate any number of host keys using
              # `ssh-keygen -t ed25519 -N "" -f /boot-1/initrd-ssh-key`
              hostKeys = [ (pkgs.writeText "ssh-initrd-host-key" sshInitrdHostKey) ];
              # public ssh key used for login
              authorizedKeys = sshRootKeys;
            };
            # this will automatically load the zfs password prompt on login
            # and kill the other prompt so boot can continue
            postCommands = ''
              cat <<EOF > /root/.profile
              if pgrep -x "zfs" > /dev/null
              then
                zfs load-key -a
                killall zfs
              else
                echo "zfs not running -- maybe the pool is taking some time to load for some unforseen reason."
              fi
              EOF
            '';
          };

          fileSystems."/" =
            { device = "rpool/local/root";
              fsType = "zfs";
            };

          fileSystems."/boot" =
            {
              device = "${diskToFormat}-part3";
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

        hetzner =
          { pkgs, lib, modulesPath, ... }:
          {
            imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

            boot.initrd.availableKernelModules = [ "virtio_net" "ata_piix" "virtio_pci" "virtio_scsi" "xhci_pci" "sd_mod" "sr_mod" ];
            boot.kernelParams = [
              # See <https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt> for docs on this
              # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>
              # The server ip refers to the NFS server -- we don't need it.
              "ip=${ipv4.address}::${ipv4.gateway}:${ipv4.netmask}:${hostName}-initrd:${networkInterface}:off:8.8.8.8"
            ];

            networking.hostName = hostName;
            networking.useDHCP = false;
            networking.interfaces.${networkInterface} = {
              useDHCP = false;
              ipv4 = { addresses = [{ address = ipv4.address; prefixLength = ipv4.prefixLength; }]; };
              ipv6 = { addresses = [{ address = ipv6.address; prefixLength = ipv6.prefixLength; }]; };
            };
            networking.defaultGateway = ipv4.gateway;
            networking.defaultGateway6 = { address = ipv6.gateway; interface = networkInterface; };
            networking.nameservers = [ "8.8.8.8" ];
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
              (let
                nukeDisk = (pkgs.writeScript "nuke-disk" (builtins.readFile ./pkgs/nuke-disk.sh));
              in
              (pkgs.writeScriptBin "install-flake" ''
              #!/usr/bin/env bash
              set -euxo pipefail

              KEYFILE=$(mktemp)
              echo "testtest" > $KEYFILE
              ${nukeDisk} "${diskToFormat}" "$KEYFILE"

              TMPDIR=/tmp nixos-install \
              --no-channel-copy \
              --root /mnt \
              --no-root-passwd \
              --flake ${self}#base

              umount /mnt/{boot,nix,home,persist} /mnt
              #zpool export rpool
              #reboot
''))
            ];

         };
      };

      nixosConfigurations = {
        base = nixpkgs.lib.nixosSystem {
              inherit system;
              modules = with self.nixosModules; [
                ssh
                zfs
                hetzner
                ({ pkgs, lib, ... }: {
                  networking.hostId = hostId;
                  nixpkgs.overlays = [ self.overlay ];
                  i18n.defaultLocale = "en_US.UTF-8";
                  time.timeZone = "UTC";
                  networking = {
                    firewall.allowedTCPPorts = [ 22 ];
                    usePredictableInterfaceNames = true;
                  };

                  environment.systemPackages = [
                    pkgs.git  # needed for nix flakes
                  ];
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
