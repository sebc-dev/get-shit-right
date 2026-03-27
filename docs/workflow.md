# Workflow Architecture: Solo Dev Pipeline

> **Version:** 0.1 — Architecture initiale pour itération **Entrée:** 4 docs pré-existants (Brief, PRD, Architecture, UX/UI) **Sortie:** Code en production, testé, déployé

---

## 1. Vue d'ensemble

### Philosophie

Trois principes empruntés à GSD adaptés au contexte solo dev :

- **Context engineering** — Chaque phase démarre avec un contexte frais et ciblé
- **Plans as prompts** — Les fichiers PLAN.md sont directement exécutables par Claude
- **State as memory** — STATE.md survit aux `/clear` et aux changements de session

### Flux global

```
┌─────────────────────────────────────────────────────────────┐
│                    DOCUMENTS PRÉ-EXISTANTS                  │
│         Brief  ·  PRD  ·  Architecture  ·  UX/UI           │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
              ┌────────────────────────┐
              │    PHASE 0 : INIT      │
              │  Parse docs → Config   │
              │  Quality gate script   │
              │  CLAUDE.md + skills    │
              │  Roadmap + State       │
              └───────────┬────────────┘
                          ▼
              ┌────────────────────────┐
              │   PHASE 1 : PLAN       │
              │  Epics → Phases        │◄── Graphe de dépendances
              │  Détection parallèle   │    + estimation taille
              │  Branches strategy     │
              └───────────┬────────────┘
                          ▼
              ┌────────────────────────┐
              │   PHASE 2 : EXECUTE    │──── Boucle par phase ────┐
              │  Par phase :           │                          │
              │  · Branch + worktree   │   ┌──────────────────┐   │
              │  · TDD (RED→GREEN→REF) │   │ Phases parallèles│   │
              │  · Commits atomiques   │   │ via worktrees    │   │
              │  · Quality gate auto   │   └──────────────────┘   │
              └───────────┬────────────┘◄─────────────────────────┘
                          ▼
              ┌────────────────────────┐
              │   REVIEW HUMAINE       │
              │  Entre chaque phase :  │
              │  · Rapport quality gate│──► Si FAIL → fix loop
              │  · Diff résumé         │
              │  · Décision go/no-go   │
              └───────────┬────────────┘
                          ▼
              ┌────────────────────────┐
              │   PHASE 3 : SHIP       │
              │  Merge → develop/main  │
              │  Deploy + smoke tests  │
              │  Archivage phase       │
              └────────────────────────┘
```

---

## 2. Structure de fichiers

```
project/
├── docs/                          # Pré-existants (READ-ONLY pendant exec)
│   ├── BRIEF.md
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   └── UX-UI.md
│
├── .workflow/                     # État du workflow (versionné)
│   ├── config.json                # Stack, quality gates, agents, flags
│   ├── STATE.md                   # État courant du projet (survit aux /clear)
│   ├── ROADMAP.md                 # Epics → phases avec dépendances
│   ├── quality-gate.sh            # Script généré à l'init selon la stack
│   │
│   ├── phases/                    # Un dossier par phase
│   │   ├── 01-foundation/
│   │   │   ├── PLAN.md            # Plan exécutable (format XML tasks)
│   │   │   ├── CONTEXT.md         # Contexte chargé au démarrage de phase
│   │   │   ├── VERIFICATION.md    # Résultat quality gate
│   │   │   └── SUMMARY.md         # Résumé post-exécution
│   │   ├── 02-auth/
│   │   └── ...
│   │
│   └── archive/                   # Phases complétées archivées
│
├── .claude/
│   ├── settings.local.json        # Hooks projet
│   ├── agents/                    # Agents spécialisés
│   │   ├── planner.md
│   │   ├── implementer.md
│   │   ├── reviewer.md
│   │   └── tdd-guard.md
│   ├── commands/                  # Slash commands du workflow
│   │   ├── wf-init.md
│   │   ├── wf-plan.md
│   │   ├── wf-execute.md
│   │   ├── wf-review.md
│   │   ├── wf-status.md
│   │   └── wf-parallel.md
│   ├── skills/                    # Skills par stack (chargés à la demande)
│   │   ├── astro.md
│   │   ├── nuxt-vue.md
│   │   ├── tauri-v2.md
│   │   └── cloudflare.md
│   └── rules/                     # Rules universelles
│       ├── tdd.md
│       ├── commit-conventions.md
│       └── context-management.md
│
├── CLAUDE.md                      # < 100 lignes — contexte universel
└── src/                           # Code source
```

### Décisions structurelles

|Choix|Justification|
|---|---|
|`.workflow/` séparé de `.claude/`|Séparation état workflow vs config Claude Code|
|`CONTEXT.md` par phase|Chargé via `cat` au début de chaque phase → contexte frais et ciblé|
|`PLAN.md` en XML tasks|Directement exécutable par Claude (pattern GSD prouvé)|
|Skills dans `.claude/skills/`|Auto-chargement par Claude quand les fichiers de la stack sont touchés|
|`quality-gate.sh` généré|Adapté à la stack, pas de one-size-fits-all|

---

## 3. Configuration — `config.json`

```jsonc
{
  // Métadonnées projet
  "project": {
    "name": "mon-projet",
    "stack": ["astro", "tailwind-v4", "cloudflare-workers"],
    "test_runner": "vitest",
    "e2e_runner": "playwright",      // null si pas d'E2E
    "package_manager": "pnpm"
  },

  // Stratégie de branches
  "git": {
    "main_branch": "main",
    "dev_branch": "develop",
    "phase_branch_template": "phase/{phase_number}-{slug}",
    "auto_commit": true,
    "commit_style": "conventional"   // conventional | gitmoji
  },

  // Quality gates — seuils par phase
  "quality_gates": {
    "coverage_min": 80,
    "mutation_min": 60,
    "lint_zero_errors": true,
    "format_check": true,
    "vuln_check": true,
    "progressive": true              // Seuils allégés phases 1-2, stricts après
  },

  // Agents et parallélisation
  "agents": {
    "max_parallel": 3,               // Max 3 worktrees simultanés (empirique < 4)
    "model_planning": "opus",
    "model_implementation": "sonnet",
    "model_review": "sonnet",
    "model_exploration": "haiku"
  },

  // Workflow toggles
  "workflow": {
    "auto_tdd": true,                // TDD obligatoire
    "mutation_testing": true,
    "auto_format_on_save": true,     // Hook PostToolUse
    "require_human_review": true     // Review entre phases
  }
}
```

---

## 4. Cycle de vie — les 4 macro-phases

### PHASE 0 : INIT (`/wf-init`)

**Objectif :** Parser les 4 documents sources et bootstrapper toute l'infrastructure du workflow.

**Étapes :**

1. **Parse des documents** — Extraction structurée :
    
    - PRD → epics, functional requirements, acceptance criteria (Given-When-Then)
    - Architecture → stack, patterns, ADRs, contraintes
    - UX/UI → composants, routes, design tokens
    - Brief → objectifs business, personas, KPIs
2. **Génération config** :
    
    - `config.json` basé sur la stack détectée dans Architecture.md
    - `quality-gate.sh` adapté (voir section 7)
    - `CLAUDE.md` minimal (< 100 lignes) avec stack + commandes + règles critiques
3. **Setup skills/rules** :
    
    - Activation des skills pertinents selon la stack
    - Configuration MCP servers (ex: `search_astro_docs`, `search_cloudflare_documentation`)
    - Rules universelles (TDD, commits, context management)
4. **Initialisation Git** :
    
    - Branche `develop` depuis `main`
    - Commit initial de `.workflow/` et `.claude/`

**Critère de sortie :** `config.json` + `quality-gate.sh` + `CLAUDE.md` + `.claude/` complet → commit `chore: init workflow`

---

### PHASE 1 : PLAN (`/wf-plan`)

**Objectif :** Transformer les epics du PRD en phases exécutables avec graphe de dépendances.

**Agent :** `planner.md` (Opus, lecture seule)

**Étapes :**

1. **Extraction des epics** depuis le PRD
2. **Décomposition en phases** — Chaque phase doit :
    - Être completable en 2-4h de travail Claude
    - Avoir des acceptance criteria testables
    - Avoir des dépendances explicites
    - Produire un incrément fonctionnel vérifiable
3. **Graphe de dépendances** — Identification des phases parallélisables :
    
    ```
    Phase 01 (Foundation) ──► Phase 02 (Auth) ──► Phase 05 (Dashboard)                       ──► Phase 03 (API)  ──► Phase 05                       ──► Phase 04 (UI)   ──► Phase 05Parallélisables : [02, 03, 04] après 01
    ```
    
4. **Génération ROADMAP.md** avec estimation et ordre d'exécution
5. **Génération PLAN.md** par phase au format XML tasks :
    
    ```xml
    <phase id="02" name="auth" depends="01" parallel_group="A">  <task type="tdd">    <n>Login endpoint</n>    <files>src/api/auth/login.ts, tests/api/auth/login.test.ts</files>    <criteria>      Given valid credentials, when POST /api/auth/login, then return JWT + httpOnly cookie      Given invalid credentials, when POST /api/auth/login, then return 401    </criteria>    <verify>pnpm test tests/api/auth/login.test.ts</verify>  </task>  <!-- ... --></phase>
    ```
    
6. **Génération CONTEXT.md** par phase — Extract ciblé des 4 docs sources ne contenant QUE ce qui est pertinent pour cette phase

**Critère de sortie :** `ROADMAP.md` complet + `PLAN.md` + `CONTEXT.md` pour chaque phase → commit `docs: plan phases`

**Anti-pattern :** Ne jamais gonfler le nombre de phases pour atteindre un ratio arbitraire. Dériver du travail réel.

---

### PHASE 2 : EXECUTE (`/wf-execute [phase_number]`)

**Objectif :** Exécuter une phase en mode `--dangerously-skip-permissions` avec TDD.

**Séquence par phase :**

```
1. Création branche    git checkout -b phase/02-auth develop
2. Chargement contexte cat .workflow/phases/02-auth/CONTEXT.md
3. Boucle TDD          Pour chaque task du PLAN.md :
   │
   ├─ 🔴 RED          Écrire le test qui fail
   │                   Vérifier qu'il fail pour la bonne raison
   │
   ├─ 🟢 GREEN        Code minimal pour passer
   │                   /clear entre RED et GREEN (isolation contexte)
   │
   ├─ 🔵 REFACTOR     Nettoyer en gardant les tests verts
   │
   └─ 📦 COMMIT       git commit (conventionnel, atomique par task)
                       Hook PreToolUse vérifie tests verts avant commit

4. Quality gate        ./workflow/quality-gate.sh
5. Vérification        Génère VERIFICATION.md + SUMMARY.md
6. Attente review      Notification humaine
```

**Gestion du contexte pendant l'exécution :**

|Seuil contexte|Action|
|---|---|
|< 60%|Continuer normalement|
|60-70%|Écrire progression dans SUMMARY.md|
|70-80%|`/compact` ou déléguer à sub-agent|
|> 80%|Document & Clear → nouvelle session avec CONTEXT.md + SUMMARY.md|

**Commits atomiques :** Chaque task = 1 commit. Format :

```
feat(02-auth): implement login endpoint
test(02-auth): add login endpoint tests
refactor(02-auth): extract token generation utility
```

---

### PHASE 2bis : EXECUTE PARALLÈLE (`/wf-parallel [phase1] [phase2] ...`)

**Objectif :** Exécuter des phases indépendantes en parallèle via worktrees.

**Prérequis :** Les phases doivent appartenir au même `parallel_group` dans ROADMAP.md (pas de dépendances croisées).

**Mécanisme :**

```
project/                          # Phase 02 (agent 1)
├── .git/
└── src/

../project-phase-03/              # Worktree phase 03 (agent 2)
└── src/

../project-phase-04/              # Worktree phase 04 (agent 3)
└── src/
```

**Orchestration :**

```bash
# Création worktrees
git worktree add ../project-phase-03 -b phase/03-api develop
git worktree add ../project-phase-04 -b phase/04-ui develop

# Lancement agents parallèles (chacun dans son worktree)
# Agent 1 : claude --dangerously-skip-permissions dans project/
# Agent 2 : claude --dangerously-skip-permissions dans ../project-phase-03/
# Agent 3 : claude --dangerously-skip-permissions dans ../project-phase-04/
```

**Fichier de coordination** `.workflow/parallel-state.md` :

```markdown
# Parallel Execution State
## Active
- Phase 02 (auth) — worktree: project/ — status: executing
- Phase 03 (api) — worktree: ../project-phase-03/ — status: executing
- Phase 04 (ui) — worktree: ../project-phase-04/ — status: quality-gate

## Completed
- (none yet)
```

**Merge séquentiel après completion :**

```bash
# Chaque phase mergée dans develop dans l'ordre de complétion
git checkout develop
git merge --no-ff phase/03-api
git merge --no-ff phase/04-ui
git merge --no-ff phase/02-auth
# Résolution conflits si nécessaire → sub-agent dédié
git worktree remove ../project-phase-03
git worktree remove ../project-phase-04
```

**Limite :** Max 3 worktrees parallèles (config `agents.max_parallel`). Au-delà, mise en queue.

---

### REVIEW HUMAINE (entre chaque phase)

**Déclenchée automatiquement** après le quality gate.

**L'humain reçoit :**

1. **VERIFICATION.md** — Résultat quality gate (pass/fail par critère)
2. **SUMMARY.md** — Ce qui a été fait, décisions prises, problèmes rencontrés
3. **Diff résumé** — `git diff develop..phase/XX-slug --stat`
4. **Rapport couverture** — Lien vers le rapport HTML si disponible

**Décisions possibles :**

|Décision|Action|
|---|---|
|✅ Approve|Merge dans develop, archiver phase, passer à la suivante|
|🔄 Fix|Liste de corrections → nouvelle itération de la phase|
|⏸️ Pause|Sauvegarder l'état, reprendre plus tard|
|❌ Reject|Supprimer la branche, re-planifier la phase|

---

### PHASE 3 : SHIP (`/wf-ship`)

**Objectif :** Merge final et déploiement.

**Séquence :**

1. Merge `develop` → `main`
2. Tag de version
3. Déploiement (selon stack : `wrangler deploy`, `pnpm build && deploy`, etc.)
4. Smoke tests post-deploy
5. Archivage `.workflow/phases/` → `.workflow/archive/`
6. Mise à jour STATE.md final

---

## 5. Agents spécialisés

Architecture **Master-Clone** : l'orchestrateur principal délègue via `Task()` à des agents avec permissions minimales.

### `planner.md`

```markdown
---
name: planner
description: Décompose les epics en phases exécutables. Invoqué pour la planification.
tools: Read, Grep, Glob
model: opus
---

Tu es un architecte de workflow spécialisé en décomposition de tâches.

## Mission
Transformer les epics du PRD en phases de 2-4h avec :
- Acceptance criteria testables (Given-When-Then)
- Dépendances explicites entre phases
- Identification des phases parallélisables
- Format XML tasks pour chaque PLAN.md

## Contraintes
- MAX 8 tasks par phase
- Chaque task doit être atomique et commitable
- Les fichiers touchés par une task ne doivent PAS chevaucher ceux d'une autre phase parallèle
- Inclure les tests dans chaque task (TDD)

## Output
Écrire directement dans .workflow/phases/XX-slug/PLAN.md
```

### `implementer.md`

```markdown
---
name: implementer
description: Exécute les tasks d'un PLAN.md en mode TDD. Agent principal d'implémentation.
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

Tu es un développeur senior appliquant strictement le TDD.

## Workflow par task
1. Lire la task et ses criteria
2. 🔴 Écrire le test qui échoue
3. Vérifier l'échec (run test)
4. 🟢 Implémenter le minimum pour passer
5. Vérifier le passage
6. 🔵 Refactorer si nécessaire
7. Commit atomique

## Règles
- JAMAIS implémenter sans test d'abord
- JAMAIS committer avec des tests qui échouent
- Un commit = une task = un incrément vérifiable
- Si le contexte dépasse 70%, écrire SUMMARY.md et signaler
```

### `reviewer.md`

```markdown
---
name: reviewer
description: Review de code et quality gate. Invoqué après exécution de phase.
tools: Read, Grep, Glob, Bash
model: sonnet
---

Tu es un reviewer senior exigeant mais constructif.

## Checklist
- [ ] Chaque task du PLAN.md a un commit correspondant
- [ ] Tests couvrent les acceptance criteria
- [ ] Pas de `any` TypeScript / pas de TODO sans issue
- [ ] Pas de secrets ou credentials en dur
- [ ] Conventions de nommage respectées
- [ ] Quality gate script passe

## Output
Écrire VERIFICATION.md avec :
- Status par critère (PASS/FAIL/WARN)
- Score global
- Liste de fixes nécessaires si FAIL
```

### `tdd-guard.md`

```markdown
---
name: tdd-guard
description: Vérifie que le workflow TDD est respecté. Invoqué comme checker.
tools: Read, Grep, Glob, Bash
model: haiku
---

Tu vérifies que le TDD est correctement appliqué.

## Vérifications
1. Chaque fichier .ts/.js a un fichier .test correspondant
2. Les tests ont été commités AVANT l'implémentation (vérifier timestamps git)
3. Les tests couvrent les Given-When-Then du PLAN.md
4. Pas de tests vides ou skip

## Output
Score TDD compliance (0-100) + liste des violations
```

---

## 6. Hooks

### `.claude/settings.local.json`

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // empty' | { read f; [[ -n \"$f\" && \"$f\" == *.ts ]] && npx prettier --write \"$f\" 2>/dev/null; } || true"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [
          {
            "type": "command",
            "command": "cd \"$CLAUDE_PROJECT_DIR\" && npm test -- --run 2>/dev/null || exit 2"
          }
        ]
      },
      {
        "matcher": "Bash(git push*)",
        "hooks": [
          {
            "type": "command",
            "command": "cd \"$CLAUDE_PROJECT_DIR\" && bash .workflow/quality-gate.sh --quick 2>/dev/null || exit 2"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo \"Phase: $(git branch --show-current) | Context: ready for review\" || true"
          }
        ]
      }
    ]
  }
}
```

### Logique des hooks

|Hook|Trigger|Action|Exit code|
|---|---|---|---|
|PostToolUse (format)|Write/Edit sur .ts|Prettier auto-format|0 (silent)|
|PreToolUse (test)|`git commit`|Run tests → bloque si fail|2 (block)|
|PreToolUse (gate)|`git push`|Quality gate quick → bloque si fail|2 (block)|
|Stop (info)|Fin de réponse|Affiche branche + état|0 (info)|

**Anti-pattern évité :** Les hooks bloquent au commit/push, pas à l'écriture. Bloquer mid-opération confuse l'agent.

---

## 7. Quality Gate — Script généré

Le script `quality-gate.sh` est généré à l'init selon la stack. Exemple pour une stack Astro + Vitest :

```bash
#!/bin/bash
set -e

MODE="${1:---full}"  # --quick (pre-push) ou --full (fin de phase)

echo "══════════════════════════════════════"
echo "  QUALITY GATE — $(git branch --show-current)"
echo "══════════════════════════════════════"

RESULTS=""
PASS=0
FAIL=0

run_check() {
  local name="$1"
  local cmd="$2"
  local required="${3:-true}"
  
  echo "▸ $name..."
  if eval "$cmd" > /tmp/qg-$name.log 2>&1; then
    RESULTS+="  ✅ $name\n"
    ((PASS++))
  else
    if [ "$required" = "true" ]; then
      RESULTS+="  ❌ $name (REQUIRED)\n"
      ((FAIL++))
    else
      RESULTS+="  ⚠️  $name (optional)\n"
    fi
  fi
}

# ── Toujours exécutés ──────────────────────────
run_check "lint"        "npx eslint src/ --max-warnings 0"
run_check "format"      "npx prettier --check 'src/**/*.{ts,tsx,astro}'"
run_check "typecheck"   "npx tsc --noEmit"
run_check "unit-tests"  "npx vitest run --reporter=verbose"

# ── Seulement en mode --full ───────────────────
if [ "$MODE" = "--full" ]; then
  run_check "coverage"       "npx vitest run --coverage --coverage.thresholds.lines=80"
  run_check "mutation"       "npx stryker run --reporters=clear-text" "false"
  run_check "vuln-check"     "npm audit --audit-level=high"
  run_check "e2e"            "npx playwright test" "false"
fi

# ── Rapport ────────────────────────────────────
echo ""
echo "══════════════════════════════════════"
echo "  RÉSULTATS: $PASS passed, $FAIL failed"
echo "══════════════════════════════════════"
echo -e "$RESULTS"

# Écrire le rapport
cat > .workflow/phases/$(git branch --show-current | sed 's|phase/||')/VERIFICATION.md << EOF
# Quality Gate Report
**Branch:** $(git branch --show-current)
**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Mode:** $MODE

## Results
$(echo -e "$RESULTS")

**Status:** $([ $FAIL -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL ($FAIL checks failed)")
EOF

[ $FAIL -eq 0 ] && exit 0 || exit 1
```

### Mode progressif

|Moment|Checks exécutés|
|---|---|
|Hook pre-commit|Tests unitaires seulement|
|Hook pre-push (`--quick`)|Lint + format + typecheck + unit tests|
|Fin de phase (`--full`)|Tout : coverage, mutation, vuln, E2E|

---

## 8. Slash commands

### `/wf-init`

```markdown
# .claude/commands/wf-init.md

Initialise le workflow de développement à partir des documents existants.

## Prérequis
Vérifie que ces fichiers existent dans docs/ :
- BRIEF.md
- PRD.md  
- ARCHITECTURE.md
- UX-UI.md

## Étapes

1. Parse chaque document et extrais :
   - Brief : objectifs, personas, KPIs
   - PRD : epics, FRs avec acceptance criteria, NFRs
   - Architecture : stack complète, patterns, ADRs
   - UX/UI : composants, routes, design tokens

2. Génère .workflow/config.json basé sur la stack détectée

3. Génère .workflow/quality-gate.sh adapté à la stack avec les outils
   de test, lint, format, et vuln détectés dans l'architecture

4. Génère CLAUDE.md (< 100 lignes) :
   - Stack et commandes (WHAT)
   - Patterns et contraintes archi (WHY)  
   - Workflow et vérifications (HOW)
   - Pointeurs vers docs/ pour le détail

5. Configure .claude/ :
   - Copie les agents depuis le template
   - Active les skills pertinents pour la stack
   - Configure les hooks dans settings.local.json

6. Initialise .workflow/STATE.md avec les métadonnées projet

7. Commit : `chore: init workflow from project docs`

## Output
Affiche un résumé de la configuration générée et propose `/wf-plan`
```

### `/wf-plan`

````markdown
# .claude/commands/wf-plan.md

Planifie l'exécution en décomposant les epics en phases.

## Contexte
Charge : .workflow/config.json + docs/PRD.md + docs/ARCHITECTURE.md + docs/UX-UI.md

## Processus

Délègue au sub-agent planner (Opus, lecture seule) :

1. Extrais les epics du PRD avec leurs FRs
2. Pour chaque epic, décompose en phases de 2-4h :
   - Chaque phase a un objectif unique et vérifiable
   - Les acceptance criteria sont au format Given-When-Then
   - Les fichiers touchés sont listés explicitement
3. Construis le graphe de dépendances entre phases
4. Identifie les groupes parallélisables (phases sans dépendances croisées
   ET sans fichiers communs)
5. Génère pour chaque phase :
   - .workflow/phases/XX-slug/PLAN.md (XML tasks)
   - .workflow/phases/XX-slug/CONTEXT.md (extract ciblé des docs sources)
6. Génère .workflow/ROADMAP.md avec vue d'ensemble

## Format ROADMAP.md

```text
# Roadmap

## Epic 1: [Nom]
| Phase | Nom | Dépend de | Groupe // | Est. |
|-------|-----|-----------|-----------|------|
| 01 | Foundation | — | — | 3h |
| 02 | Auth | 01 | A | 2h |
| 03 | API Core | 01 | A | 4h |
| 04 | UI Shell | 01 | A | 2h |
| 05 | Dashboard | 02,03,04 | — | 3h |
````

Commit : `docs: plan [N] phases across [M] epics`

````

### `/wf-execute`

```markdown
# .claude/commands/wf-execute.md
# Usage: /wf-execute [phase_number]
# Exemple: /wf-execute 02

Exécute la phase $1 en mode TDD.

## Pré-vérifications
1. La phase $1 existe dans .workflow/phases/
2. Ses dépendances sont complétées (vérifier VERIFICATION.md)
3. Pas déjà en cours d'exécution

## Séquence
1. `git checkout -b phase/$(cat .workflow/phases/$1-*/PLAN.md | head -1 | extract slug) develop`
2. Charge .workflow/phases/$1-*/CONTEXT.md dans le contexte
3. Pour chaque <task> dans PLAN.md :
   a. Affiche la task courante
   b. 🔴 Écrit le test, vérifie l'échec
   c. 🟢 Implémente le minimum
   d. 🔵 Refactore si nécessaire  
   e. Commit atomique
4. Exécute quality-gate.sh --full
5. Génère VERIFICATION.md et SUMMARY.md
6. Affiche le rapport et attend la review humaine

## Gestion contexte
- Monitor : si le contexte dépasse 70%, écrire la progression dans SUMMARY.md
- Si > 80% : Document & Clear → reprendre avec CONTEXT.md + SUMMARY.md
````

### `/wf-parallel`

```markdown
# .claude/commands/wf-parallel.md
# Usage: /wf-parallel 02 03 04

Lance les phases $1, $2, ... en parallèle via worktrees.

## Validations
1. Toutes les phases existent et ont des dépendances satisfaites
2. Pas de fichiers communs entre les phases (vérifier les <files> dans PLAN.md)
3. Nombre de phases ≤ config.agents.max_parallel

## Séquence
1. Pour chaque phase après la première :
   `git worktree add ../$(basename $PWD)-phase-$N -b phase/$N-slug develop`
2. Créer .workflow/parallel-state.md
3. Afficher les commandes pour lancer les agents dans chaque worktree :
```

# Terminal 1 (courant)

claude --dangerously-skip-permissions "/wf-execute $1"

# Terminal 2

cd ../project-phase-$2 && claude --dangerously-skip-permissions "/wf-execute $2"

# Terminal 3

cd ../project-phase-$3 && claude --dangerously-skip-permissions "/wf-execute $3"

```
4. Attendre la complétion de toutes les phases
5. Merge séquentiel dans develop avec résolution de conflits

## Nettoyage
Après merge : `git worktree remove ../project-phase-$N` pour chaque worktree
```

### `/wf-status`

````markdown
# .claude/commands/wf-status.md

Affiche l'état complet du workflow.

## Collecte
1. Lis .workflow/STATE.md
2. Lis .workflow/ROADMAP.md  
3. Pour chaque phase, vérifie :
   - Existence de PLAN.md → planned
   - Existence de branche git → in-progress
   - Existence de VERIFICATION.md → completed (check PASS/FAIL)
   - Existence dans archive/ → archived

## Affichage

```text
═══════════════════════════════════
  PROJECT STATUS: mon-projet
  Branch: develop | Phases: 3/8 done
═══════════════════════════════════

  ✅ Phase 01 — Foundation     [merged]
  ✅ Phase 02 — Auth           [merged]
  🔄 Phase 03 — API Core       [executing - 60%]
  ⏳ Phase 04 — UI Shell       [waiting - parallelizable with 03]
  ⬚  Phase 05 — Dashboard      [blocked by 03,04]
  ⬚  Phase 06 — ...

  Next: /wf-execute 04 (or /wf-parallel 03 04)
````

````

### `/wf-review`

```markdown
# .claude/commands/wf-review.md
# Usage: /wf-review [phase_number]

Prépare et affiche la review humaine pour la phase $1.

## Collecte
1. .workflow/phases/$1-*/VERIFICATION.md (quality gate)
2. .workflow/phases/$1-*/SUMMARY.md (résumé exécution)
3. `git diff develop..phase/$1-* --stat` (fichiers modifiés)
4. `git log develop..phase/$1-* --oneline` (commits)

## Affichage
Présente un rapport structuré avec :
- Résultat quality gate (PASS/FAIL par check)
- Résumé de ce qui a été fait
- Stats : fichiers modifiés, lignes ajoutées/supprimées, nombre de tests
- Décisions prises pendant l'exécution
- Problèmes rencontrés

## Actions
Propose les options :
- ✅ Approve → `git checkout develop && git merge --no-ff phase/$1-* && git branch -d phase/$1-*`
- 🔄 Fix → liste les corrections attendues, relance /wf-execute
- ⏸️ Pause → sauvegarde l'état
- ❌ Reject → `git branch -D phase/$1-*`
````

---

## 9. CLAUDE.md template

````markdown
# {Nom du projet}

{Description en une ligne}

## Stack
{Stack principale — ex: Astro 5.x + Tailwind v4 + Cloudflare Workers}

## Commands
```bash
pnpm dev          # Dev server
pnpm test         # Tests unitaires
pnpm test:watch   # Tests en watch mode
pnpm lint         # ESLint
pnpm format       # Prettier
```text

## Workflow
- Exécuter `/wf-status` pour voir l'état du projet
- Toujours suivre le TDD : test d'abord, implémentation ensuite
- Un commit = une task = un incrément vérifiable
- Vérifier `pnpm test` avant chaque commit

## Architecture
- {Pattern principal — ex: Islands architecture, server-first}
- {Contrainte critique — ex: Toute donnée externe passe par les API routes}

## Quand chercher plus de contexte
- `.workflow/phases/XX/CONTEXT.md` — Contexte de la phase courante
- `docs/ARCHITECTURE.md` — Décisions techniques et ADRs
- `docs/PRD.md` — Acceptance criteria et scope
- `.claude/skills/` — Guidelines spécifiques à la stack
````

---

## 10. Gestion de l'état — STATE.md

```markdown
# Project State

## Current Position
- **Active Phase:** 03-api-core
- **Branch:** phase/03-api-core
- **Progress:** 4/6 tasks completed
- **Context Health:** ~55% (fresh)

## Completed Phases
| Phase | Name | Date | QG Score | Notes |
|-------|------|------|----------|-------|
| 01 | Foundation | 2026-03-10 | PASS (8/8) | — |
| 02 | Auth | 2026-03-10 | PASS (7/8) | Mutation score 58%, accepted |

## Parallel Execution
- (none active)

## Decisions Log
- ADR-001: JWT over sessions (voir docs/ARCHITECTURE.md)
- Phase 02: Ajout rate limiting non prévu → ajouté phase 06

## Open Issues
- [ ] E2E tests flaky sur CI (Playwright timeout) — non bloquant
```

---

## 11. Critères de décision

### Quand créer un worktree ?

|Signal|Action|
|---|---|
|2+ phases dans le même parallel_group|Worktree|
|Phase isolée sans dépendance en attente|Worktree si gain de temps > setup|
|Phases touchant des fichiers communs|Séquentiel obligatoire|
|Budget temps serré|Paralléliser les phases A|

### Quand créer un ADR ?

|Signal|Action|
|---|---|
|Choix entre 2+ approches viables|ADR|
|Changement de stack/pattern pendant l'implem|ADR|
|Décision non documentée dans ARCHITECTURE.md|ADR|
|Choix trivial ou sans alternative|Skip|

### Quand /clear ?

|Signal|Action|
|---|---|
|Transition entre phases|`/clear` obligatoire|
|Contexte > 70%|Document & Clear|
|Transition RED → GREEN (TDD strict)|`/clear` recommandé|
|Bug loop > 3 tentatives|`/clear` + reformuler|
|Changement de type de tâche (plan → code)|`/clear` recommandé|

---

## 12. Points ouverts pour itération

1. **Template quality-gate.sh par stack** — Faut-il un générateur ou des templates statiques par stack ?
2. **Merge conflicts en parallèle** — Stratégie automatique (rebase) vs manuelle ?
3. **CI/CD headless** — Intégrer GitHub Actions avec `claude -p` pour les PR auto-review ?
4. **Granularité des phases** — Ratio tasks/phase optimal ? (proposition : 4-6 tasks)
5. **Session management** — Pattern `/wf-pause` + `/wf-resume` comme GSD ?
6. **Observabilité** — Logger les actions dans `.workflow/logs/` pour post-mortem ?
7. **Adaptation runtime** — Si une phase prend plus que prévu, re-découper dynamiquement ?
