{ pkgs, lib, ... }: {
  options.runtimeInfo = lib.mkOption {
    description = "Data gathered from hcloud host, disk, ips, interfaces, etc";
    type = lib.types.anything;
    default = false;
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
