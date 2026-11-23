# Configuration CachyOS — ODY92

Sauvegarde complète de ma configuration **CachyOS + Hyprland (Lua) + Caelestia** (état du **23 novembre 2026**), restaurable **au pixel près en 1 commande** sur un CachyOS ou Arch Linux vierge.

## Installation en 1 commande

Depuis un TTY ou un terminal, avec ton utilisateur normal (**sans** `sudo` devant la commande) :

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ODY92/dotfiles/main/.config/dotfiles/install.sh)"
```

> **Avec toutes mes applications supplémentaires** (paquets natifs + AUR + Flatpak) :
> ```bash
> bash -c "$(curl -fsSL https://raw.githubusercontent.com/ODY92/dotfiles/main/.config/dotfiles/install.sh)" -- --full
> ```

> **Simuler sans rien modifier (`--dry-run`)** :
> ```bash
> bash -c "$(curl -fsSL https://raw.githubusercontent.com/ODY92/dotfiles/main/.config/dotfiles/install.sh)" -- --dry-run
> ```

> **Si le dépôt est privé**, authentifie-toi d'abord (`gh auth login` ou clé SSH) puis lance :
> ```bash
> git clone --bare git@github.com:ODY92/dotfiles.git "$HOME/.dotfiles" && bash <(git --git-dir="$HOME/.dotfiles" show main:.config/dotfiles/install.sh) --repo git@github.com:ODY92/dotfiles.git
> ```

Après la fin du script, redémarre (`reboot`) : SDDM (`pixie`), Hyprland, Caelestia, le dock Tahoe, le curseur macOS 42px et les thèmes sont immédiatement actifs.

---

## Ce qui est restauré au pixel près

| Couche | Contenu restauré automatiquement |
|---|---|
| **Compositeur** | Hyprland `0.57.2` en Lua (`~/.config/hypr/`), shaders (`saturation.frag`), règles fenêtres/calques, animations, raccourcis AZERTY (`fr,us`), config moniteur (`hyprmoncfg`) |
| **Shell & Barre** | `caelestia-shell` + surcouche complète de **41 fichiers QML/Python** (barre horizontale `HBar`, menu bureau, batterie périphériques `peripheral-battery.py`, popouts, logo Gemini) |
| **Dock & Overlays** | `quickshell/dynamic-island` (Tahoe Dock), **Spotlight 26** (`Alt+Espace`), **Whispy** (dictée vocale + pillule Quickshell), **qs-wallpaperpicker** + démon `wallpaper-shared` |
| **Curseur & Effets** | Thème exact **macOS 42px** (Hyprcursor + XCursor, 44 formes, 1708 frames) + compilation automatique de `hypr-dynamic-cursors` avec le patch immersif (tilt, compression au clic, flou de mouvement, shake-to-find) + plugin `Hypr3D` |
| **Écran de connexion** | Thème **SDDM `pixie`** (Wayland, fond d'écran, avatar, polices et `Main.qml` personnalisés) |
| **Apparence globale** | GTK 2/3/4 (`adw-gtk3-dark`), icônes (`Papirus-Dark`), `qtengine`, `matugen`, `gsettings`, avatar `~/.face`, polices perso (`MaterialSymbolsRounded`, `SpaceGrotesk`, `Orbitron`, `Audiowide`, `MochiyPopOne`), fond d'écran de secours |
| **Shells & Outils** | `fish` (shell par défaut), `zsh` (`.p10k.zsh`), `bash`, `starship`, `kitty`, `foot`, `btop`, `htop`, `nvtop`, `cava`, `fastfetch`, `fuzzel`, `rofi`, `conky`, `micro`, `Thunar`, thème `LumaFirefox` (`chrome/` + `user.js`), thème `zed` |

### Options de l'installateur

- `--desktop` *(défaut)* : bureau complet au pixel près + paquets essentiels.
- `--full` : bureau complet + tous les paquets natifs (`pkgs-native.txt`), AUR (`pkgs-aur.txt`) et Flatpak (`flatpak.txt`), en excluant noyaux, bootloaders et pilotes matériels spécifiques.
- `--restore` : restaure uniquement les fichiers, overlays, curseur, polices et `gsettings` (sans installer de paquets ni utiliser `sudo`).
- `--skip-sddm` : ne touche pas à SDDM.
- `--skip-plugins` : ne compile pas `dynamic-cursors` ni `Hypr3D`.
- `--interactive` : demande confirmation à `pacman` / `paru`.

Les fichiers déjà présents sur la machine sont déplacés dans `~/.dotfiles-backup/<horodatage>/` avant restauration. Si ton nom d'utilisateur diffère de `ulysse`, les chemins `/home/ulysse` dans les fichiers de configuration texte sont automatiquement adaptés à `$HOME`.

---

## Données volontairement exclues

Pour que le dépôt reste propre et sans fuite de données privées, sont **exclus** :
- clés SSH, clés GPG, tokens, API keys, mots de passe, trousseaux ;
- profils complets de navigateurs, cookies, historiques, sessions connectées ;
- caches, journaux, fichiers temporaires, AppImages et gros binaires.

> **Fond d'écran animé Wallpaper Engine** : le script restaure le fond d'écran statique de secours (`~/.cache/wp-preview.png`) et la palette de couleurs exacte. Pour retrouver le fond animé Workshop (`3102158703`), connecte-toi à Steam et installe Wallpaper Engine — le service `wallpaper-shared.service` prendra automatiquement le relais.

---

## Mettre à jour cette sauvegarde

Le dépôt est géré en mode bare (`~/.dotfiles`, arbre de travail `$HOME`) :

```bash
alias dot='git --git-dir="$HOME/.dotfiles" --work-tree="$HOME"'
dot status -s
dot add -u
dot commit -m "Sync config CachyOS"
dot push origin main
```

Le relevé complet des paquets et versions installées se trouve dans [.config/dotfiles/versions-current.txt](.config/dotfiles/versions-current.txt) et [.config/dotfiles/plugins-current.toml](.config/dotfiles/plugins-current.toml).
