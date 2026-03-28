# GSR Status — Reference

Reference chargee par les commands GSR pour mettre a jour `docs/GSR-STATUS.md`.

---

<status-template>
```markdown
# GSR Status — [Nom du projet]

**Derniere mise a jour :** [YYYY-MM-DD HH:MM]
**Phase active :** [Discovery | Bootstrap | Plan | Execute | Ship]

## Pipeline

| Phase | Statut | Detail |
|-------|--------|--------|
| Discovery | [statut] | [detail] |
| Bootstrap | [statut] | [detail] |
| Plan | [statut] | [detail] |
| Execute | [statut] | [detail — stories executees, phases en cours] |
| Ship | [statut] | [detail] |

## Discovery

| Champ | Valeur |
|-------|--------|
| Statut | [statut] |
| Phase | [N]/6 |
| Sections | [liste] |
| Research Gates | [N quick, N deep] |
| Fichier | [chemin ou —] |

## Bootstrap

| Fichier | Statut |
|---------|--------|
| CLAUDE.md | [statut] |
| SPEC.md | [statut] |
| docs/discovery.md | [statut] |
| docs/agent_docs/architecture.md | [statut] |
| docs/agent_docs/database.md | [statut] |
| docs/adr/0001-initial-stack.md | [statut] |

## Plan

| Metrique | Valeur |
|----------|--------|
| Niveau | [1-roadmap / 2-story / 3-phases] |
| Granularite | [fine / standard / flexible] |
| Epics | [N] |
| Stories | [N total] |
| Stories detaillees | [N] |
| Phases generees | [N] |

### Detail par Epic

| # | Epic | Stories | Detaillees | Phases | Statut |
|---|------|---------|------------|--------|--------|

## Execute

| Metrique | Valeur |
|----------|--------|
| Stories executees | [N] / [total] |
| Phases executees | [N] / [total] |
| Commits | [N] |
| Deviations | [N] |
| Review findings | [N] (critical: [N], fixed: [N], escalated: [N]) |

### Detail par Story

| Epic | Story | Phases | Statut | Commits | Review |
|------|-------|--------|--------|---------|--------|

## Historique

| Date | Commande | Detail |
|------|----------|--------|
```
</status-template>

<statut-icons>
Les icones de statut a utiliser :

| Icone | Signification |
|-------|---------------|
| `--` | Pas commence |
| `En cours` | En progression |
| `OK` | Termine avec succes |
| `Partiel` | Sauvegarde partielle |
| `Annule` | Session annulee |
| `N/A` | Non applicable |
</statut-icons>

<update-discovery>
## Mise a jour par les commandes Discovery

### /gsr:discover — Demarrage
- Creer `docs/GSR-STATUS.md` si absent (depuis template, nom = description projet)
- Pipeline : Discovery → `En cours`
- Discovery : Statut → `En cours`, Phase → `1/6`, Sections → toutes vides
- Historique : ajouter ligne

### /gsr:discover — Progression (a chaque phase validee)
- Discovery : Phase → `[N]/6`, Sections → mettre a jour les coches
- Timestamp de mise a jour

### /gsr:discover — Fin (apres synthese)
- Pipeline : Discovery → `OK` + detail
- Discovery : Statut → `OK`, Phase → `6/6`, toutes sections cochees, Fichier → `discovery.md`
- Historique : ajouter ligne

### /gsr:discover-resume
- Meme logique que progression/fin selon le cas
- Historique : ajouter "Session reprise"

### /gsr:discover-save
- Pipeline : Discovery → `Partiel`
- Discovery : Statut → `Partiel`, Fichier → `discovery.md (partiel)`
- Historique : ajouter "Sauvegarde partielle ([N]/6 phases)"

### /gsr:discover-abort
- Pipeline : Discovery → `Annule`
- Discovery : Statut → `Annule`, reinitialiser Phase et Sections
- Historique : ajouter "Session annulee"
</update-discovery>

<update-bootstrap>
## Mise a jour par /gsr:bootstrap

- Pipeline : Bootstrap → `En cours` au debut, `OK` a la fin
- Phase active → `Bootstrap`
- Bootstrap : mettre a jour chaque fichier (`OK` si cree, `N/A` si non applicable, `--` sinon)
- Si `--dry-run` : ne pas mettre a jour (dry-run = simulation)
- Historique : ajouter "Bootstrap termine ([N] fichiers)"
</update-bootstrap>

<update-plan>
## Mise a jour par les commandes Plan

### /gsr:plan
- Pipeline : Plan → `En cours`
- Phase active → `Plan`
- Plan : Niveau → `1-roadmap`, remplir Epics/Stories counts
- Detail par Epic : generer la table
- Historique : ajouter "Roadmap genere ([N] epics, [N] stories)"

### /gsr:plan-story
- Plan : incrementer Stories detaillees
- Detail par Epic : mettre a jour le compteur Detaillees pour l'epic concerne
- Historique : ajouter "Story [epic]/[story] detaillee"

### /gsr:plan-phases
- Plan : incrementer Phases generees, Niveau → `3-phases`
- Detail par Epic : mettre a jour le compteur Phases pour l'epic concerne
- Detail par Epic : Statut de l'epic → selon progression
- Historique : ajouter "Phases generees pour [epic]/[story] ([N] phases)"

### /gsr:plan-abort
- Option A (session seule) : Plan section inchangee, historique "Session plan supprimee"
- Option B (tout supprimer) : Pipeline Plan → `Annule`, reinitialiser section Plan, historique "Plan supprime"
</update-plan>

<update-plan-epic-statut>
## Calcul du statut par epic

- Toutes stories sans STORY.md → `--`
- Au moins 1 STORY.md → `En cours`
- Toutes stories ont STORY.md → `Stories OK`
- Au moins 1 story a des phases → `En cours`
- Toutes stories ont des phases → `OK`
</update-plan-epic-statut>

<update-execute-phase>
## Mise a jour par /gsr:execute-phase

### Demarrage
- Pipeline : Execute → `En cours`
- Phase active → `Execute`
- Execute : incrementer Phases executees si complete
- Detail par Story : ajouter/mettre a jour la ligne (epic, story, phases executees, statut, commits, review)
- Historique : "Phase [epic]/[story]/[phase] executee ([N] commits, [M] findings)"

### Fin
- Execute : mettre a jour les compteurs (commits, deviations, review findings)
- Detail par Story : Statut → selon progression (En cours / Partiel / OK)
- Si toutes les phases de la story sont executees → Story Statut → `OK`
</update-execute-phase>

<update-execute>
## Mise a jour par /gsr:execute

### Demarrage
- Pipeline : Execute → `En cours`
- Phase active → `Execute`
- Historique : "Execution story [epic]/[story] demarree"

### Progression (apres chaque phase)
- Execute : incrementer Phases executees, Commits, Deviations, Review findings
- Detail par Story : mettre a jour la ligne

### Fin
- Execute : incrementer Stories executees
- Detail par Story : Statut → `OK`
- Si toutes stories de tous epics executees → Pipeline Execute → `OK`
- Historique : "Story [epic]/[story] executee ([N] phases, [M] commits)"
</update-execute>

<rebuild-logic>
## Regeneration complete (par /gsr:status --rebuild)

Si le fichier est corrompu ou absent, le reconstruire en scannant :

1. **Discovery** : `discovery.md` existe ? → `OK`. `.claude/discovery-session.md` existe ? → `En cours` (extraire phase). Sinon → `--`.
2. **Bootstrap** : verifier chaque fichier (CLAUDE.md, SPEC.md, etc.) → `OK` ou `--`.
3. **Plan** : scanner `docs/plan/` → compter epics, stories, STORY.md, phases/.
4. **Execute** : scanner `docs/plan/epics/*/stories/*/phases/*/SUMMARY.md` → compter les phases executees. Si `.claude/execute-session.md` existe avec status `in-progress` → `En cours`.
5. **Ship** : `--` (pas encore implemente).
5. **Phase active** : la derniere phase avec statut `En cours` ou `OK`.
6. **Historique** : vide (non reconstructible) — ajouter une ligne "Status regenere depuis l'etat du projet".
</rebuild-logic>
