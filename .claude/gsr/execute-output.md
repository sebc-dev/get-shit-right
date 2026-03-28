# Execute — Output Templates

Reference chargee par execute-phase et execute pour generer SUMMARY.md et la verification finale.

---

<summary-template>
## Template SUMMARY.md (par phase)

```markdown
# SUMMARY — Phase [NN]: [nom]

**Story :** [epic]/[story]
**Debut :** [timestamp]
**Fin :** [timestamp]
**Commits :** [N]
**Deviations :** [N]

---

## Plan [NN-MM]: [objectif]

**Statut :** OK | Partiel | Echoue
**Commits :** [liste hash courts]

### Tasks
| # | Task | Statut | Verify | Notes |
|---|------|--------|--------|-------|
| 1 | [nom] | OK | `[cmd]` pass | — |
| 2 | [nom] | OK | `[cmd]` pass | Deviation #1 |
| 3 | [nom] | Echoue | `[cmd]` fail | Escalade debugger |

### Deviations
[Si applicable — format depuis execute-deviation.md]

### Quality Gates
| Gate | Resultat |
|------|----------|
| format | OK / skip |
| lint | OK / N erreurs corrigees |
| tests | OK / N echecs |
| coverage | N% (seuil: M%) |

---

## Plan [NN-MM+1]: [objectif]
[Append incremental — meme structure]

---

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

---

## Verification finale

- [ ] Tous les plans executes
- [ ] Tests globaux passent
- [ ] Lint clean
- [ ] Aucun finding critical non resolu
- [ ] Coverage >= seuil configure

**Resume :** N plans, N commits, N deviations, N findings review (N critical, N fixed, N escalated)
```
</summary-template>

<verification-checklist>
## Checklist de verification finale

La verification est executee apres la review, en fin de phase :

### Checks automatiques
1. **Tests globaux** — lancer la suite complete (pas juste les tests de la phase)
2. **Lint** — verifier l'ensemble du projet
3. **Coverage** — verifier le seuil si configure
4. **Findings critiques** — compter les non resolus (escalated)

### Presentation
```
## Verification finale — Phase [NN]: [nom]

| Check | Resultat |
|-------|----------|
| Tests globaux | PASS (N tests) / FAIL (N echecs) |
| Lint | Clean / N warnings |
| Coverage | N% (seuil: M%) |
| Findings critiques non resolus | 0 / N |

**Verdict :** PHASE COMPLETE / PHASE AVEC ALERTES

[Si alertes :]
Attention :
- N finding(s) critical escalated — traitement manuel requis
- Coverage sous le seuil (N% < M%)
```
</verification-checklist>
