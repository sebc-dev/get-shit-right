# GTD — Solo Dev Workflow for Claude Code

Plugin Claude Code qui structure le cycle de vie d'un projet solo : de l'idee au deploiement.

## Phases

| Phase | Status | Description |
|-------|--------|-------------|
| Discovery | Done | Interview guidee en 6 phases generant `discovery.md` |
| Plan | Planned | Epics -> phases executables avec graphe de dependances |
| Execute | Planned | TDD, commits atomiques, quality gates |
| Ship | Planned | Merge, deploy, smoke tests |

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/sebc-dev/gtd/main/install.sh | bash
```

### Options

```bash
# Projet specifique
GTD_TARGET=/path/to/project curl -fsSL ... | bash

# Dry-run
GTD_DRY_RUN=1 curl -fsSL ... | bash

# Phase specifique
GTD_PHASES=discovery curl -fsSL ... | bash

# Lister les phases disponibles
GTD_LIST=1 curl -fsSL ... | bash

# Ecraser les fichiers existants
GTD_FORCE=1 curl -fsSL ... | bash
```

## Utilisation

```
/gtd:discover "description du projet"   # Demarrer une discovery
/gtd:discover-resume                     # Reprendre une session
/gtd:discover-save                       # Sauvegarder un partiel
/gtd:discover-abort                      # Abandonner
/gtd:bootstrap [path]                    # Generer la structure projet
```

## Structure installee

```
.claude/
├── skills/gtd-discovery/    # Skill + references (phases, templates, recherche)
├── commands/gtd/            # 5 slash commands
└── agents/                  # research-prompt-agent
```

## License

MIT
