# GSR (Get Shit Right) — Solo Dev Workflow for Claude Code

Plugin Claude Code qui structure le cycle de vie d'un projet solo : de l'idee au deploiement.

## Phases

| Phase | Status | Description |
|-------|--------|-------------|
| Discovery | Done | Interview guidee en 6 phases generant `discovery.md` + bootstrap projet |
| Plan | Done | Planification progressive : Epics → Stories → Phases atomiques (JIT) |
| Execute | Planned | TDD, commits atomiques, quality gates |
| Ship | Planned | Merge, deploy, smoke tests |

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/sebc-dev/gsr/main/install.sh | bash
```

### Options

```bash
# Projet specifique
GSR_TARGET=/path/to/project curl -fsSL ... | bash

# Dry-run
GSR_DRY_RUN=1 curl -fsSL ... | bash

# Phase specifique
GSR_PHASES=discovery curl -fsSL ... | bash

# Lister les phases disponibles
GSR_LIST=1 curl -fsSL ... | bash

# Ecraser les fichiers existants
GSR_FORCE=1 curl -fsSL ... | bash
```

## Utilisation

### Discovery

```
/gsr:discover "description du projet"   # Demarrer une discovery
/gsr:discover-resume                     # Reprendre une session
/gsr:discover-save                       # Sauvegarder un partiel
/gsr:discover-abort                      # Abandonner
/gsr:bootstrap [path]                    # Generer la structure projet
```

### Plan (progressif)

```
/gsr:plan [SPEC.md] [--granularity=flexible]   # Niveau 1 : ROADMAP (Epics + Stories)
/gsr:plan-story [epic/story]                    # Niveau 2 : Detailler une story
/gsr:plan-phases [epic/story]                   # Niveau 3 : Phases atomiques
/gsr:plan-status                                # Voir la progression
/gsr:plan-abort                                 # Annuler la session
```

### Version et mise a jour

```
/gsr:version                                    # Version installee + check update
/gsr:update [--dry-run] [--force]               # Mettre a jour depuis GitHub
```

## Migration depuis l'ancienne architecture

Si vous avez installe l'ancienne version (skill-based / GTD), utilisez le script de migration :

```bash
# Dry-run d'abord
GSR_DRY_RUN=1 curl -fsSL https://raw.githubusercontent.com/sebc-dev/gsr/main/migrate.sh | bash

# Migration reelle
curl -fsSL https://raw.githubusercontent.com/sebc-dev/gsr/main/migrate.sh | bash

# Projet specifique
curl -fsSL https://raw.githubusercontent.com/sebc-dev/gsr/main/migrate.sh | GSR_TARGET=/path/to/project bash
```

Le script supprime les anciens fichiers (`.claude/skills/`, `.claude/commands/gtd/`, `.claude/gtd/`, agents a la racine) puis reinstalle GSR proprement. Les fichiers projet (`discovery.md`, `docs/`, `CLAUDE.md`) sont preserves.

## Architecture

Architecture **Command + Agents + References** (pattern GSD) — pas de skill-orchestrateur.

```
.claude/
├── commands/gsr/          # Slash commands (orchestrateurs legers)
│   ├── discover.md        # Interface conversationnelle discovery
│   ├── discover-resume.md
│   ├── discover-save.md
│   ├── discover-abort.md
│   ├── bootstrap.md       # Thin dispatcher → agent
│   ├── plan.md            # Niveau 1 : ROADMAP
│   ├── plan-story.md      # Niveau 2 : Detail story
│   ├── plan-phases.md     # Niveau 3 : Phases atomiques
│   ├── plan-status.md
│   ├── plan-abort.md
│   ├── version.md        # Version installee + check update
│   └── update.md         # Mise a jour depuis GitHub
├── agents/gsr/             # Agents specialises (contexte frais)
│   ├── gsr-synthesizer.md # Phase 6 discovery : synthese + validation
│   ├── gsr-bootstrapper.md# Bootstrap : CLAUDE.md, SPEC.md, etc.
│   ├── gsr-analyst.md     # Plan : analyse docs bootstrap
│   ├── gsr-planner.md     # Plan : decomposition multi-mode
│   ├── gsr-generator.md   # Plan : generation fichiers
│   └── research-prompt-agent.md  # Recherche : prompts optimises
└── gsr/                   # References + metadata
    ├── VERSION              # Version installee (semver)
    ├── discovery-phases.md
    ├── discovery-output.md
    ├── discovery-research.md
    ├── plan-output.md
    └── plan-research.md
```

## License

MIT
