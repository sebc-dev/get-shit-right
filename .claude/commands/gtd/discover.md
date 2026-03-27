---
name: discover
description: Start a new discovery session — interactive 6-phase interview generating discovery.md
human_ai_ratio: 70/30
---

# /gtd:discover "$ARGUMENTS"

## Pré-checks

1. Vérifier si un fichier `discovery.md` existe déjà dans le projet :
   - Si oui → "Un discovery.md existe déjà. Veux-tu le remplacer ? [Oui, nouvelle discovery] [Non, annuler]"
   - Si "Non" → stop

2. Vérifier si une session existe dans `.claude/discovery-session.md` :
   - Si oui → "Une session discovery est en cours (Phase [N]/6). Utilise `/gtd:discover-resume` pour la reprendre, ou confirme pour en démarrer une nouvelle (l'ancienne sera archivée). [Reprendre] [Nouvelle session]"
   - Si "Reprendre" → basculer vers le flow de `/gtd:discover-resume`
   - Si "Nouvelle session" → archiver l'ancienne session, continuer

## Initialisation

1. Lire la description du projet depuis les arguments : `$ARGUMENTS`
   - Si vide → demander : "Décris ton projet en 1-2 phrases."

2. Créer le fichier session `.claude/discovery-session.md` avec :
   ```
   # Discovery Session
   Project: [description depuis arguments]
   Phase: 1/6 (Problème)
   Next: Contraintes
   Updated: [timestamp]
   Started: [timestamp]

   ## Timing
   Elapsed: ~0 min
   Target: < 45 min
   Status: ✅ On track

   ## Captured
   [vide — sera rempli phase par phase]

   ## Open Questions
   [vide]

   ## Research Log
   | # | Timestamp | Phase | Type | Mode | Status | Résumé |
   |---|-----------|-------|------|------|--------|--------|

   ## Validation Metadata
   ### Checklist complétude
   - [ ] Problème défini (§1)
   - [ ] Contraintes documentées (§2)
   - [ ] Stack avec versions (§3)
   - [ ] Architecture avec schéma (§4)
   - [ ] MVP délimité (§5)
   - [ ] Exclusions listées (§6)
   - [ ] Risques identifiés (§7)
   ```

3. Charger le skill `discovery` (`.claude/skills/gtd-discovery/discovery.md`)

## Lancement Phase 1

1. Lire la section `<phase-1-problem>` depuis `.claude/skills/gtd-discovery/discovery-phases.md`

2. Message d'accueil :
   ```
   Discovery démarrée pour : "[description projet]"

   On va cadrer ton projet en 6 phases (~30-45 min).
   Je pose une question à la fois. Tu peux dire "je ne sais pas" — on gérera.

   Phase 1/6 — Problème

   [Première question de Phase 1, contextualisée avec la description fournie]
   ```

3. Suivre le flow de la Phase 1 selon les règles du skill et les critères de sortie de `<phase-1-problem>`

4. À chaque phase validée → sauvegarder la session → charger la section XML de la phase suivante → continuer

5. Après Phase 6 → écrire `discovery.md` final → proposer `/gtd:bootstrap`
