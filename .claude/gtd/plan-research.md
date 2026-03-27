# Plan Research Reference

Chargement sélectif : lire uniquement la section XML nécessaire.

---

<trigger-types>
## Types de déclencheurs Research Gate (Planification)

### IMPLEMENTATION_PATTERN

**Quand :** Niveaux 2-3 — une feature peut être implémentée de plusieurs façons et le choix impacte la décomposition en phases (ex: REST vs GraphQL, SSR vs CSR, monolith vs services).

**`<content>` à générer :**
1. Comparaison des patterns candidats pour le cas d'usage spécifique
2. Impact sur la complexité d'implémentation (nombre de phases, effort)
3. Impact sur la testabilité et la maintenabilité
4. Compatibilité avec la stack choisie et les contraintes fixées
5. Retours d'expérience solo dev (DX, debugging, temps de setup)

**`<output>` à générer :**
```
Format : Tableau comparatif pattern → critères + recommandation argumentée.
Inclure : Impact estimé sur le nombre de phases.
Si un pattern nécessite une lib non prévue, le signaler.
```

**Queries web search :**
- `[pattern_a] vs [pattern_b] [framework] 2025`
- `[pattern] implementation complexity solo developer`
- `[pattern] [framework] best practices`

---

### LIBRARY_CHOICE

**Quand :** Niveaux 2-3 — une librairie est nécessaire pour estimer la complexité d'une story/phase mais n'a pas été choisie dans la stack discovery (ex: ORM, validation, state management).

**`<content>` à générer :**
1. Comparaison des libs candidates (API, DX, bundle size, maintenance)
2. Maturité : fréquence releases, issues ouvertes, bus factor
3. Compatibilité avec la stack existante
4. Courbe d'apprentissage pour un solo dev
5. Impact sur la décomposition (setup phase nécessaire ? migration ?)

**`<output>` à générer :**
```
Format : Tableau lib → critères + recommandation.
Inclure : Niveau de confiance par critère (Élevé/Moyen/Faible).
Si une lib est récente ou peu testée en production, le signaler.
```

**Queries web search :**
- `best [category] library [framework] 2025`
- `[lib_a] vs [lib_b] comparison`
- `[lib] production issues known bugs`

---

### INTEGRATION_RISK

**Quand :** Niveau 3 — deux composants doivent s'intégrer mais l'interface n'est pas claire dans l'architecture, ou des incompatibilités sont suspectées.

**`<content>` à générer :**
1. Patterns d'intégration documentés entre les deux composants
2. Problèmes fréquents et incompatibilités connues
3. Étapes d'intégration recommandées (ordonnancement)
4. Tests d'intégration nécessaires
5. Fallbacks si l'intégration échoue

**`<output>` à générer :**
```
Format : Checklist d'intégration ordonnée + risques identifiés.
Recommandation : phases d'intégration dédiées si nécessaire.
```

**Queries web search :**
- `[comp_a] [comp_b] integration guide`
- `[comp_a] [comp_b] known issues`
- `[framework] [comp_a] setup tutorial`

---

### UNKNOWN_RESOLUTION

**Quand :** Tout niveau — l'utilisateur dit "je ne sais pas" ou exprime une incertitude sur un point structurant pour la planification (ex: "je ne sais pas si on devrait avoir un cache", "pas sûr de l'approche pour les notifications").

**`<content>` à générer :**
1. Best practices pour le contexte spécifique du projet
2. Approche recommandée pour un solo dev
3. Trade-offs des options principales
4. Impact sur la planification de chaque option
5. Approche "start simple" recommandée si applicable

**`<output>` à générer :**
```
Format : Recommandation principale + alternatives classées par simplicité.
Inclure : "Start simple" option si le choix est réversible.
```

**Queries web search :**
- `[domain] best practices [context]`
- `[topic] simple approach solo developer`
- `when to use [option] vs [option]`
</trigger-types>

---

<integration-flow>
## Flux d'intégration Research Gate (Planification)

### Détecter un trigger

Pendant la planification (niveaux 2-3 principalement), un Research Gate se déclenche quand :

| Signal | Trigger probable |
|--------|-----------------|
| ≥ 2 approches d'implémentation viables, pas de choix évident | IMPLEMENTATION_PATTERN |
| Lib nécessaire mais non définie dans la stack discovery | LIBRARY_CHOICE |
| 2 composants à intégrer, interface floue ou risque suspecté | INTEGRATION_RISK |
| L'utilisateur dit "je ne sais pas" sur un point structurant | UNKNOWN_RESOLUTION |

### Proposer à l'utilisateur

Quand un trigger est détecté, la command (pas l'agent) propose :

```
🔍 Research Gate — [TYPE]

[Description en 1-2 phrases du point à résoudre]

Options :
[A] Recherche rapide (~30s) — je cherche sur le web et je synthétise
[B] Deep Research (~15-30min) — prompt optimisé pour Claude Desktop
[C] Continuer sans recherche — je fais au mieux avec ce qu'on a
```

### Option A — Recherche rapide

1. La command spawne `research-prompt-agent` avec :
   - Chemin vers `plan-session.md` (au lieu de discovery-session.md)
   - Bloc `<research_trigger>` avec type, mode=quick, contexte, question
2. L'agent génère les queries dans `.claude/research-prompt.md`
3. La command exécute 2-3 web searches
4. La command synthétise les résultats et les intègre dans le plan
5. Mise à jour Research Log dans plan-session.md

### Option B — Deep Research

1. La command spawne `research-prompt-agent` avec mode=deep
2. L'agent génère le prompt complet dans `.claude/research-prompt.md`
3. La command affiche :
   ```
   Prompt Deep Research généré dans .claude/research-prompt.md

   Instructions :
   1. Copie le contenu de .claude/research-prompt.md
   2. Colle-le dans Claude Desktop (claude.ai) en mode Deep Research
   3. Attends le résultat (~15-30 min)
   4. Reviens ici et lance /gtd:plan-story --resume ou /gtd:plan-phases --resume

   La session est sauvegardée. Tu peux fermer cette conversation.
   ```
4. Sauvegarde automatique de la session avec `## Pending Research`

### Option C — Continuer sans

1. Documenter la décision dans plan-session.md :
   ```
   ## Décision sans recherche
   Question: [question]
   Approche choisie: [best effort]
   Risque: [impact si le choix est sous-optimal]
   ```
2. Continuer la planification avec l'approche best-effort
3. Ajouter un risque dans le plan si pertinent

### Limites par session

| Type | Max |
|------|-----|
| Quick searches | 5 par session de planification |
| Deep Research | 3 par session de planification |

Au-delà : "On a déjà fait [N] recherches. Je recommande de continuer avec ce qu'on a et d'ajuster en exécution si besoin."

### Adaptation au contexte plan (vs discovery)

Le `research-prompt-agent` détecte le mode via le fichier session :
- Si le prompt mentionne `plan-session.md` → mode planification
- Adapte le `<context>` : inclut stack validée, architecture définie, features MVP
- Adapte les `<sources>` : priorise docs techniques, exemples d'implémentation, benchmarks
- Le `<output>` demande explicitement l'impact sur la décomposition en phases
</integration-flow>
