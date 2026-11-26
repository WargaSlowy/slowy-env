#!/usr/bin/env bash
set -euo pipefail

info() { printf '[info] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*" >&2; }
die()  { printf '[error] %s\n' "$*" >&2; exit 1; }

if ! command -v pacman >/dev/null 2>&1; then
  die "this installer is intended for Arch Linux (pacman not found)"
fi

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  die "run this script as a normal user, it will use sudo when needed"
fi

packages=(
  hyprland
  python
  pipewire
  pipewire-pulse
  networkmanager
  bluez
  bluez-utils
)

info "installing minimal requirements from official repos..."
sudo pacman -S --needed --noconfirm "${packages[@]}"

if command -v quickshell >/dev/null 2>&1; then
  info "quickshell is already installed"
else
  aur_helper=""
  for h in yay paru; do
    if command -v "$h" >/dev/null 2>&1; then
      aur_helper="$h"
      break
    fi
  done

  if [ -n "$aur_helper" ]; then
    info "installing quickshell with $aur_helper..."
    "$aur_helper" -S --needed --noconfirm quickshell-git
  else
    warn "quickshell was not installed"
    warn "install it with an AUR helper (for example: yay -S quickshell-git) or follow https://quickshell.outfoxxed.me/"
  fi
fi

info "enabling NetworkManager and bluetooth services..."
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth

info "done, minimal requirements are installed"
