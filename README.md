# Dotfiles ODY92 — Arch Linux / CachyOS

Mon bureau Hyprland + Caelestia, avec effets Liquid Glass, couleurs Matugen, barre personnalisée, Spotlight 26 et Luma (Firefox personnalisé).

Ce guide part d’un **Arch Linux déjà installé, démarrable, connecté à Internet, avec un compte utilisateur et sudo**. Il ne partitionne pas le disque et n’installe pas Arch depuis l’ISO. La référence est mon CachyOS du **26 octobre 2026**.

## Ce qui est reproductible

Le dépôt restaure les réglages, raccourcis, scripts, thèmes GTK/Qt, le thème Firefox, Spotlight et les **14 fichiers QML personnalisés de Caelestia**. L’installateur copie d’abord le shell Caelestia installé, puis applique ces fichiers, avec leur licence d’origine.

Pour obtenir le même rendu, il faut aussi les mêmes versions compatibles des composants, le curseur personnalisé et le même fond d’écran. Ces dotfiles ne sont pas une image disque : les pilotes, le noyau CachyOS, les comptes, logiciels externes, données personnelles et certains assets ne sont pas embarqués. Les sections ci-dessous indiquent comment les remettre. Sur un autre écran, il faut adapter la disposition et la résolution.

| Composant de référence | Version / révision relevée |
|---|---|
| Hyprland CachyOS | `0.56.2-4.1`, configuration Lua `hl.*` |
| Caelestia Shell | `2.5.0-1` |
| Caelestia CLI | `1.1.3-1` |
| Quickshell | `0.3.2-1.1` |
| Hyprglass | `14df05f8bfcc0c5df9f66e5fbc6d71bb2a7c0475` |
| Hypr3D | `9301dcf6d0625daf632d5be04f2a3cefabec1769` |

Le relevé complet est dans [.config/dotfiles/versions-current.txt](.config/dotfiles/versions-current.txt). C’est une référence, pas un verrou de versions : les commandes ci-dessous installent les versions disponibles aujourd’hui dans Arch et l’AUR. Ne mélangez pas de vieilles bibliothèques avec un système Arch récent pour essayer de reproduire ces numéros.

## 1. Installer le bureau

À exécuter depuis un TTY, avec votre utilisateur habituel, **sans lancer le script avec sudo**. Le script demandera sudo uniquement pour les paquets.

```bash
sudo pacman -Syu --needed git base-devel python
git clone --bare https://github.com/ODY92/dotfiles.git "$HOME/.dotfiles"
git --git-dir="$HOME/.dotfiles" show main:.config/dotfiles/install.sh > /tmp/ody92-install.sh
bash /tmp/ody92-install.sh --desktop
```

Si `~/.dotfiles` existe déjà, sautez le clonage et utilisez :

```bash
git --git-dir="$HOME/.dotfiles" fetch origin main:refs/remotes/origin/main
git --git-dir="$HOME/.dotfiles" show origin/main:.config/dotfiles/install.sh > /tmp/ody92-install.sh
bash /tmp/ody92-install.sh --desktop
```

Pour examiner le programme ou afficher son plan avant installation :

```bash
less /tmp/ody92-install.sh
bash /tmp/ody92-install.sh --desktop --dry-run
```

Le mode `--desktop` :

1. met Arch à jour et installe les dépendances du bureau ;
2. récupère la branche `main` ;
3. sauvegarde les fichiers qui seraient remplacés dans `~/.dotfiles-backup/DATE-PID/` ;
4. restaure les fichiers suivis, y compris les fichiers cachés ;
5. adapte les chemins `/home/ulysse` à votre dossier personnel dans les fichiers texte de configuration ;
6. installe Paru si nécessaire, puis Caelestia et Qtengine depuis l’AUR ;
7. copie le shell Caelestia depuis `/etc/xdg/quickshell/caelestia` et applique ma surcouche QML.

Paru et `makepkg` peuvent demander d’examiner les recettes AUR. Une erreur d’installation arrête le script ; elle n’est pas masquée. Conservez la sauvegarde annoncée à la fin.

### Ajouter mes applications

Pour installer aussi les applications répertoriées sur mon PC :

```bash
bash /tmp/ody92-install.sh --full
```

Ce mode peut être long et occuper beaucoup d’espace. Il ajoute les paquets disponibles des listes `pkgs-native.txt`, `pkgs-aur.txt` et les applications Flatpak. Il écarte les paquets spécifiques CachyOS, les noyaux, le démarrage et une partie des paquets propres au matériel. Les paquets absents des dépôts sont indiqués dans `paquets-absents-des-depots.txt` à l’intérieur de la sauvegarde. Un paquet AUR retiré ou incompatible peut demander une intervention.

**Ne rajoutez pas les dépôts CachyOS pour satisfaire aveuglément cette liste.** Gardez les pilotes et le noyau adaptés au nouveau PC. Les commandes de ce guide ne choisissent pas les pilotes NVIDIA/AMD/Intel à votre place.

## 2. Activer les services et l’audio

Sur un Arch vierge, si vous utilisez NetworkManager comme gestionnaire réseau :

```bash
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now power-profiles-daemon.service
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
xdg-user-dirs-update
```

N’activez pas deux gestionnaires réseau concurrents. Les unités personnelles Hermes / Steam du dépôt ne sont pas activées automatiquement : leurs applications et scripts externes doivent d’abord être installés.

## 3. Installer les plugins du verre et du bureau

Ces commandes se lancent dans une session Hyprland fonctionnelle, **sans sudo** :

```bash
hyprpm update
hyprpm add https://github.com/hyprnux/hyprglass
hyprpm enable hyprglass
hyprpm reload
hyprctl configerrors
```

Le plugin est compilé pour la version locale de Hyprland. Si le gestionnaire refuse un plugin, consultez sa compatibilité avec votre version ; ne copiez pas un `.so` pris sur un autre PC. Les dotfiles utilisent notamment le masque `contour` pour que Spotlight ait du verre uniquement sur ses contours.

Optionnel, pour le curseur qui grossit lorsqu’on l’agite :

```bash
hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors
hyprpm reload
```

Optionnel, pour mon mode bureau 3D :

```bash
hyprpm add https://github.com/samine825/Hypr3D
hyprpm enable hypr3d
hyprpm reload
```

La scène `~/hypr3d/dust2.glb` n’est pas incluse. Sans ce fichier, cette scène ne peut pas être reproduite ; le bureau normal reste utilisable. Les réglages des plugins sont protégés par des tests de présence dans la configuration.

Références officielles : [Hyprglass](https://github.com/hyprnux/hyprglass), [Hypr3D](https://github.com/samine825/Hypr3D), [curseur dynamique](https://github.com/VirtCode/hypr-dynamic-cursors).

## 4. Retrouver exactement le curseur, les polices et le fond

Mon curseur est une adaptation locale **MacTahoe-Tailless**, différente du thème MacTahoe standard. Pour transférer les assets depuis mon ancien PC, y créer une archive :

```bash
tar -czf "$HOME/ody92-assets.tar.gz" -C "$HOME" \
  .local/share/icons/MacTahoe-Tailless .local/share/fonts
```

Copiez cette archive sur le nouveau PC par clé USB, puis :

```bash
tar -xzf "$HOME/ody92-assets.tar.gz" -C "$HOME"
fc-cache -f
hyprctl setcursor MacTahoe-Tailless 64
```

L’archive conserve les crédits et la licence du curseur. Son origine est [MacTahoe de vinceliuice](https://github.com/vinceliuice/MacTahoe-icon-theme). Sans cette copie locale, choisissez un curseur installé dans `.config/caelestia/hypr-vars.lua`, par exemple `Adwaita` ; le résultat visuel sera différent.

Transférez séparément le fond d’écran que vous voulez retrouver, puis appliquez-le :

```bash
mkdir -p "$HOME/Images"
# Copier votre image dans ~/Images/fond.jpg avant ces deux commandes
caelestia wallpaper -f "$HOME/Images/fond.jpg"
matugen image "$HOME/Images/fond.jpg"
```

Matugen actualise notamment les palettes de Luma. Fermez complètement Luma puis rouvrez-le pour que Firefox recharge son thème. Les scènes Wallpaper Engine, leurs fichiers Steam et les bibliothèques de fonds ne sont pas distribués ici.

Le sélecteur de fonds utilisé par mon raccourci est un projet externe :

```bash
git clone https://github.com/dhrruvsharma/qs-wallpaperpicker \
  "$HOME/.config/qs-wallpaperpicker-github"
```

## 5. Démarrer Hyprland et adapter les écrans

Cette configuration utilise **`hyprland.lua` et l’API `hl.*`**, pas une ancienne configuration `hyprland.conf`. Il faut une version de Hyprland qui accepte cette API ; renommer le fichier ne convertit pas sa syntaxe. Commencez par tester depuis un TTY :

```bash
Hyprland --config "$HOME/.config/hypr/hyprland.lua"
```

Dans la session :

```bash
hyprctl monitors
hyprctl configerrors
```

Adaptez `.config/hypr/hyprmoncfg-monitors.lua` à vos sorties, modes et positions. La référence utilise un écran **3440×1440 à 165 Hz** ; les règles spécifiques à son nom ne correspondent pas forcément à vos écrans. Une règle générale `preferred / auto` existe également.

Pour un écran de connexion, SDDM est optionnel :

```bash
sudo pacman -S --needed sddm
sudo systemctl enable sddm.service
```

À la prochaine connexion, choisissez la session Hyprland. Le thème de connexion CachyOS n’est pas inclus. Si la session proposée par SDDM ne charge pas le fichier Lua, revenez au lancement TTY explicite ci-dessus et vérifiez la version/configuration du paquet Hyprland.

## 6. Vérifier le bureau

| Action | Commande / raccourci |
|---|---|
| Ouvrir Spotlight 26 | `Alt+Espace` ou `~/.local/bin/spotlight26 --show` |
| Catégories Spotlight | `Ctrl+1` à `Ctrl+4` |
| Recharger la configuration | `hyprctl reload` |
| Vérifier les erreurs | `hyprctl configerrors` |
| Placer ma barre Caelestia | `barpos top`, `barpos left`, `barpos right`, `barpos bottom` |
| Ouvrir Luma | `~/.local/bin/luma` |
| Contrôler les plugins | `hyprpm list` |
| Entrer / sortir du mode 3D | `Super+F11` / `Super+F12`, si Hypr3D est chargé |

Spotlight utilise GTK et les bibliothèques système : pas besoin du runtime privé de mon PC. Luma utilise Firefox avec un profil distinct. Les comptes, mots de passe, favoris, extensions et historiques ne sont pas dans Git : connectez ensuite votre compte Firefox et choisissez ce qu’il doit synchroniser.

## Dépannage

- **Barre absente ou différente** : vérifier `caelestia shell -d`, le paquet `caelestia-shell` et la copie complète de `/etc/xdg/quickshell/caelestia`. Les fichiers de `.config/dotfiles/caelestia-overlay/` s’ajoutent à cette base ; ils ne remplacent pas le shell entier. Ma surcouche provient de Caelestia 2.5.0 et peut nécessiter une adaptation avec une autre version.
- **Pas de verre** : vérifier `hyprpm list`, recharger les plugins et consulter `hyprctl configerrors`. Sans Hyprglass compatible, les règles seules ne produisent pas le même matériau.
- **Spotlight ne s’ouvre pas** : lancer `~/.local/bin/spotlight26 --show` dans un terminal pour lire l’erreur ; vérifier `gtk-layer-shell`, `python-gobject` et `python-cairo`.
- **Chemins cassés** : rechercher les anciennes références avec `rg -n '/home/ulysse' ~/.config/hypr ~/.config/caelestia ~/.local/bin`. L’installateur remplace ces chemins dans les fichiers suivis ; certains raccourcis concernent néanmoins des applications externes absentes.
- **Bibliothèques ou programmes externes absents** : Voicemod, Hermes, les scripts de jeux, AppImages, thèmes personnels et dépôts cités dans les alias ne sont pas tous inclus. Installer les outils souhaités ou retirer leurs appels.
- **Ancien écran / clavier inadapté** : éditer les écrans et `.config/caelestia/hypr-vars.lua`. Mon clavier utilise `fr,us` avec `Super+Espace` pour changer de disposition.

## Mise à jour et restauration des fichiers

Pour consulter les modifications locales :

```bash
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" status --short --untracked-files=no
```

Avant de réappliquer une nouvelle version, sauvegardez ou commitez vos adaptations locales. Réutilisez les commandes de récupération de la section 1, puis le script. `--restore-only` réapplique les fichiers et la surcouche si Caelestia est déjà installé, sans installer de paquets :

```bash
bash /tmp/ody92-install.sh --restore-only
```

Pour récupérer un fichier antérieur, retrouvez le dossier de sauvegarde, puis copiez uniquement le fichier voulu :

```bash
ls "$HOME/.dotfiles-backup"
cp "$HOME/.dotfiles-backup/DATE-PID/.config/hypr/hyprland.lua" \
   "$HOME/.config/hypr/hyprland.lua"
```

Les commandes d’installation ont été contrôlées et le mode simulation testé, mais **l’installation complète n’a pas été exécutée sur une VM Arch vierge**. La compatibilité du matériel et des paquets actuels reste à vérifier sur le PC cible.
