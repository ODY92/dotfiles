# Configuration CachyOS — ODY92

Sauvegarde de la configuration courante du bureau et des outils personnels, mise à jour le 26 octobre 2026. Le dépôt est géré en mode bare avec `~/.dotfiles` et le dossier personnel comme arbre de travail.

## Éléments synchronisés

- Hyprland en Lua : raccourcis, règles, écrans, curseur Tahoe, Hypr3D, transparence et intégration Hyprglass.
- Caelestia, thèmes GTK/Qt, Matugen, terminaux, shells, outils de suivi système et éditeurs déjà suivis.
- Spotlight 26 : code Python/GTK, styles, animations, lanceur Alt+Espace et entrée du menu d’applications. L’ancien nom `sphere-launcher` redirige vers Spotlight.
- Luma : lanceur Firefox, réglages explicites et thème du profil `LumaFirefox`, palette et logo. Les ressources encore référencées sous `Documents/Codex/2026-10-26/luma/` sont conservées à leur emplacement actuel pour que les chemins restent valides.
- Scripts personnels et unités systemd utilisateur, ainsi que les listes actualisées de paquets.

## Données exclues

La sauvegarde n’inclut pas les profils complets de navigateur, connexions de compte, mots de passe, cookies, favoris, historiques, presse-papiers, clés privées, fichiers de secrets, caches, journaux, sauvegardes intermédiaires ou gros exécutables/AppImages. Le dossier `LumaFirefox` ne contient que les fichiers de thème et `user.js`. Les extensions du navigateur ne sont pas embarquées et devront être réinstallées ou synchronisées via le compte Firefox.

## Restauration

L’installateur existant est `.config/dotfiles/install.sh`. Il restaure les fichiers et propose la réinstallation des paquets. Lire le script avant de le lancer : il déplace les configurations existantes vers une sauvegarde et installe des logiciels.

Les chemins absolus actuels utilisent `/home/ulysse`. Adapter ces références si le nom d’utilisateur change. Les paramètres d’écrans sont propres à la machine. Les applications externes, leurs dépôts, plugins Hyprland, thèmes de curseurs et AppImages cités dans les raccourcis ne sont pas tous distribués dans ce dépôt ; il faut les installer séparément.

Pour Spotlight, prévoir `gtk3`, `gtk-layer-shell`, `python-gobject`, `python-cairo`, `cliphist` et `wl-clipboard`. Le dossier runtime privé n’est pas embarqué : les bibliothèques système prennent le relais une fois ces paquets installés. L’effet Liquid Glass requiert le plugin Hyprglass ; la prise en charge de `mask_mode = contour` dépend de sa version. Pour Luma, installer Firefox et ouvrir le lanceur une première fois avant de connecter le compte.

## Gestion du dépôt

```sh
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" status --short --untracked-files=no
```

Ajouter les nouveaux fichiers par chemins explicites. Éviter d’ajouter tout le dossier personnel, qui contient des données privées et des programmes volumineux.
