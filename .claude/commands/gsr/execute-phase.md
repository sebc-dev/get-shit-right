---
name: execute-phase
description: >
  Execute une phase isolee d'une story. Orchestre : chargement config,
  branching, execution des plans, review, verification finale.
  Args: [epic-slug/story-slug/phase-slug]
human_ai_ratio: 20/80
---

# /gsr:execute-phase $ARGUMENTS

## 0. Charger la configuration

1. Determiner le mode config : executer `.claude/gsr/bin/gsr-config.sh config-mode`
   - Si `jq` → executer `.claude/gsr/bin/gsr-config.sh dump execute` pour obtenir les valeurs
   - Si `claude` → lire `.claude/gsr/config.json` avec Read et extraire `workflow.execute.*`, `workflow.review.*`, `git.*` et `models.*`
   - Si `.claude/gsr/config.json` n'existe pas → utiliser les valeurs par defaut de `.claude/gsr/config-defaults.json`

2. Valeurs chargees :

| Variable | Cle config | Defaut |
|----------|------------|--------|
| `$quality_run_after` | `workflow.execute.quality_gates.run_after` | `task` |
| `$quality_lint` | `workflow.execute.quality_gates.lint` | `true` |
| `$quality_format` | `workflow.execute.quality_gates.format` | `true` |
| `$quality_tests` | `workflow.execute.quality_gates.tests` | `true` |
| `$coverage_threshold` | `workflow.execute.quality_gates.coverage_threshold` | `0` |
| `$max_retries` | `workflow.execute.max_retries_before_debug` | `3` |
| `$commit_style` | `workflow.execute.commit_style` | `conventional` |
| `$review_enabled` | `workflow.review.enabled` | `true` |
| `$review_criteria` | `workflow.review.criteria` | `["security","bugs","conventions","test-coverage"]` |
| `$checkpoint_on` | `workflow.review.checkpoint_on` | `critical` |
| `$branching` | `git.branching_strategy` | `none` |
| `$branch_template` | `git.branch_templates.phase` | `gsr/phase-{phase}-{slug}` |
| `$profile` | `models.active_profile` | `balanced` |

## 1. Parse arguments

Extraire depuis `$ARGUMENTS` :
- `path` : format `[epic-slug]/[story-slug]/[phase-slug]` — ex: `01-auth/01-login/01-setup`
- `--resume` : si present, reprendre une execution interrompue

Deduire :
- `$phase_dir` = `docs/plan/epics/[epic-slug]/stories/[story-slug]/phases/[phase-slug]`
- `$story_dir` = `docs/plan/epics/[epic-slug]/stories/[story-slug]`

## 2. Pre-checks

1. **PLAN.md existe** :
   - Verifier `$phase_dir/PLAN.md` existe
   - Si absent → "Phase introuvable. Verifie le chemin ou lance `/gsr:plan-phases` d'abord."

2. **CONTEXT.md existe** :
   - Verifier `$phase_dir/CONTEXT.md` existe
   - Si absent → "CONTEXT.md manquant pour cette phase."

3. **Session existante** :
   - Si `--resume` ou `.claude/execute-session.md` existe avec status `in-progress` :
     - Afficher le resume de la session
     - Proposer : [Reprendre] [Recommencer]
     - Si reprendre → charger le point de reprise
     - Si recommencer → archiver, creer une nouvelle session

4. **Dependances** :
   - Lire `<phase depends="...">` dans PLAN.md
   - Verifier que les phases dependantes ont un SUMMARY.md avec status complete
   - Si dependance non satisfaite → "Phase [dep] pas encore executee. Execute-la d'abord."

## 3. Initialisation

1. **Creer le session file** (`.claude/execute-session.md`) selon execute-session.md template
2. **Capturer le commit de reference** : `git rev-parse HEAD` → `$ref_commit`
3. **Branching** (si `$branching == "phase"`) :
   - Creer la branche : `git checkout -b [template avec phase+slug]`
   - Documenter dans le session file

## 4. Execution des plans

Lire PLAN.md → parser le XML → extraire tous les `<task>` groupes par plan.

Pour chaque plan dans la phase :

### 4a. Spawn gsr-executor

Spawner l'agent `gsr-executor` :

```
Mode : normal
PLAN.md : $phase_dir/PLAN.md
CONTEXT.md : $phase_dir/CONTEXT.md
SUMMARY.md : $phase_dir/SUMMARY.md
Plan : [numero du plan]

<config>
quality_gates:
  run_after=$quality_run_after
  lint=$quality_lint
  format=$quality_format
  tests=$quality_tests
  coverage_threshold=$coverage_threshold
max_retries=$max_retries
commit_style=$commit_style
</config>

<deviation-rules>
Regle 1 (bug bloquant) : full-auto, fix + test regression + commit fix: separe
Regle 2 (dependance critique) : full-auto, installer + commit chore: separe
Regle 3 (erreur repetee apres $max_retries retries) : STOP, retourner contexte pour debugger
Regle 4 (changement architectural) : STOP, retourner deviation pour checkpoint humain
</deviation-rules>

Execute ce plan. Commite apres chaque task. Documente dans SUMMARY.md.
```

### 4b. Gerer le retour de l'executor

| Retour | Action |
|--------|--------|
| Succes | Mettre a jour session file, passer au plan suivant |
| Deviation regle 3 (echec repete) | Spawner gsr-debugger (voir 4c) |
| Deviation regle 4 (architectural) | Afficher la deviation, demander : [Approuver] [Rejeter] [Modifier] |
| Echec non categorise | Logger dans SUMMARY.md, passer au plan suivant avec avertissement |

### 4c. Escalade debugger (si regle 3)

Spawner l'agent `gsr-debugger` :

```
Erreur : [message d'erreur de l'executor]
Commande : [commande qui echoue]
Fichiers : [fichiers impliques]
Tentatives : [description des N tentatives]
CONTEXT.md : $phase_dir/CONTEXT.md
PLAN.md : $phase_dir/PLAN.md

Diagnostique la cause racine et propose un fix.
```

Selon le diagnostic :
- **fix-simple / fix-complexe** → Spawner gsr-executor en mode fix avec le diagnostic
- **blocage-architectural** → Deviation regle 4 (checkpoint humain)
- **blocage-environnement** → Afficher a l'utilisateur, proposer action manuelle (checkpoint:human-action)

### 4d. Mettre a jour le session file apres chaque plan

## 5. Review

Si `$review_enabled == true` :

### 5a. Spawn gsr-reviewer

```
Ref commit : $ref_commit
Head commit : [git rev-parse HEAD]
Criteres : $review_criteria
CONTEXT.md : $phase_dir/CONTEXT.md
PLAN.md : $phase_dir/PLAN.md
Sortie : .claude/review-findings.json

Review le diff de cette phase.
```

### 5b. Lire les findings

Lire `.claude/review-findings.json` → parser le JSON.

### 5c. Checkpoint si necessaire

**Si critical > 0 ET `$checkpoint_on` in ["critical", "warning"] :**

Afficher :

```
## Review — [N] findings

| Severite | Count |
|----------|-------|
| Critical | N |
| Warning  | N |
| Note     | N |

### Critical findings (action requise)

1. **[criterion]** `file:line` — detail
   → [Fix] [Skip] [Escalate]
```

Pour chaque finding critical, selon le choix :

| Action | Implementation |
|--------|---------------|
| **Fix** | Spawner gsr-executor mode fix (diff + finding + CONTEXT.md). Quality gates. Commit `fix:`. |
| **Skip** | Documenter "Skipped" dans SUMMARY.md |
| **Escalate** | Documenter "Escalated" dans SUMMARY.md |

**Si warning > 0 ET `$checkpoint_on == "warning"` :**
Meme presentation pour les warnings.

### 5d. Documenter dans SUMMARY.md

Ajouter la section Review selon le format dans execute-output.md `<summary-template>`.

## 6. Verification finale

Lire `.claude/gsr/execute-output.md` section `<verification-checklist>`.

### Checks automatiques

1. **Tests globaux** : lancer la suite de tests complete du projet
2. **Lint** : lancer le linter sur le projet
3. **Coverage** : verifier le seuil si `$coverage_threshold > 0`
4. **Findings critiques** : compter les "Escalated" non resolus

### Afficher le verdict

```
## Verification finale — Phase [NN]: [nom]

| Check | Resultat |
|-------|----------|
| Tests globaux | PASS (N tests) / FAIL (N echecs) |
| Lint | Clean / N warnings |
| Coverage | N% (seuil: M%) |
| Findings critiques non resolus | 0 / N |

Verdict : PHASE COMPLETE / PHASE AVEC ALERTES
```

Append au SUMMARY.md.

## 7. Finalisation

1. **Mettre a jour le session file** : status → `completed`
2. **Mettre a jour GSR-STATUS.md** selon `.claude/gsr/status-output.md` section `<update-execute-phase>`
3. **Nettoyer** : supprimer `.claude/review-findings.json` (temporaire)

## 8. Resume final

```
Phase [NN]: [nom] — COMPLETE

Plans : N executes, N commits
Deviations : N (N auto, N checkpoint)
Review : N findings (N critical, N fixed, N escalated)
Verification : [PASS/ALERTES]

Prochaine etape :
  Phase suivante : /gsr:execute-phase [epic]/[story]/[phase-suivante]
  Ou toute la story : /gsr:execute [epic]/[story]
```

## Garde-fous

| Limite | Valeur | Comportement |
|--------|--------|-------------|
| Retries par task | `$max_retries` (defaut: 3) | Escalade debugger |
| Fix loop par finding | 2 max | Si 2 tentatives echouent → Escalate automatiquement |
| Checkpoints humains cumules | 5 max | "Trop de blocages. Revoir le plan ?" |
