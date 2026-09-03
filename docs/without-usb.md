# Installing NixOS on Apple silicon without using an external USB drive

I'd like to call this a guide to installing NixOS on Apple silicon Macintosh computers. More accurately, it is a record of my experience in doing such an installation. [YMMV](https://en.wiktionary.org/wiki/your_mileage_may_vary)

All of the hard work has been done by others; see the references below. However, the method described in [UEFI Boot Standalone NixOS](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md) requires booting a USB drive, which seems to require a keyboard that works under U-Boot - and none of my 3 keyboards do!

So instead of a USB drive, I use another Linux distribution installed on the same computer. NixOS will end up installed beside this other distribution. In this guide, I assume the other distribution is Fedora.

This guide was written in mid-summer 2024. Even while I was writing it, there were changes in the details of what I needed to do. So things may have changed since then; be careful.

## References

- [Asahi Linux](https://asahilinux.org/) is the home for porting Linux to Apple silicon.
- [UEFI Boot Standalone NixOS](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md) describes how to install NixOS on Apple silicon, using a NixOS live USB.
- [Installing from another Linux distribution](https://nixos.org/manual/nixos/stable/#sec-installing-from-other-distro) is a general guide to installing NixOS using another Linux distribution on the same machine.
- [Guide for LUKS encryption setup](https://github.com/tpwrules/nixos-apple-silicon/issues/108) has links to how to encrypt the root partition for NixOS on Apple silicon systems.

## UEFI Preparation

You will need to prepare an UEFI environment into which NixOS will be installed. The details of how to do this are described at [UEFI Preparation](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md#uefi-preparation), but in brief:

- Boot into MacOS
- Open the Terminal application
- Run `curl https://alx.sh | sh` and select the "UEFI environment only" option.

If you already have Fedora or another Linux distribution installed, and you want to install NixOS beside it, that is all you need to do in this step.

If you are starting with just MacOS installed, and want to end up with just MacOS and NixOS, I recommend you set up the UEFI environment for NixOS first, as above. Then boot into MacOS and run the curl command again, this time making space for and installing a minimal Fedora system. You might need to create a temporary partition in the space that was allocated for NixOS, in order to prevent the installer from using that space for Fedora. After you have finished installing NixOS, you should then be able to delete the Fedora installation and return its space to MacOS.

Be aware that if you have two Linux installations created with the same choice in `curl https://alx.sh | sh`, you might (or might not) have problems. See [this issue](https://pagure.io/fedora-asahi/remix-bugs/issue/9).

## Install Nix

In Fedora, we need to install the Nix package manager (this is different from NixOS!). As a normal (not root) user, run

```
curl -L https://nixos.org/nix/install | sh
export PATH="$PATH":~/.nix-profile/bin
```

At this point, you will be using the `nixpkgs` channel. Running

```
nix-channel --list
```

should produce the output `nixpkgs https://nixos.org/channels/nixpkgs-unstable`.

Per [Installing from another Linux distribution](https://nixos.org/manual/nixos/stable/#sec-installing-from-other-distro), it is safer to switch to a `nixos-*` channel. Look for the latest `nixos-*` channel at <https://channels.nixos.org>; at the time of writing, this is `nixos-24.05`. Switch to that channel (change 24.05 to whatever you found as the latest):

```
nix-channel --add https://nixos.org/channels/nixos-24.05 nixpkgs
nix-channel --list
nix-channel --update
```

Now get the NixOS installation tools:

```
nix-env -f '<nixpkgs>' -iA nixos-install-tools
```

## Partitioning and formatting

You will have to create a root partition and format it. [UEFI Boot Standalone NixOS](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md#partitioning-and-formatting) shows how to create the partition with `sgdisk`. I prefer to use `parted`. Look for the free space gap between existing partitions; this is where you should create the new partition. Measuring in sectors allows us to place the partition precisely.

The sector and partition numbers will likely be different in your installation; do not copy this example blindly.

```
sudo parted /dev/nvme0n1
GNU Parted 3.6
Using /dev/nvme0n1
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) unit s
(parted) print                                                            
Model: APPLE SSD AP1024Z (nvme)
Disk /dev/nvme0n1: 244276265s
Sector size (logical/physical): 4096B/4096B
Partition Table: gpt
Disk Flags: 

Number  Start       End         Size        File system  Name                  Flags
 1      6s          128005s     128000s                  iBootSystemContainer
 2      128006s     29669125s   29541120s                Container
 3      29669126s   30279429s   610304s
 4      30279430s   30401541s   122112s     fat32                              boot, esp
 5      36749318s   37359621s   610304s
 6      37359622s   37487621s   128000s     fat32                              boot, esp
 7      37487622s   37749765s   262144s     ext4
 8      37749766s   242965509s  205215744s
 9      242965551s  244276259s  1310709s                 RecoveryOSContainer
 
(parted) mkpart primary ext4 30401542 36749317
Warning: The resulting partition is not properly aligned for best performance: 30401542s % 256s != 0s
Ignore/Cancel? ignore
(parted) print                                                            
Model: APPLE SSD AP1024Z (nvme)
Disk /dev/nvme0n1: 244276265s
Sector size (logical/physical): 4096B/4096B
Partition Table: gpt
Disk Flags: 

Number  Start       End         Size        File system  Name                  Flags
 1      6s          128005s     128000s                  iBootSystemContainer
 2      128006s     29669125s   29541120s                Container
 3      29669126s   30279429s   610304s
 4      30279430s   30401541s   122112s     fat32                              boot, esp
10      30401542s   36749317s   6347776s    ext4         primary
 5      36749318s   37359621s   610304s
 6      37359622s   37487621s   128000s     fat32                              boot, esp
 7      37487622s   37749765s   262144s     ext4
 8      37749766s   242965509s  205215744s
 9      242965551s  244276259s  1310709s                 RecoveryOSContainer
(parted) quit
```

### Without encryption

If you do not want to encrypt your root filesystem, simply create a filesystem on the new partition and mount it:
 
```
sudo mkfs.ext4 -L NixOS /dev/nvme0n1p10
sudo mount /dev/nvme0n1p10 /mnt
```

### With encryption

Encrypting the root filesystem is also straightforward:

```
sudo cryptsetup luksFormat /dev/nvme0n1p10
sudo cryptsetup open /dev/nvme0n1p10 nixroot
sudo mkfs.ext4 -L NixOS /dev/mapper/nixroot
sudo mount /dev/mapper/nixroot /mnt
```

## Configure NixOS

At this point, you should have the NixOS root filesystem mounted at `/mnt`. Find the EFI filesystem that was created for NixOS, and mount it at `/mnt/boot`:

```
lsblk -f
sudo mkdir /mnt/boot
sudo mount /dev/nvme0n1p4 /mnt/boot
```

Next, generate the default NixOS configuration:

```
sudo ~/.nix-profile/bin/nixos-generate-config --root /mnt
```

and include the configuration specific to Apple silicon (see [UEFI Boot Standalone NixOS](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md) for more information):

```
git clone https://github.com/tpwrules/nixos-apple-silicon/
sudo cp -r nixos-apple-silicon/apple-silicon-support /mnt/etc/nixos/
rm -rf nixos-apple-silicon
```

Use any text editor to edit the main configuration file:

```
sudo nvim /mnt/etc/nixos/configuration.nix
```

As described in [NixOS Configuration](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md#nixos-configuration), add the `./apple-silicon-support` directory to the imports list and switch off the `canTouchEfiVariables` option. That portion of the file should look like this:

```
imports =
  [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Include the necessary packages and configuration for Apple Silicon support.
    ./apple-silicon-support
  ];

# Use the systemd-boot EFI boot loader.
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

You may wish to make other changes to the configuration at this time; see [NixOS Configuration](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md#nixos-configuration) for some suggestions.

## Install NixOS

The installation requires a `nixbld` user and group:

```
sudo groupadd -g 30000 nixbld
sudo useradd -u 30000 -g nixbld -G nixbld nixbld
```

To install NixOS, run this command:

```
time sudo PATH="$PATH" ~/.nix-profile/bin/nixos-install -I ~/.nix-defexpr/channels --root /mnt
```

If all goes well, you will eventually be asked to enter and confirm the root password for the new installation.

You should now be able to shut down your system and boot into NixOS. Be sure to read this [Maintenance](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md#maintenance) information, especially the section on [Apple Silicon Support Updates](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/uefi-standalone.md#apple-silicon-support-updates). Also, these [Release Notes](https://github.com/tpwrules/nixos-apple-silicon/blob/main/docs/release-notes.md) are a good place to look if you have problems.

After booting into the new NixOS installation, I found that I could not run `nixos-rebuild switch --upgrade`. Running `nix-channel --update` once fixed the problem.

The `boot` filesystem seems to be quite small, and may fill up after a while. To avoid this, you could occasionally run something like

```
sudo nix-collect-garbage --delete-older-than 30d
```
 
## Cleaning up
 
You might want to undo the changes you made in your Fedora installation.
 
To remove the `nixbld` user and group,
 
```
sudo userdel -r nixbld
sudo groupdel nixbld
```

To remove the Nix packager,

```
sudo rm -rf /nix ~/.nix-profile ~/nix-defexpr ~/.nix-channels ~/.local/state/nix ~/.cache/nix
```