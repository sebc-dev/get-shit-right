---
name: discover-save
description: Save partial discovery.md from incomplete session
human_ai_ratio: 20/80
---

# /gsr:discover-save

## Pré-checks

1. Vérifier si `.claude/discovery-session.md` existe :
   - Si non → "Aucune session discovery en cours."
   - Si oui → continuer

2. Lire la session et extraire toutes les données capturées

## Génération du discovery.md partiel

Lire `<discovery-template>` depuis `.claude/gsr/discovery-output.md`.

Générer un `discovery.md` avec :

1. **Header modifié** :
   ```markdown
   # Discovery : [Nom du projet]

   ## ⚠️ Discovery incomplète
   **Phases complétées** : [N]
   **Phases manquantes** : [liste]
   **Raison** : [sauvegarde manuelle | timeout | blocage]
   ```

2. **Sections complétées** → contenu normal depuis la session
3. **Sections incomplètes** → `*Non défini*`
4. **Section finale** :
   ```markdown
   ---

   ## Ce qui reste à définir
   - [ ] [liste des éléments manquants par phase]
   ```

## Output

Écrire le fichier `discovery.md` dans le répertoire du projet.

```
📄 discovery.md partiel généré ([N]/6 phases).

Sections complétées : [liste]
Sections manquantes : [liste]

Pour compléter plus tard : `/gsr:discover-resume`
Pour bootstrapper avec ce qu'on a : `/gsr:bootstrap discovery.md --minimal`
```

La session `.claude/discovery-session.md` est conservée pour permettre la reprise.
