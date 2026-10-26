#!/usr/bin/env bash
set -euo pipefail

PROFILE=desktop
DRY_RUN=0
for argument in "$@"; do
    case "$argument" in
        --desktop) PROFILE=desktop ;;
        --full) PROFILE=full ;;
        --restore-only) PROFILE=restore ;;
        --dry-run) DRY_RUN=1 ;;
        --help|-h)
            echo 'Usage: bash install.sh [--desktop|--full|--restore-only] [--dry-run]'
            echo 'desktop: bureau et dépendances ; full: ajoute les applications du relevé ; restore-only: fichiers seuls.'
            exit 0 ;;
        *) echo "Option inconnue : $argument" >&2; exit 2 ;;
    esac
done

REPO=https://github.com/ODY92/dotfiles.git
GITDIR="$HOME/.dotfiles"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)-$$"
dot() { git -C "$HOME" --git-dir="$GITDIR" --work-tree="$HOME" "$@"; }

if (( DRY_RUN )); then
    printf 'Simulation : profil=%s\nDépôt : %s\nDestination : %s\nSauvegarde : %s\n' "$PROFILE" "$REPO" "$HOME" "$BACKUP"
    echo 'Étapes : dépendances, récupération de main, sauvegarde des fichiers remplacés, restauration, adaptation des chemins, copie Caelestia puis surcouche personnelle.'
    echo 'Aucun téléchargement, aucune installation ni modification en mode simulation.'
    exit 0
fi

if (( EUID == 0 )); then
    echo 'Lancer ce script avec un compte utilisateur normal disposant de sudo, pas avec root.' >&2
    exit 1
fi
command -v pacman >/dev/null || { echo 'Ce script nécessite Arch Linux ou une distribution compatible pacman.' >&2; exit 1; }
if [[ "$PROFILE" != restore ]]; then
    sudo pacman -Syu --needed git base-devel python
fi
command -v git >/dev/null
command -v python3 >/dev/null
if [[ ! -e "$GITDIR" ]]; then
    git clone --bare "$REPO" "$GITDIR"
else
    [[ "$(dot rev-parse --is-bare-repository)" == true ]] || { echo "$GITDIR n’est pas un dépôt bare." >&2; exit 1; }
    case "$(dot remote get-url origin)" in
        https://github.com/ODY92/dotfiles.git|https://github.com/ODY92/dotfiles|git@github.com:ODY92/dotfiles.git) ;;
        *) echo 'Le dépôt local ne correspond pas à ODY92/dotfiles ; arrêt.' >&2; exit 1 ;;
    esac
fi
dot fetch origin main:refs/remotes/origin/main
if dot show-ref --verify --quiet refs/heads/main; then
    dot merge-base --is-ancestor refs/heads/main refs/remotes/origin/main || { echo 'La branche locale contient des commits divergents ; les conserver et résoudre avant de restaurer.' >&2; exit 1; }
fi
dot update-ref refs/heads/main "$(dot rev-parse refs/remotes/origin/main)"
dot symbolic-ref HEAD refs/heads/main
dot config status.showUntrackedFiles no
mkdir -p "$BACKUP"
while IFS= read -r -d '' file; do
    if [[ -e "$HOME/$file" || -L "$HOME/$file" ]]; then
        mkdir -p "$BACKUP/$(dirname "$file")"
        mv -- "$HOME/$file" "$BACKUP/$file"
    fi
done < <(dot ls-tree -rz --name-only --full-tree HEAD)
dot read-tree HEAD
dot checkout-index --all

python3 - "$HOME" "$GITDIR" <<'PY'
from pathlib import Path
import subprocess
import sys
home = Path(sys.argv[1])
gitdir = sys.argv[2]
paths = subprocess.check_output(['git', '-C', str(home), '--git-dir=' + gitdir, '--work-tree=' + str(home), 'ls-tree', '-rz', '--name-only', '--full-tree', 'HEAD']).decode().split('\0')
for name in filter(None, paths):
    path = home / name
    if name.endswith('.md') or name == '.config/dotfiles/install.sh' or path.is_symlink() or not path.is_file():
        continue
    data = path.read_bytes()
    if b'\0' not in data and b'/home/ulysse' in data:
        path.write_bytes(data.replace(b'/home/ulysse', str(home).encode()))
PY

LISTS="$HOME/.config/dotfiles"
if [[ "$PROFILE" != restore ]]; then
    mapfile -t desktop < <(sed '/^[[:space:]]*$/d' "$LISTS/pkgs-desktop.txt")
    sudo pacman -S --needed "${desktop[@]}"
    if ! command -v paru >/dev/null; then
        build=$(mktemp -d)
        git clone https://aur.archlinux.org/paru-bin.git "$build/paru-bin"
        (cd "$build/paru-bin" && makepkg -si)
    fi
    mapfile -t aur < <(sed '/^[[:space:]]*$/d' "$LISTS/pkgs-desktop-aur.txt")
    paru -S --needed "${aur[@]}"
fi

base_shell=/etc/xdg/quickshell/caelestia
if [[ -d "$base_shell" ]]; then
    if [[ -e "$HOME/.config/quickshell/caelestia" ]]; then
        mkdir -p "$BACKUP/.config/quickshell"
        mv "$HOME/.config/quickshell/caelestia" "$BACKUP/.config/quickshell/caelestia"
    fi
    mkdir -p "$HOME/.config/quickshell/caelestia"
    cp -a "$base_shell/." "$HOME/.config/quickshell/caelestia/"
    cp -a "$LISTS/caelestia-overlay/." "$HOME/.config/quickshell/caelestia/"
else
    echo 'Caelestia non installé : surcouche non appliquée. Installer caelestia-shell, puis suivre le README.' >&2
fi

if [[ "$PROFILE" == full ]]; then
    available=$(mktemp)
    selected=$(mktemp)
    pacman -Slq | sort -u > "$available"
    grep -vE '^(linux|cachyos-|cachy-|chwd$|amd-ucode$|intel-ucode$|nvidia|xf86-video-|grub|shim|sbctl$|systemd-boot-|mkinitcpio|dracut)' "$LISTS/pkgs-native.txt" | sort -u > "$selected"
    comm -23 "$selected" "$available" > "$BACKUP/paquets-absents-des-depots.txt"
    mapfile -t extra < <(comm -12 "$selected" "$available")
    if (( ${#extra[@]} )); then sudo pacman -S --needed "${extra[@]}"; fi
    mapfile -t extra_aur < <(grep -vE '^(cachy-|cachyos-)' "$LISTS/pkgs-aur.txt" | sed '/^[[:space:]]*$/d')
    if (( ${#extra_aur[@]} )); then paru -S --needed "${extra_aur[@]}"; fi
    if [[ -s "$LISTS/flatpak.txt" ]]; then
        sudo pacman -S --needed flatpak
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        xargs -r -a "$LISTS/flatpak.txt" flatpak install --user flathub
    fi
fi

printf '\nFichiers restaurés. Sauvegarde : %s\n' "$BACKUP"
echo 'Lire le README : activer les services, installer les plugins compatibles, transférer le curseur et les fonds, adapter les écrans, puis lancer Hyprland.'
echo 'Aucun plugin, pilote graphique, chargeur de démarrage ou service personnel n’a été activé automatiquement.'
