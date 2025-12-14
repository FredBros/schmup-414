# TODO List - Schmup-414

Liste des fonctionnalités et améliorations à venir pour le projet.

## Priorités Actuelles (High Priority)

- [ ] **Correction du pattern `BOUNCE` pour les escadrilles**:
  - [ ] La détection de collision avec les bords de l'écran doit se baser sur les membres de l'escadrille, et non sur le point central du `SquadronController`.

- [ ] **Déclencheurs d'Événements (Event Triggers)**:
  - [ ] Permettre à un ennemi d'émettre des signaux à des moments clés (ex: à 50% de sa vie, ou après un certain `_age`).
  - [ ] Le `LevelSequencer` pourrait écouter ces signaux pour déclencher des événements de script (faire apparaître des renforts, changer la musique, etc.).

## Prochaines Étapes (Next Steps)

- [ ] **Feedback Visuel & Audio (Game Feel / "Juice")**:
  - [ ] Ajouter un effet visuel/sonore à l'apparition des ennemis (`spawn`).
  - [ ] Créer un effet d'explosion (particules, son) à la destruction d'un ennemi.
  - [ ] Implémenter un feedback de dégât (ex: clignotement blanc du sprite) quand un ennemi est touché.

- [ ] **Butin & Collectibles (Loot System)**:
  - [ ] Créer une ressource `LootTable` pour définir les objets qu'un ennemi peut laisser tomber.
  - [ ] Mettre à jour `SpawnEventData` pour y attacher une `LootTable`.
  - [ ] Implémenter la logique de drop à la mort de l'ennemi.

## Vaisseau Joueur

- [ ] Définir et implémenter les mécaniques de base du vaisseau joueur (mouvement, tir, santé, power-ups).

---

## Terminé (Done)

- [x] **Système de Rotation des Escadrilles**:
  - [x] Refonte complète de la logique de rotation pour corriger les problèmes d'orientation (V inversé).
  - [x] Séparation de la rotation de la formation (`rotate_formation`) et de la rotation des membres (`rotate_members`).
  - [x] Correction de l'orientation pour les patterns `LINEAR`, `PATH_2D`, `SINUSOIDAL`.

- [x] **Pattern `HOMING` pour les Escadrilles**:
  - [x] Implémentation de la logique de poursuite dans le `SquadronController`.
  - [x] Le ciblage choisit un joueur au hasard si plusieurs sont disponibles, en prévision du multijoueur.

- [x] **Phases de Comportement de Mouvement**:
  - [x] Le `SquadronController` interprète une séquence de `EnemyBehaviorPattern`, chacun avec une `duration`, permettant des changements de mouvement au fil du temps.

- [x] **Pooling des `SquadronController`**:
  - [x] Création du singleton `SquadronControllerPoolManager` pour gérer le cycle de vie des contrôleurs.
  - [x] Modification de `SquadronController` pour être compatible avec le pooling (`activate`, `deactivate`, `reclaimed` signal).
  - [x] Modification de `EnemySpawner` pour utiliser le pool au lieu de `instantiate()`.

- [x] **Système de Tir Modulaire et Chronométré**:
  - [x] Création de la ressource `ShootingPattern` pour définir des types de tirs (Single, Burst, Spread, Spiral).
  - [x] Découplage des patterns de tir de la scène de l'ennemi.
  - [x] Création de la ressource `TimedShootingPattern` pour activer/désactiver les tirs à des moments précis.
  - [x] L'ennemi peut gérer plusieurs patterns de tir simultanément.