{ pkgs, lib, config, ... }:
{
  # runtimeInfo is false during evaluation-time of the kexec environment.
  # Over there, we rely on an systemd service to read the key from
  # runtime_info kernel cmdline and write it to tmpfs.
  config =
    lib.mkMerge [
      ({
        services.openssh = {
          enable = true;
          passwordAuthentication = lib.mkForce false;
          permitRootLogin = lib.mkForce "without-password";
        };
      })
      (lib.mkIf (config.runtimeInfo != null) {
        users.users.root.openssh.authorizedKeys.keys = config.runtimeInfo.rootAuthorizedKeys;
      })
      (lib.mkIf (config.runtimeInfo == null) {
        services.openssh.extraConfig = ''
            match User root
                AuthorizedKeysFile /var/run/keys/root-authorized-keys
            '';
      })
    ];
}
