#!/usr/bin/env bash
# Desktop rice — the parts that need root. Run with: sudo bash ~/.local/share/rice/sudo-setup.sh
set -euo pipefail
U=${SUDO_USER:?run this with sudo}; H=$(getent passwd "$U" | cut -d: -f6)
THEME=catppuccin-mocha-mauve-standard+default
WALL=$H/Pictures/Wallpapers/shaded_landscape.png

echo "==> 1/4 Packages: plank, rofi, conky, playerctl, gtop (system monitor applet), xdotool"
apt-get update -qq
apt-get install -y plank rofi conky-all playerctl gir1.2-gtop-2.0 xdotool

echo "==> 2/4 Login screen (slick-greeter): theme, icons, cursor, font, wallpaper"
cp -r "$H/.themes/$THEME" /usr/share/themes/
cp -r "$H/.icons/catppuccin-mocha-dark-cursors" /usr/share/icons/
# Mint ships an older Papirus whose symlinks point the opposite way to ours;
# --remove-destination replaces each file instead of writing through a link
for t in Papirus Papirus-Dark; do
  mkdir -p "/usr/share/icons/$t"
  cp -a --remove-destination "$H/.local/share/icons/$t/." "/usr/share/icons/$t/"
  chown -R root:root "/usr/share/icons/$t"
  gtk-update-icon-cache -q "/usr/share/icons/$t" 2>/dev/null || true
done
mkdir -p /usr/share/fonts/truetype/inter && cp "$H"/.local/share/fonts/Inter/*.ttf /usr/share/fonts/truetype/inter/
mkdir -p /usr/share/backgrounds/rice && cp "$WALL" /usr/share/backgrounds/rice/login.png
fc-cache -f >/dev/null
cat > /etc/lightdm/slick-greeter.conf <<EOF
[Greeter]
background=/usr/share/backgrounds/rice/login.png
draw-user-backgrounds=false
background-color=#1e1e2e
theme-name=$THEME
icon-theme-name=Papirus-Dark
cursor-theme-name=catppuccin-mocha-dark-cursors
cursor-theme-size=24
font-name=Inter Variable 11
draw-grid=false
show-hostname=true
clock-format=%H:%M  ·  %A %d %B
EOF

echo "==> 3/4 GRUB: Catppuccin Mocha theme, visible menu (5s), remember-able default"
tmp=$(mktemp -d)
git clone -q --depth 1 https://github.com/catppuccin/grub "$tmp/grub"
mkdir -p /usr/share/grub/themes
rm -rf /usr/share/grub/themes/catppuccin-mocha-grub-theme
cp -r "$tmp/grub/src/catppuccin-mocha-grub-theme" /usr/share/grub/themes/
rm -rf "$tmp"
cp /etc/default/grub /etc/default/grub.bak-rice
set_grub() { grep -q "^$1=" /etc/default/grub && sed -i "s|^$1=.*|$1=$2|" /etc/default/grub || echo "$1=$2" >> /etc/default/grub; }
set_grub GRUB_THEME '"/usr/share/grub/themes/catppuccin-mocha-grub-theme/theme.txt"'
set_grub GRUB_TIMEOUT_STYLE menu
set_grub GRUB_TIMEOUT 5
set_grub GRUB_DEFAULT saved
set_grub GRUB_GFXMODE 1920x1080,auto
update-grub

echo "==> 4/4 Helper for the power menu's 'Reboot to Windows'"
cat > /usr/local/sbin/reboot-to-windows <<'EOF'
#!/bin/sh
# Boot Windows once on the next restart (used by ~/.local/bin/rofi-power)
entry=$(grep -oP "menuentry '\KWindows[^']*" /boot/grub/grub.cfg | head -1)
[ -n "$entry" ] && grub-reboot "$entry"
EOF
chmod 755 /usr/local/sbin/reboot-to-windows

echo; echo "All done. (GRUB backup: /etc/default/grub.bak-rice)"
