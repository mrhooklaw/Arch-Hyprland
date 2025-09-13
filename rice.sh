#!/usr/bin/env bash
set -euo pipefail

# hypr-quicksetup-reset.sh
# Force-reset Hyprland + Waybar configs to known-good defaults
# Run as normal user (not root)

info(){ printf '\e[1;34m[INFO]\e[0m %s\n' "$*"; }
warn(){ printf '\e[1;33m[WARN]\e[0m %s\n' "$*"; }
err(){ printf '\e[1;31m[ERROR]\e[0m %s\n' "$*"; exit 1; }
bak(){ printf '.bak.%s' "$(date +%Y%m%d-%H%M%S)"; }

# Require bash + Arch
if [ -z "${BASH_VERSION:-}" ]; then
  err "Run this script with bash."
fi
if [ "$EUID" -eq 0 ]; then
  err "Do NOT run as root. Use your normal user."
fi
command -v pacman >/dev/null 2>&1 || err "This script is for Arch Linux."

# ---------- Required packages ----------
REPO_PKGS=(swaybg waybar dunst rofi kitty thunar polkit-gnome \
           network-manager-applet pipewire pipewire-pulse wireplumber \
           grim slurp wl-clipboard mesa)

sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"

# ---------- Hyprland install ----------
if ! pacman -Qi hyprland >/dev/null 2>&1; then
  if ! sudo pacman -S --noconfirm hyprland; then
    warn "pacman hyprland failed, falling back to AUR (yay)"
    if ! command -v yay >/dev/null 2>&1; then
      sudo pacman -S --needed --noconfirm base-devel git
      tmpdir="$(mktemp -d)"
      git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
      (cd "$tmpdir/yay" && makepkg -si --noconfirm)
      rm -rf "$tmpdir"
    fi
    yay -S --noconfirm hyprland
  fi
fi

# ---------- Config reset ----------
HYPRDIR="$HOME/.config/hypr"
WAYBARDIR="$HOME/.config/waybar"
mkdir -p "$HYPRDIR" "$WAYBARDIR"

# Backup & overwrite Hyprland config
HYPR_CONF="$HYPRDIR/hyprland.conf"
if [ -f "$HYPR_CONF" ]; then
  mv "$HYPR_CONF" "$HYPR_CONF$(bak)"
  info "Backed up old hyprland.conf"
fi
cat > "$HYPR_CONF" <<'HYPRCONF'
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

# Backup & overwrite Waybar config
WAYBAR_CONF="$WAYBARDIR/config"
WAYBAR_CSS="$WAYBARDIR/style.css"
[ -f "$WAYBAR_CONF" ] && mv "$WAYBAR_CONF" "$WAYBAR_CONF$(bak)"
[ -f "$WAYBAR_CSS" ] && mv "$WAYBAR_CSS" "$WAYBAR_CSS$(bak)"

cat > "$WAYBAR_CONF" <<'WAYBARCONF'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["sway/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network"]
}
WAYBARCONF

cat > "$WAYBAR_CSS" <<'WAYBARCSS'
* {
  font-family: "DejaVu Sans", sans-serif;
  font-size: 12px;
  padding: 6px;
}
#clock {
  font-weight: 600;
}
WAYBARCSS

# ---------- Autostart in bash_profile ----------
PROFILE="$HOME/.bash_profile"
AUTOSTART_SNIPPET='if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
  exec Hyprland
fi'

if [ -f "$PROFILE" ]; then
  mv "$PROFILE" "$PROFILE$(bak)"
  info "Backed up old .bash_profile"
fi
printf '#!/usr/bin/env bash\n\n# Auto-start Hyprland on TTY1\n%s\n' "$AUTOSTART_SNIPPET" > "$PROFILE"

# ---------- Enable services ----------
sudo systemctl enable --now NetworkManager
systemctl --user enable --now pipewire wireplumber || warn "PipeWire user services may need a relogin"

info "Setup complete. Old configs were backed up, new ones written fresh."
