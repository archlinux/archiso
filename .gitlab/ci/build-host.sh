#!/usr/bin/env bash
#
# This script runs a build script in a QEMU VM using the latest Arch Linux installation medium.
# The build script is expected to create an './output' directory in the project's directory (when running in the VM) and
# place any build artifacts there.
# After the build script has finished this script will copy all artifacts to a (local) './output' directory and shutdown
# the VM.
#
# Dependencies:
# - coreutils
# - curl
# - libarchive
# - qemu-headless
# - util-linux
#
# Considered environment variables:
# ARCHISO_COW_SPACE_SIZE: The amount of RAM to allocate for the copy-on-write space used by archiso (defaults to 1g -
# see https://man.archlinux.org/man/tmpfs.5 for understood units)
# ARCHITECTURE: A string to set the CPU architecture (defaults to x86_64)
# BUILD_SCRIPT: A script that will be called on the host (defaults to ./build-inside-vm.sh)
# BUILD_SCRIPT_ARGS: The arguments to BUILD_SCRIPT (as a space delimited list)
# PACKAGE_LIST: A space delimited list of packages to install to the virtual machine
# PACMAN_MIRROR: The pacman mirror to use (defaults to "https://mirror.pkgbuild.com")
# QEMU_DISK_SIZE: A string given to fallocate to create a scratch disk to build in (defaults to 8G - see
# https://man.archlinux.org/man/fallocate.1 for understood units)
# QEMU_VM_MEMORY: The amount of RAM (in MiB) allocated for the QEMU virtual machine (defaults to 1024)
# QEMU_LOGIN_TIMEOUT: The maximum time (in seconds) to wait for the initial prompt in the VM to appear (defaults to 60)
# QEMU_PACKAGES_TIMEOUT: The maximum time (in seconds) to wait for output from pacman when installing packages (defaults
# to 120)
# QEMU_BUILD_TIMEOUT: The maximum time (in seconds) to wait for output from the build script (defaults to 1800)
# QEMU_COPY_ARTIFACTS_TIMEOUT: The maximum time (in seconds) to wait for output from the action of copying the build
# artifacts from the VM to a local directory (defaults to 60)


set -euo pipefail

readonly orig_pwd="${PWD}"
readonly output="${PWD}/output"

# variables with presets/ environmental overrides
arch="${ARCHITECTURE:-x86_64}"
script="${BUILD_SCRIPT:-./build-inside-vm.sh}"
script_args="${BUILD_SCRIPT_ARGS:-}"
mirror="${PACMAN_MIRROR:-https://mirror.pkgbuild.com}"
disk_size="${QEMU_DISK_SIZE:-8G}"
vm_memory="${QEMU_VM_MEMORY:-1024}"
login_timeout="${QEMU_LOGIN_TIMEOUT:-60}"
packages_timeout="${QEMU_PACKAGES_TIMEOUT:-120}"
build_timeout="${QEMU_BUILD_TIMEOUT:-1800}"
copy_artifacts_timeout="${QEMU_COPY_ARTIFACTS_TIMEOUT:-60}"
cow_space_size="${ARCHISO_COW_SPACE_SIZE:-1g}"
packages="${PACKAGE_LIST:-}"

# variables without presets/ environmental overrides
iso=""
iso_volume_id=""
tmpdir=""
tmpdir="$(mktemp --dry-run --directory --tmpdir="${PWD}/tmp")"

print_section_start() {
  # gitlab collapsible sections start: https://docs.gitlab.com/ee/ci/jobs/#custom-collapsible-sections
  local _section _title
  _section="${1}"
  _title="${2}"

  printf "\e[0Ksection_start:%(%s)T:%s\r\e[0K%s\n" '-1' "${_section}" "${_title}"
}

print_section_end() {
  # gitlab collapsible sections end: https://docs.gitlab.com/ee/ci/jobs/#custom-collapsible-sections
  local _section
  _section="${1}"

  printf "\e[0Ksection_end:%(%s)T:%s\r\e[0K\n" '-1' "${_section}"
}

init() {
  print_section_start "create_dirs" "Create required directories"

  mkdir -p "${output}" "${tmpdir}"
  cd "${tmpdir}"

  print_section_end "create_dirs"
}

# Do some cleanup when the script exits
cleanup() {
  print_section_start "cleanup" "Cleaning up"

  rm -rf -- "${tmpdir}"
  jobs -p | xargs --no-run-if-empty kill

  print_section_end "cleanup"
}
trap cleanup EXIT

# Use local Arch iso or download the latest iso and extract the relevant files
prepare_boot() {
  local _latest_iso _iso
  local _isos=()

  print_section_start "prepare_boot" "Prepare boot media"

  # retrieve any local images and sort them
  for _iso in "${orig_pwd}/"archlinux-*-"${arch}.iso"; do
    if [[ -f "${_iso}" ]]; then
      _isos+=("${_iso}")
    fi
  done
  if (( ${#_isos[@]} >= 1 )); then
    iso="$(printf '%s\n' "${_isos[@]}" | sort -r | head -n1)"
    printf "Using local iso: %s\n" "$iso"
  fi

  if (( ${#_isos[@]} < 1 )); then
    _latest_iso="$(
        curl -fs "${mirror}/iso/latest/" | \
        grep -Eo "archlinux-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-${arch}.iso" | \
        head -n 1
    )"
    if [[ -z "${_latest_iso}" ]]; then
      echo "Error: Could not find latest iso"
      exit 1
    fi
    curl -fO "${mirror}/iso/latest/${_latest_iso}"
    iso="${PWD}/${_latest_iso}"
  fi

  # Extract the kernel and initrd so that a custom kernel cmdline can be set:
  # console=ttyS0, so that the kernel and systemd send output to the serial.
  bsdtar -x -f "${iso}" -C . "arch/boot/${arch}"
  iso_volume_id="$(blkid -s LABEL -o value "${iso}")"

  print_section_end "prepare_boot"
}

start_qemu() {
  local _kernel_params=(
    "archisobasedir=arch"
    "archisolabel=${iso_volume_id}"
    "cow_spacesize=${cow_space_size}"
    "ip=dhcp"
    "net.ifnames=0"
    "console=ttyS0"
    "mirror=${mirror}"
  )

  print_section_start "start_qemu" "Start VM using QEMU"

  # Used to communicate with qemu
  mkfifo guest.out guest.in
  # We could use a sparse file but we want to fail early
  fallocate -l "${disk_size}" scratch-disk.img

  { qemu-system-x86_64 \
    -machine accel=kvm:tcg \
    -smp "$(nproc)" \
    -m "${vm_memory}" \
    -device virtio-net-pci,romfile=,netdev=net0 \
    -netdev user,id=net0 \
    -kernel "arch/boot/${arch}/vmlinuz-linux" \
    -initrd "arch/boot/${arch}/initramfs-linux.img" \
    -append "${_kernel_params[*]}" \
    -drive file=scratch-disk.img,format=raw,if=virtio \
    -drive "file=${iso},format=raw,if=virtio,media=cdrom,read-only=on" \
    -virtfs "local,path=${orig_pwd},mount_tag=host,security_model=none" \
    -monitor none \
    -serial pipe:guest \
    -nographic || kill "${$}"; } &

  # We want to send the output to both stdout (fd1) and fd10 (used by the expect function)
  exec 3>&1 10< <(tee /dev/fd/3 <guest.out)

  print_section_end "start_qemu"
}

# Wait for a specific string from qemu
expect() {
  local length="${#1}"
  local i=0
  local timeout="${2:-30}"
  # We can't use ex: grep as we could end blocking forever, if the string isn't followed by a newline
  while true; do
    # read should never exit with a non-zero exit code,
    # but it can happen if the fd is EOF or it times out
    IFS= read -r -u 10 -n 1 -t "${timeout}" c
    if [[ "${1:${i}:1}" = "${c}" ]]; then
      i="$((i + 1))"
      if [[ "${length}" -eq "${i}" ]]; then
        break
      fi
    else
      i=0
    fi
  done
}

# Send string to qemu
send() {
  echo -en "${1}" >guest.in
}

main() {
  local _pacman_command=(
    "pacman -Fy &&"
    "pacman -Syu --ignore"
    "\$(pacman -Fq --machinereadable /usr/lib/modules/"
    "| awk 'BEGIN { FS =\"\\\0\";ORS=\",\" }; { print \$2 }'"
    "| sort -ut , | head -c -2)"
    "--noconfirm --needed ${packages}\n"
  )

  init
  prepare_boot
  start_qemu

  print_section_start "init_build_environment" "Initialize build environment"

  # Login
  expect "archiso login:" "${login_timeout}"
  send "root\n"
  expect "# "

  # Switch to bash and shutdown on error
  send "bash\n"
  expect "# "
  send "trap \"shutdown now\" ERR\n"
  expect "# "

  # Prepare environment
  send "mkdir /mnt/project && mount -t 9p -o trans=virtio host /mnt/project -oversion=9p2000.L\n"
  expect "# "
  send "mkfs.ext4 /dev/vda && mkdir /mnt/scratch-disk/ && mount /dev/vda /mnt/scratch-disk && cd /mnt/scratch-disk\n"
  expect "# "
  send "rsync -a --exclude tmp --exclude .git -- /mnt/project/ .\n"
  expect "# "
  send "mkdir pkg && mount --bind pkg /var/cache/pacman/pkg\n"
  expect "# "

  # Wait for pacman-init
  send "until systemctl is-active pacman-init; do sleep 1; done\n"
  expect "# "

  # Explicitly lookup mirror address as we'd get random failures otherwise during pacman
  send "curl -sSo /dev/null ${mirror}\n"
  expect "# "

  print_section_end "init_build_environment"
  print_section_start "install_packages" "Install packages"

  if [[ -n "${packages}" ]]; then
    # Install required packages
    send "${_pacman_command[*]}"
    expect "# " "${packages_timeout}"
  fi

  print_section_end "install_packages"

  ## Start build and copy output to local disk
  send "bash -x ${script} ${script_args}\n "
  expect "# " "${build_timeout}"

  print_section_start "move_artifacts" "Move artifacts to output directory"

  send "rsync -av -- output /mnt/project/tmp/$(basename "${tmpdir}")/\n"
  expect "# " "${copy_artifacts_timeout}"
  mv -- output/* "${output}/"

  print_section_end "move_artifacts"
  print_section_start "shutdown" "Shutdown the VM"

  # Shutdown the VM
  send "systemctl poweroff -i\n"
  wait

  print_section_end "shutdown"
}

main
