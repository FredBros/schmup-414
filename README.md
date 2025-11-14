# Schmup-414

Un jeu de tir vertical (shmup) développé avec Godot 4.

## Fonctionnalités

- ✅ Joueur contrôlable avec mouvement fluide
- ✅ Système de tir automatique
- ✅ Ennemis avec IA basique
- ✅ Système de santé avec barres de vie
- ✅ Interface utilisateur moderne
- ✅ Architecture modulaire avec composants

## Installation

1. **Cloner le repository :**
   ```bash
   git clone https://github.com/fredb/schmup-414.git
   cd schmup-414
   ```

2. **Télécharger les assets :**
   Les assets ne sont pas inclus dans le repository pour réduire sa taille.
   Vous devez les télécharger séparément et les placer dans le dossier `assets/`.

   **Assets requis :**
   - [Pixel SHMUP Free Asset Pack](https://example.com/link-to-assets)
   - [Wenrexa Interface UI KIT #4](https://example.com/link-to-ui-assets)
   - [Background Seamless Assets](https://example.com/link-to-backgrounds)

3. **Ouvrir avec Godot 4 :**
   - Lancez Godot 4
   - Ouvrez le fichier `project.godot`
   - Lancez le jeu avec F5

## Structure du projet

```
schmup-414/
├── assets/                 # Assets graphiques (à télécharger séparément)
├── scenes/                 # Scènes du jeu
│   ├── player/            # Scène du joueur
│   ├── enemy/             # Scène des ennemis
│   ├── bullet/            # Scène des projectiles
│   ├── utils/             # Utilitaires et composants
│   └── main UI/           # Interface utilisateur
├── autoloads/             # Scripts chargés automatiquement
└── project.godot         # Configuration du projet Godot
```

## Architecture

Le jeu utilise une architecture modulaire avec :

- **Entity.gd** : Classe de base pour tous les objets vivants
- **Health.gd** : Composant de gestion de la santé
- **Hurtbox.gd/Hitbox.gd** : Système de collision
- **SignalManager** : Gestion centralisée des événements

## Contrôles

- **Flèches directionnelles** ou **WASD** : Déplacement
- **Espace** ou **Clic gauche** : Tir

## Développement

Pour contribuer au projet :

1. Fork le repository
2. Créez une branche pour votre fonctionnalité
3. Commitez vos changements
4. Poussez vers votre fork
5. Créez une Pull Request

## Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## Crédits

- Assets graphiques : Divers packs libres
- Framework : Godot Engine
- Développement : fredb