---
name: discover-abort
description: Abort discovery session, delete session file
human_ai_ratio: 80/20
---

# /gtd:discover-abort

## Pré-checks

1. Vérifier si `.claude/discovery-session.md` existe :
   - Si non → "Aucune session discovery en cours."
   - Si oui → continuer

2. Lire la session et extraire : projet, phase courante

## Confirmation

```
Session discovery en cours.
Projet : [description]
Phase : [N]/6 ([nom phase])

Supprimer cette session ? Aucun discovery.md ne sera généré.
[Oui, supprimer] [Non, reprendre plutôt] [Sauvegarder un partiel d'abord]
```

- **Oui, supprimer** → supprimer `.claude/discovery-session.md` et `.claude/research-prompt.md` (si existe) → "Session supprimée."
- **Non, reprendre** → basculer vers `/gtd:discover-resume`
- **Sauvegarder un partiel** → basculer vers `/gtd:discover-save`
