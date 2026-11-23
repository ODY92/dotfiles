# Configuration CachyOS — ODY92

Voir le [README principal à la racine du dépôt](../../README.md) pour la commande d'installation en 1 ligne et le détail complet.

## Contenu de `.config/dotfiles/`

- `install.sh` — installateur autonome 1 commande (`--desktop`, `--full`, `--restore`, `--dry-run`).
- `caelestia-overlay/` — 41 fichiers QML/Python personnalisés appliqués sur `/etc/xdg/quickshell/caelestia`.
- `assets/` — curseur `macOS` 42px (`macos-cursor.tar.zst`), polices personnalisées (`fonts.tar.zst`), fond d'écran de secours (`default-wallpaper.png`).
- `patches/` — patch immersif de `hypr-dynamic-cursors` (`dynamic-cursors.patch`, `Immersive.hpp`).
- `system/sddm/` — thème SDDM `pixie` et fichiers `/etc/sddm.conf.d/`.
- `pkgs-*.txt`, `flatpak.txt`, `versions-current.txt`, `plugins-current.toml` — listes de paquets et versions de référence au 23 novembre 2026.
