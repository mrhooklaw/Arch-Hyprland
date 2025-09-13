#!/usr/bin/env bash
set -euo pipefail

# hypr-quicksetup.sh
# Run as normal user: bash hypr-quicksetup.sh

# Helpers
info(){ echo -e "\e[1;34m[INFO]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[WARN]\e[0m $*"; }
err(){ echo -e "\e[1;31m[ERROR]\e[0m $*"; exit 1; }

# Detect user
if [ "$EUID" -eq 0 ]; then
  err "Don't run as root. Use your normal user (script will sudo when needed)."
fi

# Check sudo
if ! command -v sudo >/dev/null 2>&1; then
  err "sudo required. Install sudo first."
fi

info "Updating system..."
sudo pacman -Syu --noconfirm

info "Installing core packages..."
sudo pacman -S --needed --noconfirm \
  swaybg waybar dunst rofi-wayland kitty thunar polkit-gnome \
  network-manager-applet pipewire pipewire-pulse wireplumber \
  grim slurp wl-clipboard mesa

# yay check
if ! command -v yay >/dev/null 2>&1; then
  info "Installing yay..."
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
else
  info "yay found"
fi

# Hyprland install
if pacman -Qi hyprland >/dev/null 2>&1; then
  info "Hyprland already installed (pacman)"
else
  info "Trying pacman install for Hyprland"
  if sudo pacman -S --noconfirm hyprland >/dev/null 2>&1; then
    info "Installed Hyprland from pacman"
  else
    warn "pacman failed, using yay (AUR)"
    yay -S --noconfirm hyprland
  fi
fi

info "Creating config dirs..."
mkdir -p ~/.config/hypr ~/.config/waybar

# hyprland.conf
cat > ~/.config/hypr/hyprland.conf <<'HYPRCONF'
monitor=,preferred,auto,1

exec-once = swaybg -i /usr/share/backgrounds/archlinux/archlinux-simplyblack.png -m fill
exec-once = waybar
exec-once = dunst
exec-once = nm-applet --indicator
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

bind = SUPER, RETURN, exec, kitty
bind = SUPER, Q, killactive
bind = SUPER, M, exit
bind = SUPER, D, exec, rofi -show drun
bind = SUPER, F, togglefloating
bind = SUPER, E, exec, thunar

bind = SUPER, H, movefocus, l
bind = SUPER, L, movefocus, r
bind = SUPER, K, movefocus, u
bind = SUPER, J, movefocus, d

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4

general {
    gaps_in = 5
    gaps_out = 15
    border_size = 2
    col.active_border = rgb(88c0d0)
    col.inactive_border = rgb(4c566a)
}

decoration {
    rounding = 8
    blur = yes
}

animations {
    enabled = yes
}
HYPRCONF

# waybar config
cat > ~/.config/waybar/config <<'WAYBARCONF'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["sway/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network"]
}
WAYBARCONF

cat > ~/.config/waybar/style.css <<'WAYBARCSS'
* {
  font-family: "DejaVu Sans", sans-serif;
  font-size: 12px;
  padding: 6px;
}
#clock {
  font-weight: 600;
}
WAYBARCSS

# Auto-start snippet
if ! grep -q 'exec Hyprland' ~/.bash_profile 2>/dev/null; then
cat >> ~/.bash_profile <<'BASHPROFILE'

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
  exec Hyprland
fi
BASHPROFILE
fi

# Services
sudo systemctl enable --now NetworkManager
systemctl --user enable --now pipewire wireplumber || true

info "✅ Setup finished. Reboot, log into tty1, and Hyprland should start."
