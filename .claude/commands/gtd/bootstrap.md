---
name: bootstrap
description: Generate project structure (CLAUDE.md, SPEC.md, docs) from completed discovery.md
human_ai_ratio: 20/80
---

# /gtd:bootstrap $ARGUMENTS

## Parse des arguments

- `$ARGUMENTS` contient le chemin vers discovery.md (défaut : `discovery.md` dans le répertoire courant)
- Détecter les flags :
  - `--dry-run` : montrer ce qui serait créé sans créer
  - `--no-adr` : skip ADR même si conditions remplies
  - `--minimal` : seulement CLAUDE.md + SPEC.md

## Pré-checks

1. Vérifier que le fichier discovery.md existe au chemin spécifié
   - Si non → "Fichier non trouvé : [chemin]. Vérifie le chemin ou lance `/gtd:discover` d'abord."

2. Lire discovery.md et vérifier les 7 sections :
   - Si header contient "⚠️ Discovery incomplète" :
     - Si `--minimal` → continuer avec les sections disponibles
     - Sinon → "Discovery incomplète ([sections manquantes]). Options : [Compléter avec /gtd:discover-resume] [Bootstrapper en mode --minimal]"

## Extraction

Parser discovery.md et extraire dans des variables structurées :
- `project_name` : depuis le titre
- `problem_statement` : depuis §1
- `target_user` : depuis §1
- `fixed_constraints` : depuis §2
- `timeline` : depuis §2
- `stack` : tableau depuis §3
- `architecture_pattern` : depuis §4
- `ascii_schema` : depuis §4
- `components` : tableau depuis §4
- `data_flow` : depuis §4
- `mvp_features` : tableau depuis §5
- `exclusions` : tableau depuis §6
- `risks` : tableau depuis §7

## Génération

Lire les templates depuis `.claude/skills/gtd-discovery/discovery-output.md`.

### 1. CLAUDE.md
Lire `<claude-md-template>`.
Générer `CLAUDE.md` à la racine du projet.
- < 60 lignes
- Déduire les commandes build/test/lint depuis la stack (§3)

### 2. SPEC.md
Lire `<spec-template>`.
Générer `SPEC.md` à la racine du projet.
- Pour chaque feature MVP → au moins 1 critère d'acceptation vérifiable
- Si discovery incomplète → marquer les sections manquantes

### 3. docs/discovery.md
Copier le discovery.md source dans `docs/discovery.md` (archivage).

### 4. docs/agent_docs/architecture.md
Générer depuis §4 :
- Pattern architectural
- Composants avec responsabilités
- Schéma ASCII
- Flux de données
- Points d'entrée

### 5. docs/agent_docs/database.md (conditionnel)
Lire `<database-template>`.
**Générer seulement si** la stack (§3) contient une base de données.
- Inférer les tables depuis §4 (composants) + §5 (features MVP)
- Schema SQL préliminaire minimal

### 6. docs/adr/0001-initial-stack.md (conditionnel)
Lire `<adr-template>`.
**Générer si** au moins une condition :
- Stack non-standard pour le type de projet
- Contrainte technique forte imposée
- Trade-off explicite documenté en §3
- Alternatives considérées et rejetées

**Ne PAS générer si** `--no-adr` flag OU stack standard sans contrainte particulière.

### 7. .claude/settings.json
Mettre à jour les permissions basées sur la stack :
- Ajouter les commandes pertinentes (ex: `pnpm`, `npm`, `cargo`, etc.)

### 8. Structure projet (si non --minimal)
Créer les dossiers de base selon §4 Architecture :
- `src/` (ou équivalent selon la stack)
- `tests/` (ou équivalent)

## Mode --dry-run

Ne rien créer. Afficher :

```
Mode dry-run — voici ce qui serait créé :

Fichiers :
  ✓ CLAUDE.md (~[N] lignes)
  ✓ SPEC.md (~[N] features, ~[N] lignes)
  ✓ docs/discovery.md (copie)
  ✓ docs/agent_docs/architecture.md
  [✓|✗] docs/agent_docs/database.md — [raison]
  [✓|✗] docs/adr/0001-initial-stack.md — [raison]

Dossiers :
  ✓ src/
  ✓ tests/
  ✓ docs/agent_docs/
  [✓|✗] docs/adr/

Relance sans --dry-run pour créer.
```

## Output final

```
✅ Bootstrap terminé

Fichiers créés :
- CLAUDE.md ([N] lignes)
- SPEC.md (lean, [N] features MVP)
- docs/discovery.md (copie de référence)
- docs/agent_docs/architecture.md
- docs/agent_docs/database.md ← [ou "Non généré — pas de BDD dans stack"]
- docs/adr/0001-initial-stack.md ← [ou "ADR non généré — stack standard"]

Prochaines étapes :
1. Revoir CLAUDE.md — ajuster si nécessaire
2. Revoir SPEC.md — compléter les critères d'acceptation si besoin
3. git init && git add -A && git commit -m "Initial bootstrap from discovery"
4. Choisir la première feature MVP dans SPEC.md et lancer le TDD
```
