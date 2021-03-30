#########
Changelog
#########

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
