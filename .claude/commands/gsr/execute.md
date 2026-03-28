---
name: execute
description: >
  Execute une story complete en orchestrant ses phases sequentiellement.
  Gere le branching, le /clear entre phases, et le suivi global.
  Args: [epic-slug/story-slug] [--phase=NN] [--resume]
human_ai_ratio: 15/85
---

# /gsr:execute $ARGUMENTS

## 0. Charger la configuration

Meme chargement que `/gsr:execute-phase` — voir execute-phase.md section 0.

Variables supplementaires :

| Variable | Cle config | Defaut |
|----------|------------|--------|
| `$branching` | `git.branching_strategy` | `none` |
| `$milestone_template` | `git.branch_templates.story` | `gsr/{epic}-{story}` |

## 1. Parse arguments

Extraire depuis `$ARGUMENTS` :
- `path` : format `[epic-slug]/[story-slug]` — ex: `01-auth/01-login`
- `--phase=NN` : optionnel, commencer a partir de la phase NN (skip les precedentes)
- `--resume` : reprendre une execution interrompue

Deduire :
- `$story_dir` = `docs/plan/epics/[epic-slug]/stories/[story-slug]`
- `$phases_dir` = `$story_dir/phases`

## 2. Pre-checks

1. **Story planifiee** :
   - Verifier `$phases_dir` existe et contient des sous-dossiers
   - Chaque sous-dossier doit avoir PLAN.md + CONTEXT.md
   - Si absent → "Phases non generees. Lance `/gsr:plan-phases [epic]/[story]` d'abord."

2. **Lister les phases** :
   - Scanner `$phases_dir/*/PLAN.md`
   - Trier par numero de phase (prefix numerique du dossier)
   - Stocker dans `$phases` (liste ordonnee)

3. **Session existante** :
   - Si `--resume` ou `.claude/execute-session.md` existe avec status `in-progress` :
     - Lire le session file
     - Identifier la derniere phase completee
     - Proposer : [Reprendre a phase N] [Recommencer]
   - Si pas de session → creer une nouvelle

4. **Phase de depart** :
   - Si `--phase=NN` → commencer a cette phase (verifier qu'elle existe)
   - Si `--resume` → reprendre apres la derniere phase completee
   - Sinon → commencer a la phase 1

## 3. Initialisation

1. **Creer le session file** (`.claude/execute-session.md`) avec toutes les phases listees
2. **Capturer le commit de reference global** : `git rev-parse HEAD` → `$global_ref`
3. **Branching** (si `$branching == "milestone"`) :
   - Creer la branche story : `git checkout -b [template avec epic+story]`
   - Documenter dans le session file

## 4. Boucle d'execution des phases

Pour chaque phase dans `$phases` (a partir de la phase de depart) :

### 4a. Afficher la progression

```
## Execution — Phase [N]/[total] : [nom]

Story : [epic]/[story]
Phase : [slug]
Objectif : [depuis PLAN.md]
```

### 4b. Contexte frais

**IMPORTANT :** Avant chaque phase (sauf la premiere) :
- L'orchestrateur recharge CONTEXT.md de la phase pour maintenir un contexte propre
- Le session file sert de memoire entre les phases

### 4c. Executer la phase

Suivre exactement le flow de `/gsr:execute-phase` etapes 3 a 7, MAIS :
- Ne PAS creer un session file separe (utiliser le session file global)
- Ne PAS creer de branche si `$branching == "milestone"` (deja sur la branche story)
- Si `$branching == "phase"` → creer/supprimer des branches par phase comme dans execute-phase

Le commit de reference pour la review est le commit de debut de phase (pas le `$global_ref`).

### 4d. Gerer le resultat

| Resultat | Action |
|----------|--------|
| Phase complete | Mettre a jour session file, passer a la suivante |
| Phase avec alertes | Afficher les alertes, proposer : [Continuer] [Stop] |
| Phase echouee | Afficher l'erreur, proposer : [Retry] [Skip] [Stop] |

Si **Stop** → mettre a jour session file status `interrupted`, proposer `/gsr:execute --resume`

### 4e. Mettre a jour le session file

Apres chaque phase :
- Marquer la phase comme completed/failed
- Timestamp de mise a jour

### 4f. Checkpoint inter-phases

Entre chaque phase, afficher un bref resume :

```
Phase [N]/[total] complete — [M] commits, [K] deviations

[Continuer phase suivante] [Pause]
```

Si **Pause** → sauvegarder le session file, proposer `/gsr:execute --resume`

## 5. Verification globale

Apres la derniere phase :

1. Lancer les tests globaux du projet
2. Verifier le lint
3. Verifier la coverage

```
## Verification globale — Story [epic]/[story]

| Check | Resultat |
|-------|----------|
| Tests globaux | PASS / FAIL |
| Lint | Clean / N warnings |
| Coverage | N% |

Phases : [N] executees, [M] commits total
Deviations : [N] total
Review findings : [N] total ([K] critical, [J] fixed, [L] escalated)
```

## 6. Finalisation

1. **Session file** : status → `completed`
2. **GSR-STATUS.md** : mettre a jour selon `<update-execute>` dans status-output.md
3. **Nettoyer** : supprimer `.claude/review-findings.json`

## 7. Resume final

```
Story [epic]/[story] — EXECUTION COMPLETE

Phases : N/N executees
Commits : N total
Deviations : N (N auto, N checkpoint)
Review : N findings (N critical, N fixed, N escalated)
Verification : [PASS/ALERTES]

Prochaine etape :
  Autre story : /gsr:execute [epic]/[autre-story]
  Plan une story : /gsr:plan-story [epic]/[story]
```

## Mise a jour du suivi

Mettre a jour `docs/GSR-STATUS.md` selon `.claude/gsr/status-output.md` section `<update-execute>` :
- Pipeline : Execute → `En cours` (debut) ou `OK` (fin si toutes les stories executees)
- Phase active → `Execute`
- Detail par Epic : mettre a jour le statut des stories executees
- Historique : "Story [epic]/[story] executee ([N] phases, [M] commits)"

## Garde-fous

| Limite | Valeur | Comportement |
|--------|--------|-------------|
| Phases max par execution | 8 (config) | Au-dela → "Story tres longue, execution par lots ?" |
| Checkpoints humains cumules | 10 max | "Trop de blocages. Revoir la planification ?" |
| Phases echouees consecutives | 2 | "2 phases echouees d'affilee. Stop automatique." |
