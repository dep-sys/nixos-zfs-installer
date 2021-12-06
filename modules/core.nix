{ pkgs, lib, ... }: {
  options.runtimeInfo = with lib; mkOption {
    description = "Data gathered from hcloud host, disk, ips, interfaces, etc";
    type = types.anything;
    #type = with types; nullOr (attrsOf (types.submodule {
    #  options = {
    #    hostName = mkOption { type = str; };
    #    hostId = mkOption { type = str; };
    #    rootAuthorizedKeys = mkOption { type = listOf str; };
    #    diskToFormat = mkOption { type = str; };
    #    networkInterface = mkOption { type = str; };
    #    networkInterfaceModule = mkOption { type = str; };
    #    ipv4 = mkOption {
    #      type = attrsOf (types.submodule {
    #        options = {
    #          address = mkOption { type = str; };
    #          prefixLength = mkOption { type = int; };
    #          gateway = mkOption { type = str; };
    #          netmask = mkOption { type = str; };
    #        };
    #      });
    #    };
    #    ipv6 = mkOption {
    #      type = attrsOf (types.submodule {
    #        options = {
    #          address = mkOption { type = str; };
    #          prefixLength = mkOption { type = int; };
    #          gateway = mkOption { type = str; };
    #        };
    #      });
    #    };
    #  };
    #}));
    default = null;
  };

  config = {
    i18n.defaultLocale = "en_US.UTF-8";
    time.timeZone = "UTC";
    networking = {
      firewall.allowedTCPPorts = [ 22 ];
      usePredictableInterfaceNames = true;
    };
    environment.systemPackages = [
      pkgs.gitMinimal  # de facto needed to work with flakes
    ];

    # TODO REMOVE, debug only
    users.extraUsers.root.password = "testtest";
  };
}
