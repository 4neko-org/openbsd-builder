# OpenBSD Builder

<img src="https://cdn.4neko.org/freya/vm_openbsd.webp" width="250"/>

This project builds a QEMU VM Image for the [freya](https://codeberg.org/4neko/freya)

This project is based on
[cross-platform-actions/openbsd-builder](https://github.com/cross-platform-actions/openbsd-builder)
GitHub action. The image contains a standard OpenBSD installation without any
 man pages or games. It will install the following file sets:

* bsd
* bsd.mp
* bsd.rd
* baseXX.tgz
* compXX.tgz
* xbaseXX.tgz
* xfontXX.tgz
* xservXX.tgz
* xshareXX.tgz

In addition to the above file sets, the following packages are installed as well:

* sudo
* bash
* curl
* rsync
* rust

The follwoing packages are built:
* freyashell

BIOS:
EFI OVMF.fd

Disk layout:
```text
eb7c21148591978e.a / ffs ro,wxallowed 1 1
swap /tmp mfs rw,nodev,nosuid,-s=128m 0 0
swap /dev mfs rw,-P=/cfg/dev,-s=32m 0 0
swap /var mfs rw,-P=/cfg/var,-s=800m 0 0
swap /home/freya/.ssh mfs rw,-s=4m 0 0
```

Attached images:
```text
DISK1:
An image of the disk formatted as msdosfs with the following directory layout:

/KEYS - authorized_keys which will be copied to /home/freya/.ssh/


DISK2:
An image of the disk non-formatted, large enough (to fit the code and building) where 
all the files received over freyashell will be installed. The VM will format and mount
the disk manually.

DISK3:
An image of the disk non-formatted, large enough as you expect to have the swap in the system.
Optional. If this disk is not added, the system will operate without swap.
```
!!! Make sure that both disks are attached to VM because each is strictly binded by its order. Even if you don't need DISK1 i.e you will use default passwords, attach a dummy disk which is not necessary to format.

The `/` is mounted as read-only. The `freya's` homedir is also read-only.


Except for the root user, there's one additional user, `freya`, which is the
user that will be running the [freyashell](https://codeberg.org/4neko/freyashell). 
This user can use `sudo` with a password.

The default password for the `root` is `runner`.

## Usage

In order to use it, you need to make the image yourself (at the moment a binary images are not provided).

How to do it, see below.

## Architectures and Versions

The following architectures and versions are supported:

| Version | x86-64 | arm64 |
|---------|--------|-------|
| 6.8     | ✓      | ✓     |
| 6.9     | ✓      | ✓     |
| 7.1     | ✓      | ✓     |
| 7.2     | ✓      | ✓     |
| 7.3     | ✓      | ✓     |
| 7.4     | ✓      | ✓     |
| 7.5     | ✓      | ✓     |
| 7.6     | ✓      | ✓     |
| 7.7     | ✓      | ✓     |
| 7.8     | ✓      | ✓     |
| 7.9     | ✓      | ✓     |

## Building Locally

### Prerequisite

####  [UEFI firmware](https://github.com/tianocore/edk2)

This needs to be located at `resources/ovmf.fd`. Copy the `OVMF.fd` for it's
install location to `resources/ovmf.fd`.

* **Ubuntu** - Install the [`ovmf`](https://packages.ubuntu.com/jammy/ovmf) package.
* **Fedora** - Install the [`edk2-ovmf`](https://fedora.pkgs.org/34/fedora-x86_64/edk2-ovmf-20200801stable-4.fc34.noarch.rpm.html) package.
* **macOS** - Copy the `OVMF.fd` file from a Linux machine

#### Other

* [Packer](https://www.packer.io) 1.7.1 or later
* [QEMU](https://qemu.org)

### Building

1. Clone the repository:

    ```
    git clone https://github.com/4neko-org/openbsd-builder
    cd openbsd-builder
    ```

2. If you running it first time, probably you need to run
    ```
    packer init openbsd.pkr.hcl
    ```

3. Run `build.sh` to build the image:

    ```
    ./build.sh <version> <architecture>
    ```

    Where `<version>` and `<architecture>` are the any of the versions or
    architectures available in the above table.

    To target a snapshot, override the `checksum` variable manually by
    specifying `-var checksum=<checksum>` at the end when invoking the `build.sh`
    script. You can find the appropriate checksum by looking at the SHA256 file
    for `miniroot<version>.img` on [an OpenBSD mirror](https://www.openbsd.org/ftp.html).

    ```
    ./build.sh <version> <architecture> -var checksum=<checksum>
    ```

    On non-macOS platforms the `display` variable needs to be overridden by
    specifying `-var display=gtk` or `-var display=sdl` at the end when invoking
    the `build.sh` script:

    ```
    ./build.sh <version> <architecture> -var display=gtk
    ```

    To enable the hardware acceleration during building run

    ```
    ./build.sh <version> <architecture> -var display=gtk -var cpu_type=host
    ```

    Example:

    ```
    ./build.sh 7.9 x86-64 -var display=gtk -var cpu_type=host
    ```

The above command will build the VM image and the resulting disk image will be
at the path: `output/openbsd-7.9-amd64.qcow2`.

## Additional Information

This VM can be shut down without any gracefull shutdown as the disk is running in 
read-only mode.

At startup, the image will look for a second hard drive (as described above). 
If it presents and it
contains a file named `keys` at the root, it will install this file as the
`authorized_keys` file for the `runner` user. The disk is expected to be
formatted as FAT32. This is used as an alternative to a shared folder between
the host and the guest, since this is not supported by the xhyve hypervisor.
FAT32 is chosen because it's the only filesystem that is supported by both the
host (macOS) and the guest (OpenBSD) out of the box.

Also, at startup, the OS will look for the third hard drive (as described above).
If it presents, an OS will `disklabel` the image and invoke `newfs` on the disk
erasing everything which was installed previously. This disk image is a workdisk 
where writing is allowed.

The VM needs to be configured with the `virtio-net` network device. The disk needs to
be configured with the GPT partitioning scheme. And the VM needs to be configured
to use UEFI. All this is required for the VM image to be able to run using the
xhyve hypervisor.

The qcow2 format is chosen because unused space doesn't take up any space on
disk, it's compressible and easily converts the raw format, used by xhyve.

## Mounting / altering image without rebuilding

If it is required to alter something in the image (instead of rebuilding it), 
the following should be performed:

1. Log into the VM

2. Run the follwoing

```
# mount the root dir as RW
mount -uw /

# do needed actions
# i.e install something 
# ...
# sync data from RAM to disk
cp -Rp /var/ /cfg/
sync

# mount the root dir as RO
mount -ur /
```

## Startup example

```
/usr/bin/qemu-system-x86_64 \
    -machine type=q35,accel=hvf:kvm:tcg \
    -cpu host \
    -smp 2 \
    -m 4G \
    -device e1000,netdev=user.0,addr=0x03 \
    -netdev user,id=user.0,hostfwd=tcp::65500-:22 \
    -display sdl \
    -monitor none \
    -serial file:/tmp/OpenBSD_7.9_65500.txt \
    -boot strict=off \
    --bios /usr/share/edk2/ovmf/OVMF_CODE.fd \
    -device virtio-blk-pci,drive=drive0,bootindex=0 \
    -drive if=none,file=/tmp/openbsd-7.9-x86-64.qcow2,id=drive0,cache=unsafe,discard=ignore \
    -device virtio-scsi-pci,drive=drive1,bootindex=1 \
    -drive if=none,file=/tmp/test0.qcow2,id=drive1,cache=unsafe,discard=ignore,format=qcow2 \
    -device virtio-scsi-pci,drive=drive2,bootindex=2 \
    -drive if=none,file=/tmp/test1.qcow2,id=drive2,cache=unsafe,discard=ignore,format=qcow2
```

## Contributing (Not Appliciable for the fork)

### Updating the Changelog

The changelog is maintained in the [changelog.md](changelog.md) file, following
the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. The
changelog is updated incrementally. That is, for every new feature or bugfix,
add an entry to the changelog under the `[Unreleased]` section using an
appropriate sub header (`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`,
or `Security`).

For example, when adding a new feature:

```markdown
## [Unreleased]
### Added
- Short description of the new feature
```

Entries under these sub headers determine the semantic version bump when the
next release is cut with [relog](https://github.com/jacob-carlborg/relog).

### Creating a New Release (NOT APPLICIABLE/ IGNORE)

Releases are cut with [relog](https://github.com/jacob-carlborg/relog), driven
by the `[Unreleased]` section of `changelog.md`. relog derives the next
version from the sub headers under `[Unreleased]`:

* `### Fixed` only -> patch bump
* `### Added`, `### Changed`, `### Deprecated` -> minor bump
* `### Removed` (or "Breaking" anywhere in the section) -> major bump

To cut a release, from a clean `master` working tree, run:

```
relog
```

To preview the changes without modifying anything:

```
relog --dry-run
```

To override the auto-detected version:

```
relog X.Y.Z
```

relog rewrites the changelog, commits the result, creates an annotated `vX.Y.Z`
tag, and prompts before pushing. Pushing the `vX.Y.Z` tag triggers the GitHub
Actions workflow defined in
[`.github/workflows/build.yml`](.github/workflows/build.yml), which builds the
VM images and, in the "Create Release" step, creates a draft GitHub release
using the newly added changelog section as the release notes. Review the draft
release on GitHub and publish it.
