#!/usr/bin/env bash
set -euo pipefail

# We reuse the hostname of hetzners debian image which matches the servers name in hcloud interfaces.
HOST_NAME="$(hostname -f)"
# ...and derive the hostID from this hostname. This is a.o. used by ZFS to determine whether
# a given filesystem pool belongs to the host.
HOST_ID="$(hostname -f | sha256sum | cut -c 1-8)"

# We use lsblk to find the disk of the currently mounted / file system, which in hclouds case is persistent.
# this returns PKNAME, a path to the disk like "/dev/sda"
_ROOT_DEVICE_INFO="$(lsblk --list --paths --json --output MOUNTPOINT,PKNAME | jq '.blockdevices[] | select(.mountpoint=="/")')"
_ROOT_DEVICE_DISK="$(echo "$_ROOT_DEVICE_INFO" | jq -r .pkname)"

# resolve _ROOT_DEVICE_DISK, e.g. /dev/sda to its /dev/disk/by-id path because thats more stable
DISK_TO_FORMAT="$(find -L /dev/disk/by-id/ -samefile "$_ROOT_DEVICE_DISK")"

# WARNING: This might not work with multiple network devices
_IP_ADDR_INFO="$(ip --json addr show | jq '.[] | select(.link_type != "loopback") | .')"

NETWORK_INTERFACE="$(echo "$_IP_ADDR_INFO" | jq -r .ifname)"
NETWORK_INTERFACE_MODULE="$(ethtool -i "$NETWORK_INTERFACE" | awk '/driver:/ {print $2}')"

_IPV4_INFO="$(echo "$_IP_ADDR_INFO" | jq '.addr_info[] | select(.scope == "global" and .family == "inet")')"
IPV4_ADDRESS="$(echo "$_IPV4_INFO" | jq -r '.local')"
IPV4_PREFIX_LENGTH="$(echo "$_IPV4_INFO" | jq -r '.prefixlen')"
IPV4_GATEWAY="$(ip route | awk '/default via/ {print $3}')"

_IPV6_INFO="$(echo "$_IP_ADDR_INFO" | jq '.addr_info[] | select(.scope == "global" and .family == "inet6")')"
IPV6_ADDRESS="$(echo "$_IPV6_INFO" | jq -r '.local')"
IPV6_PREFIX_LENGTH="$(echo "$_IPV6_INFO" | jq -r '.prefixlen')"
IPV6_GATEWAY="$(ip -6 route | awk '/default via/ {print $3}')"

jq --null-input \
  --arg hostName "$HOST_NAME" \
  --arg hostId "$HOST_ID" \
  --arg diskToFormat "$DISK_TO_FORMAT" \
  --arg networkInterface "$NETWORK_INTERFACE" \
  --arg networkInterfaceModule "$NETWORK_INTERFACE_MODULE" \
  --arg ipv4Address "$IPV4_ADDRESS" \
  --arg ipv4PrefixLength "$IPV4_PREFIX_LENGTH" \
  --arg ipv4Gateway "$IPV4_GATEWAY" \
  --arg ipv6Address "$IPV6_ADDRESS" \
  --arg ipv6PrefixLength "$IPV6_PREFIX_LENGTH" \
  --arg ipv6Gateway "$IPV6_GATEWAY" \
  '
{
  "hostName": $hostName,
  "hostId": $hostId,
  "diskToFormat": $diskToFormat,
  "networkInterface": $networkInterface,
  "networkInterfaceModule": $networkInterfaceModule,
  "ipv4": {
    "address": $ipv4Address,
    "prefixLength": $ipv4PrefixLength,
    "gateway": $ipv4Gateway,
    "netmask": "255.255.255.255",  # TODO, dont hardcode
  },
  "ipv6": {
    "address": $ipv6Address,
    "prefixLength": $ipv6PrefixLength,
    "gateway": $ipv6Gateway,
  }
 }
'
