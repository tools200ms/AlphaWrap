

# AlphaWrap
This is a wrapper for `qemu-system-*` that allows on creation, launch and interaction with QEmu emulated machines. 

`AlphaWrap` uses concept of `images`, and `containters`. Containers are crated from image, images are never modified, only containers can be modified.

This tool has been developed to support the development and automation of AlpBase Linux, which is specifically designed for ARM platforms, particularly Raspberry Pi boards.

![Made with ChatGPT (accually ChatGPT made this)](./art/AlphaWrap-mini.png)

## What it does, what doesn't

AlphaWrap uses system tools: `fdisk`, `dd` and `mkfs.*`, but it does not modify anything on a 'physical' hardware.
It only operates within `/var/lib/alphawrap` and `/tmp` directories. 'Dangerous' operations are ONLY performed on ISO files desired for VMs.

## When root access is needed?

If `--imgboot` is set to `yes` root is required, otherwise regular user is sufficient. This is becuse `--imgboot yes` do mount image using loopback, hence high privilages are needed.

## Features

In short, `AlphaWrap` provides: 
- Simple QEmu VM creation.
- Concept of images and containers.
- Emulated USB storage.
- Guest interaction via SSH.

**Note:** `AlphaWrap` has been tested with `qemu-system-aarch64` and `qemu-system-arm`, however, as this is only 'wrapper', other architectures, such as `qemu-system-riscv64` should not be an issue.

## Concept

At the beginning, there is an image (ARM image). To launch the image, the user specifies the device model to emulate (by default 'raspi3b' if omitted), along with the paths to the kernel, initramfs, and most importantly, the ARM image file.

`AlphaWrap` creates container basing on image, if option `--name` is provided, 'named' container is created. If `--name` is skipped, 'temporary' container is created that will live only until VM is on. 'Named' container stays indefinitely, until intentional removal.

The benefit coming from this approach is that the image stays intact. Some systems, such as Raspberry PI OS modify image upon first launch what is very practical for user. But, while experimenting and developing, it's essential to keep track on what has changed, what not. Thus, the distinction between images - that never change, and containers - that are prone for changes, is very practical.
Container name can be provided after parameter `--name`, if `--name` does not have any name afterward, random container name is given.

Unlike Docker, `AlphaWrap` allows on launching only one VM (container). The reason is that there is actually no need for an interaction in between containers. Container is launched to do a certain job, such as build Linux distribution for ARM and exit.

When a container is created, user can attach "Attachable Storage" that is emulated "USB storage device", or execute (over SSH) certain command.

Below, complete guide with an examples.

## AlphaWrap Guid

### Installation

Clone this repository: 
```bash
git clone https://github.com/tools200ms/projectalpha_deployment.git
cd projectalpha_deployment
```
Copy DTB files and `alpha-wrap`:
```bash
sudo mkdir -p /var/lib/alphawrap/_dtb
sudo cp -r alpha-wrap/dtbs/* /var/lib/alphawrap/_dtb

sudo cp ./alpha-wrap/alpha-wrap /usr/local/bin/
```
and finally, initialize directory structure and databases: 
```bash
alpha-wrap init
```
AlphaWrap uses `/var/lib/alphawrap` for storage, ensure that you have enough free space under this location. Containers might take about 10 GB, the rule of thumb is to have at least half of the disk space to be free (and trimmed if it's SSD). Make sure you are well below half of the available storage capacity.

### Running ARM Linux Image

`AlphaWrap` supports emulation of the following devices:
- `raspi3b` - emulated ARMv8 four core CPU, uses emulated USB 2.0, thus networking and storage access is kinda slowish.
- `raspi0` - Under tests

Desired device is chosen with `--device` flag. 

VM requires kernel and eventually initramfs in order to boot a system. These parameters can be provided as `--imgboot` (`-i`) argument. `--imgboot` works in two 'modes':
- `y` or `yes`, to search for a kernel and eventually initramfs within image file. `AlphaWrap` will examine image and attempt to find a boot partition, kernel and initramfs is loaded from an image.
- `n` or `no`, kernel and an optionally initramfs must be located on host.


Below are the instructions on how to run popular Raspberry Pi Linuxes.

#### Raspberry Pi OS
[Download Raspberry Pi OS (preferably 64-bit and Lite version - who needs Desktop?)](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-64-bit), once done and saved run emulation: 

```bash
alpha-wrap -d raspi3b <pathto>/<date>-raspios-<release_name>-arm64-lite.img \
        -i y kernel8.img initramfs8
```

##### Legacy version
To run Raspberry Pi OS on emulated Raspberry Pi Zero (first version) download [legacy OS](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-legacy).

and run: 
```bash
alpha-wrap -d raspi0 <pathto>/<date>-raspios-<release_name>-armhf-lite.img \
        -i y kernel8.img
```

Once when `Raspberry Pi OS` is boot it will grow filesystem to span over entire space. `AlphaWrap` always creates a container based on image. Thus, any modification is saved into container, making image intact what is a convenience as the image stays in its original (downloaded) form.

#### DietPi
DietPi is Debian based distribution tuned for a performance, it is available for a wide variety of a Single Board Computers. Download ["Raspberry Pi 2/3/4/Zero 2"](https://dietpi.com/#download) image and run emulation with: 
```bash
alpha-wrap -d raspi3b <pathto>/DietPi_RPi-ARMv8-<release_name>.img \
        -i y kernel8.img
```
**Note:** Diet Pi does not require Initial ramdisk (initramfs). Kernel is tuned for a specific board and system, so it does not need initramfs 'stage' - that is the case for more generic distribution (one for multiple boards and configurations).

DietPi installation is launched automatically. As in the case of Raspberry Pi OS, DietPi image stays intact as all changes are saved into container.

#### Alpine

Download [Alpine for Raspberry Pi, preferebly aarch64](https://www.alpinelinux.org/downloads/).

Run emulation with: 
```bash
alpha-wrap -d raspi3b <pathto>/alpine-rpi-<version>-aarch64.img \
        -i y boot/vmlinuz-rpi boot/initramfs-rpi
```

This will boot Alpine linux, to install login as root (no password) and issue `setup-alpine` for installation wizard.

### Listing containers
To see the list of containers and its statuses use `ls` (`-f` for more detailed view): 
```bash
$ alpha-wrap ls -f
alpine-alpbase-aarch64    1.1G
drive-river 257M
tmp.SlmE1dsYnY-container RUNNING Temporary   257M
```
In this example there is a container named 'alpine-alpbase-aarch64', one with a random name 'drive-river' and one temporary 'tmp.SlmE1dsYnY-container'.

### Persistent containers

If no `--name` (`-n`) parameter is provided created container is temporary and will live until machine shutdown. To define persistent continer add `--name` followed by choosen name, or without parameter if you want to relay on a random name.

```bash
alpha-wrap -d raspi3b <pathto>/<date>-raspios-<release_name>-arm64-lite.img \
        -i y kernel8.img initramfs8 \
        --name
```
this will create container with a random name.
```bash
alpha-wrap -d raspi3b <pathto>/<date>-raspios-<release_name>-arm64-lite.img \
        -i y kernel8.img initramfs8 \
        --name this_is_raspberrypios01
```
or this named 'this_is_raspberrypios01'.

### Virtual USB storage `extstore`
Below command: 
```bash
alpha-wrap extstore add usbstick01 1GB
```
Creates virtual USB storage device (with a given size) and attaches it to currently running VM. Entire space of the device is 'zeroed' before attaching to the machine.
The list of available storages can be checked with: 
```bash
alpha-wrap extstore ls
```
If storage is already created, it can be attached to curently running machine with: 
```bash
alpha-wrap extstore add usbstick01
```

### Guest interaction
`AlphaWrap` can interact with VM via SSH, this requires SSH private key to be installed (copied) into: 
```
/var/cache/alphawrap/db/${CONTINER_NAME}/id_ed25519
```
Public pair must be added into VM's: 
```
/root/.ssh/authorized_keys
```
This enables `AlphaWrap` to execute as root commands within VM: 
```
alpha-wrap-run command "cat /proc/cpuinfo"
```

Local (host) directory can be synchronised with givaen location in guset with: 
```
alpha-wrap-run sync <path to local directory or file> <guest location>
```

## TODO

TODO:
- Guest interaction should work over serial console (no keys, no network stack etc.), there should be emulated `/dev/AMA0`, figure out how to do this.

## References

[Raspberry PI Firmware (source of DTBs overlays)](https://github.com/raspberrypi/firmware)

