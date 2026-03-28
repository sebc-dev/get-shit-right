---
name: update
description: >
  Met a jour GSR vers la derniere version depuis GitHub.
  Re-telecharge les fichiers des phases installees.
  Args: [--dry-run] [--force]
human_ai_ratio: 20/80
---

# /gsr:update $ARGUMENTS

## Parse arguments

- `--dry-run` : afficher ce qui serait mis a jour sans ecrire
- `--force` : mettre a jour meme si deja a jour

## Etape 1 — Verifier les versions

1. Lire la version locale depuis `.claude/gsr/VERSION`
   - Si absent → "Aucune version installee. Utilise `curl -fsSL https://raw.githubusercontent.com/sebc-dev/get-shit-right/main/install.sh | bash` pour installer."

2. Recuperer la version distante :
   - URL : `https://raw.githubusercontent.com/sebc-dev/get-shit-right/main/VERSION`
   - Si echec → "Impossible de contacter GitHub. Verifie ta connexion."

3. Comparer :
   - Si locale == distante et pas `--force` → "Deja a jour (v[version]). Utilise --force pour forcer la reinstallation."
   - Sinon → continuer

## Etape 2 — Detecter les phases installees

Scanner les fichiers presents dans `.claude/` pour determiner quelles phases sont installees :

- Si `.claude/commands/gsr/discover.md` existe → phase `discovery` installee
- Si `.claude/commands/gsr/plan.md` existe → phase `plan` installee
- Si `.claude/commands/gsr/execute.md` existe → phase `execute` installee

Afficher :
```
Mise a jour GSR : v[locale] → v[distante]

Phases installees : [liste]
Fichiers a mettre a jour : [N]

[Continuer] [Annuler] [Voir les changements sur GitHub]
```

Si "Voir les changements" → afficher le lien `https://github.com/sebc-dev/get-shit-right/compare/v[locale]...v[distante]`

## Etape 3 — Telecharger et installer

Pour chaque phase installee, executer dans le terminal :

```bash
GSR_PHASES="[phases]" GSR_FORCE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebc-dev/get-shit-right/main/install.sh)"
```

Si `--dry-run` → ajouter `GSR_DRY_RUN=1`

## Etape 4 — Verifier

1. Relire `.claude/gsr/VERSION` → confirmer la nouvelle version
2. Afficher :
   ```
   GSR mis a jour : v[ancienne] → v[nouvelle]

   Phases mises a jour : [liste]
   Fichiers : [N] installes

   Changelog : https://github.com/sebc-dev/get-shit-right/compare/v[ancienne]...v[nouvelle]
   ```
