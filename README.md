# Défi de Codage Flutter : Gestionnaire de Tâches avec Synchronisation Hors Ligne

## Aperçu du Défi

Créer une application de gestion de tâches qui fonctionne de manière transparente en ligne et hors ligne, en synchronisant les données lorsque la connectivité est rétablie.

## Exigences Principales

### 1. Fonctionnalités

- Créer, lire, mettre à jour et supprimer des tâches
- Marquer les tâches comme terminées/non terminées
- Chaque tâche doit avoir : titre, description, date d'échéance, niveau de priorité
- Afficher les tâches dans une liste avec options de filtrage (toutes, actives, terminées)
- Afficher un indicateur d'état de connectivité

### 2. Fonctionnalité Hors Ligne

- L'application doit fonctionner entièrement sans connexion internet
- Stocker les données localement en utilisant SQLite (package sqflite)
- Mettre en file d'attente les opérations effectuées hors ligne

### 3. Fonctionnalité En Ligne

- Synchroniser les données locales avec une API backend lorsqu'en ligne
- Gérer les conflits (par ex., même tâche modifiée hors ligne et en ligne)
- Afficher l'état de synchronisation à l'utilisateur

### 4. Implémentation Technique

- Utiliser une solution de gestion d'état (Provider, Riverpod, ou Bloc)
- Implémenter la détection de connectivité (package connectivity_plus)
- Gérer la synchronisation en arrière-plan lorsque l'application revient en ligne
- Gestion appropriée des erreurs et retour utilisateur

## Architecture Suggérée

```
lib/
├── models/
│   └── task.dart
├── services/
│   ├── database_service.dart
│   ├── api_service.dart
│   └── sync_service.dart
├── providers/
│   └── task_provider.dart
├── screens/
│   ├── task_list_screen.dart
│   └── task_detail_screen.dart
└── main.dart
```

## Points Bonus

- Implémenter des mises à jour optimistes de l'interface utilisateur
- Ajouter une fonctionnalité de recherche
- Inclure des catégories/étiquettes de tâches
- Implémenter le glissement pour rafraîchir pour une synchronisation manuelle
- Ajouter des tests unitaires pour la logique de synchronisation
- Gérer les synchronisations partielles (certaines tâches réussissent, d'autres échouent)

## Critères d'Évaluation

- Organisation du code et architecture
- Qualité de l'implémentation offline-first
- Stratégie de résolution des conflits
- Considérations UI/UX
- Robustesse de la gestion des erreurs

## API Simulée

Vous pouvez utiliser JSONPlaceholder ou créer une API simulée simple, ou utiliser Firebase/Supabase pour un backend réel.
