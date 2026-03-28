# Plan d'implémentation — Configuration GSR

## Vue d'ensemble

3 phases séquentielles. Chaque phase est un incrément fonctionnel testable.

```
Phase 1: Config core + env scan   → config.json + gsr-config.sh + scan dépendances à l'install
Phase 2: Injection commands       → commands lisent config, agents reçoivent via <config>
Phase 3: Commands settings        → /gsr:settings + /gsr:set-profile (écrit frontmatter agents)
```

---

## Phase 1 — Config core + environnement scan

**Objectif :** un fichier `config.json` existe, un script bash le lit, l'installation scanne l'environnement (jq, gh/glab, auth).

### Fichiers à créer

#### `.claude/gsr/config-defaults.json`

Référence commité dans le repo, sert de fallback :

```json
{
  "version": "1.0.0",
  "environment": {
    "jq_available": false,
    "config_mode": "claude",
    "git_cli": null,
    "git_cli_authenticated": false,
    "git_mcp": null,
    "git_mcp_authenticated": false,
    "git_provider": null
  },
  "models": {
    "active_profile": "balanced",
    "overrides": {}
  },
  "git": {
    "branching_strategy": "none",
    "branch_templates": {
      "phase": "gsr/phase-{phase}-{slug}",
      "story": "gsr/{epic}-{story}"
    },
    "conventional_commits": true
  },
  "workflow": {
    "mode": "interactive",
    "granularity": "flexible",
    "research": {
      "enabled": true,
      "max_deep": 3,
      "max_quick": 5
    },
    "discovery": {
      "max_questions_per_phase": 5,
      "max_returns_per_phase": 3,
      "max_interview_exchanges": 30,
      "timeout_minutes": 45
    },
    "plan": {
      "max_stories_per_epic": 6,
      "max_phases_per_story": 8,
      "max_epics": 10,
      "max_review_cycles": 3,
      "timeout_minutes": 30
    }
  },
  "output": {
    "claude_md_max_lines": 60,
    "spec_format": "lean",
    "plan_format": "xml"
  }
}
```

#### `.claude/gsr/bin/gsr-config.sh`

Utilitaire bash :

```bash
#!/usr/bin/env bash
# Usage: gsr-config.sh <command> [args]
#   ensure                      → crée config.json si absent (depuis defaults)
#   scan                        → scanne l'environnement (jq, git CLI, MCP, auth)
#   get <key.path>              → valeur (stdout) — requiert jq
#   set <key.path> <value>      → écrit dans config.json — requiert jq
#   dump <section>              → dump une section complète (key=value, 1 appel)
#   resolve-model <agent-name>  → modèle effectif (profile + overrides)
#   profile                     → nom du profil actif
#   config-mode                 → "jq" ou "claude" (comment lire/écrire la config)

CONFIG_DIR=".claude/gsr"
CONFIG_PATH="${CONFIG_DIR}/config.json"
DEFAULTS_PATH="${CONFIG_DIR}/config-defaults.json"
```

#### Sous-commande `scan`

Scanne l'environnement et stocke les résultats dans `config.json` section `environment` :

1. **jq** : `command -v jq` → `jq_available: true/false`, `config_mode: "jq"/"claude"`
2. **Git CLI** :
   - `command -v gh` → `git_cli: "gh"`, `git_provider: "github"`
   - `command -v glab` → `git_cli: "glab"`, `git_provider: "gitlab"`
   - `gh auth status` / `glab auth status` → `git_cli_authenticated: true/false`
3. **Git MCP** : scan `.claude/settings.json` et `~/.claude/settings.json` pour détecter des MCP github/gitlab → `git_mcp: "github"/"gitlab"/null`, `git_mcp_authenticated: true/false`

Si jq absent, les résultats du scan sont écrits en mode basique (template string replacement dans le JSON).

#### Logique `config-mode` — deux chemins selon jq

| Opération | Mode `jq` | Mode `claude` |
|-----------|-----------|---------------|
| `get` | `jq -r '.path.to.key' config.json` | Erreur → "Utilise Read pour lire config.json" |
| `set` | `jq '.path = value' config.json` | Erreur → "Utilise Write pour modifier config.json" |
| `dump` | `jq` extraction par section | Parse bash basique (grep/sed) sur JSON formaté |
| `ensure` | `jq -s merge` defaults + config | `cp` defaults si config absent |
| `scan` | Résultat JSON propre | Template string replacement |
| `resolve-model` | Fonctionne (lit profile via jq) | Lit profile via grep, fonctionne en mode dégradé |

Le mode `claude` est le fallback : les commands dans Claude Code utilisent `Read`/`Write` directement sur `config.json` au lieu de passer par le script.

#### Sous-commande `dump`

Sortie structurée pour une seule invocation bash par command :

```bash
cmd_dump() {
  local section="$1"
  case "$section" in
    discovery)  # workflow.discovery.* + workflow.research.* + workflow.mode
    plan)       # workflow.plan.* + workflow.research.* + workflow.granularity
    models)     # models.active_profile + résolution pour chaque agent
    git)        # git.*
    output)     # output.*
    environment) # environment.*
  esac
}
# Format sortie :
# max_questions_per_phase=5
# max_returns_per_phase=3
# research_enabled=true
```

#### Sous-commande `resolve-model`

Profils hardcodés dans le script :

```
Profils — rôle → modèle :
  quality:  orchestrator=opus   worker=opus    generator=sonnet
  balanced: orchestrator=opus   worker=sonnet  generator=sonnet
  budget:   orchestrator=sonnet worker=sonnet  generator=haiku

Mapping agent → rôle :
  gsr-planner           → orchestrator
  gsr-analyst           → worker
  gsr-synthesizer       → worker
  research-prompt-agent → worker
  gsr-generator         → generator
  gsr-bootstrapper      → generator
```

Logique de résolution :
1. Vérifier `models.overrides.<agent>` dans config.json
2. Sinon, résoudre via profil actif + mapping agent→rôle
3. Sortie : nom du modèle (ex: "opus", "sonnet", "haiku")

### Modifications à `install.sh`

Ajouter la phase `config` au registre (toujours installée) :

```bash
phase_config_files() {
  cat <<'FILES'
.claude/gsr/config-defaults.json
.claude/gsr/bin/gsr-config.sh
FILES
}
```

Post-install hook dans `cmd_install()` :

```bash
# Après l'installation :
# 1. chmod +x .claude/gsr/bin/gsr-config.sh
# 2. .claude/gsr/bin/gsr-config.sh ensure
# 3. .claude/gsr/bin/gsr-config.sh scan
# 4. Afficher le résultat :
#    - jq détecté → "full config management available"
#    - jq absent → "config will be managed by Claude Code (Read/Write)"
#    - gh/glab détecté → "GitHub/GitLab CLI: authenticated/not authenticated"
#    - MCP détecté → "GitHub/GitLab MCP: detected"
```

### Tâches Phase 1

| # | Tâche | Fichier |
|---|-------|---------|
| 1.1 | Créer `config-defaults.json` | `.claude/gsr/config-defaults.json` |
| 1.2 | Créer `gsr-config.sh` avec 8 sous-commandes | `.claude/gsr/bin/gsr-config.sh` |
| 1.3 | Ajouter phase `config` à `install.sh` + post-install scan | `install.sh` |
| 1.4 | Test : `gsr-config.sh ensure && scan && resolve-model gsr-planner` | — |

---

## Phase 2 — Injection dans les commands

**Objectif :** chaque command existante lit la config via `dump` (1 appel bash) et injecte les valeurs dans le prompt de l'agent via un bloc `<config>`.

### Pattern d'injection (identique pour toutes les commands)

Ajouter en tête de chaque command, avant les pré-checks :

```markdown
## 0. Charger la configuration

1. Exécuter : `.claude/gsr/bin/gsr-config.sh config-mode`
   - Si `jq` → exécuter `.claude/gsr/bin/gsr-config.sh dump <section>` pour obtenir les valeurs
   - Si `claude` → lire `.claude/gsr/config.json` avec Read et extraire les valeurs manuellement

2. Stocker les valeurs pour les passer aux agents dans le bloc <config> du prompt.
```

### Modifications par command

#### `discover.md` — section `discovery`

Valeurs attendues :
- max_questions_per_phase, max_returns_per_phase, max_interview_exchanges
- timeout_minutes, research_enabled, max_deep_research, max_quick_research
- mode (interactive/yolo)

Les garde-fous hardcodés (lignes 76-83) deviennent dynamiques :
- "5 max" → $max_questions_per_phase
- "3 max" → $max_returns_per_phase
- "~30 échanges" → $max_interview_exchanges
- "< 45 min" → $timeout_minutes
- "3 deep + 5 quick max" → $max_deep_research deep + $max_quick_research quick

Fallback : si config absente ou illisible, utiliser les valeurs actuelles hardcodées.

Le prompt de l'agent `gsr-synthesizer` reçoit :

```xml
<config>
research_enabled: $research_enabled
max_deep_research: $max_deep_research
</config>
```

#### `bootstrap.md` — section `output` + modèle

Valeurs : claude_md_max_lines, spec_format, git_provider, model (via resolve-model gsr-bootstrapper).

Le prompt de `gsr-bootstrapper` reçoit :

```xml
<config>
claude_md_max_lines: $claude_md_max_lines
spec_format: $spec_format
git_provider: $git_provider
</config>
```

#### `plan.md` — section `plan` + 3 modèles

Valeurs :
- max_stories_per_epic, max_phases_per_story, max_epics
- max_review_cycles, timeout_minutes
- granularity, research_enabled, max_deep, max_quick

Les garde-fous hardcodés (lignes 192-198) deviennent dynamiques. Chaque agent spawné reçoit son bloc `<config>`.

#### `plan-story.md` — section `plan`

Subset des valeurs : review cycles, timeout, research.

#### `plan-phases.md` — section `plan` + granularity

Les garde-fous (lignes 160-165) deviennent dynamiques.

#### `discover-resume.md`

Hérite les mêmes valeurs que `discover.md` (mêmes garde-fous).

#### Commands non modifiées

`discover-abort.md`, `discover-save.md`, `plan-abort.md`, `plan-status.md`, `status.md`, `version.md`, `update.md` — pas d'agents ni de garde-fous configurables.

### Fallback dans les references

`.claude/gsr/discovery-phases.md` et `.claude/gsr/plan-output.md` ne changent PAS. Les valeurs par défaut restent documentées dans les commands comme fallback si aucune config n'est chargée. La config surcharge, elle ne remplace pas.

### Tâches Phase 2

| # | Tâche | Fichier |
|---|-------|---------|
| 2.1 | Ajouter section "0. Charger la configuration" + garde-fous dynamiques | `commands/gsr/discover.md` |
| 2.2 | Injection `<config>` dans prompt synthesizer | `commands/gsr/discover.md` |
| 2.3 | Ajouter config loading dans discover-resume | `commands/gsr/discover-resume.md` |
| 2.4 | Ajouter config loading + output config dans bootstrap | `commands/gsr/bootstrap.md` |
| 2.5 | Ajouter config loading + garde-fous dynamiques | `commands/gsr/plan.md` |
| 2.6 | Idem | `commands/gsr/plan-story.md` |
| 2.7 | Idem + granularity depuis config | `commands/gsr/plan-phases.md` |

---

## Phase 3 — Commands settings

**Objectif :** `/gsr:settings` pour config interactive, `/gsr:set-profile` pour switch rapide (modifie le frontmatter des agents).

### `/gsr:settings`

**`.claude/commands/gsr/settings.md`** :

```yaml
---
name: settings
description: Configure GSR workflow and model profile
human_ai_ratio: 60/40
---
```

Process :

1. `gsr-config.sh ensure` — crée le fichier si absent
2. Lire les valeurs actuelles (via `dump` ou `Read` selon config-mode)
3. Afficher l'état groupé par catégorie :

```markdown
## Configuration GSR actuelle

### Environnement (détecté à l'installation)
| Element | Statut | Détail |
|---------|--------|--------|
| jq | ✓ Disponible | Config mode: jq |
| Git CLI | gh | Authentifié: ✓ |
| Git MCP | — | Non détecté |
| Provider | github | Auto-détecté depuis CLI |

### Modèles
| Setting | Valeur | Options |
|---------|--------|---------|
| Profil actif | **balanced** | quality / balanced / budget |
| Overrides | aucun | /gsr:set-profile pour changer |

### Workflow
| Setting | Valeur | Options |
|---------|--------|---------|
| Mode | **interactive** | interactive / yolo |
| Granularité | **flexible** | fine / standard / flexible |
| Research | **activé** | activé / désactivé |

### Git
| Setting | Valeur | Options |
|---------|--------|---------|
| Branching | **none** | none / phase / story |
| Conventional commits | **oui** | oui / non |

Que veux-tu modifier ?
```

4. L'utilisateur dit quoi changer en langage naturel
5. Écrire via `gsr-config.sh set` (mode jq) ou `Write` (mode claude)
6. Si changement de profil → appeler la logique de `/gsr:set-profile` pour modifier les frontmatters
7. Confirmation avec tableau mis à jour
8. Proposer : "Relancer le scan d'environnement ? (`gsr-config.sh scan`)"

### `/gsr:set-profile`

**`.claude/commands/gsr/set-profile.md`** :

```yaml
---
name: set-profile
description: Switch model profile (quality/balanced/budget)
argument-hint: <profile>
human_ai_ratio: 10/90
---
```

Process :

1. Valider l'argument : `quality` | `balanced` | `budget`
   - Si invalide → "Profil inconnu. Choisis : quality, balanced, budget"

2. Écrire dans config : `models.active_profile = $PROFILE`

3. **Modifier les frontmatters des agents** — pour chaque agent dans `.claude/agents/gsr/` :
   - Lire le fichier
   - Résoudre le modèle via `gsr-config.sh resolve-model <agent-name>`
   - Si le `model:` dans le frontmatter est différent → modifier avec Edit
   - Gérer les overrides : si `models.overrides.<agent>` existe, utiliser cette valeur

4. Afficher le résultat :

```
Profil : budget

| Agent              | Rôle          | Modèle |
|--------------------|---------------|--------|
| gsr-planner        | orchestrator  | sonnet |
| gsr-analyst        | worker        | sonnet |
| gsr-synthesizer    | worker        | sonnet |
| research-prompt    | worker        | sonnet |
| gsr-generator      | generator     | haiku  |
| gsr-bootstrapper   | generator     | haiku  |

6 agents mis à jour.
```

### Tâches Phase 3

| # | Tâche | Fichier |
|---|-------|---------|
| 3.1 | Créer `/gsr:settings` | `.claude/commands/gsr/settings.md` |
| 3.2 | Créer `/gsr:set-profile` | `.claude/commands/gsr/set-profile.md` |
| 3.3 | Ajouter `settings` et `set-profile` au registre `install.sh` (nouvelle phase `config`) | `install.sh` |

---

## Résumé des fichiers touchés

| Fichier | Action | Phase |
|---------|--------|-------|
| `.claude/gsr/config-defaults.json` | **Créer** | 1 |
| `.claude/gsr/bin/gsr-config.sh` | **Créer** | 1 |
| `install.sh` | Modifier (phase config + scan + phase 3 registry) | 1, 3 |
| `.claude/commands/gsr/discover.md` | Modifier (config loading + garde-fous dynamiques) | 2 |
| `.claude/commands/gsr/discover-resume.md` | Modifier (config loading) | 2 |
| `.claude/commands/gsr/bootstrap.md` | Modifier (config loading + output config) | 2 |
| `.claude/commands/gsr/plan.md` | Modifier (config loading + garde-fous dynamiques) | 2 |
| `.claude/commands/gsr/plan-story.md` | Modifier (config loading) | 2 |
| `.claude/commands/gsr/plan-phases.md` | Modifier (config loading + granularity) | 2 |
| `.claude/commands/gsr/settings.md` | **Créer** | 3 |
| `.claude/commands/gsr/set-profile.md` | **Créer** | 3 |

## Dépendances entre phases

```
Phase 1 ──→ Phase 2 ──→ Phase 3
(config)    (injection)  (UI)
```

Phase 2 a besoin que `gsr-config.sh` existe. Phase 3 a besoin que les commands sachent déjà lire la config.

## Backlog (reporté)

- **Phase 4 — Defaults globaux** : `~/.gsr/defaults.json` pour que les préférences survivent entre projets. À implémenter quand le besoin est validé par l'usage.
