#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/ODY92/dotfiles.git"
GITDIR="$HOME/.dotfiles"
dot() { git --git-dir="$GITDIR" --work-tree="$HOME" "$@"; }

sudo pacman -S --needed --noconfirm git base-devel

# paru (déjà présent sur CachyOS)
if ! command -v paru >/dev/null; then
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
fi

# Récupération des dotfiles
[ -d "$GITDIR" ] || git clone --bare "$REPO" "$GITDIR"
dot config status.showUntrackedFiles no

# Sauvegarde des fichiers existants qui seraient écrasés (sur le NOUVEL appareil)
BK="$HOME/.dotfiles-backup/$(date +%F-%H%M%S)"
dot ls-tree -r --name-only HEAD | while read -r f; do
  if [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; then
    mkdir -p "$BK/$(dirname "$f")"; mv "$HOME/$f" "$BK/$f"
  fi
done
dot checkout

# Paquets (on ignore ceux absents des dépôts, ex. paquets CachyOS sur Arch)
L="$HOME/.config/dotfiles"
grep -vE '^(linux-cachyos|cachyos-)' "$L/pkgs-native.txt" \
  | while read -r p; do pacman -Si "$p" &>/dev/null && echo "$p"; done \
  | sudo pacman -S --needed --noconfirm -
paru -S --needed --noconfirm - < "$L/pkgs-aur.txt" || true

if command -v flatpak >/dev/null && [ -s "$L/flatpak.txt" ]; then
  xargs -a "$L/flatpak.txt" flatpak install -y --noninteractive flathub || true
fi

# Sélecteur de fonds d'écran (dépôt externe utilisé par wp-picker-toggle)
[ -d "$HOME/.config/qs-wallpaperpicker-github" ] || \
  git clone https://github.com/dhrruvsharma/qs-wallpaperpicker "$HOME/.config/qs-wallpaperpicker-github"

echo "Terminé. Redémarre ta session (ou reboot)."
