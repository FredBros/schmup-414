# TODO List - Schmup-414

Liste des fonctionnalités et améliorations à venir pour le projet.

## Gameplay & Ennemis

- [ ] **Comportements de Tir Complexes**:
  - [ ] Créer une nouvelle ressource `ShootingPattern` (similaire à `EnemyBehaviorPattern`).
  - [ ] Définir des types de tirs : rafales (`bursts`), spirales, tirs visant le joueur (`aimed shots`), pauses entre les tirs.
  - [ ] Mettre à jour `enemy.gd` pour qu'il puisse utiliser un `ShootingPattern`.
  - [ ] (Optionnel) Permettre à un ennemi de changer de `ShootingPattern` (ex: après avoir perdu 50% de sa vie).

- [ ] **Phases de Comportement pour les Ennemis**:
  - [ ] Faire évoluer `EnemyBehaviorPattern` pour qu'il puisse contenir une *séquence* d'actions (ex: `LINEAR` pendant 2s, puis `STATIONARY` pendant 5s).
  - [ ] Mettre à jour la logique dans `enemy.gd` et `squadron_controller.gd` pour interpréter ces séquences. Très utile pour les mini-boss.

- [ ] **Feedback Visuel & Audio (Game Feel)**:
  - [ ] Ajouter un effet visuel/sonore à l'apparition des ennemis (`spawn`).
  - [ ] Créer un effet d'explosion (particules, son) à la destruction d'un ennemi.
  - [ ] Implémenter un feedback de dégât (ex: clignotement blanc du sprite) quand un ennemi est touché.

## Optimisation & Système

- [ ] **Pooling des `SquadronController`**:
  - [ ] Créer un système de pooling pour les `SquadronController` (sur le modèle de l'`EnemyPoolManager`).
  - [ ] Modifier `EnemySpawner` pour utiliser ce pool au lieu de `instantiate()` à chaque spawn d'escadrille.

## Vaisseau Joueur

- [ ] Définir et implémenter les mécaniques de base du vaisseau joueur (mouvement, tir, santé, power-ups).