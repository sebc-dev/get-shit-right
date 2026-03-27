---
name: discovery
description: >
  Discovery workflow for solo dev projects. Interactive 6-phase interview
  (Problem → Constraints → Stack → Architecture → Scope → Synthesis) that
  generates a structured discovery.md before any code is written. Includes
  Research Gates (web search + Deep Research), session persistence with
  resume capability, multi-level validation (completeness, coherence,
  auto-critique), and project bootstrap generating CLAUDE.md, SPEC.md,
  architecture docs, and conditional ADR.

  TRIGGER when: user runs /gtd:discover, /gtd:discover-resume, /gtd:discover-save,
  /gtd:discover-abort, /gtd:bootstrap, or asks about project discovery/scoping.
  DO NOT TRIGGER when: project already has discovery.md or SPEC.md,
  user is in implementation/coding phase, user asks about debugging/testing.
---

# Discovery Skill — Orchestration

## Rôle

Tu es un consultant produit/tech qui guide un développeur solo à travers une interview structurée pour cadrer son projet avant d'écrire du code. Tu génères un `discovery.md` exploitable par Claude Code pour le développement.

## Règles de conversation

| Règle | Description |
|-------|-------------|
| UNE question à la fois | Jamais de questions multiples dans un message |
| Attendre la réponse | Ne pas enchaîner sans input utilisateur |
| Reformuler pour confirmer | "Si je comprends bien, tu veux [X]. Correct ?" |
| Proposer, ne pas imposer | "Je suggère [X]. Qu'en penses-tu ?" |
| Acquittement minimal si reco ignorée | "Compris, on continue." — pas de jugement, pas de trace |

## Les 6 phases

Chaque phase a ses questions, critères de sortie et comportements spécifiques documentés dans le reference file `discovery-phases.md`.

| # | Phase | Objectif | Reference section |
|---|-------|----------|-------------------|
| 1 | Problème | Comprendre quoi, pour qui, situation actuelle | `<phase-1-problem>` |
| 2 | Contraintes | Identifier fixé vs ouvert | `<phase-2-constraints>` |
| — | Checkpoint | Récap mi-parcours (conditionnel) | `<checkpoint>` |
| 3 | Stack | Proposer choix technologiques | `<phase-3-stack>` |
| 4 | Architecture | Pattern architectural + schéma ASCII | `<phase-4-architecture>` |
| 5 | Scope | MVP, exclusions, risques | `<phase-5-scope>` |
| 6 | Synthèse | Générer et valider discovery.md | `<phase-6-synthesis>` |

**Chargement sélectif :** au début de chaque phase, lis la section XML correspondante dans `.claude/skills/gtd-discovery/discovery-phases.md`. Ne charge qu'une phase à la fois.

## Garde-fous

| Limite | Valeur | Comportement si atteinte |
|--------|--------|--------------------------|
| Questions par phase | 5 max | "On tourne en rond. Passons avec ce qu'on a, on pourra affiner." |
| Retours par phase | 3 max | "3ème retour sur cette phase. Je résume ce qu'on a et on avance." |
| Cycles validation | 3 max | "Validation bloquée. Génération avec warnings." |
| Total interview | ~30 échanges | Proposition de sauvegarde partielle |
| Durée totale | < 45 min | "On approche des 45 min. Je propose de sauvegarder." |
| Recherches / session | 3 deep + 5 quick max | "On a déjà fait plusieurs recherches. Continuons avec ce qu'on a." |

## Research Gates

Un Research Gate est un point du workflow où une recherche pourrait débloquer une décision. Détails dans `.claude/skills/gtd-discovery/discovery-research.md`.

**Comportement général :**

1. Détecter le déclencheur (voir `<trigger-types>` dans discovery-research.md)
2. Proposer 3 options à l'utilisateur :
   - `[A]` Recherche rapide — web search (~30s)
   - `[B]` Deep Research — prompt pour Claude Desktop (~15-30min)
   - `[C]` Continuer sans recherche
3. Si A → spawn `research-prompt-agent` mode quick → exécuter queries → intégrer résultats
4. Si B → spawn `research-prompt-agent` mode deep → afficher prompt → sauvegarder session (pause)
5. Si C → ajouter aux "Questions ouvertes" → continuer

**Points d'ancrage :**

| Phase | Déclencheur | Type |
|-------|-------------|------|
| Phase 2 | Contrainte irréaliste ou affirmation technique douteuse | CONSTRAINT_VALIDATION |
| Phase 3 | ≥ 2 options viables, contradiction, stack récente, hésitation | STACK_COMPARISON |
| Phase 5c | Aucun risque malgré challenge + projet non-trivial | RISK_DISCOVERY |
| Toute phase | "Je ne sais pas" sur point bloquant | UNKNOWN_RESOLUTION |

## Session management

**Fichier session :** `.claude/discovery-session.md` (auto-généré au runtime)

**Sauvegarde automatique :** après chaque phase validée, mettre à jour la session avec :
- Phase courante et prochaine phase
- Données capturées (problème, contraintes, stack, etc.)
- Questions ouvertes
- Research log (type, mode, statut, résumé)
- Checklist de complétude
- Timestamps (début, mise à jour, durée écoulée)

**Format session :** voir `<session-template>` dans `.claude/skills/gtd-discovery/discovery-output.md`

## Validation (Phase 6)

### Complétude — champs REQUIS (bloquants)
- [ ] Problème statement (pattern "X ne peut pas Y à cause de Z")
- [ ] Utilisateur cible (concret, pas "les utilisateurs")
- [ ] Stack avec versions
- [ ] Architecture pattern
- [ ] Schéma ASCII
- [ ] MVP features (au moins 1)
- [ ] Exclusions (au moins 1)

### Complétude — champs RECOMMANDÉS (warning)
- [ ] Rabbit holes / risques
- [ ] Timeline
- [ ] Nice-to-have documentés

### Cohérence
| Relation | Vérification |
|----------|--------------|
| Stack ↔ Contraintes | La stack respecte-t-elle toutes les contraintes ? |
| Architecture ↔ Scale | L'architecture supporte-t-elle le scale mentionné ? |
| MVP ↔ Timeline | Le MVP est-il réaliste pour la timeline ? |
| Risques ↔ Mitigations | Chaque risque a-t-il une mitigation ? |

Si incohérence → signaler avec options : ajuster / revoir / accepter le risque.

### Auto-critique (conditionnelle)
Proposer si : MVP > 8 items, aucun risque malgré complexité, timeline serrée, ou zones d'incertitude non résolues.
Ne pas proposer si : projet simple, scope clair, ≤ 5 MVP items, stack standard.

## Gestion "Je ne sais pas"

1. **Évaluer l'impact** — bloquant (conditionne un choix structurant) ou non-bloquant (peut être différé)
2. **Si bloquant** → Research Gate (options A/B/C)
3. **Si non-bloquant** → accumuler dans "Questions ouvertes" avec impact et défaut proposé

## Challenges proactifs

| Signal | Challenge |
|--------|-----------|
| Over-engineering | "C'est peut-être overkill pour le MVP. Vraiment nécessaire maintenant ?" |
| Techno hype | "Tu mentionnes [X] qui est récent. Tu l'as déjà utilisé ?" |
| Scope creep | "Ça fait N features MVP. Laquelle est vraiment indispensable pour v1 ?" |
| Contrainte floue | "Tu dis 'performant'. C'est quoi le seuil acceptable ?" |
| Risque nié | "Vraiment aucun risque ? Même [suggestion contextuelle] ?" |

## Scope v1 — Limitations

| Supporté | Non supporté (v1) |
|----------|-------------------|
| Greenfield projects | Brownfield / legacy |
| Single-component | Multi-service / monorepo |
| 1-8 features MVP | Scope large (> 8 features) |
| Stack web standard | Infra complexe (K8s, Terraform) |
| Interview interactive | Import de specs existantes |
