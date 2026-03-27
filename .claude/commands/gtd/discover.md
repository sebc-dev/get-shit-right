---
name: discover
description: Start a new discovery session — interactive 6-phase interview generating discovery.md
human_ai_ratio: 70/30
---

# /gtd:discover "$ARGUMENTS"

## Pré-checks

1. Vérifier si un fichier `discovery.md` existe déjà dans le projet :
   - Si oui → "Un discovery.md existe déjà. Veux-tu le remplacer ? [Oui, nouvelle discovery] [Non, annuler]"
   - Si "Non" → stop

2. Vérifier si une session existe dans `.claude/discovery-session.md` :
   - Si oui → "Une session discovery est en cours (Phase [N]/6). Utilise `/gtd:discover-resume` pour la reprendre, ou confirme pour en démarrer une nouvelle (l'ancienne sera archivée). [Reprendre] [Nouvelle session]"
   - Si "Reprendre" → basculer vers le flow de `/gtd:discover-resume`
   - Si "Nouvelle session" → archiver l'ancienne session, continuer

## Initialisation

1. Lire la description du projet depuis les arguments : `$ARGUMENTS`
   - Si vide → demander : "Décris ton projet en 1-2 phrases."

2. Créer le fichier session `.claude/discovery-session.md` avec :
   ```
   # Discovery Session
   Project: [description depuis arguments]
   Phase: 1/6 (Problème)
   Next: Contraintes
   Updated: [timestamp]
   Started: [timestamp]

   ## Timing
   Elapsed: ~0 min
   Target: < 45 min
   Status: On track

   ## Captured
   [vide — sera rempli phase par phase]

   ## Open Questions
   [vide]

   ## Research Log
   | # | Timestamp | Phase | Type | Mode | Status | Résumé |
   |---|-----------|-------|------|------|--------|--------|

   ## Validation Metadata
   ### Checklist complétude
   - [ ] Problème défini (§1)
   - [ ] Contraintes documentées (§2)
   - [ ] Stack avec versions (§3)
   - [ ] Architecture avec schéma (§4)
   - [ ] MVP délimité (§5)
   - [ ] Exclusions listées (§6)
   - [ ] Risques identifiés (§7)
   ```

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

## Garde-fous

| Limite | Valeur | Comportement si atteinte |
|--------|--------|--------------------------|
| Questions par phase | 5 max | "On tourne en rond. Passons avec ce qu'on a, on pourra affiner." |
| Retours par phase | 3 max | "3ème retour sur cette phase. Je résume ce qu'on a et on avance." |
| Cycles validation | 3 max | "Validation bloquée. Génération avec warnings." |
| Total interview | ~30 échanges | Proposition de sauvegarde partielle |
| Durée totale | < 45 min | "On approche des 45 min. Je propose de sauvegarder." |
| Recherches / session | 3 deep + 5 quick max | "On a déjà fait plusieurs recherches. Continuons avec ce qu'on a." |

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

## Research Gates

Un Research Gate est un point du workflow où une recherche pourrait débloquer une décision. Détails dans `.claude/gtd/discovery-research.md`.

**Comportement général :**

1. Détecter le déclencheur (voir `<trigger-types>` dans `.claude/gtd/discovery-research.md`)
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

**Format session :** voir `<session-template>` dans `.claude/gtd/discovery-output.md`

## Boucle conversationnelle — Phases 1 à 5

Les 6 phases et leurs détails (questions, critères de sortie, comportements) sont dans `.claude/gtd/discovery-phases.md`.

| # | Phase | Objectif | Reference section |
|---|-------|----------|-------------------|
| 1 | Problème | Comprendre quoi, pour qui, situation actuelle | `<phase-1-problem>` |
| 2 | Contraintes | Identifier fixé vs ouvert | `<phase-2-constraints>` |
| — | Checkpoint | Récap mi-parcours (conditionnel) | `<checkpoint>` |
| 3 | Stack | Proposer choix technologiques | `<phase-3-stack>` |
| 4 | Architecture | Pattern architectural + schéma ASCII | `<phase-4-architecture>` |
| 5 | Scope | MVP, exclusions, risques | `<phase-5-scope>` |

**Chargement sélectif :** au début de chaque phase, lis la section XML correspondante dans `.claude/gtd/discovery-phases.md`. Ne charge qu'une phase à la fois.

### Lancement Phase 1

1. Lire la section `<phase-1-problem>` depuis `.claude/gtd/discovery-phases.md`

2. Message d'accueil :
   ```
   Discovery démarrée pour : "[description projet]"

   On va cadrer ton projet en 6 phases (~30-45 min).
   Je pose une question à la fois. Tu peux dire "je ne sais pas" — on gérera.

   Phase 1/6 — Problème

   [Première question de Phase 1, contextualisée avec la description fournie]
   ```

3. Suivre le flow de la Phase 1 selon les critères de sortie de `<phase-1-problem>`

### Progression entre phases

À chaque phase validée :
1. Sauvegarder les données dans `.claude/discovery-session.md`
2. Mettre à jour la checklist de complétude
3. Charger la section XML de la phase suivante
4. Annoncer : "Phase [N]/6 — [Nom]"
5. Continuer l'interview

### Checkpoint mi-parcours (après Phase 2)

Charger `<checkpoint>` depuis `.claude/gtd/discovery-phases.md`.
Proposer un récap selon la logique documentée (recommander OUI si clarifications, contraintes nombreuses, contradictions).

## Phase 6 — Synthèse (Agent)

Après la Phase 5, la synthèse est déléguée à un agent spécialisé :

1. Sauvegarder la session avec toutes les données des phases 1-5

2. Spawner l'agent `gtd-synthesizer` avec le prompt :
   ```
   Session : .claude/discovery-session.md
   Répertoire projet : [cwd]
   ```

3. L'agent produit `discovery.md` et retourne un résumé structuré

4. Traiter le résultat :
   - **Complétude PASS + Cohérence PASS** :
     ```
     Discovery terminée.

     discovery.md généré ([N] mots, 7/7 sections).
     Lance `/gtd:bootstrap` pour générer la structure projet.
     ```
   - **Complétude FAIL** (champ requis manquant) :
     ```
     Il manque des éléments requis :
     - [champ manquant 1]
     - [champ manquant 2]

     [Compléter maintenant] [Générer quand même avec warnings]
     ```
     Si "Compléter" → retour à la phase concernée
   - **Cohérence WARNINGS** :
     ```
     Incohérences détectées :
     [table des incohérences]

     Options :
     [A] Ajuster [composant]
     [B] Revoir [autre composant]
     [C] Accepter les risques et continuer
     ```

## Scope v1 — Limitations

| Supporté | Non supporté (v1) |
|----------|-------------------|
| Greenfield projects | Brownfield / legacy |
| Single-component | Multi-service / monorepo |
| 1-8 features MVP | Scope large (> 8 features) |
| Stack web standard | Infra complexe (K8s, Terraform) |
| Interview interactive | Import de specs existantes |
