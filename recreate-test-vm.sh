#!/usr/bin/env bash
set -euo pipefail
set -x


SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
wait_for_ssh() {
    until ssh -o ConnectTimeout=2 $SSH_ARGS root@"$1" "true"
        do sleep 1
    done
}
nix build .#kexec
hcloud server delete installer-test || true
hcloud server create --name installer-test --type cx21 --image debian-11 --location nbg1 --ssh-key "phaers yubikey"
export TARGET_SERVER=$(hcloud server ip installer-test)
wait_for_ssh "$TARGET_SERVER"
rsync -e "ssh $SSH_ARGS" -Lvz --info=progress2 result/* root@$TARGET_SERVER:
ssh $SSH_ARGS root@$TARGET_SERVER "./run-installer"
#ssh -t $SSH_ARGS root@$TARGET_SERVER install-flake # -t for interactive questions
