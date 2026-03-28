# Execute — Review

Reference chargee par gsr-reviewer et la command execute-phase pour le checkpoint review.

---

<review-criteria>
## Criteres de review

### Criteres par defaut

| Critere | Ce qu'il verifie |
|---------|------------------|
| `security` | Injections (SQL, XSS, command), secrets hardcodes, auth manquante, CORS mal configure |
| `bugs` | Logique incorrecte, null refs, off-by-one, race conditions, ressources non fermees |
| `conventions` | Conformite CLAUDE.md, naming, patterns du projet, imports, structure fichiers |
| `test-coverage` | Tests manquants pour le code ajoute, cas limites non couverts, mocks excessifs |

### Configuration

Dans `config-defaults.json` sous `workflow.review` :

| Parametre | Defaut | Description |
|-----------|--------|-------------|
| `enabled` | `true` | Activer/desactiver la review |
| `criteria` | `["security", "bugs", "conventions", "test-coverage"]` | Criteres actifs |
| `checkpoint_on` | `"critical"` | Quand declencher un checkpoint humain |

Valeurs de `checkpoint_on` :
- `"critical"` — checkpoint uniquement si findings critiques (defaut)
- `"warning"` — checkpoint aussi sur warnings
- `"none"` — review documentaire uniquement, pas de checkpoint
</review-criteria>

<review-finding-format>
## Format des findings

Chaque finding est un objet JSON structure :

```json
{
  "file": "src/auth/login.ts",
  "line_start": 42,
  "line_end": 45,
  "severity": "critical",
  "criterion": "security",
  "detail": "SQL injection via string interpolation dans la requete utilisateur"
}
```

### Severites

| Severite | Signification | Action |
|----------|---------------|--------|
| `note` | Suggestion d'amelioration, pas de risque | Documente dans SUMMARY.md |
| `warning` | Probleme potentiel, risque modere | Documente dans SUMMARY.md, checkpoint si `checkpoint_on=warning` |
| `critical` | Risque eleve, doit etre traite | Checkpoint humain, choix : Fix / Skip / Escalate |

### Fichier de sortie

Les findings sont ecrits dans `.claude/review-findings.json` :

```json
{
  "ref_commit": "abc1234",
  "head_commit": "def5678",
  "files_reviewed": 12,
  "lines_added": 245,
  "lines_removed": 30,
  "findings": [
    { "file": "...", "line_start": 0, "severity": "...", "criterion": "...", "detail": "..." }
  ],
  "summary": {
    "critical": 1,
    "warning": 3,
    "note": 5
  }
}
```
</review-finding-format>

<review-checkpoint>
## Protocole checkpoint review

### Declenchement

Apres que gsr-reviewer a produit ses findings :

1. Compter les findings par severite
2. Si `critical > 0` ET `checkpoint_on` in [`critical`, `warning`] → checkpoint humain
3. Si `warning > 0` ET `checkpoint_on == "warning"` → checkpoint humain
4. Sinon → documenter dans SUMMARY.md, pas de checkpoint

### Presentation au checkpoint

Afficher un resume structure :

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

2. ...
```

### Actions par finding

| Action | Comportement |
|--------|-------------|
| **Fix** | Spawn gsr-executor frais avec le diff + le finding. Re-run quality gates sur fichiers modifies. Commit du fix. |
| **Skip** | Documenter comme "Skipped" dans SUMMARY.md. Pas d'action. |
| **Escalate** | Documenter comme "Escalated" dans SUMMARY.md. Signaler dans la verification finale. |

### Fix loop

1. Spawn gsr-executor avec contexte minimal :
   - Le diff du fichier concerne
   - Le finding (description du probleme)
   - Le CONTEXT.md de la phase
2. L'executor corrige le probleme specifique
3. Quality gates sur les fichiers modifies
4. Commit avec prefix `fix:` + reference au finding
5. Retour au checkpoint pour le finding suivant
</review-checkpoint>

<review-summary>
## Section review dans SUMMARY.md

```markdown
## Review

**Diff reviewe :** [ref-commit]..[head-commit] ([N] fichiers, [+M/-P] lignes)

| Severite | Count |
|----------|-------|
| Critical | N |
| Warning  | N |
| Note     | N |

### Critical (resolution)
| Finding | Fichier | Resolution |
|---------|---------|------------|
| [detail] | [file:line] | Fixed (commit [hash]) / Skipped / Escalated |

### Warnings
- `file:line` — [criterion] — [detail]

### Notes
- `file:line` — [criterion] — [detail]
```
</review-summary>
