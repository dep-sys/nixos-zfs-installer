#!/usr/bin/env bash
set -euxo pipefail

DISK_KEY="${1:-}"

[[ -z "$DISK_KEY" ]] && {
  read -r -e -p "Enter disk encryption key" DISK_KEY
}

TO_INSTALL=""
command -v kexec || TO_INSTALL="kexec-tools $TO_INSTALL"
command -v jq || TO_INSTALL="jq $TO_INSTALL"
command -v ethtool || TO_INSTALL="ethtool $TO_INSTALL"
command -v gawk || TO_INSTALL="gawk $TO_INSTALL"

test -n "$TO_INSTALL" && apt update -y && DEBIAN_FRONTEND=noninteractive apt install -y $TO_INSTALL

./write-runtime-info > runtime-info.json

echo "Gathered the following configuration parameters from existing linux"
jq . runtime-info.json

# We base64 encode the runtime data and pass it via linux kernel parameter
# to our nixos kexec environment to configure our flake there.
RUNTIME_KERNEL_PARAMETER="$(jq -c . runtime-info.json | base64 -w0)"

# We encode the disk key as an extra parameter, because runtimeInfo will be persisted.
DISK_KEY_KERNEL_PARAMETER="$(echo "$DISK_KEY" | base64 -w0)"

KERNEL_PARAMETERS="@kernelParams@ runtime_info=\"$RUNTIME_KERNEL_PARAMETER\" disk_key=\"$DISK_KEY_KERNEL_PARAMETER\""
# https://github.com/torvalds/linux/blob/master/arch/x86/include/asm/setup.h#L7
# #define COMMAND_LINE_SIZE 2048
[[ ${#KERNEL_PARAMETERS} -gt 2048 ]] && {
  echo "kernel parameters can't be more than 2048 characters long on x86. (${#KERNEL_PARAMETERS})"
  echo "$KERNEL_PARAMETERS"
  exit 1
}

# Adapted from https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97
kexec --load ./bzImage \
  --initrd=./initrd.gz \
  --command-line "$KERNEL_PARAMETERS"
if systemctl --version >/dev/null 2>&1; then
  systemctl kexec
else
  kexec -e
fi
