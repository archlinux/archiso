#########
Changelog
#########

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
