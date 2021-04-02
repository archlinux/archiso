#!/usr/bin/env bash
#
# This script is run within a virtual environment to build the available archiso profiles and create checksum files for
# the resulting images.
# The script needs to be run as root and assumes $PWD to be the root of the repository.

readonly orig_pwd="${PWD}"
readonly output="${orig_pwd}/output"
tmpdir=""
tmpdir="$(mktemp --dry-run --directory --tmpdir="${orig_pwd}/tmp")"

cleanup() {
  # clean up temporary directories
  if [ -n "${tmpdir:-}" ]; then
    rm -rf "${tmpdir}"
  fi
}

create_checksums() {
  # create checksums for a file
  # $1: a file
  sha256sum "${1}" >"${1}.sha256"
  sha512sum "${1}" >"${1}.sha512"
  b2sum "${1}" >"${1}.b2"
  if [[ -n "${SUDO_UID:-}" ]] && [[ -n "${SUDO_GID:-}" ]]; then
    chown "${SUDO_UID}:${SUDO_GID}" "${1}"{,.b2,.sha{256,512}}
  fi
}

create_zsync_delta() {
  # create a zsync control file for a file
  # $1: a file
  zsyncmake -C -u "${1##*/}" -o "${1}".zsync "${1}"
  if [[ -n "${SUDO_UID:-}" ]] && [[ -n "${SUDO_GID:-}" ]]; then
    chown "${SUDO_UID}:${SUDO_GID}" "${1}".zsync
  fi
}

create_metrics() {
  # create metrics
  {
    printf 'image_size_mebibytes{image="%s"} %s\n' "${1}" "$(du -m "${output}/${1}/"*.iso | cut -f1)"
    printf 'package_count{image="%s"} %s\n' "${1}" "$(sort -u "${tmpdir}/${1}/iso/"*/pkglist.*.txt | wc -l)"
    if [[ -e "${tmpdir}/${1}/efiboot.img" ]]; then
      printf 'eltorito_efi_image_size_mebibytes{image="%s"} %s\n' \
        "${1}" "$(du -m "${tmpdir}/${1}/efiboot.img" | cut -f1)"
    fi
    # shellcheck disable=SC2046
    # shellcheck disable=SC2183
    printf 'initramfs_size_mebibytes{image="%s",initramfs="%s"} %s\n' \
      $(du -m "${tmpdir}/${1}/iso/"*/boot/**/initramfs*.img | awk -v profile="${1}" '
        function basename(file) {
          sub(".*/", "", file)
          return file
        }
        { print profile, basename($2), $1 }')
  } > "${output}/${1}/job-metrics"
}

run_mkarchiso() {
  # run mkarchiso
  # $1: template name
  mkdir -p "${output}/${1}" "${tmpdir}/${1}"
  ./archiso/mkarchiso -o "${output}/${1}" -w "${tmpdir}/${1}" -v "configs/${1}"
  create_checksums "${output}/${1}/"*.iso
  create_zsync_delta "${output}/${1}/"*.iso
  create_metrics "${1}"
}

trap cleanup EXIT

run_mkarchiso "${1}"
