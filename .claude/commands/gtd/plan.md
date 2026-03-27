---
name: plan
description: >
  Niveau 1 de la planification progressive. Analyse les documents bootstrap
  et génère un ROADMAP avec Epics et Stories. Ne descend pas au niveau des
  phases — celles-ci seront planifiées au fur et à mesure avec /gtd:plan-phases.
  Args: [path/to/SPEC.md] [--granularity=fine|standard|flexible]
human_ai_ratio: 40/60
---

# /gtd:plan $ARGUMENTS

## Parse arguments

1. Extraire depuis `$ARGUMENTS` :
   - `spec_path` : premier argument positionnel (chemin vers SPEC.md) — si absent, chercher `SPEC.md` dans le répertoire courant
   - `--granularity=` : `fine` | `standard` | `flexible` — défaut : `flexible`
   - `--dry-run` : si présent, afficher ce qui serait créé sans créer

## Pré-checks

1. **SPEC.md existe** :
   - Vérifier que `spec_path` pointe vers un fichier existant et non vide
   - Si absent → "SPEC.md introuvable. Lance `/gtd:bootstrap` d'abord pour générer les documents projet."

2. **Documents bootstrap complets** :
   - Vérifier `docs/agent_docs/architecture.md` existe
   - Vérifier `docs/discovery.md` existe
   - Vérifier `CLAUDE.md` existe
   - Si un document obligatoire manque → lister les manquants et proposer `/gtd:bootstrap`

3. **Pas de session en cours** :
   - Vérifier si `.claude/plan-session.md` existe
   - Si oui → "Une session de planification est en cours (Niveau [N]). Utilise `/gtd:plan-status` pour voir l'état, ou `/gtd:plan-abort` pour recommencer. [Continuer quand même] [Annuler]"
   - Si "Continuer" → archiver l'ancienne session (renommer avec timestamp)

4. **Pas de plan existant** :
   - Vérifier si `docs/plan/ROADMAP.md` existe
   - Si oui → "Un plan existe déjà. Veux-tu le remplacer ? [Oui, re-planifier] [Non, annuler]"
   - Si "Non" → stop

## Étape 1 — Analyse (Agent)

1. Spawner l'agent `gtd-analyst` avec le prompt :
   ```
   Analyse les documents bootstrap du projet.
   SPEC.md : [spec_path]
   Granularité : [granularity]
   Répertoire projet : [cwd]
   ```

2. Vérifier que `.claude/plan-session.md` a été créé avec la section `## Analyse`

3. Si la section `## Alertes` contient des éléments :
   - Afficher les alertes à l'utilisateur
   - Pour chaque incohérence : "Incohérence détectée : [détail]. Continuer quand même ? [Oui] [Non, je corrige d'abord]"
   - Si "Non" → stop

## Étape 2 — Décomposition (Agent)

1. Spawner l'agent `gtd-planner` avec le prompt :
   ```
   Mode : roadmap
   Session : .claude/plan-session.md
   Granularité : [granularity]

   Décompose le projet en Epics et Stories (SANS phases).
   Lire la section ## Analyse de la session pour les données.
   Écrire le résultat dans la section ## Roadmap de la session.
   ```

2. Vérifier que `plan-session.md` section `## Roadmap` est remplie

3. Vérifier les Research Gates dans `## Research Needed` :
   - Si présent → pour chaque Research Gate :
     a. Lire `.claude/gtd/plan-research.md` section `<integration-flow>`
     b. Proposer à l'utilisateur :
        ```
        Research Gate — [TYPE]
        [Description du point à résoudre]

        Options :
        [A] Recherche rapide (~30s)
        [B] Deep Research (~15-30min)
        [C] Continuer sans recherche
        ```
     c. Si [A] → spawner `research-prompt-agent` mode=quick → exécuter web searches → intégrer → re-spawner planner
     d. Si [B] → spawner `research-prompt-agent` mode=deep → afficher instructions → sauvegarder session → stop (reprendre via /gtd:plan-resume ou relancer /gtd:plan)
     e. Si [C] → continuer avec l'approche best-effort

## Étape 3 — Review interactive

Présenter le plan draft epic par epic :

Pour chaque epic dans `## Roadmap` :

1. Afficher :
   ```
   Epic [N] : [Nom]
   Feature MVP : [référence]
   Dépend de : [dépendances]
   Stories : [N]

   | # | Story | Priorité | Complexité |
   |---|-------|----------|------------|
   [table des stories]

   [Valider] [Ajuster] [Passer]
   ```

2. Si **Valider** → marquer l'epic comme validé dans la session

3. Si **Ajuster** → demander quoi changer :
   - "Que veux-tu ajuster ?" (texte libre)
   - Appliquer les modifications dans la session
   - Re-présenter l'epic modifié
   - Max 3 cycles par epic → "3ème itération. On valide et on ajuste en exécution si besoin."

4. Si **Passer** → marquer comme draft, continuer

Après tous les epics :

5. Validation finale — vérifier :
   - [ ] ≥ 1 epic validé
   - [ ] Chaque epic a ≥ 1 story
   - [ ] Graphe de dépendances acyclique
   - [ ] Chaque feature MVP a au moins 1 epic
   - Si échec → signaler et proposer d'ajuster

6. Afficher le résumé :
   ```
   Plan validé : [N] epics, [N] stories

   Graphe :
   [Diagramme ASCII des dépendances]

   Ordonnancement : [liste ordonnée]
   ```

## Étape 4 — Génération (Agent)

Si `--dry-run` :
- Afficher la liste des fichiers qui seraient créés
- Stop

Sinon :

1. Mettre à jour `plan-session.md` : déplacer le contenu validé dans `## Roadmap`

2. Spawner l'agent `gtd-generator` avec le prompt :
   ```
   Mode : roadmap
   Session : .claude/plan-session.md
   Répertoire de sortie : docs/plan/
   Répertoire projet : [cwd]

   Génère ROADMAP.md + EPIC.md par epic + arborescence stories.
   Charger les templates depuis .claude/gtd/plan-output.md.
   ```

3. Vérifier que les fichiers ont été créés

## Étape 5 — Résumé final

```
Planification niveau 1 terminée.

Fichiers créés :
- docs/plan/ROADMAP.md
- docs/plan/epics/[NN]-[slug]/EPIC.md (× [N])
- [N] dossiers stories créés (à détailler)

Prochaine étape :
  /gtd:plan-story [epic-slug]/[story-slug]

  Suggestion : commence par l'epic [premier dans l'ordonnancement]
  → /gtd:plan-story [slug du premier epic]/[slug de la première story]
```

## Garde-fous

| Limite | Valeur | Comportement |
|--------|--------|-------------|
| Total epics | 10 max | "10 epics = projet très ambitieux pour solo dev." |
| Stories par epic | 6 max | "Beaucoup de stories. Certaines sont-elles post-MVP ?" |
| Cycles review / epic | 3 max | "3ème itération. On valide et ajuste en exécution." |
| Recherches / session | 3 deep + 5 quick | "Continuons avec ce qu'on a." |
| Durée totale | < 30 min | "On approche de 30 min. On finalise ?" |
