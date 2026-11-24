#!/usr/bin/env bash
set -euo pipefail

REPO="${DOTFILES_REPO:-https://github.com/ODY92/dotfiles.git}"
GITDIR="$HOME/.dotfiles"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)-$$"

PROFILE=desktop
DRY_RUN=0
SKIP_SDDM=0
SKIP_PLUGINS=0
INTERACTIVE=0

usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Modes:
  --desktop        Installe tout le bureau CachyOS/Hyprland au pixel près (défaut)
  --full           Mode --desktop + tous les paquets natifs, AUR et Flatpak
  --restore        Restaure uniquement les fichiers, thèmes, curseur et polices (sans sudo)

Options:
  --dry-run        Affiche le plan sans rien modifier
  --skip-sddm      Ne modifie pas /etc/sddm.conf.d ni /usr/share/sddm/themes/pixie
  --skip-plugins   Ne compile pas dynamic-cursors ni Hypr3D
  --interactive    Demande confirmation pour pacman/paru
  --repo URL       URL du dépôt Git (défaut : https://github.com/ODY92/dotfiles.git)
  -h, --help       Affiche cette aide
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --desktop)      PROFILE=desktop ;;
        --full)         PROFILE=full ;;
        --restore)      PROFILE=restore ;;
        --dry-run)      DRY_RUN=1 ;;
        --skip-sddm)    SKIP_SDDM=1 ;;
        --skip-plugins) SKIP_PLUGINS=1 ;;
        --interactive)  INTERACTIVE=1 ;;
        --repo)
            shift
            REPO="${1:?--repo attend une URL}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Option inconnue : $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

dot() {
    git -C "$HOME" --git-dir="$GITDIR" --work-tree="$HOME" "$@"
}

step() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$1"
}

warn() {
    printf '\033[1;33m[!] %s\033[0m\n' "$1" >&2
}

if (( DRY_RUN )); then
    cat <<EOF
Simulation (--dry-run) — Profil : $PROFILE
  Dépôt      : $REPO
  Bare repo  : $GITDIR
  Sauvegarde : $BACKUP
  SDDM       : $( (( SKIP_SDDM )) && echo "ignoré" || echo "thème pixie + Wayland" )
  Plugins    : $( (( SKIP_PLUGINS )) && echo "ignorés" || echo "dynamic-cursors (patch immersif) + Hypr3D" )

Étapes prévues :
  1. Paquets pacman de base + bureau (.config/dotfiles/pkgs-desktop.txt)
  2. Clonage/sync bare repo ~/.dotfiles + sauvegarde des fichiers existants + checkout
  3. Adaptation des chemins /home/ulysse -> $HOME
  4. Paru + paquets AUR du bureau (.config/dotfiles/pkgs-desktop-aur.txt)
  5. Copie /etc/xdg/quickshell/caelestia + surcouche QML/Python personnalisée (41 fichiers)
  6. Extraction curseur macOS 42px + polices perso + fc-cache + wallpaper fallback
  7. Clonage qs-wallpaperpicker + restauration settings.json
  8. Application exacte des réglages GTK/GNOME/curseur/polices via gsettings
  9. Installation thème SDDM pixie + /etc/sddm.conf.d + services système
 10. Compilation dynamic-cursors (patch immersif) + installation Hypr3D via hyprpm
 11. Activation des services utilisateur (wallpaper-shared, whispy, ydotoold) + shell fish
 12. (Si --full) Installation des paquets natifs, AUR et Flatpak supplémentaires

Aucune modification effectuée en mode simulation.
EOF
    exit 0
fi

if (( EUID == 0 )); then
    echo "Ne pas lancer ce script en root. Utiliser un compte utilisateur normal avec sudo." >&2
    exit 1
fi

if [[ "$PROFILE" != restore ]]; then
    command -v pacman >/dev/null || { echo "pacman introuvable : ce script cible CachyOS / Arch Linux." >&2; exit 1; }
    sudo -v
    # Maintient la session sudo active pendant l'installation
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
fi

PACMAN_FLAGS=(--needed)
PARU_FLAGS=(--needed)
if (( ! INTERACTIVE )); then
    PACMAN_FLAGS+=(--noconfirm)
    PARU_FLAGS+=(--noconfirm --skipreview)
fi

# 1. Prérequis minimaux
if [[ "$PROFILE" != restore ]]; then
    step "1/11 — Mise à jour système et prérequis de base"
    sudo pacman -Syu "${PACMAN_FLAGS[@]}" git base-devel python zstd curl
fi
command -v git >/dev/null
command -v python3 >/dev/null
command -v zstd >/dev/null

# 2. Clonage / mise à jour du dépôt bare et checkout sécurisé
step "2/11 — Synchronisation des dotfiles depuis $REPO"
if [[ ! -e "$GITDIR" ]]; then
    git clone --bare "$REPO" "$GITDIR"
else
    [[ "$(dot rev-parse --is-bare-repository)" == true ]] || { echo "$GITDIR n'est pas un dépôt bare." >&2; exit 1; }
fi
dot fetch origin main:refs/remotes/origin/main
if dot show-ref --verify --quiet refs/heads/main; then
    if ! dot merge-base --is-ancestor refs/heads/main refs/remotes/origin/main; then
        warn "Branche locale main divergente : réinitialisation sur origin/main (sauvegarde dans $BACKUP)"
    fi
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

# Hyprland charge hyprland.conf avant hyprland.lua : on archive tout ancien hyprland.conf
if [[ -e "$HOME/.config/hypr/hyprland.conf" || -L "$HOME/.config/hypr/hyprland.conf" ]]; then
    mkdir -p "$BACKUP/.config/hypr"
    mv -- "$HOME/.config/hypr/hyprland.conf" "$BACKUP/.config/hypr/hyprland.conf"
fi

# 3. Adaptation des chemins /home/ulysse -> $HOME si le nom d'utilisateur diffère
if [[ "$HOME" != "/home/ulysse" ]]; then
    step "3/11 — Adaptation des chemins (/home/ulysse -> $HOME)"
    python3 - "$HOME" "$GITDIR" <<'PY'
from pathlib import Path
import subprocess, sys

home = Path(sys.argv[1])
gitdir = sys.argv[2]
paths = subprocess.check_output(
    ["git", "-C", str(home), "--git-dir=" + gitdir, "--work-tree=" + str(home),
     "ls-tree", "-rz", "--name-only", "--full-tree", "HEAD"]
).decode().split("\0")

for name in filter(None, paths):
    path = home / name
    if (
        name.endswith((".md", ".zst", ".png", ".jpg", ".ttf", ".otf", ".svg"))
        or name == ".config/dotfiles/install.sh"
        or path.is_symlink()
        or not path.is_file()
    ):
        continue
    data = path.read_bytes()
    if b"\0" not in data and b"/home/ulysse" in data:
        path.write_bytes(data.replace(b"/home/ulysse", str(home).encode()))
PY
else
    step "3/11 — Chemins déjà sur /home/ulysse"
fi

LISTS="$HOME/.config/dotfiles"

# 4. Paquets bureau (pacman + AUR via paru)
AUR_HELPER=""
if [[ "$PROFILE" != restore ]]; then
    step "4/11 — Installation des paquets bureau (pacman + AUR)"
    mapfile -t desktop_pkgs < <(sed '/^[[:space:]]*$/d' "$LISTS/pkgs-desktop.txt")
    sudo pacman -S "${PACMAN_FLAGS[@]}" "${desktop_pkgs[@]}"

    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER=paru
    elif command -v yay >/dev/null 2>&1; then
        AUR_HELPER=yay
    else
        build_paru=$(mktemp -d)
        git clone https://aur.archlinux.org/paru-bin.git "$build_paru/paru-bin"
        (cd "$build_paru/paru-bin" && makepkg -si --noconfirm)
        rm -rf "$build_paru"
        AUR_HELPER=paru
    fi

    aur_install() {
        local pkg="$1"
        if [[ "$AUR_HELPER" == paru ]]; then
            paru -S "${PARU_FLAGS[@]}" "$pkg"
        else
            yay -S --needed --noconfirm "$pkg"
        fi
    }

    # 4a. Paquets critiques du bureau (caelestia-cli, qtengine, puis caelestia-shell sans conflit quickshell-git)
    for pkg in caelestia-cli qtengine; do
        aur_install "$pkg" || warn "Échec AUR pour $pkg"
    done

    if ! pacman -Q caelestia-shell >/dev/null 2>&1; then
        sudo pacman -S "${PACMAN_FLAGS[@]}" ddcutil brightnessctl lm_sensors aubio libqalculate swappy qt6-shadertools || true
        for dep in libcava qt6-m3shapes-git ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd; do
            aur_install "$dep" || warn "Dépendance AUR $dep en échec"
        done
        build_cs=$(mktemp -d)
        if git clone https://aur.archlinux.org/caelestia-shell.git "$build_cs/caelestia-shell"; then
            (
                cd "$build_cs/caelestia-shell"
                # Utilise le binaire précompilé `quickshell` de CachyOS au lieu de recompiler quickshell-git
                sed -i "s/'quickshell-git'/'quickshell'/g" PKGBUILD
                makepkg -si --noconfirm
            ) || warn "Échec de la construction de caelestia-shell."
        fi
        rm -rf "$build_cs"
    fi

    # 4b. Paquets AUR secondaires installés un par un (un échec n'interrompt pas le reste)
    mapfile -t aur_pkgs < <(sed '/^[[:space:]]*$/d' "$LISTS/pkgs-desktop-aur.txt")
    for pkg in "${aur_pkgs[@]}"; do
        case "$pkg" in
            caelestia-cli|caelestia-shell|qtengine) continue ;;
        esac
        aur_install "$pkg" || warn "Paquet AUR optionnel ignoré : $pkg"
    done
fi

# 5. Surcouche Quickshell Caelestia (41 fichiers personnalisés)
step "5/11 — Application de la surcouche Caelestia Quickshell"
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
    warn "Caelestia (/etc/xdg/quickshell/caelestia) absent : surcouche ignorée."
fi

# 6. Curseur macOS 42px, polices perso, fond d'écran de secours
step "6/11 — Extraction curseur macOS 42px, polices personnalisées et fond de secours"
if [[ -f "$LISTS/assets/macos-cursor.tar.zst" ]]; then
    mkdir -p "$HOME/.local/share/icons"
    rm -rf "$HOME/.local/share/icons/macOS"
    zstd -dc "$LISTS/assets/macos-cursor.tar.zst" | tar -C "$HOME/.local/share/icons" -xf -
fi

if [[ -f "$LISTS/assets/fonts.tar.zst" ]]; then
    mkdir -p "$HOME/.local/share/fonts"
    zstd -dc "$LISTS/assets/fonts.tar.zst" | tar -C "$HOME/.local/share/fonts" -xf -
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" || true
fi

if [[ -f "$LISTS/assets/default-wallpaper.png" ]]; then
    mkdir -p "$HOME/.cache" "$HOME/.local/state/caelestia/wallpaper"
    cp -f "$LISTS/assets/default-wallpaper.png" "$HOME/.cache/wp-preview.png"
    ln -sfn "$HOME/.cache/wp-preview.png" "$HOME/.local/state/caelestia/wallpaper/current"
    printf '%s' "$HOME/.cache/wp-preview.png" > "$HOME/.local/state/caelestia/wallpaper/path.txt"

    # Si le fond Workshop Steam n'est pas sur cette machine, activer le fond statique Caelestia
    if [[ ! -f "$HOME/.local/share/Steam/steamapps/workshop/content/431960/3102158703/project.json" && -f "$HOME/.config/caelestia/shell.json" ]]; then
        python3 - "$HOME/.config/caelestia/shell.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data.setdefault("background", {})["wallpaperEnabled"] = True
p.write_text(json.dumps(data, indent=4) + "\n")
PY
    fi
fi

# 7. Wallpaper picker Quickshell
step "7/11 — Installation de qs-wallpaperpicker"
WP_DIR="$HOME/.config/qs-wallpaperpicker-github"
WP_SETTINGS_TMP=""
if [[ -f "$WP_DIR/settings.json" ]]; then
    WP_SETTINGS_TMP=$(mktemp)
    cp -f "$WP_DIR/settings.json" "$WP_SETTINGS_TMP"
fi
if [[ ! -d "$WP_DIR/.git" ]]; then
    rm -rf "$WP_DIR"
    if git clone https://github.com/dhrruvsharma/qs-wallpaperpicker.git "$WP_DIR"; then
        git -C "$WP_DIR" checkout 3cfae3517cc683133508d1a035eb8f3eb775126d 2>/dev/null || true
    else
        warn "Échec du clonage de qs-wallpaperpicker."
    fi
fi
if [[ -n "$WP_SETTINGS_TMP" && -f "$WP_SETTINGS_TMP" ]]; then
    mkdir -p "$WP_DIR"
    cp -f "$WP_SETTINGS_TMP" "$WP_DIR/settings.json"
    rm -f "$WP_SETTINGS_TMP"
fi

# 8. Réglages GTK / GNOME / curseur / polices exacts
step "8/11 — Application des réglages gsettings (thème, icônes, curseur, polices)"
apply_gsettings() {
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface accent-color 'blue' || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface cursor-theme 'macOS'
    gsettings set org.gnome.desktop.interface cursor-size 42
    gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'
    gsettings set org.gnome.desktop.interface document-font-name 'Adwaita Sans 12'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Adwaita Mono 11'
    gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale'
    gsettings set org.gnome.desktop.interface font-hinting 'slight'
}
if command -v gsettings >/dev/null 2>&1; then
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        apply_gsettings || warn "gsettings a retourné une erreur mineure."
    elif command -v dbus-run-session >/dev/null 2>&1; then
        dbus-run-session -- bash -c "$(declare -f apply_gsettings); apply_gsettings" || warn "gsettings hors-session a échoué."
    fi
fi

# 9. SDDM thème pixie + Wayland + services système
if [[ "$PROFILE" != restore && "$SKIP_SDDM" == 0 ]]; then
    step "9/11 — Installation du thème SDDM pixie et des services système"
    if [[ -d "$LISTS/system/sddm/pixie" ]]; then
        sudo mkdir -p /etc/sddm.conf.d /usr/share/sddm/themes
        sudo cp -f "$LISTS/system/sddm/10-wayland.conf" /etc/sddm.conf.d/10-wayland.conf
        sudo cp -f "$LISTS/system/sddm/theme.conf" /etc/sddm.conf.d/theme.conf
        sudo rm -rf /usr/share/sddm/themes/pixie
        sudo cp -a "$LISTS/system/sddm/pixie" /usr/share/sddm/themes/pixie
    fi
    sudo systemctl set-default graphical.target 2>/dev/null || true
    sudo systemctl enable NetworkManager.service bluetooth.service 2>/dev/null || true
    sudo systemctl enable --force sddm.service || warn "Impossible d'activer sddm.service"
else
    step "9/11 — SDDM ignoré"
fi

# 10. Plugins Hyprland : dynamic-cursors (patch immersif) + Hypr3D
if [[ "$PROFILE" != restore && "$SKIP_PLUGINS" == 0 ]]; then
    step "10/11 — Compilation du plugin dynamic-cursors (patch immersif) et Hypr3D"
    CURSOR_DIR="$HOME/.local/share/macos-cursor"
    SRC_DIR="$CURSOR_DIR/dynamic-cursors-src"
    mkdir -p "$CURSOR_DIR"

    if [[ ! -d "$SRC_DIR/.git" ]]; then
        rm -rf "$SRC_DIR"
        git clone https://github.com/VirtCode/hypr-dynamic-cursors.git "$SRC_DIR" || warn "Clonage hypr-dynamic-cursors échoué."
    fi
    if [[ -d "$SRC_DIR/.git" ]]; then
        (
            cd "$SRC_DIR"
            git checkout -- . 2>/dev/null || true
            git checkout 2a8d0b735328d874a78ca93b2f201649f712a74a 2>/dev/null || true
            mkdir -p src/other
            cp -f "$LISTS/patches/Immersive.hpp" src/other/Immersive.hpp
            git apply --check "$LISTS/patches/dynamic-cursors.patch" 2>/dev/null && git apply "$LISTS/patches/dynamic-cursors.patch" || true
            make clean >/dev/null 2>&1 || true
            if make -j"$(nproc)" all; then
                cp -f out/dynamic-cursors.so "$CURSOR_DIR/dynamic-cursors.so"
                HYPR_ABI=$(Hyprland --version-json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("abiHash",""))' 2>/dev/null || true)
                if [[ -n "$HYPR_ABI" ]]; then
                    printf '%s\n' "$HYPR_ABI" > "$CURSOR_DIR/plugin-abi"
                fi
            else
                warn "Compilation de dynamic-cursors échouée (API Hyprland différente ?). Le thème macOS 42px reste actif."
            fi
        )
    fi

    if command -v hyprpm >/dev/null 2>&1; then
        hyprpm update -n >/dev/null 2>&1 || true
        yes | hyprpm add https://github.com/samine825/Hypr3D >/dev/null 2>&1 || warn "hyprpm add Hypr3D a échoué (réessayer après démarrage de Hyprland)."
        hyprpm enable Hypr3D >/dev/null 2>&1 || true
    fi
else
    step "10/11 — Plugins Hyprland ignorés"
fi

# 11. Services utilisateur + shell par défaut fish
step "11/11 — Activation des services utilisateur et du shell fish"
enable_user_unit() {
    local unit="$1" target="$2"
    if systemctl --user enable "$unit" >/dev/null 2>&1; then
        return 0
    fi
    local src=""
    for dir in "$HOME/.config/systemd/user" "/usr/lib/systemd/user"; do
        if [[ -f "$dir/$unit" ]]; then
            src="$dir/$unit"
            break
        fi
    done
    if [[ -n "$src" ]]; then
        mkdir -p "$HOME/.config/systemd/user/${target}.wants"
        ln -sfn "$src" "$HOME/.config/systemd/user/${target}.wants/$unit"
    fi
}

enable_user_unit wallpaper-shared.service graphical-session.target
enable_user_unit ydotoold.service default.target
enable_user_unit whispy-daemon.service graphical-session.target
enable_user_unit whispy-pill.service graphical-session.target
enable_user_unit pipewire.socket sockets.target
enable_user_unit pipewire-pulse.socket sockets.target
enable_user_unit wireplumber.service pipewire.service

if [[ "$PROFILE" != restore ]] && command -v fish >/dev/null 2>&1; then
    FISH_BIN=$(command -v fish)
    if [[ "${SHELL:-}" != "$FISH_BIN" ]]; then
        sudo chsh -s "$FISH_BIN" "$USER" || true
    fi
fi

# Mode --full : paquets supplémentaires et Flatpak
if [[ "$PROFILE" == full ]]; then
    step "Mode --full — Installation des applications supplémentaires et Flatpak"
    available=$(mktemp)
    selected=$(mktemp)
    pacman -Slq | sort -u > "$available"
    grep -vE '^(linux|cachyos-|cachy-|chwd$|amd-ucode$|intel-ucode$|nvidia|xf86-video-|grub|shim|sbctl$|systemd-boot-|mkinitcpio|dracut)' "$LISTS/pkgs-native.txt" | sort -u > "$selected"
    comm -23 "$selected" "$available" > "$BACKUP/paquets-absents-des-depots.txt"
    mapfile -t extra < <(comm -12 "$selected" "$available")
    if (( ${#extra[@]} )); then
        sudo pacman -S "${PACMAN_FLAGS[@]}" "${extra[@]}" || warn "Certains paquets natifs supplémentaires ont échoué."
    fi
    rm -f "$available" "$selected"

    mapfile -t extra_aur < <(grep -vE '^(cachy-|cachyos-)' "$LISTS/pkgs-aur.txt" | sed '/^[[:space:]]*$/d')
    if (( ${#extra_aur[@]} )); then
        if [[ "$AUR_HELPER" == paru ]]; then
            paru -S "${PARU_FLAGS[@]}" "${extra_aur[@]}" || warn "Certains paquets AUR supplémentaires ont échoué."
        else
            yay -S --needed --noconfirm "${extra_aur[@]}" || warn "Certains paquets AUR supplémentaires ont échoué."
        fi
    fi

    if [[ -s "$LISTS/flatpak.txt" ]]; then
        sudo pacman -S "${PACMAN_FLAGS[@]}" flatpak
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        xargs -r -a "$LISTS/flatpak.txt" flatpak install -y --user flathub || warn "Certains Flatpaks ont échoué."
    fi
fi

printf '\n\033[1;32m✔ Configuration CachyOS ODY92 restaurée avec succès !\033[0m\n'
printf '  Sauvegarde des anciens fichiers : %s\n' "$BACKUP"
printf '  Redémarre (reboot) pour lancer SDDM (pixie) + Hyprland + Caelestia.\n'
