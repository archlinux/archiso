#########
Changelog
#########

[55] - 2021-06-01
=================

Added
-----

- Add integration for pv when using the copytoram boot parameter so that progress on copying the image to RAM is shown
- Add experimental support for EROFS by using it for the rootfs image in the baseline profile

Changed
-------

- Change information on IRC channel, as Arch Linux moved to Libera Chat
- Fix a regression, that would prevent network interfaces to be configured under certain circumstances

[54] - 2021-05-13
=================

Added
-----

- Add the concept of buildmodes to mkarchiso, which allows for building more than the default .iso artifact
  (sequentially)
- Add support to mkarchiso and both baseline and releng profiles for building a bootstrap image (a compressed
  bootstrapped Arch Linux environment), by using the new buildmode `bootstrap`
- Add support to mkarchiso and both baseline and releng profiles for building artifacts required for netboot with iPXE
  (optionally allowing codesigning on the artifacts), by using the new buildmode `netboot`
- Add qemu-guest-agent and virtualbox-guest-utils-nox to the releng profile and enable their services by default to
  allow interaction between hypervisor and virtual machine if the installation medium is booted in a virtualized
  environment

Changed
-------

- Always use the .sig file extension when signing the rootfs image, as that is how mkinitcpio-archiso expects it
- Fix for CI and run_archiso scripts to be compatible with QEMU >= 6.0
- Increase robustness of CI by granting more time to reach the first prompt
- Change CI to build all available buildmodes of the baseline and releng profiles (baseline's netboot is currently
  excluded due to a bug)
- Install all implicitly installed packages explicitly for the releng profile
- Install keyrings more generically when using pacman-init.service
- Consolidate CI scripts so that they may be shared between the archiso, arch-boxes and releng project in the future and
  expose their configuration with the help of environment variables

[53] - 2021-05-01
=================

Added
-----

- Add ISO name to grubenv
- Add further metrics to CI, so that number of packages and further image sizes can be tracked
- Add IMAGE_ID and IMAGE_VERSION to /etc/os-release

Changed
-------

- Revert to an invalid GPT for greater hardware compatibility
- Fix CI scripts and initcpio script to comply with stricter shellcheck
- Fix an issue where writing to /etc/machine-id might override a file outside of the build directory
- Change gzip flags, so that compressed files are created reproducibly
- Increase default serial baud rate to 115200
- Remove deprecated documentation and format existing documentation

[52] - 2021-04-01
=================

Added
-----

- Add usbmuxd support
- Add EROFS support (as an experimental alternative to squashfs)
- Add creation of zsync control file for delta downloads
- Add sof-firmware for additional soundcard support
- Add support for recursively setting file permissions on folders using profiledef.sh
- Add support for mobile broadband devices with the help of modemmanager
- Add information on PGP signatures of tags
- Add archinstall support

Changed
-------

- Remove haveged
- Fix various things in relation to gitlab CI
- Change systemd-networkd files to more generically setup networkds for devices
- Fix the behavior of the `script=` kernel commandline parameter to follow redirects
- Change the amount of mirrors checked by reflector to 20 to speed up availability of the mirrorlist

[51] - 2021-02-01
=================

Added
-----

- VNC support for `run_archiso`
- SSH enabled by default in baseline and releng profiles
- Add cloud-init support to baseline and releng profiles
- Add simple port forwarding to `run_archiso` to allow testing of SSH
- Add support for loading cloud-init user data images to `run_archiso`
- Add version information to images generated with `mkarchiso`
- Use pacman hooks for things previously done in `customize_airootfs.sh` (e.g. generating locale, uncommenting mirror
  list)
- Add network setup for the baseline profile
- Add scripts for CI to build the baseline and releng profiles automatically

Changed
-------

- Change upstream URL in vendored profiles to archlinux.org
- Reduce the amount of sed calls in mkarchiso
- Fix typos in `mkarchiso`
- mkinitcpio-archiso: Remove resolv.conf before copy to circumvent its use
- Remove `customize_airootfs.sh` from the vendored profiles
- Support overriding more variables in `profiledef.sh` and refactor their use in `mkarchiso`
- Cleanup unused code in `run_archiso`
