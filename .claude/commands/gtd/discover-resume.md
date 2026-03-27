---
name: discover-resume
description: Resume an interrupted discovery session, detect pending Deep Research
human_ai_ratio: 60/40
---

# /gtd:discover-resume

## Pré-checks

1. Vérifier si `.claude/discovery-session.md` existe :
   - Si non → "Aucune session discovery en cours. Lance `/gtd:discover \"description\"` pour en démarrer une."
   - Si oui → continuer

2. Lire la session et extraire : projet, phase courante, prochaine phase, durée écoulée, recherches pending

## Reprise standard (pas de recherche pending)

```
Session précédente trouvée.
Projet : [description]
Phase complétée : [N]/6 ([nom phase])
Prochaine : [prochaine phase]
Temps écoulé : ~[N] min

Reprendre ? [Oui] [Non, nouvelle session] [Abandonner]
```

- **Oui** → charger le skill `discovery` + la section XML de la prochaine phase → continuer depuis la phase suivante
- **Non, nouvelle session** → archiver la session (ajouter suffixe timestamp), lancer `/gtd:discover`
- **Abandonner** → basculer vers le flow `/gtd:discover-abort`

## Reprise avec recherche Deep pending

Si le Research Log contient une entrée avec `Status: Pending` :

```
Session précédente trouvée.
Projet : [description]
⚠️ Recherche Deep Research en attente ([TYPE])

Tu as les résultats ?
[Oui, je les colle] [Non, skip la recherche] [Relancer le prompt]
```

- **Oui, je les colle** → attendre que l'utilisateur colle les résultats → extraire les points pertinents → mettre à jour le Research Log (status: Done + résumé) → reprendre la phase enrichie des résultats. Si les résultats contredisent une hypothèse précédente → signaler et proposer ajustement.
- **Non, skip** → marquer comme "Skipped" dans le Research Log → ajouter aux questions ouvertes → reprendre la phase normalement
- **Relancer le prompt** → lire `.claude/research-prompt.md` → réafficher le prompt formaté → reproposer les options

## Après reprise

Charger le skill `discovery` et la section XML correspondant à la phase en cours. Reprendre le flow exactement où il s'était arrêté, avec le contexte capturé dans la session.
