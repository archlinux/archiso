#!/usr/bin/env bash
#
# This script is run within a virtual environment to build the available archiso profiles and their available build
# modes and create checksum files for the resulting images.
# The script needs to be run as root and assumes $PWD to be the root of the repository.
#
# Dependencies:
# * all archiso dependencies
# * zsync
#
# $1: profile
# $2: buildmode

set -euo pipefail
shopt -s extglob

readonly orig_pwd="${PWD}"
readonly output="${orig_pwd}/output"
readonly profile="${1}"
readonly buildmode="${2}"
readonly install_dir="arch"

tmpdir=""
tmpdir="$(mktemp --dry-run --directory --tmpdir="${orig_pwd}/tmp")"
gnupg_homedir=""
codesigning_dir=""
codesigning_cert=""
codesigning_key=""
pgp_key_id=""

cleanup() {
  # clean up temporary directories

  # gitlab collapsable sections start
  printf "\e[0Ksection_start:%(%s)T:cleanup\r\e[0KCleaning up temporary directory"

  if [ -n "${tmpdir:-}" ]; then
    rm -rf "${tmpdir}"
  fi

  # gitlab collapsable sections end
  printf "\e[0Ksection_end:%(%s)T:cleanup\r\e[0K"
}

create_checksums() {
  # create checksums for files
  # $@: files
  local _file

  # gitlab collapsable sections start
  printf "\e[0Ksection_start:%(%s)T:checksums\r\e[0KCreating checksums"

  for _file in "$@"; do
    md5sum "${_file}" >"${_file}.md5"
    sha1sum "${_file}" >"${_file}.sha1"
    sha256sum "${_file}" >"${_file}.sha256"
    sha512sum "${_file}" >"${_file}.sha512"
    b2sum "${_file}" >"${_file}.b2"

    if [[ -n "${SUDO_UID:-}" ]] && [[ -n "${SUDO_GID:-}" ]]; then
      chown "${SUDO_UID}:${SUDO_GID}" -- "${_file}"{,.b2,.sha{256,512}}
    fi
  done

  # gitlab collapsable sections end
  printf "\e[0Ksection_end:%(%s)T:checksums\r\e[0K"
}

create_zsync_delta() {
  # create zsync control files for files
  # $@: files
  local _file

  # gitlab collapsable sections start
  printf "\e[0Ksection_start:%(%s)T:zsync_delta\r\e[0KCreating zsync delta"
  for _file in "$@"; do
    if [[ "${buildmode}" == "bootstrap" ]]; then
      # zsyncmake fails on 'too long between blocks' with default block size on bootstrap image
      zsyncmake -b 512 -C -u "${_file##*/}" -o "${_file}".zsync "${_file}"
    else
      zsyncmake -C -u "${_file##*/}" -o "${_file}".zsync "${_file}"
    fi
    if [[ -n "${SUDO_UID:-}" ]] && [[ -n "${SUDO_GID:-}" ]]; then
      chown "${SUDO_UID}:${SUDO_GID}" -- "${_file}"{,.zsync}
    fi
  done

  # gitlab collapsable sections end
  printf "\e[0Ksection_end:%(%s)T:zsync_delta\r\e[0K"
}

create_metrics() {
  # create metrics

  # gitlab collapsable sections start
  printf "\e[0Ksection_start:%(%s)T:metrics\r\e[0KCreating metrics"

  {
    # create metrics based on buildmode
    case "${buildmode}" in
      iso)
        printf 'image_size_mebibytes{image="%s"} %s\n' \
          "${profile}" \
          "$(du -m -- "${output}/${profile}/"*.iso | cut -f1)"
        printf 'package_count{image="%s"} %s\n' \
          "${profile}" \
          "$(sort -u -- "${tmpdir}/${profile}/iso/"*/pkglist.*.txt | wc -l)"
        if [[ -e "${tmpdir}/${profile}/efiboot.img" ]]; then
          printf 'eltorito_efi_image_size_mebibytes{image="%s"} %s\n' \
            "${profile}" \
            "$(du -m -- "${tmpdir}/${profile}/efiboot.img" | cut -f1)"
        fi
        # shellcheck disable=SC2046
        # shellcheck disable=SC2183
        printf 'initramfs_size_mebibytes{image="%s",initramfs="%s"} %s\n' \
          $(du -m -- "${tmpdir}/${profile}/iso/"*/boot/**/initramfs*.img | \
            awk -v profile="${profile}" \
            'function basename(file) {
              sub(".*/", "", file)
              return file
            }
            { print profile, basename($2), $1 }'
          )
        ;;
      netboot)
        printf 'netboot_size_mebibytes{image="%s"} %s\n' \
          "${profile}" \
          "$(du -m -- "${output}/${profile}/${install_dir}/" | tail -n1 | cut -f1)"
        printf 'netboot_package_count{image="%s"} %s\n' \
          "${profile}" \
          "$(sort -u -- "${tmpdir}/${profile}/iso/"*/pkglist.*.txt | wc -l)"
        ;;
      bootstrap)
        printf 'bootstrap_size_mebibytes{image="%s"} %s\n' \
          "${profile}" \
          "$(du -m -- "${output}/${profile}/"*.tar*(.gz|.xz|.zst) | cut -f1)"
        printf 'bootstrap_package_count{image="%s"} %s\n' \
          "${profile}" \
          "$(sort -u -- "${tmpdir}/${profile}/"*/bootstrap/root.*/pkglist.*.txt | wc -l)"
        ;;
    esac
  } > "${output}/${profile}/job-metrics"

  # gitlab collapsable sections end
  printf "\e[0Ksection_end:%(%s)T:metrics\r\e[0K"
}

create_ephemeral_pgp_key() {
  # create an ephemeral PGP key for signing the rootfs image

  # gitlab collapsable sections start
  printf "\e[0Ksection_start:%(%s)T:ephemeral_pgp_key\r\e[0KCreating ephemeral PGP key"

  gnupg_homedir="$tmpdir/.gnupg"
  mkdir -p "${gnupg_homedir}"
  chmod 700 "${gnupg_homedir}"

  cat << __EOF__ > "${gnupg_homedir}"/gpg.conf
quiet
batch
no-tty
no-permission-warning
export-options no-export-attributes,export-clean
list-options no-show-keyring
armor
no-emit-version
__EOF__

  gpg --homedir "${gnupg_homedir}" --gen-key <<EOF
%echo Generating ephemeral Arch Linux release engineering key pair...
Key-Type: default
Key-Length: 3072
Key-Usage: sign
Name-Real: Arch Linux Release Engineering
Name-Comment: Ephemeral Signing Key
Name-Email: arch-releng@lists.archlinux.org
Expire-Date: 0
%no-protection
%commit
%echo Done
EOF

  pgp_key_id="$(
    gpg --homedir "${gnupg_homedir}" \
        --list-secret-keys \
        --with-colons \
        | awk -F':' '{if($1 ~ /sec/){ print $5 }}'
  )"

  # gitlab collapsable sections end
  printf "\e[0Ksection_end:%(%s)T:ephemeral_pgp_key\r\e[0K"
}

create_ephemeral_codesigning_key() {
  # create ephemeral certificates used for codesigning

  # gitlab collapsable sections start
  printf "\e[0Ksection_start:%(%s)T:ephemeral_codesigning_key\r\e[0KCreating ephemeral codesigning key"

  codesigning_dir="${tmpdir}/.codesigning/"
  local codesigning_conf="${codesigning_dir}/openssl.cnf"
  local codesigning_subj="/C=DE/ST=Berlin/L=Berlin/O=Arch Linux/OU=Release Engineering/CN=archlinux.org"
  codesigning_cert="${codesigning_dir}/codesign.crt"
  codesigning_key="${codesigning_dir}/codesign.key"
  mkdir -p "${codesigning_dir}"
  cp -- /etc/ssl/openssl.cnf "${codesigning_conf}"
  printf "\n[codesigning]\nkeyUsage=digitalSignature\nextendedKeyUsage=codeSigning\n" >> "${codesigning_conf}"
  openssl req \
      -newkey rsa:4096 \
      -keyout "${codesigning_key}" \
      -nodes \
      -sha256 \
      -x509 \
      -days 365 \
      -out "${codesigning_cert}" \
      -config "${codesigning_conf}" \
      -subj "${codesigning_subj}" \
      -extensions codesigning

  # gitlab collapsable sections end
  printf "\e[0Ksection_end:%(%s)T:ephemeral_codesigning_key\r\e[0K"
}

run_mkarchiso() {
  # run mkarchiso

  # gitlab collapsable sections start
  printf "\e[0Ksection_start:%(%s)T:mkarchiso\r\e[0KRunning mkarchiso"

  create_ephemeral_pgp_key
  create_ephemeral_codesigning_key

  mkdir -p "${output}/${profile}" "${tmpdir}/${profile}"
  GNUPGHOME="${gnupg_homedir}" ./archiso/mkarchiso \
      -D "${install_dir}" \
      -c "${codesigning_cert} ${codesigning_key}" \
      -g "${pgp_key_id}" \
      -o "${output}/${profile}" \
      -w "${tmpdir}/${profile}" \
      -m "${buildmode}" \
      -v "configs/${profile}"

  # gitlab collapsable sections end
  printf "\e[0Ksection_end:%(%s)T:mkarchiso\r\e[0K"

  if [[ "${buildmode}" =~ "iso" ]]; then
    create_zsync_delta "${output}/${profile}/"*.iso
    create_checksums "${output}/${profile}/"*.iso
  fi
  if [[ "${buildmode}" == "bootstrap" ]]; then
    create_zsync_delta "${output}/${profile}/"*.tar*(.gz|.xz|.zst)
    create_checksums "${output}/${profile}/"*.tar*(.gz|.xz|.zst)
  fi
  create_metrics
}

trap cleanup EXIT

run_mkarchiso
