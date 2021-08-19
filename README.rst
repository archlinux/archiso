About this fork
===============
This is a fork of archiso with support for creating aarch64 (ARM64) Arch Linux ARM (referred to as ALARM) generic UEFI ISOs.

Why?
----
I wanted to be able to easily install ALARM in a Parallels VM on my M1 Mac. This repo will allow anyone to fairly easily
create ALARM ISOs to be able to run in VMs on their aarch64 computers. It will almost certainly be helpful to people wanting
to install ALARM on their aarch64 computers that have UEFI firmwares that allow for booting from multiple storage devices
(e.g., devices that can boot from USB flash drives).

Changes here vs archiso
-----------------------
- Modified `archiso/mkarchiso <archiso/mkarchiso/>`_ script with aarch64 support, removed hardcoded `ucodes` that are unavailable on aarch64
- Modified `configs/releng/pacman.conf <configs/releng/pacman.conf>`_ to remove packages that are unavailable on aarch64, and add ``linux-aarch64`` kernel
- Removed config files + systemd services for packages have been removed
- Updated various files with aarch64 branding (e.g., replace "x64" strings with "aarch64")
- Replace x64 Arch Linux specific config files with ALARM versions (e.g., use ALARM pacman config + mirrorlist)
- Add new `journald.conf.d <configs/releng/airootfs/etc/systemd/journald.conf.d>`_ config "`audit.conf <configs/releng/airootfs/etc/systemd/journald.conf.d/audit.conf>`_" to disable outputting audit messages to the Linux TTY
   - TTY would otherwise get filled with audit messages, which would make it very hard to install ALARM
- Move archiso ``initcpio`` files directly into the `releng airootfs <configs/releng/airootfs>`_
   - Modified `archiso_kms <configs/releng/airootfs/usr/lib/initcpio/install/archiso_kms>`_ hooks to not show warnings
     when running archiso in the mkintcpio section, as there are modules which are unavailable in ``linux-aarch64``
   - Note: this fork is currently based off of the ``v57`` release, which is the last version that has these files included in
     in the archiso project. They have since been moved `here <https://gitlab.archlinux.org/mkinitcpio/mkinitcpio-archiso/>`_,
     as x64 Arch Linux now has those files added to the ISO through the ``mkinitcpio-archiso`` package. This package *IS* available
     from the ALARM packages (as the package is flagged as "any" architecture), however those files can't be modified with the changes
     noted above. Maybe at some point the changes can get merged upstream or an ALARM-specifc fork can be created,
     but for now, having them inside the ``airootfs`` is fine

Check the commits to this repo to see all the changes.

How to use?
-----------
**Note: I will occasionally push new ISOs to the releases section of this repository, so if you don't want
to build the ISO yourself, check there first**

*I assume these commands are being run from an existing Arch Linux install, whether that be x64 or ARM)*

1. Install the packages mentioned in `Requirements`_. Note that you don't need the virtualized test environment packages.
2. ``git clone`` this repository and ``cd`` into it
3. run ``sudo ./archiso/mkarchiso -v configs/releng``. This will download all the packages and build the ISO
4. You can find the generated ISO in in `work <work/>`_ once it has been built
5. If you want to run it again (e.g., you want to build a more up-to-date ISO, or you want to add packages to be installed
   to the ISO), first run ``sudo rm -rf work`` and ``sudo rm -rf out`` to delete the working tree and ISO.
   Then re-run from step #3.

**The original README for archiso continues below:**
====================================================

archiso
=======

The archiso project features scripts and configuration templates to build installation media (*.iso* images and
*.tar.gz* bootstrap images) as well as netboot artifacts for BIOS and UEFI based systems on the x86_64 architecture.
Currently creating the images is only supported on Arch Linux but may work on other operating systems as well.

Requirements
============

The following packages need to be installed to be able to create an image with the included scripts:

* arch-install-scripts
* awk
* dosfstools
* e2fsprogs
* erofs-utils (optional)
* findutils
* gzip
* libarchive
* libisoburn
* mtools
* openssl
* pacman
* sed
* squashfs-tools

For running the images in a virtualized test environment the following packages are required:

* edk2-ovmf
* qemu

For linting the shell scripts the following package is required:

* shellcheck

Profiles
========

Archiso comes with two profiles: **baseline** and **releng**. While both can serve as starting points for creating
custom live media, **releng** is used to create the monthly installation medium.
They can be found below `configs/baseline/ <configs/baseline/>`_  and `configs/releng/ <configs/releng/>`_
(respectively). Both profiles are defined by files to be placed into overlays (e.g. airootfs ‎→‎ the image's ``/``).

Read `README.profile.rst <docs/README.profile.rst>`_ to learn more about how to create profiles.

Create images
=============

Usually the archiso tools are installed as a package. However, it is also possible to clone this repository and create
images without installing archiso system-wide.

As filesystems are created and various mount actions have to be done when creating an image, **root** is required to run
the scripts.

When archiso is installed system-wide and the modification of a profile is desired, it is necessary to copy it to a
writeable location, as ``/usr/share/archiso`` is tracked by the package manager and only writeable by root (changes will
be lost on update).

The examples below will assume an unmodified profile in a system location (unless noted otherwise).

It is advised to consult the help output of **mkarchiso**:

.. code:: sh

   mkarchiso -h

Create images with packaged archiso
-----------------------------------

.. code:: sh

   mkarchiso -w path/to/work_dir -o path/to/out_dir path/to/profile

Create images with local clone
------------------------------

Clone this repository and run:

.. code:: sh

   ./archiso/mkarchiso -w path/to/work_dir -o path/to/out_dir path/to/profile

Testing
=======

The convenience script **run_archiso** is provided to boot into the medium using qemu.
It is advised to consult its help output:

.. code:: sh

   run_archiso -h

Run the following to boot the iso using BIOS:

.. code:: sh

   run_archiso -i path/to/an/arch.iso

Run the following to boot the iso using UEFI:

.. code:: sh

   run_archiso -u -i path/to/an/arch.iso

The script can of course also be executed from this repository:


.. code:: sh

   ./scripts/run_archiso.sh -i path/to/an/arch.iso

Installation
============

To install archiso system-wide use the included ``Makefile``:

.. code:: sh

   make install

Optionally install archiso's mkinitcpio hooks:

.. code:: sh

   make install-initcpio

Optional features

The iso image contains a GRUB environment block holding the iso name and version. This allows to
boot the iso image from GRUB with a version specific cow directory to mitigate overlay clashes.

.. code:: sh
     loopback loop archlinux.iso
     load_env -f (loop)/arch/grubenv
     linux (loop)/arch/boot/x86_64/vmlinuz-linux ... \
         cow_directory=${NAME}/${VERSION} ...
     initrd (loop)/arch/boot/x86_64/initramfs-linux-lts.img

Contribute
==========

Development of archiso takes place on Arch Linux' Gitlab: https://gitlab.archlinux.org/archlinux/archiso.

Please read our distribution-wide `Code of Conduct <https://wiki.archlinux.org/title/Code_of_conduct>`_ before
contributing, to understand what actions will and will not be tolerated.

Read our `contributing guide <CONTRIBUTING.rst>`_ to learn more about how to provide fixes or improvements for the code
base.

Discussion around archiso takes place on the `arch-releng mailing list
<https://lists.archlinux.org/listinfo/arch-releng>`_ and in `#archlinux-releng
<ircs://irc.libera.chat/archlinux-releng>`_ on `Libera Chat <https://libera.chat/>`_.

All past and present authors of archiso are listed in `AUTHORS <AUTHORS.rst>`_.

Releases
========

`Releases of archiso <https://gitlab.archlinux.org/archlinux/archiso/-/tags>`_ are created by its current maintainer
`David Runge <https://gitlab.archlinux.org/dvzrv>`_. Tags are signed using the PGP key with the ID
``C7E7849466FE2358343588377258734B41C31549``.

To verify a tag, first import the relevant PGP key:

.. code:: sh

  gpg --auto-key-locate wkd --search-keys dvzrv@archlinux.org


Afterwards a tag can be verified from a clone of this repository:

.. code:: sh

  git verify-tag <tag>

License
=======

Archiso is licensed under the terms of the **GPL-3.0-or-later** (see `LICENSE <LICENSE>`_).
