{ pkgs, lib, config, ... }: {
  config = {
    boot.loader.grub.enable = true;
    boot.loader.grub.version = 2;
    boot.loader.grub.efiSupport = false;
    boot.loader.grub.devices = [ config.runtimeInfo.diskToFormat ];
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
        # ssh-keygen -t ed25519 -N "" -f /persist/etc/ssh/initrd_ssh_host_ed25519_key
        hostKeys = [ "/persist/etc/ssh/initrd_ssh_host_ed25519_key" ];
        # public ssh key used for login
        # TODO There's no authorizedKeyFiles for boot.initrd.network.ssh yet, and we cant
        # just use ExtraConfig because NixOS (or us) would need to copy those paths to the initrd
        # during rebuild
        authorizedKeys = config.runtimeInfo.rootAuthorizedKeys;
      };
      # this will automatically load the zfs password prompt on login
      # and kill the other prompt and the ssh daemon so boot can continue
      postCommands = ''
              cat <<EOF > /root/.profile
              if pgrep -x "zfs" > /dev/null
              then
                zfs load-key -a
                killall zfs
              else
                echo "zfs not running -- maybe the pool is taking some time to load for some unforseen reason."
              fi

              killall sshd
              EOF
            '';
    };


    # https://grahamc.com/blog/nixos-on-zfs
    # "Note: If you do partition the disk, make sure you set the disk’s scheduler to none. ZFS takes this step automatically if it does control the entire disk.
    # On NixOS, you an set your scheduler to none via:"
    boot.kernelParams = [ "elevator=none" ];



    fileSystems."/" =
      { device = "rpool/local/root";
        fsType = "zfs";
      };

    fileSystems."/boot" =
      {
        device = "${config.runtimeInfo.diskToFormat}-part3";
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
}
