# Execute — Quality Gates

Reference chargee par gsr-executor pour les quality gates en cours d'execution.

---

<quality-gates>
## Configuration des quality gates

Les quality gates sont configures dans `config-defaults.json` sous `workflow.execute.quality_gates` :

| Parametre | Defaut | Description |
|-----------|--------|-------------|
| `run_after` | `"task"` | Quand executer : `"task"` (apres chaque task) ou `"phase"` (en fin de phase) |
| `lint` | `true` | Executer le linter |
| `format` | `true` | Executer le formateur |
| `tests` | `true` | Executer les tests |
| `coverage_threshold` | `0` | Seuil minimum de couverture (0 = pas de seuil) |

## Execution des gates

### Ordre d'execution
1. **Format** (si active) — auto-fix, pas d'echec
2. **Lint** (si active) — echec si erreurs (warnings OK)
3. **Tests** (si actives) — echec si tests echouent
4. **Coverage** (si seuil > 0) — echec si sous le seuil

### Detection automatique des commandes

L'executor detecte les commandes en lisant `package.json`, `Makefile`, `pyproject.toml`, etc. :

| Gate | Detection (ordre de priorite) |
|------|-------------------------------|
| format | `package.json` scripts: format, prettier | `Makefile`: format | `pyproject.toml`: black/ruff format |
| lint | `package.json` scripts: lint | `Makefile`: lint | `pyproject.toml`: ruff/flake8 |
| tests | `package.json` scripts: test | `Makefile`: test | `pytest` | `go test` |
| coverage | Flag `--coverage` sur la commande test si disponible |

Si aucune commande n'est detectee pour un gate, le gate est **skip** (pas d'erreur).
</quality-gates>

<quality-on-failure>
## Comportement en cas d'echec

### Lint echoue
1. Lire les erreurs
2. Corriger automatiquement (max 2 tentatives)
3. Si persistant → documenter dans SUMMARY.md, continuer

### Tests echouent
1. Identifier les tests en echec
2. Si c'est un test qu'on vient d'ecrire → corriger (max 2 tentatives)
3. Si c'est un test existant (regression) → deviation regle 1 (bug bloquant)
4. Si persistant apres retries → escalade debugger (deviation regle 3)

### Coverage sous le seuil
1. Identifier les lignes non couvertes dans le code ajoute
2. Ajouter les tests manquants
3. Si le seuil est inatteignable (code legacy) → documenter dans SUMMARY.md
</quality-on-failure>

<quality-scope>
## Scope des tests

L'executor ne lance PAS tous les tests du projet a chaque task. Le scope depend du `run_after` :

### run_after = "task"
- Tests lies aux fichiers modifies dans la task
- Detection : meme nom de fichier avec `.test.`, `.spec.`, `_test.` suffix
- Si le PLAN.md contient une commande `<verify>` → utiliser celle-la

### run_after = "phase"
- Tous les tests lies aux fichiers modifies dans la phase entiere
- Plus la commande `<verify>` de chaque task
</quality-scope>
