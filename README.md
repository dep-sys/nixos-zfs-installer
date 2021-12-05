# An optionated NixOS remote installer

This repo contains an opionated installer for the [NixOS](https://nixos.org) operating system on a remote machine.

It assumes that another Linux (Live) System is already running on the target host and root login via SSH is enabled.

It then uses a custom-built [kexec](https://en.wikipedia.org/wiki/Kexec) bundle to replace the running System with a Linux kernel and minimal NixOS [initrd](https://en.wikipedia.org/wiki/Initial_ramdisk) which includes our installer.

The installer then formats the disks with [ZFS](https://openzfs.org/wiki/Main_Page) and installs an encrypted NixOS system, unlockable via SSH.

It's a [Nix Flake]() which uses [NixPkgs stable]()

## TODOS
- TODO: enp0s3  in debian vs ens3 (with altname enp0s3) in nixos
- Decide how to handle ssh public keys.
  Could add /root/.ssh/authorized_keys to runtime_info.json, but that might make it big for kernel cmdline.
  Should be stored in /persist or nix store in final system
- reduce size of kexec bundle
- Store ssh host key for final system in /persist?
- Port to nixos.party? Maybe once i find out wheter its open source and how it works

## ZFS setup

## Configuration

## Terraform

## Colmena 


## Secrets 
 

# Roadmap

## [x] Get the server to boot with kexec

``` sh
bash recreate-test-vm.sh
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
```
# References
* [Github: Mic92s kexec-installer.nix](https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97)
* [Github: Impermanence NixOS module](https://github.com/nix-community/impermanence)
* [Blog: Grahamc: Erase your darlings](https://grahamc.com/blog/erase-your-darlings)
