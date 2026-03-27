# Discovery Output Templates

Chargement sélectif : lire uniquement la section XML nécessaire.

---

<discovery-template>
## Template discovery.md (7 sections)

```markdown
# Discovery : [Nom du projet]

**Généré le** : [date]
**Durée interview** : [X minutes]
**Phases complétées** : 6/6

---

## §1 Problème

### Statement
[1 phrase, pattern "X ne peut pas Y à cause de Z"]

### Utilisateur cible
[Qui est l'utilisateur principal — pas "les utilisateurs"]

### Situation actuelle
[Comment le problème est géré aujourd'hui]

### Motivation
[Pourquoi résoudre ce problème maintenant]

---

## §2 Contraintes

### Contraintes fixées (non négociables)
| Contrainte | Type | Détail | Impact sur stack |
|------------|------|--------|------------------|

### Contraintes ouvertes (flexibles)
| Aspect | Options considérées | Décision | Raison |
|--------|---------------------|----------|--------|

### Timeline
[Estimation : X semaines/mois]

---

## §3 Stack

| Composant | Technologie | Version | Contrainte liée |
|-----------|-------------|---------|-----------------|

### Dépendances notables
- [lib]: [raison]

---

## §4 Architecture

### Pattern
[ex: API REST monolithique avec SPA séparé]

### Composants
| Composant | Responsabilité | Technologie |
|-----------|----------------|-------------|

### Schéma

```
[Schéma ASCII]
```

### Flux de données
[Description du flux principal en 2-3 phrases]

---

## §5 Scope MVP

### Features MVP (v1)
| # | Feature | Priorité | Complexité |
|---|---------|----------|------------|

### Nice-to-have (post-MVP)
| Feature | Raison du report | Phase cible |
|---------|------------------|-------------|

---

## §6 Hors Scope (Exclusions)

| Exclu | Raison | Phase cible |
|-------|--------|-------------|

---

## §7 Risques & Rabbit Holes

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|

### Incohérences acceptées (si présentes)
| Conflit | Détail | Statut |
|---------|--------|--------|

### Questions ouvertes (si présentes)
| Question | Phase | Impact |
|----------|-------|--------|
```
</discovery-template>

---

<session-template>
## Template discovery-session.md

```markdown
# Discovery Session
Project: [description courte]
Phase: [N]/6 ([nom phase])
Next: [prochaine phase]
Updated: [timestamp ISO]
Started: [timestamp ISO]

## Timing
Elapsed: ~[N] min
Target: < 45 min
Status: [✅ On track | ⚠️ Approaching limit]

## Captured

### Problem
[1-2 lignes — rempli après Phase 1]

### Constraints
- Fixed: [liste courte]
- Open: [liste courte]
- Timeline: [estimation]

### Stack
[si défini — sinon omis]

### Architecture
[si défini — sinon omis]

### Scope
[si défini — sinon omis]

## Open Questions
| Question | Phase | Impact | Recherche proposée | Statut |
|----------|-------|--------|--------------------|--------|

## Research Log
| # | Timestamp | Phase | Type | Mode | Status | Résumé résultat |
|---|-----------|-------|------|------|--------|-----------------|

## Pending Research
[Contenu de .claude/research-prompt.md si une recherche deep est en attente]

## Validation Metadata

### Checklist complétude
- [ ] Problème défini (§1)
- [ ] Contraintes documentées (§2)
- [ ] Stack avec versions (§3)
- [ ] Architecture avec schéma (§4)
- [ ] MVP délimité (§5)
- [ ] Exclusions listées (§6)
- [ ] Risques identifiés (§7)

### Incohérences détectées
| Conflit | Détail | Statut |
|---------|--------|--------|

## Bootstrap Ready
Command: /gsr:bootstrap docs/discovery.md
Prerequisites: [ce qui sera généré]
Next step: /prd --from-discovery (si > 5 features MVP)

## Resume Command
/gsr:discover-resume
```
</session-template>

---

<spec-template>
## Template SPEC.md lean

```markdown
# SPEC.md — [Nom du projet]

## Objectif
[Depuis §1 — pattern "X ne peut pas Y à cause de Z"]

## Utilisateur cible
[Depuis §1 — concret, pas "les utilisateurs"]

## Fonctionnalités MVP
### F1: [Feature depuis §5]
- [ ] [Critère d'acceptation vérifiable]
- [ ] [Cas limite si identifié]

### F2: [Feature depuis §5]
- [ ] [Critère d'acceptation]

### F3: [Feature depuis §5]
- [ ] [Critère d'acceptation]

## Stack
| Composant | Technologie | Version |
|-----------|-------------|---------|

## Contraintes
[Depuis §2 — contraintes fixées uniquement]

## Hors scope (v1)
| Exclu | Raison |
|-------|--------|
```

**Propriétés :**
- ~1-2 pages maximum
- Contient tout ce dont Claude Code a besoin pour démarrer le TDD
- Chaque feature MVP a au moins un critère d'acceptation vérifiable
</spec-template>

---

<claude-md-template>
## Template CLAUDE.md généré

```markdown
# [Nom projet]

[1 phrase depuis §1 Problem Statement]

## Commandes
- `[build_cmd]` : Build
- `[test_cmd]` : Tests
- `[lint_cmd]` : Lint

## Stack
- [Composant]: [Techno] [Version]

## Architecture
[Pattern depuis §4]

```
[Schéma ASCII depuis §4]
```

## Contexte détaillé
- Architecture : `docs/agent_docs/architecture.md`
- Database : `docs/agent_docs/database.md` (si applicable)
- Spec projet : `SPEC.md`

## Contraintes critiques
- [2-3 points depuis §2 contraintes fixées et §6 exclusions]
```

**Propriétés :**
- < 60 lignes
- Contient le minimum pour orienter Claude Code
- Pointe vers les docs détaillées pour le contexte approfondi
</claude-md-template>

---

<database-template>
## Template database.md (conditionnel — généré seulement si BDD dans §3 Stack)

```markdown
# Database — [Nom du projet]

## Moteur
[Depuis §3 — ex: PostgreSQL 16]

## Schéma initial

### Tables principales
| Table | Description | Relations |
|-------|-------------|-----------|

### Schéma préliminaire
[Inféré depuis §4 Architecture + §5 Features MVP]

```sql
-- Exemple minimal inféré
CREATE TABLE [entity] (
  id SERIAL PRIMARY KEY,
  -- colonnes inférées des features
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Migrations
- Framework : [Depuis §3 — ex: Prisma Migrate]
- Convention : `docs/adr/` si changement de schéma majeur

## Notes
- [Contraintes spécifiques depuis §2 si applicable]
```
</database-template>

---

<adr-template>
## Template ADR initial (conditionnel)

**Générer SI au moins une condition :**
- Stack non-standard pour le type de projet
- Contrainte technique forte imposée
- Trade-off explicite documenté en §3
- Alternatives considérées et rejetées

**Ne PAS générer si :** stack standard, aucune contrainte particulière, décision facilement réversible.

```markdown
# ADR-0001 : Stack technique initiale

## Statut
Accepté — [date]

## Contexte
[Résumé de §1 Problème + §2 Contraintes pertinentes]

## Décision
[Stack choisie depuis §3 avec justifications]

## Alternatives considérées
| Alternative | Rejetée car |
|-------------|-------------|

## Conséquences

### Positives
- [avantage]

### Négatives / Trade-offs
- [trade-off]

### Risques associés
[Référence à §7 si applicable]
```
</adr-template>

---

<bootstrap-logic>
## Bootstrap — Étapes d'exécution

### Syntaxe
```
/gsr:bootstrap [path/to/discovery.md]
```

**Flags optionnels :**
| Flag | Effet |
|------|-------|
| `--dry-run` | Montre ce qui serait créé sans créer |
| `--no-adr` | Skip génération ADR même si conditions remplies |
| `--minimal` | Seulement CLAUDE.md + SPEC.md |

### Étapes

1. **Parse** discovery.md → extraction structurée des 7 sections
2. **Valide** que discovery.md est complet (7 sections présentes)
   - Si incomplet → "Discovery incomplète ([sections manquantes]). Lance `/gsr:discover-resume` pour compléter."
3. **Évalue** si ADR nécessaire (voir conditions dans `<adr-template>`)
4. **Génère** la structure de fichiers :

```
project/
├── CLAUDE.md                    # < 60 lignes
├── SPEC.md                      # Lean — §1+§2+§3+§5+§6
├── docs/
│   ├── discovery.md             # Copie de référence
│   ├── agent_docs/
│   │   ├── architecture.md      # Depuis §4
│   │   └── database.md          # Depuis §3+§4 (si BDD)
│   └── adr/
│       └── 0001-initial-stack.md  # Si conditions remplies
├── .claude/
│   └── settings.json            # Permissions basées sur §3
└── [structure selon §4]
```

5. **Affiche** le résumé :

```
✅ Bootstrap terminé

Fichiers créés :
- CLAUDE.md ([N] lignes)
- SPEC.md (lean, ~1-2 pages)
- docs/discovery.md (copie de référence)
- docs/agent_docs/architecture.md
- docs/agent_docs/database.md ← [ou "Non généré — pas de BDD dans stack"]
- docs/adr/0001-initial-stack.md ← [ou "ADR non généré — stack standard"]
- .claude/settings.json

Prochaines étapes :
1. Revoir CLAUDE.md — ajuster si nécessaire
2. Revoir SPEC.md — compléter les critères d'acceptation si besoin
3. git init && git add -A && git commit -m "Initial bootstrap from discovery"
4. Choisir la première feature MVP dans SPEC.md et lancer le TDD
```
</bootstrap-logic>
