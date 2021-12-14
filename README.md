# An optionated NixOS remote installer

This repo contains an opionated installer for the [NixOS](https://nixos.org) operating system on a remote machine.

It assumes that another Linux (Live) System is already running on the target host and root login via SSH is enabled.
While the general approach should be pretty universal, the current implementation supports [hetzner.cloud](https://hetzner.cloud) only.
Especially [write-runtime-info](./installer/scripts/read-runtime-info.sh) would need to be ported, made more generic or to be replaced
by [cloud-init](https://cloud-init.io/).

It then uses a custom-built [kexec](https://en.wikipedia.org/wiki/Kexec) bundle to replace the running System with a Linux kernel and minimal NixOS [initrd](https://en.wikipedia.org/wiki/Initial_ramdisk) which includes our installer
as well as a script to start it. The [script](./installer/scripts/run-installer.sh) collects runtime info like the machines hostname and ip addresses and prompts for a disk-encryption key if not given as an argument. This info is then base64-encoded and passed to the kexec-environment via kernel parameters. 

Inside the kexec-environment, [do-install](./installer/scripts/do-install.sh) reads those kernel parameters, runs [nuke-disk](./installer/scripts/do-install.sh)
to format the disks with encrypted [ZFS](https://openzfs.org/wiki/Main_Page), generates ssh host keys and a host-specific flake which imports runtime information as JSON. It then installs the NixOS system from this flake to disk.

It's a [Nix Flake](https://nixos.wiki/wiki/Flakes) which uses [NixOS 21.11](https://github.com/nixos/nixpkgs/tree/nixos-21.11).

## Possible Improvements
- reduce size of kexec bundle
- make the host-specific flake, currently hardcoded in [do-install.sh](./installer/scripts/do-install.sh) a flake-template
- ...and think about the best workflow to import runtime-info.json from a single host into a flake/repo describing a network of multiple hosts.
- cleanup & commit terraform/terranix example
- store ssh host key for final system in /persist
- use impermanence & reset / on reboot
- support efi boot (at least on dedicated hetzner hosts)
- support other hosters. Either in a generic way or via plugins
- support netbooting/iso generation?

## Steps

### Build the kexec-bundle

``` shellsession
# nix build .#kexec
```

This should build the following result:

``` shellsession
# ls -1 result/
bzImage             # the kernel image to boot
initrd.gz           # the initial ram disk to load
run-installer       # installs utils, adds encoded runtime info to kernel parameters and "reboots" the system using kexec.
write-runtime-info  # gather info like disk, ips, etc from hcloud host.
```

TODO This needs to be cleaned up, but here's my quick-and-dirty test-script to completely destroy and re-provision a machine on [hetzner.cloud](https://hetzner.cloud)

``` shellsession
bash recreate-test-vm.sh
```


# Notes

## Howto rebuild an installed system from itself and howto customize the host-specific flake

``` shellsession
export HOST_FLAKE=$(jq -r '.flakes[] | select(.from.id == "installed") | .to.path' /etc/nix/registry.json)
nixos-rebuild switch --flake $HOST_FLAKE#installed
mkdir ~/hostFlake && cp -Rv $HOST_FLAKE/* ~/hostFlake && cd ~/hostFlake && git init || true  && git add . && nixos-rebuild switch --flake .#installed
```

## Debugging kexec with grub

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

# References
* [Github: Mic92s kexec-installer.nix](https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97)
* [Github: Impermanence NixOS module](https://github.com/nix-community/impermanence)
* [Blog: Grahamc: Erase your darlings](https://grahamc.com/blog/erase-your-darlings)
