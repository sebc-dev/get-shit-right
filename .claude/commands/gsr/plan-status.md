---
name: plan-status
description: >
  Affiche l'état de planification du projet : quels epics et stories sont
  planifiés, lesquels restent à détailler, progression globale.
human_ai_ratio: 10/90
---

# /gsr:plan-status

## Pré-checks

1. Vérifier si `docs/plan/ROADMAP.md` existe :
   - Si absent → "Aucun plan trouvé. Lance `/gsr:plan` pour démarrer la planification."

## Collecte d'état

1. Lire `docs/plan/ROADMAP.md` pour la vue d'ensemble

2. Scanner l'arborescence `docs/plan/epics/` :
   - Pour chaque epic (`[NN]-[slug]/`) :
     - Lire EPIC.md → extraire priorité, dépendances
     - Pour chaque story dans `stories/` :
       - STORY.md absent → `⬜ À détailler`
       - STORY.md présent, pas de dossier `phases/` → `🔲 Story détaillée`
       - Dossier `phases/` avec PLAN.md → `✅ Phases générées`

3. Vérifier si `.claude/plan-session.md` existe :
   - Si oui → extraire le niveau en cours et ce qui est en progression

## Affichage

```
Planification : [Nom du projet]
Granularité : [fine|standard|flexible]

| # | Epic | Stories | Détaillées | Phases prêtes | Statut |
|---|------|---------|------------|---------------|--------|
[table avec compteurs par epic]

Total : [N] epics, [N] stories, [N] détaillées, [N] avec phases

Graphe de dépendances :
[Depuis ROADMAP.md]

Session en cours : [oui/non — si oui, quel niveau et quoi]

Prochaines actions suggérées :
  [Suggérer la prochaine story/epic à planifier selon l'ordonnancement]
```

## Suggestions intelligentes

Proposer la prochaine action logique selon l'état :
- Si des stories sont `⬜` dans l'epic prioritaire → `/gsr:plan-story [epic]/[story]`
- Si une story est `🔲` et prête pour les phases → `/gsr:plan-phases [epic]/[story]`
- Si tout est `✅` → "Plan complet. Prêt pour l'exécution."
- Si rien n'est planifié → `/gsr:plan` pour commencer
