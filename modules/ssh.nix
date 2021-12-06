{ pkgs, lib, config, ... }:
{
  # runtimeInfo is false during evaluation-time of the kexec environment.
  # Over there, we rely on an systemd service to read the key from
  # runtime_info kernel cmdline and write it to tmpfs.
  config =
    {
      services.openssh = {
        enable = true;
        passwordAuthentication = lib.mkForce false;
        permitRootLogin = lib.mkForce "without-password";
      };
    }
    // (lib.mkIf (config.runtimeInfo) {
      users.users.root.openssh.authorizedKeys.keys = config.runtimeInfo.rootAuthorizedKeys;
    })
    // (lib.mkIf (!config.runtimeInfo) {
    services.openssh.extraConfig = ''
            match User root
                AuthorizedKeysFile /var/run/keys/root-authorized-keys
            '';
    });
}