---
name: plan-abort
description: >
  Annuler la session de planification en cours. Supprime .claude/plan-session.md
  et optionnellement les fichiers partiels dans docs/plan/ après confirmation.
human_ai_ratio: 80/20
---

# /gsr:plan-abort

## Pré-checks

1. Vérifier si `.claude/plan-session.md` existe :
   - Si absent → "Aucune session de planification en cours."

2. Vérifier si `docs/plan/` existe et contient des fichiers

## Confirmation

Afficher l'état actuel :
```
Session de planification en cours :
- Niveau : [depuis session]
- Epics planifiés : [N]
- Stories détaillées : [N]
- Phases générées : [N]
- Durée écoulée : [N min]

Que veux-tu supprimer ?
[A] Session uniquement (.claude/plan-session.md) — garder les fichiers générés
[B] Tout supprimer (session + docs/plan/) — repartir de zéro
[C] Annuler — ne rien faire
```

## Actions

### Option A — Session uniquement
1. Supprimer `.claude/plan-session.md`
2. Supprimer `.claude/research-prompt.md` si présent
3. Message : "Session supprimée. Les fichiers dans docs/plan/ sont conservés."

### Option B — Tout supprimer
1. Demander confirmation : "Confirmer la suppression de docs/plan/ et de la session ? [Oui] [Non]"
2. Si confirmé :
   - Supprimer `.claude/plan-session.md`
   - Supprimer `.claude/research-prompt.md` si présent
   - Supprimer le dossier `docs/plan/` et tout son contenu
3. Message : "Session et fichiers de plan supprimés. Tu peux relancer `/gsr:plan`."

### Option C — Annuler
- Message : "Annulation. La session est intacte."
