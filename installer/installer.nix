{ installerFlake }:
{ pkgs, lib, ... }:
{
  imports = with installerFlake.nixosModules; [
    core
    ssh
    nix
  ];

  config =
    let
      readRuntimeInfoScript = pkgs.writeScriptBin "read-runtime-info"  (builtins.readFile ./scripts/read-runtime-info.sh);
      readDiskKeyScript = pkgs.writeScriptBin "read-disk-key"  (builtins.readFile ./scripts/read-disk-key.sh);
      nukeDiskScript = pkgs.writeScriptBin "nuke-disk" (builtins.readFile ./scripts/nuke-disk.sh);
      doInstallScript =
        pkgs.writeScriptBin "do-install"
          (builtins.readFile (pkgs.substituteAll {
            src = ./scripts/do-install.sh;
            flakePath = installerFlake.outPath;
          }));
    in
      {
        networking = {
          firewall.allowedTCPPorts = [ 22 ];
          usePredictableInterfaceNames = true;
          useDHCP = true;
        };

        systemd.services.write-authorized-keys = {
          enable = true;
          wants = [ "run-keys.mount" ];
          wantedBy = [ "sshd.service" ];
          description = "Read SSH authorized keys from kernel cmdline and write them for SSHD";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = "yes";
          };
          script = ''
                    if [ ! -f /var/run/keys/root-authorized-keys ]; then
                      # Write authorized key for root user in final system
                      PATH=${readRuntimeInfoScript}/bin:${pkgs.jq}/bin:${pkgs.gawk}/bin:$PATH
                      read-runtime-info \
                      | jq -r '.rootAuthorizedKeys[]' \
                      > /var/run/keys/root-authorized-keys
                      chown root:root /var/run/keys/root-authorized-keys
                      chmod 0600 /var/run/keys/root-authorized-keys
                    fi
                    '';
        };
        environment.systemPackages = [
          pkgs.jq
          pkgs.ethtool
          readRuntimeInfoScript
          readDiskKeyScript
          nukeDiskScript
          doInstallScript
        ];
      };
}
