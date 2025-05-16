

# AlphaWrap
This is a wrapper for `qemu-system-*` that allows on creation, launch and interaction with QEmu emulated machines. 

AlphaWrap uses concept of images and containers. Image - e.g. ARM linux ISO file, can be used to run a particular distribution in an emulated machine. `AlphaWrap` just before launching image creates a container that is a 'live' copy of the image. Image is never modified, while container is a run-time instance of the image.

This tool has been developed to support the development and automation of AlpBase Linux, which is specifically designed for ARM platforms, particularly Raspberry Pi boards.

![Made with ChatGPT (accually ChatGPT made this)](./art/AlphaWrap-mini.png)



## Requirements

`AlphaWrap` uses following system tools: `fdisk`, `dd` and `mkfs.*` - these tools are used **only** to operate on QEmu VMs it manages.

## When root access is needed?

If `--imgboot` is set to `yes` root is required, otherwise regular user is sufficient. Root access is necessary as `--imgboot yes` mounts image using loopback device.

## Features

`AlphaWrap` enhances QEmu by adding:
- Simplified VM creation
- Image and container support
- Virtual USB storage attach/detach options
- SSH-based guest interaction

**Note:** `AlphaWrap` has been tested only with `qemu-system-aarch64` and `qemu-system-arm`.

## AlphaWrap Guid

### Pre-installation
Ensure `qemu-system-arm` and `libvirt-daemon` is installed. 

To install these on Ubuntu/Debian do: 
```commandline
sudo apt install qemu-system-arm qemu-utils libvirt-daemon
# and run libvirtd: 
sudo systemctl start libvirtd
```

### Installation
Clone this repository: 
```bash
git clone https://github.com/tools200ms/AlphaWrap.git
cd AlphaWrap/
```
Copy DTB files and `alpha-wrap`:
```bash
sudo mkdir /var/lib/alphawrap
sudo cp -r alpha-wrap/dtbs /var/lib/alphawrap/_dtb

sudo cp ./alpha-wrap/alpha-wrap* /usr/local/bin/
sudo chmod +x /usr/local/bin/alpha-wrap*
```
and finally, initialize directory structure and databases: 
```bash
sudo alpha-wrap init
```
AlphaWrap uses `/var/lib/alphawrap` for storage, ensure that you have enough free space under this location. Containers might take a several GB of storage.

### Running ARM Linux Image

`AlphaWrap` supports emulation of the following devices:
- `raspi3b` - emulated ARMv8 four core CPU, uses emulated USB 2.0, thus networking and storage access is kinda slowish.
- `raspi0` - under tests

Device is chosen with `--device` flag. 

VM requires kernel and eventually initramfs in order to boot a system. These parameters can be set with `--imgboot` (`-i`) argument:

> --imgboot yes|y [kelner image path] [optional initramfs image path]
> 
> --imgboot no|n [kelner host path] [optional initramfs host path]

`--imgboot yes` - search for a kernel and eventually initramfs within image file. `AlphaWrap` will examine image and do attempt to find a boot partition, kernel and initramfs.

`--imgboot no` - kernel and an optionally initramfs must be located on a host.


Below are the instructions on how to run popular Raspberry Pi Linuxes.

#### Running: Raspberry Pi OS
[Download Raspberry Pi OS (preferably 64-bit and Lite version - who needs Desktop?)](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-64-bit), once done and saved run emulation: 

```bash
alpha-wrap -d raspi3b <pathto>/<date>-raspios-<release_name>-arm64-lite.img \
        -i y kernel8.img initramfs8
```

#### Running: Raspberry Pi OS Legacy version
To run Raspberry Pi OS on emulated Raspberry Pi Zero (first version) download [legacy OS](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-legacy).

and run: 
```bash
alpha-wrap -d raspi0 <pathto>/<date>-raspios-<release_name>-armhf-lite.img \
        -i y kernel8.img
```

Once when `Raspberry Pi OS` is boot it will grow filesystem to span over entire space. `AlphaWrap` always creates a container based on image. Thus, any modification is saved into container, making image intact what is a convenience as the image stays in its original (downloaded) form.

#### Running: DietPi
DietPi is Debian based distribution tuned for a performance, it is available for a wide variety of a Single Board Computers. Download ["Raspberry Pi 2/3/4/Zero 2"](https://dietpi.com/#download) image and run emulation with: 
```bash
alpha-wrap -d raspi3b <pathto>/DietPi_RPi-ARMv8-<release_name>.img \
        -i y kernel8.img
```
**Note:** Diet Pi does not require Initial ramdisk (initramfs). Kernel is tuned for a specific board and system, so it does not need initramfs 'stage' - that is the case for more generic distribution (one for multiple boards and configurations).

DietPi installation is launched automatically. As in the case of Raspberry Pi OS, DietPi image stays intact as all changes are saved into container.

#### Running: Alpine

Download [Alpine for Raspberry Pi, preferebly aarch64](https://www.alpinelinux.org/downloads/).

Run emulation with: 
```bash
alpha-wrap -d raspi3b <pathto>/alpine-rpi-<version>-aarch64.img \
        -i y boot/vmlinuz-rpi boot/initramfs-rpi
```

This will boot Alpine linux, to install login as root (no password) and issue `setup-alpine` for installation wizard.

#### Running AlpBase

To run [AlpBase](https://github.com/tools200ms/alpbase-linux), download the image and run:

```bash
alpha-wrap -d raspi3b iso/alpbase-<aarch64 edition>t-<version>.iso \
        -i y vmlinuz-rpi initramfs-rpi
```

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

