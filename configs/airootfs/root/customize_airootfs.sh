#!/bin/sh
set -e

hostname="archiso"
echo $hostname > /etc/hostname

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo -e 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen

sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
pacman-key --init
pacman-key --populate

usermod -aG wheel,input,video,audio,kvm xundaoxd
sed -E -i '/^#\s*%wheel.*NOPASSWD/{s/^#\s*//}' /etc/sudoers

systemctl enable NetworkManager
systemctl enable sddm
systemctl enable sshd

systemctl enable libvirtd
sed -i 's/^#unix_sock_group/#unix_sock_group/;s/^#unix_sock_rw_perms/unix_sock_rw_perms/' /etc/libvirt/libvirtd.conf
usermod -aG libvirt xundaoxd

