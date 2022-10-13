#!/bin/sh
set -e

hostname="archiso"
echo $hostname > /etc/hostname

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo -e 'en_US.UTF-8 UTF-8\nzh_CN.UTF-8 UTF-8' >> /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen

sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
pacman-key --init
pacman-key --populate

systemctl enable iwd
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable sshd

# setup dwm
git clone https://gitee.com/xundaoxd/dogeystamp-dmenu.git
(cd dogeystamp-dmenu && make && make install)
git clone https://gitee.com/xundaoxd/dogeystamp-st.git
(cd dogeystamp-st && make && make install)
git clone https://gitee.com/xundaoxd/archlinux-dwm.git
(cd archlinux-dwm && make && make install)

chsh -s /bin/zsh
cp /etc/X11/xinit/xinitrc /root/.xinitrc
sed -i '/^twm/,$d' /root/.xinitrc
echo 'exec dwm' >> /root/.xinitrc
echo 'if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
  exec startx
fi' >> /root/.zprofile

