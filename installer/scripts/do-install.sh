#!/usr/bin/env bash
set -euo pipefail
mkdir -p hostFlake
cd hostFlake

read-runtime-info > runtime-info.json

echo "Installing with the following runtime data"
jq . runtime-info.json
echo "The disk will be NUKED and ALL DATA deleted. You will be asked for a disk encryption key next, the rest of the installation is non-interactive"
read -p "Press Enter delete ALL DATA" </dev/tty

nuke-disk "$(jq -r .diskToFormat runtime-info.json)"

# we link /persist in the kexec environment to /mnt/persist, because
# an absolute path outside the nix store is hardcoded in boot.initrd.network.ssh.hostKeys
ln -s /mnt/persist /persist

# generate ssh host key for initrd.
mkdir -p /persist/etc/ssh
chown root:root /persist/etc/ssh
chmod 0700 /persist/etc/ssh

ssh-keygen -t ed25519 -N "" -f /persist/etc/ssh/initrd_ssh_host_ed25519_key
chown root:root /persist/etc/ssh/initrd_ssh_host_ed25519_key{,.pub}
chmod 0600 /persist/etc/ssh/initrd_ssh_host_ed25519_key
chmod 044 /persist/etc/ssh/initrd_ssh_host_ed25519_key.pub

# todo make flake template
cat > flake.nix <<EOF
{
  description = "A host-specific config, containing runtime info";
    inputs.installer.url = "@flakePath@";
    outputs = { self, installer }:
    let
      system = "x86_64-linux";
      pkgs = import installer.inputs.nixpkgs { inherit system; overlays = [ installer.outputs.overlay ]; };
      runtimeInfo = builtins.fromJSON(builtins.readFile(./runtime-info.json));
      extraModule = {pkgs, lib, config, ...}: {
        config = {
          environment.systemPackages = [
            pkgs.jq
            pkgs.vim
            pkgs.tmux
            pkgs.rsync
          ];
        };
      };
    in { nixosConfigurations.installed = installer.lib.makeSystem self extraModule runtimeInfo; };
}
EOF

TMPDIR=/tmp nixos-install \
    --no-channel-copy \
    --root /mnt \
    --no-root-passwd \
    --flake .#installed

umount /mnt/{boot,nix,home,persist} /mnt
reboot
