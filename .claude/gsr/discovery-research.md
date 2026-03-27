# Discovery Research Reference

Chargement sélectif : lire uniquement la section XML nécessaire.

---

<trigger-types>
## Types de déclencheurs Research Gate

### STACK_COMPARISON

**Quand :** Phase 3, choix techno non trivial (≥ 2 options viables, pas de préférence claire, ou contradiction contrainte ↔ stack)

**`<content>` à générer :**
1. Benchmarks de performance récents (métriques spécifiques au type de projet)
2. Maturité écosystème : packages, communauté, fréquence releases, bus factor
3. Fit contraintes : mapping explicite option → contrainte
4. Coût réel : tier gratuit vs production, coûts cachés
5. DX solo dev : temps de setup, qualité docs, debugging

**`<output>` à générer :**
```
Format : Tableau comparatif avec scores par critère + recommandation argumentée.
Inclure : Niveau de confiance par critère (Élevé/Moyen/Faible).
Si un critère manque de données fiables, le signaler plutôt que d'extrapoler.
```

**Queries web search :**
- `{techno_a} vs {techno_b} benchmark [année]`
- `{techno_a} pricing free tier`
- `{techno_b} known issues production`

---

### RISK_DISCOVERY

**Quand :** Phase 5c, aucun risque identifié sur projet non-trivial, ou stack récente/non-standard

**`<content>` à générer :**
1. Pitfalls et limitations documentées de la stack choisie
2. Problèmes fréquents en production pour des projets similaires (solo dev / petite équipe)
3. Incompatibilités connues entre composants de la stack
4. Points de friction à l'échelle (même modeste)
5. Dépendances à risque (maintenance, bus factor, breaking changes)

**`<output>` à générer :**
```
Format : Top 5 risques classés par (probabilité × impact).
Pour chaque risque : description, source, mitigation recommandée.
Exclure les risques enterprise-scale non pertinents pour un solo dev.
```

**Queries web search :**
- `{stack_principale} common pitfalls production`
- `{stack_principale} limitations known issues [année]`
- `{framework} breaking changes migration`

---

### UNKNOWN_RESOLUTION

**Quand :** Toute phase, l'utilisateur dit "je ne sais pas" sur un sujet technique bloquant

**`<content>` à générer (adapté dynamiquement à la question) :**
1. État de l'art sur le sujet spécifique
2. Options disponibles avec trade-offs
3. Recommandation contextuelle pour le profil du projet
4. Sources de référence pour approfondir

**`<output>` à générer :**
```
Format : Réponse directe si possible, sinon tableau d'options avec trade-offs.
Inclure : Recommandation explicite pour le contexte du projet.
Niveau de confiance global de la recommandation.
```

**Queries web search :**
- `{sujet_question} best practices [année]`
- `{sujet_question} {stack_ou_framework} guide`
- `{sujet_question} comparison solo developer`

---

### CONSTRAINT_VALIDATION

**Quand :** Phase 2 ou 3, contrainte irréaliste ou contradictoire nécessitant vérification factuelle

**`<content>` à générer :**
1. Faisabilité technique de la contrainte
2. Coût réel vs estimation de l'utilisateur
3. Alternatives si la contrainte est trop restrictive
4. Exemples de projets similaires ayant résolu cette contrainte

**`<output>` à générer :**
```
Format : Verdict de faisabilité + alternatives si nécessaire.
Structure : Contrainte → Faisable ? → Si non, alternatives → Recommandation.
```

**Queries web search :**
- `{contrainte_specifique} feasibility`
- `{service} pricing calculator [année]`
- `{contrainte} alternative solutions`
</trigger-types>

---

<integration-flow>
## Flow d'intégration des résultats

### Pattern d'invocation de l'agent

Quand un Research Gate est déclenché, invoquer l'agent via :

```
Spawn research-prompt-agent :

"Lis la session discovery dans .claude/discovery-session.md

<research_trigger>
  type: [TYPE]
  mode: [MODE]
  trigger_context: [Description de ce qui a déclenché]
  specific_question: [Question précise à résoudre]
</research_trigger>

Génère le prompt de recherche et écris-le dans .claude/research-prompt.md"
```

### Après retour de l'agent

Lire `.claude/research-prompt.md` et :

**Si mode deep :**
1. Afficher le prompt Deep Research dans un bloc de code (copier-coller facile)
2. Afficher les queries web search comme alternative rapide
3. Proposer : `[Copié, je lance Deep Research] [Plutôt la recherche rapide] [Skip]`
4. Si "Copié" → sauvegarder session + "Reviens avec /gsr:discover-resume quand tu as les résultats."
5. Si "Plutôt rapide" → exécuter les queries web search
6. Si "Skip" → continuer sans recherche

**Si mode quick :**
1. Exécuter les queries web search directement (outil WebSearch)
2. Synthétiser les résultats en 3-5 points pertinents
3. Intégrer dans le flow de la phase en cours
4. Mettre à jour le Research Log avec statut "Done"

### Intégration des résultats Deep Research au retour

Quand l'utilisateur revient avec `/gsr:discover-resume` et colle les résultats :
1. Lire les résultats collés
2. Extraire les points pertinents pour la phase en cours
3. Mettre à jour le Research Log avec statut "Done" + résumé
4. Reprendre la phase exactement où elle s'était arrêtée, enrichie des résultats
5. Si les résultats contredisent une hypothèse précédente → signaler et proposer ajustement

### Compteurs de recherche

Maintenir dans la session :
- `quick_count` : nombre de recherches rapides effectuées (max 5)
- `deep_count` : nombre de recherches Deep effectuées (max 3)

Si limite atteinte → "On a déjà fait plusieurs recherches. Continuons avec ce qu'on a."
</integration-flow>
