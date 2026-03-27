# Plan Output Templates

Chargement sélectif : lire uniquement la section XML nécessaire.

---

<roadmap-template>
## Template ROADMAP.md

```markdown
# Roadmap : [Nom du projet]

**Généré le** : [date]
**Granularité par défaut** : [fine|standard|flexible]
**Epics** : [N]
**Stories totales** : [N]

---

## Epics

| # | Epic | Stories | Priorité | Dépend de |
|---|------|---------|----------|-----------|

## Graphe de dépendances (niveau epic)

```
[Diagramme ASCII — ex:]
Epic 01 (Foundation) ──► Epic 02 (Auth) ──► Epic 05 (Dashboard)
                     ──► Epic 03 (API)  ──► Epic 05
                     ──► Epic 04 (UI)   ──► Epic 05

Parallélisables : [02, 03, 04] après 01
```

## Ordonnancement recommandé

| Ordre | Epic | Parallélisable avec |
|-------|------|---------------------|

---

## Par Epic

### Epic [N] : [Nom]

**Feature MVP :** [référence SPEC.md §5, ex: "F2: Authentification"]
**Estimation macro :** [fourchette heures]

**Stories :**

| # | Story (titre court) | Priorité | Complexité estimée | Statut |
|---|---------------------|----------|--------------------|--------|

[Statut planification : ⬜ À détailler | 🔲 Story détaillée | ✅ Phases générées]

[Répéter pour chaque epic]
```

**Propriétés :**
- Vue d'ensemble uniquement — pas de détail d'implémentation
- Suffisant pour prioriser et séquencer le travail
- Se construit progressivement : les statuts évoluent avec /plan-story et /plan-phases
</roadmap-template>

---

<epic-template>
## Template EPIC.md

```markdown
# Epic [N] : [Nom]

**Feature MVP :** [référence SPEC.md §5]
**Dépend de :** [epics prérequis ou "Aucun"]
**Priorité :** [P1|P2|P3]
**Estimation macro :** [fourchette heures]

---

## Stories

| # | Story | Priorité | Complexité | Statut planification |
|---|-------|----------|------------|---------------------|

---

## Composants architecturaux concernés

[Extrait ciblé de architecture.md — uniquement les composants pertinents pour cet epic]

| Composant | Responsabilité dans cet epic |
|-----------|------------------------------|

## Contraintes applicables

[Depuis SPEC.md — contraintes fixées impactant cet epic]

## Notes

[Observations du planner : risques, points d'attention, suggestions]
```

**Propriétés :**
- Créé par /gtd:plan (niveau 1)
- Sert de contexte pour /gtd:plan-story (niveau 2)
- Les stories sont listées mais pas détaillées
</epic-template>

---

<story-template>
## Template STORY.md

```markdown
# Story : [En tant que [persona], je peux [action] pour [bénéfice]]

**Epic :** [N] — [Nom]
**Priorité :** [P1|P2|P3]
**Estimation :** [fourchette heures]

---

## Acceptance Criteria

| # | Given | When | Then |
|---|-------|------|------|
| AC1 | [contexte initial] | [action utilisateur] | [résultat attendu] |
| AC2 | [contexte initial] | [action utilisateur] | [résultat attendu] |

## Composants concernés

| Composant | Responsabilité dans cette story |
|-----------|-------------------------------|

## Risques spécifiques

| Risque | Impact | Mitigation |
|--------|--------|-----------|

## Pré-requis

[Stories ou phases d'autres stories qui doivent être terminées avant celle-ci]

## Notes d'implémentation

[Observations de l'agent : approche recommandée, patterns à suivre, pièges à éviter]

---

## Statut

- [ ] Phases planifiées (/gtd:plan-phases)
- [ ] Implémentée
- [ ] Reviewée
```

**Propriétés :**
- Créé par /gtd:plan-story (niveau 2)
- Contient tout le contexte nécessaire pour découper en phases
- Les acceptance criteria servent de base aux tests
</story-template>

---

<plan-template>
## Template PLAN.md (par phase)

```xml
<phase id="[NN]" name="[slug]" epic="[epic-slug]" story="[story-slug]" depends="[phase-ids]">
  <estimate>[Nh]</estimate>
  <objective>[Objectif en 1 phrase claire]</objective>

  <task type="[setup|tdd|integration|config]">
    <n>[Nom de la tâche]</n>
    <files>[fichiers à créer/modifier, séparés par virgules]</files>
    <criteria>
      Given [contexte initial],
      when [action],
      then [résultat attendu]
    </criteria>
    <verify>[commande de vérification — ex: pnpm test src/auth/login.test.ts]</verify>
  </task>

  <!-- Répéter pour chaque task -->

  <review>
    <checklist>
      - [ ] [Critère de review humaine 1]
      - [ ] [Critère de review humaine 2]
      - [ ] Tests passent
      - [ ] Pas de régression
    </checklist>
  </review>
</phase>
```

**Types de task :**

| Type | Usage |
|------|-------|
| `setup` | Configuration, scaffolding, dépendances |
| `tdd` | Implémentation avec tests (RED → GREEN → REFACTOR) |
| `integration` | Connexion entre composants, E2E |
| `config` | Configuration infrastructure, CI, env |

**Propriétés :**
- Créé par /gtd:plan-phases (niveau 3)
- Directement exécutable par un futur /gtd:execute
- Chaque task a une commande de vérification
- La checklist de review guide le passage humain
</plan-template>

---

<context-template>
## Template CONTEXT.md (par phase)

```markdown
# Contexte — Phase [NN]: [Nom]

## Objectif

[1-2 phrases depuis le PLAN.md de cette phase]

## Stack pertinente

[Extrait ciblé de CLAUDE.md — uniquement les technos utilisées dans cette phase]

| Composant | Technologie | Version |
|-----------|-------------|---------|

## Architecture pertinente

[Extrait ciblé de architecture.md — uniquement les composants touchés par cette phase]

```
[Schéma ASCII réduit aux composants pertinents — ou référence au schéma complet]
```

## Contraintes applicables

[Depuis SPEC.md — contraintes impactant spécifiquement cette phase]

## Dépendances

[Ce qui doit exister avant cette phase — output des phases précédentes]
- Phase [NN-1]: [ce qu'elle a produit de pertinent]

## Fichiers clés

### À lire (existants)
- `[chemin]` — [pourquoi le lire]

### À créer
- `[chemin]` — [ce que le fichier contiendra]

### À modifier
- `[chemin]` — [nature de la modification]
```

**Propriétés :**
- Créé par /gtd:plan-phases (niveau 3)
- Chargé par un futur agent d'exécution au début de la phase
- Contient UNIQUEMENT le contexte nécessaire — pas de bruit
- Permet un `/clear` + chargement contexte frais en cas de saturation
</context-template>

---

<session-template>
## Template plan-session.md

```markdown
# Plan Session
Project: [nom du projet depuis SPEC.md]
Granularity: [fine|standard|flexible]
Level: [1-roadmap|2-story|3-phases]
Current: [ce qui est en cours — ex: "Review Epic 2" ou "Phases pour 01-auth/01-login"]
Updated: [timestamp ISO]
Started: [timestamp ISO]

## Timing
Elapsed: ~[N] min
Target: < 30 min (par niveau)
Status: [OK | Approaching limit]

---

## Analyse
[Résultat structuré de gtd-analyst — persisté entre les niveaux]

### Features MVP
| # | Feature | Priorité | Complexité | Ref SPEC.md |
|---|---------|----------|------------|-------------|

### Composants architecturaux
| Composant | Responsabilité | Technologie |
|-----------|----------------|-------------|

### Contraintes impactant la planification
| Contrainte | Type | Impact |
|------------|------|--------|

### Risques identifiés
| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|

### Stack
| Composant | Technologie | Version |
|-----------|-------------|---------|

---

## Roadmap
[Résultat du niveau 1 — Epics + Stories validés]

### Epics validés
| # | Epic | Stories | Priorité | Dépend de | Statut |
|---|------|---------|----------|-----------|--------|

---

## Story en cours
[Détail de la story en cours de planification — niveau 2]
Epic: [N]
Story: [slug]
Phase: review | validée

---

## Phases en cours
[Phases de la story en cours — niveau 3]
Epic: [N]
Story: [slug]
Phases draft: [N]

---

## Research Log
| # | Timestamp | Level | Type | Mode | Status | Résumé |
|---|-----------|-------|------|------|--------|--------|

## Historique
| Date | Action | Détail |
|------|--------|--------|
```
</session-template>
