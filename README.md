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

## Secrets 
 

# Quick notes regarding installer tests

``` sh

# hcloud server create --name installer-test --type cx21 --image debian-11 --location nbg1 --ssh-key "phaers yubikey"
[=====================================] 100.00%
Waiting for server 16336486 to have started
 ... done                                                                                                                                                                                      
Server 16336486 created
IPv4: 116.203.101.184

# rsync -Lvz --info=progress2 result/* 116.203.101.184:
[ Uploading almost 1GB can take a while, but we end up with a pretty much fully functional environment]

```

Grub entry

``` sh
setparams "NixOS"
    load_video
    insmod gzio
    insmod part_gpt
    insmod ext2
    set root='hd0,gpt1'
    echo 'loading kernel'
    linux /root/bzImage init=/nix/store/sqh8cmi552m0spg4g2q505nif7vy5g3p-nixos-system-nixos-21.05pre-git/init loglevel=4
    #consoleblank=-1 systemd.show_status=true console=tty1 console=ttyS0
    echo 'loading initrd'
    initrd /root/initrd.gz 
    boot
    
```

# References
* [Github: Mic92s kexec-installer.nix](https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97)
* [Github: Impermanence NixOS module](https://github.com/nix-community/impermanence)
* [Blog: Grahamc: Erase your darlings](https://grahamc.com/blog/erase-your-darlings)
