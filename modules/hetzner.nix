{ pkgs, lib, config, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  config = {

    boot.initrd.availableKernelModules = [ "virtio_net" "ata_piix" "virtio_pci" "virtio_scsi" "xhci_pci" "sd_mod" "sr_mod" ];
    boot.kernelParams = with config.runtimeInfo; [
      # See <https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt> for docs on this
      # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>
      "ip=dhcp"
    ];
    # We mirror the default settings from a hcloud instance with debian-11 setup with cloud-init,
    # dhcp autoconfiguration for ipv4, bugt a static one for the first ipv6 address in our subnet
    networking = with config.runtimeInfo; {
      hostName = hostName;
      hostId = config.runtimeInfo.hostId;
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
}
