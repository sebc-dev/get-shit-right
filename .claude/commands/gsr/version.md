---
name: version
description: >
  Affiche la version GSR installee et verifie si une mise a jour est disponible.
human_ai_ratio: 10/90
---

# /gsr:version

## Lire la version installee

1. Lire `.claude/gsr/VERSION` dans le projet courant
   - Si absent → afficher "GSR installe sans version (installation ancienne). Lance `/gsr:update` pour synchroniser."
   - Si present → extraire le numero (ex: `0.2.0`)

## Verifier la derniere version

1. Recuperer la version distante via web fetch :
   - URL : `https://raw.githubusercontent.com/sebc-dev/get-shit-right/main/VERSION`
   - Si echec reseau → afficher la version locale avec "(impossible de verifier les mises a jour)"

2. Comparer les versions (semver) :
   - Si locale == distante → "a jour"
   - Si locale < distante → "mise a jour disponible"
   - Si locale > distante → "version locale plus recente que le repo (dev ?)"

## Affichage

```
GSR (Get Shit Right) v[locale]

Derniere version : v[distante]
Statut : [A jour | Mise a jour disponible → /gsr:update | Erreur reseau]

Repo : https://github.com/sebc-dev/get-shit-right
```
