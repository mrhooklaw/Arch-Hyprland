#!/usr/bin/env bash
set -euo pipefail

# hypr-quicksetup-safe.sh
# Safe, idempotent Hyprland starter setup for Arch.
# Run as normal user (not root): bash hypr-quicksetup-safe.sh

# ---------- helpers ----------
info(){ printf '\e[1;34m[INFO]\e[0m %s\n' "$*"; }
warn(){ printf '\e[1;33m[WARN]\e[0m %s\n' "$*"; }
err(){ printf '\e[1;31m[ERROR]\e[0m %s\n' "$*"; exit 1; }
bak(){ printf '.bak.%s' "$(date +%Y%m%d-%H%M%S)"; }

# Ensure running under bash
if [ -z "${BASH_VERSION:-}" ]; then
  err "This script requires bash. Run with: bash hypr-quicksetup-safe.sh"
fi

# Don't run as root
if [ "$EUID" -eq 0 ]; then
  err "Do NOT run as root. Run as your normal user (the script will use sudo where needed)."
fi

# Require pacman (Arch)
if ! command -v pacman >/dev/null 2>&1; then
  err "pacman not found. This script is for Arch Linux (or derivatives with pacman)."
fi

# ---------- packages (repo) ----------
REPO_PKGS=(swaybg waybar dunst rofi kitty thunar polkit-gnome \
           network-manager-applet pipewire pipewire-pulse wireplumber \
           grim slurp wl-clipboard mesa)

to_install=()
for pkg in "${REPO_PKGS[@]}"; do
  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    info "$pkg already installed"
  else
    to_install+=("$pkg")
  fi
done

if [ "${#to_install[@]}" -gt 0 ]; then
  info "Installing missing repo packages: ${to_install[*]}"
  sudo pacman -S --needed --noconfirm "${to_install[@]}"
else
  info "All repo packages already present."
fi

# ---------- AUR helper (yay) - install only if needed ----------
need_yay=0
if ! command -v yay >/dev/null 2>&1; then
  # we'll only install yay if we need it (for hyprland fallback)
  need_yay=1
fi

# ---------- hyprland install ----------
if pacman -Qi hyprland >/dev/null 2>&1; then
  info "hyprland already installed (pacman)."
else
  info "hyprland not found in pacman local DB. Attempting pacman first..."
  if sudo pacman -S --noconfirm hyprland >/dev/null 2>&1; then
    info "hyprland installed via pacman."
  else
    warn "pacman couldn't install hyprland (likely AUR or custom repo)."
    if ! command -v yay >/dev/null 2>&1; then
      info "Installing yay (AUR helper) because hyprland must be fetched from AUR or an external repo."
      # ensure base-devel and git are present
      sudo pacman -S --needed --noconfirm base-devel git
      tmpdir="$(mktemp -d)"
      git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
      (cd "$tmpdir/yay" && makepkg -si --noconfirm)
      rm -rf "$tmpdir"
      info "yay installed."
    fi
    info "Installing hyprland with yay (AUR)... this may take time."
    yay -S --noconfirm hyprland
  fi
fi

# ---------- config files (create only if missing) ----------
HYPRDIR="$HOME/.config/hypr"
WAYBARDIR="$HOME/.config/waybar"
mkdir -p "$HYPRDIR" "$WAYBARDIR"

# hyprland.conf (create only if not exist)
HYPR_CONF="$HYPRDIR/hyprland.conf"
if [ -e "$HYPR_CONF" ]; then
  info "$HYPR_CONF exists — leaving it alone (won't overwrite)."
else
  info "Creating default $HYPR_CONF"
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
fi

# waybar config (create only if missing)
WAYBAR_CONF="$WAYBARDIR/config"
WAYBAR_CSS="$WAYBARDIR/style.css"

if [ -e "$WAYBAR_CONF" ]; then
  info "$WAYBAR_CONF exists — leaving it alone."
else
  info "Creating default $WAYBAR_CONF"
  cat > "$WAYBAR_CONF" <<'WAYBARCONF'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["sway/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network"]
}
WAYBARCONF
fi

if [ -e "$WAYBAR_CSS" ]; then
  info "$WAYBAR_CSS exists — leaving it alone."
else
  info "Creating default $WAYBAR_CSS"
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
fi

# ---------- add autostart to ~/.bash_profile if missing (safe) ----------
BASH_PROFILE="$HOME/.bash_profile"
AUTOSTART_SNIPPET='if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
  exec Hyprland
fi'

if [ -f "$BASH_PROFILE" ]; then
  if grep -Fq 'exec Hyprland' "$BASH_PROFILE"; then
    info "Hyprland autostart snippet already present in $BASH_PROFILE"
  else
    info "Appending Hyprland autostart snippet to existing $BASH_PROFILE"
    printf '\n# Start Hyprland automatically on tty1\n%s\n' "$AUTOSTART_SNIPPET" >> "$BASH_PROFILE"
  fi
else
  info "Creating $BASH_PROFILE with Hyprland autostart snippet"
  printf '#!/usr/bin/env bash\n\n# Start Hyprland automatically on tty1\n%s\n' "$AUTOSTART_SNIPPET" > "$BASH_PROFILE"
  chmod 644 "$BASH_PROFILE"
fi

# ---------- enable services (idempotent) ----------
info "Enabling NetworkManager (system) and PipeWire (user) services"
sudo systemctl enable --now NetworkManager || warn "Failed to enable NetworkManager (check sudo privileges)"
systemctl --user enable --now pipewire wireplumber || warn "Failed to enable user PipeWire (may not be supported if running from live ISO)"

# ---------- summary ----------
info "Setup complete. Summary:"
info " - Hyprland installed: $(pacman -Qi hyprland >/dev/null 2>&1 && printf 'yes' || printf 'no')"
info " - Repo packages installed (checked individually)"
info " - Configs were created only if missing; existing configs were NOT overwritten."

cat <<'ACTION'

Next steps / recommended checks:
1) If you run into "Hyprland starts but blank screen", log into tty and run `Hyprland` manually to view stderr output.
2) To view what this script did, inspect these files:
   - ~/.config/hypr/hyprland.conf
   - ~/.config/waybar/config
   - ~/.config/waybar/style.css
   - ~/.bash_profile
3) If you want the script to forcibly overwrite configs (replace defaults), tell me and I will provide a version that backs up then overwrites.

How to run (safe):
  curl -fsSL 'https://your-host/raw/hypr-quicksetup-safe.sh' -o hypr-quicksetup-safe.sh
  sed -i 's/\r$//' hypr-quicksetup-safe.sh    # remove CRLF just in case
  less hypr-quicksetup-safe.sh               # inspect before running
  chmod +x hypr-quicksetup-safe.sh
  bash hypr-quicksetup-safe.sh

ACTION
