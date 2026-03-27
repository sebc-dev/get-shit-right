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
   - Si header contient "Discovery incomplète" :
     - Si `--minimal` → continuer avec les sections disponibles
     - Sinon → "Discovery incomplète ([sections manquantes]). Options : [Compléter avec /gtd:discover-resume] [Bootstrapper en mode --minimal]"

## Génération (Agent)

Spawner l'agent `gtd-bootstrapper` avec le prompt :
```
Discovery : [chemin discovery.md]
Templates : .claude/gtd/discovery-output.md
Flags : [--dry-run] [--no-adr] [--minimal]
Répertoire projet : [cwd]

Génère la structure projet depuis discovery.md.
Charger les templates depuis .claude/gtd/discovery-output.md.
```

## Traitement du résultat

### Mode --dry-run

Afficher le résumé du dry-run retourné par l'agent. Ne rien créer.

```
Mode dry-run — voici ce qui serait créé :
[résumé de l'agent]

Relance sans --dry-run pour créer.
```

### Mode normal

Afficher le résumé des fichiers créés :

```
Bootstrap terminé.

Fichiers créés :
[liste depuis le résumé de l'agent]

Prochaines étapes :
1. Revoir CLAUDE.md — ajuster si nécessaire
2. Revoir SPEC.md — compléter les critères d'acceptation si besoin
3. git init && git add -A && git commit -m "Initial bootstrap from discovery"
4. /gtd:plan pour planifier l'implémentation
```
