# An optionated NixOS remote installer

This repo contains an opionated installer for the [NixOS](https://nixos.org) operating system on a remote machine.

It assumes that another Linux (Live) System is already running on the target host and root login via SSH is enabled.

It then uses a custom-built [kexec](https://en.wikipedia.org/wiki/Kexec) bundle to replace the running System with a Linux kernel and minimal NixOS [initrd](https://en.wikipedia.org/wiki/Initial_ramdisk) which includes our installer.

The installer then formats the disks with [ZFS](https://openzfs.org/wiki/Main_Page) and installs an encrypted NixOS system, unlockable via SSH.

It's a [Nix Flake]() which uses [NixPkgs stable]()

## ZFS setup

## Configuration

## Terraform

## Colmena 


## Secrets 
 

# Roadmap

## [x] Get the server to boot with kexec

``` sh
nix build .#kexec
hcloud server create --name installer-test --type cx21 --image debian-11 --location nbg1 --ssh-key "phaers yubikey"

export TARGET_SERVER=$(hcloud server ip installer-test)
rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -Lvz --info=progress2 result/* root@$TARGET_SERVER:
# [ Uploading almost 1GB can take a while, but we end up with a pretty much fully functional environment]
# "Boot" into the installation environment using kexec (this might take a few minutes)
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$TARGET_SERVER "apt update && DEBIAN_FRONTEND=noninteractive apt install -y kexec-tools && bash kexec-installer"

```

### Debugging with grub

During development, it can be useful to boot the generated kernel and initrd manually via grub. I use hetzners web console
to get to the bootloader, press `c` for a console and paste the following lines:

Make sure to replace the init hash from kexec-installer (or try to remove it, and if it does, delete this notice)

``` sh
    insmod gzio
    insmod part_gpt
    insmod ext2
    set root='hd0,gpt1'
    linux /root/bzImage init=/nix/store/sqh8cmi552m0spg4g2q505nif7vy5g3p-nixos-system-nixos-21.05pre-git/init loglevel=4
    initrd /root/initrd.gz 
    boot
    
```

### Install NiXOS

``` sh
# TODO interactive zpool key
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$TARGET_SERVER install-flake
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$TARGET_SERVER reboot
```


# References
* [Github: Mic92s kexec-installer.nix](https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97)
* [Github: Impermanence NixOS module](https://github.com/nix-community/impermanence)
* [Blog: Grahamc: Erase your darlings](https://grahamc.com/blog/erase-your-darlings)
