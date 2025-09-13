#!/usr/bin/env bash
set -euo pipefail

# Reset Hyprland and related configs safely

CONFIG_DIR="$HOME/.config"

echo "[INFO] Resetting Hyprland configs..."

# Remove old configs if they exist
rm -rf "$CONFIG_DIR/hypr" "$CONFIG_DIR/waybar" "$CONFIG_DIR/kitty" "$CONFIG_DIR/dunst"

mkdir -p "$CONFIG_DIR/hypr" "$CONFIG_DIR/waybar" "$CONFIG_DIR/kitty" "$CONFIG_DIR/dunst"

#####################
# Hyprland config
#####################
cat > "$CONFIG_DIR/hypr/hyprland.conf" <<'EOF'
# Hyprland base config (safe version, no blur)

general {
    gaps_in = 5
    gaps_out = 15
    border_size = 2
    col.active_border = rgb(88c0d0)
    col.inactive_border = rgb(4c566a)
}

decoration {
    rounding = 8
}

animations {
    enabled = yes
}

exec-once = waybar &
exec-once = dunst &
exec-once = nm-applet &
EOF

#####################
# Waybar config
#####################
mkdir -p "$CONFIG_DIR/waybar"

cat > "$CONFIG_DIR/waybar/config.jsonc" <<'EOF'
{
  "layer": "top",
  "modules-left": ["clock"],
  "modules-center": ["window"],
  "modules-right": ["network", "battery"],
  "clock": { "format": "%Y-%m-%d %H:%M:%S" },
  "network": { "format-wifi": "{essid} {signalStrength}%" },
  "battery": { "format": "{capacity}% {icon}" }
}
EOF

cat > "$CONFIG_DIR/waybar/style.css" <<'EOF'
* {
  font-family: JetBrainsMono, monospace;
  font-size: 13px;
}
window#waybar {
  background: #2e3440;
  color: #eceff4;
}
#clock, #network, #battery {
  padding: 0 10px;
}
EOF

#####################
# Kitty config
#####################
mkdir -p "$CONFIG_DIR/kitty"

cat > "$CONFIG_DIR/kitty/kitty.conf" <<'EOF'
font_family JetBrainsMono
font_size 12
background_opacity 0.95
EOF

#####################
# Dunst config
#####################
mkdir -p "$CONFIG_DIR/dunst"

cat > "$CONFIG_DIR/dunst/dunstrc" <<'EOF'
[global]
    font = JetBrainsMono 10
    frame_width = 2
    separator_height = 2
    padding = 8
    horizontal_padding = 8
    transparency = 0
    corner_radius = 6
    monitor = 0
    follow = mouse

[urgency_low]
    background = "#3b4252"
    foreground = "#d8dee9"
    frame_color = "#88c0d0"

[urgency_normal]
    background = "#4c566a"
    foreground = "#eceff4"
    frame_color = "#81a1c1"

[urgency_critical]
    background = "#bf616a"
    foreground = "#eceff4"
    frame_color = "#bf616a"
EOF

echo "[DONE] Hyprland environment reset successfully!"
