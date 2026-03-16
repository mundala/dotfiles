#!/bin/bash
# ============================================
# Glassmorphism Dotfiles Install Script
# CachyOS / Arch + Hyprland
# ============================================

set -e

echo "🔮 Installing Glassmorphism Rice..."

# 1. Install dependencies
echo "📦 Installing packages..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm --needed \
    hyprland waybar kitty rofi rofi-wayland dunst \
    swww grim slurp wl-clipboard cliphist \
    thunar brightnessctl pavucontrol \
    nwg-look qt5ct papirus-icon-theme \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    pipewire pipewire-pulse wireplumber \
    networkmanager network-manager-applet \
    polkit-gnome xdg-desktop-portal-hyprland

# AUR packages
echo "📦 Installing AUR packages..."
yay -S --noconfirm \
    catppuccin-gtk-theme-mocha \
    catppuccin-cursors-mocha \
    hyprlock hypridle \
    rofi-power-menu

# 2. Create config dirs
echo "📁 Creating config directories..."
mkdir -p ~/.config/hypr
mkdir -p ~/.config/waybar
mkdir -p ~/.config/kitty
mkdir -p ~/.config/rofi
mkdir -p ~/.config/dunst
mkdir -p ~/Pictures/wallpapers

# 3. Copy dotfiles
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📋 Copying configs..."
cp "$DOTFILES_DIR/hypr/hyprland.conf"     ~/.config/hypr/
cp "$DOTFILES_DIR/waybar/config.jsonc"    ~/.config/waybar/config
cp "$DOTFILES_DIR/waybar/style.css"       ~/.config/waybar/style.css
cp "$DOTFILES_DIR/kitty/kitty.conf"       ~/.config/kitty/
cp "$DOTFILES_DIR/rofi/config.rasi"       ~/.config/rofi/config.rasi
cp "$DOTFILES_DIR/dunst/dunstrc"          ~/.config/dunst/dunstrc

# 4. Download a glassmorphism wallpaper
echo "🖼️  Setting up wallpaper..."
# Using a dark abstract wallpaper — swap with your own
curl -sL "https://raw.githubusercontent.com/catppuccin/wallpapers/main/minimalistic/cat-sound.png" \
    -o ~/Pictures/wallpapers/wallpaper.jpg 2>/dev/null || \
    echo "⚠️  Wallpaper download failed — add your own to ~/Pictures/wallpapers/wallpaper.jpg"

# Symlink wallpaper to hypr config dir
ln -sf ~/Pictures/wallpapers/wallpaper.jpg ~/.config/hypr/wallpaper.jpg

# 5. Enable services
echo "⚙️  Enabling services..."
systemctl --user enable --now pipewire
systemctl --user enable --now pipewire-pulse
systemctl --user enable --now wireplumber
sudo systemctl enable --now NetworkManager

# 6. Set GTK theme
echo "🎨 Setting GTK theme..."
gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-standard-mauve-dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-mocha-dark-cursors" 2>/dev/null || true
gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 11" 2>/dev/null || true

echo ""
echo "✅ Done! Glassmorphism rice installed."
echo ""
echo "Next steps:"
echo "  1. Log out and select Hyprland from your display manager"
echo "  2. Or run: Hyprland"
echo "  3. Super+Return = terminal"
echo "  4. Super+Shift+Return = app launcher"
echo "  5. Add your own wallpaper to ~/.config/hypr/wallpaper.jpg"
echo ""
echo "🔮 Enjoy your glass setup."
