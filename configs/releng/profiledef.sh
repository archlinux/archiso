#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="archlinuxarm"
iso_label="ARCH_AARCH64_$(date +%Y%m)"
iso_publisher="Jack Myers"
iso_application="Generic ARM64 Arch Linux Live/Rescue CD"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi-aarch64.systemd-boot.esp' 'uefi-aarch64.systemd-boot.eltorito')
arch="aarch64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'arm' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
)
