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


        ssh = { pkgs, lib, ... }: {
          users.users.root.openssh.authorizedKeys.keys = sshRootKeys;
          services.openssh = {
            enable = true;
            passwordAuthentication = lib.mkForce false;
            permitRootLogin = lib.mkForce "without-password";
          };
        };

        zfs = { pkgs, lib, runtimeInfo, ... }: {
          boot.loader.grub.enable = true;
          boot.loader.grub.version = 2;
          boot.loader.grub.efiSupport = false;
          boot.loader.grub.devices = [ runtimeInfo.diskToFormat ];
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
              # ssh-keygen -t ed25519 -N "" -f /persist/initrd-ssh-key
              hostKeys = [ "/persist/initrd-ssh-key" ];
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
              device = "${runtimeInfo.diskToFormat}-part3";
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
          { pkgs, lib, modulesPath, runtimeInfo, ... }:
          {
            imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

            boot.initrd.availableKernelModules = [ "virtio_net" "ata_piix" "virtio_pci" "virtio_scsi" "xhci_pci" "sd_mod" "sr_mod" ];
            boot.kernelParams = with runtimeInfo; [
              # See <https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt> for docs on this
              # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>
              "ip=dhcp"
            ];
            # We mirror the default settings from a hcloud instance with debian-11 setup with cloud-init,
            # dhcp autoconfiguration for ipv4, bugt a static one for the first ipv6 address in our subnet
            networking = with runtimeInfo; {
              hostName = hostName;
              hostId = runtimeInfo.hostId;
              useDHCP = false;
              interfaces.${networkInterface} = {
                useDHCP = true;
                ipv6 = { addresses = [{ address = ipv6.address; prefixLength = ipv6.prefixLength; }]; };
              };
              defaultGateway6 = { address = ipv6.gateway; interface = networkInterface; };
              nameservers = [
                # Hcloud nameservers
                "185.12.64.1"
                "185.12.64.2"
                "2a01:4ff:ff00::add:1"
                "2a01:4ff:ff00::add:2"
              ];
            };
          };

        core = { pkgs, lib, ... }: {
          i18n.defaultLocale = "en_US.UTF-8";
          time.timeZone = "UTC";
          networking = {
            firewall.allowedTCPPorts = [ 22 ];
            usePredictableInterfaceNames = true;
          };
          environment.systemPackages = [
            pkgs.gitMinimal  # de facto needed to work with flakes
          ];

        };


        installationEnvironment =
          { pkgs, lib, ... }:
          {
            imports = with self.nixosModules; [
              core
              ssh
              nix
            ];

           networking = {
              firewall.allowedTCPPorts = [ 22 ];
              usePredictableInterfaceNames = true;
              useDHCP = true;
            };

           environment.systemPackages = [
             pkgs.jq
             pkgs.ethtool
             (let
               readRuntimeInfoScript = pkgs.writeScript "read-runtime-info" ''
                 set -euo pipefail
                 cat /proc/cmdline \
                 | awk -v RS=" " '/^runtime_info/ {print gensub(/runtime_info="(.+)"/, "\\1", "g", $0);}' \
                 | base64 -d
                 '';
                nukeDiskScript = pkgs.writeScript "nuke-disk" (builtins.readFile ./pkgs/nuke-disk.sh);
              in
              (pkgs.writeScriptBin "install-flake" ''
              #!/usr/bin/env bash
              set -euo pipefail
              mkdir -p hostFlake
              cd hostFlake

              ${readRuntimeInfoScript} > runtime-info.json

              echo "Installing with the following runtime data"
              jq . runtime-info.json
              echo "The disk will be NUKED and ALL DATA deleted. You will be asked for a disk encryption key next, the rest of the installation is non-interactive"
              read -p "Press Enter delete ALL DATA" </dev/tty

              ${nukeDiskScript} "$(jq -r .diskToFormat runtime-info.json)"

              # generate ssh-key.
              # HACK: we link /persist in the kexec environment to /mnt/persist, because
              # an absolute path outside the nix store is hardcoded in boot.initrd.network.ssh.hostKeys
              ln -s /mnt/persist /persist
              ssh-keygen -t ed25519 -N "" -f /persist/initrd-ssh-key

              # todo make flake template
              cat > flake.nix <<EOF
              {
                description = "A host-specific config, containing runtime info";
                  inputs.installer.url = "${self.outPath}";
                  outputs = { self, installer }:
                  let runtimeInfo = builtins.fromJSON(builtins.readFile(./runtime-info.json));
                  in { nixosConfigurations.install = installer.lib.makeSystem self runtimeInfo; };
              }
              EOF

              TMPDIR=/tmp nixos-install \
              --no-channel-copy \
              --root /mnt \
              --no-root-passwd \
              --flake .#install

              umount /mnt/{boot,nix,home,persist} /mnt
              #zpool export rpool
              reboot
''))
            ];

         };
      };

      lib.makeSystem = flake: runtimeInfo:
        nixpkgs.lib.nixosSystem {
          inherit system;
          extraArgs.runtimeInfo = builtins.trace runtimeInfo runtimeInfo;
          modules = with self.nixosModules; [
            core
            ssh
            nix
            zfs
            hetzner
            ({ pkgs, lib, ... }: {
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
