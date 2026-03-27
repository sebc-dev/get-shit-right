# Discovery Phases Reference

Chargement sélectif : lire uniquement la section XML de la phase en cours.

---

<phase-1-problem>
## Phase 1 — Problème

**Objectif :** Comprendre le quoi, pour qui, et la situation actuelle.

**Questions types (une à la fois) :**

1. Quel problème résous-tu ?
2. Pour qui ? (utilisateurs cibles)
3. Comment c'est géré aujourd'hui ? (situation actuelle)
4. Pourquoi maintenant ? (déclencheur)

**Output :** Section §1 de discovery.md

**Critères de sortie (tous requis) :**

- [ ] Problème formulable en 1 phrase (pattern "X ne peut pas Y à cause de Z")
- [ ] Utilisateur cible nommable (pas "les utilisateurs")
- [ ] Douleur quantifiable ou observable
- [ ] Motivation claire

**Comportement :**
- Reformuler le problème en pattern "X ne peut pas Y à cause de Z" et demander confirmation
- Si l'utilisateur ne sait pas nommer sa cible → proposer des exemples contextuels
- Si la motivation est floue → demander "Qu'est-ce qui a changé récemment pour que tu veuilles résoudre ça maintenant ?"
</phase-1-problem>

---

<phase-2-constraints>
## Phase 2 — Contraintes

**Objectif :** Identifier ce qui est fixé vs ce qui est ouvert.

**Questions types (une à la fois) :**

1. Contraintes techniques imposées ? (langage, hosting, infra existante)
2. Contraintes business ? (budget, timeline, compliance)
3. Qu'est-ce qui te ferait échouer ? (fait émerger les contraintes implicites)
4. Négociable vs non-négociable ?

**Template de capture :**

| Contrainte | Type | Négociable ? | Impact sur stack |
|------------|------|--------------|------------------|
| [ex: AWS only] | Infra | Non | Hosting, services |
| [ex: Budget < 50€/mois] | Business | Oui (si justifié) | Pas de services managés coûteux |

**Output :** Section §2 de discovery.md + filtre pour Phase 3

**Critères de sortie (tous requis) :**

- [ ] Au moins une contrainte identifiée OU explicitement "aucune"
- [ ] Distinction fixé/ouvert claire pour chaque contrainte
- [ ] Timeline mentionnée (même approximative)

**Research Gate conditionnel :**

Déclencheurs (au moins un) :
- Une contrainte semble irréaliste ou contradictoire et nécessite vérification factuelle
- L'utilisateur affirme un fait technique douteux ("X est gratuit", "Y supporte Z")

Comportement :
```
Je peux vérifier ça rapidement.

[A] Recherche rapide — vérification factuelle (~30s)
[B] Continuer sans vérifier
```

Si A → spawn `research-prompt-agent` avec `type=CONSTRAINT_VALIDATION`

**→ Checkpoint mi-parcours proposé après cette phase**
</phase-2-constraints>

---

<checkpoint>
## Checkpoint Mi-Parcours (après Phase 2)

**Raison :** Valider le cadrage avant d'engager la discussion technique sur la stack.

**Format de proposition :**

```
Veux-tu un récap des 2 premières phases avant de passer à la stack ?

Recommandation : [OUI/NON] — [raison]

[Oui, faire le récap] [Non, continuer vers Stack]
```

**Logique de recommandation :**

| Condition | Reco | Raison |
|-----------|------|--------|
| Clarification nécessaire en Phase 1 ou 2 | OUI | "On a dû clarifier [X] — un récap évite les malentendus" |
| Contraintes nombreuses (> 5) | OUI | "Beaucoup de contraintes — vérifier la cohérence" |
| Changement de direction pendant phases 1-2 | OUI | "Tu as pivoté sur [X] — s'assurer que tout reste aligné" |
| Contraintes contradictoires détectées | OUI | "Contradictions potentielles — résoudre avant la stack" |
| Phases 1-2 fluides, peu de contraintes | NON | "Flow clair — récap probablement superflu" |
| Projet simple avec scope évident | NON | "Projet straightforward — on peut continuer" |

**Contenu du récap (si accepté) :**

```
## Récap Phases 1-2

**Problème** : [résumé 1 phrase, pattern "X ne peut pas Y à cause de Z"]

**Utilisateur cible** : [qui]

**Contraintes fixées** :
- [liste]

**Contraintes ouvertes** :
- [liste]

**Timeline** : [estimation]

Cohérent ? [Continuer vers Stack] [Ajuster] [Pivoter] [Pause]
```

**Options utilisateur :**
- Continuer → Phase 3
- Ajuster → retour Phase 1 ciblé
- Pivoter → nouvelle session
- Pause → save partial
</checkpoint>

---

<phase-3-stack>
## Phase 3 — Stack

**Objectif :** Proposer des choix technologiques basés sur les contraintes.

**Comportement Claude :**

1. Synthétiser les contraintes de Phase 2
2. "Basé sur tes contraintes [liste], voici ce que je propose :"
3. Tableau avec mapping contrainte → choix techno
4. Si contradiction détectée → signaler AVANT de proposer
5. Research Gate (voir ci-dessous)
6. Demander validation ou ajustement

**Exemple de proposition :**

| Contrainte | Choix proposé | Raison |
|------------|---------------|--------|
| AWS only | Lambda + DynamoDB | Serverless natif AWS |
| Budget < 50€/mois | ⚠️ Conflit potentiel | DynamoDB peut coûter plus — alternative : SQLite + EC2 micro |

**Questions types :**

- Voici ce que je propose : [stack]. Ça te convient ?
- Tu as une préférence entre [A] et [B] ?
- Des outils/libs spécifiques que tu veux utiliser ?

**Research Gate — Phase 3 :**

Déclencheurs (au moins un) :
- ≥ 2 options technologiques viables sans préférence claire
- Contradiction détectée entre contrainte et stack proposée
- Stack récente (< 2 ans) ou que Claude ne connaît pas bien
- L'utilisateur hésite explicitement entre des alternatives

Comportement :
```
J'ai identifié [N] options viables pour [composant]. Une recherche pourrait
aider à trancher.

[A] Recherche rapide — je vérifie les points clés maintenant (~30s)
[B] Deep Research — prompt optimisé pour Claude Desktop (~15-30min)
[C] Continuer avec ma recommandation sans recherche
```

Si A ou B → spawn `research-prompt-agent` avec `type=STACK_COMPARISON`
Si C → continuer le flow normal

**Si Deep Research choisi :**
1. Afficher le prompt formaté depuis `.claude/research-prompt.md`
2. "Copie ce prompt dans Claude Desktop (Deep Research). Reviens avec `/gsr:discover-resume` quand tu as les résultats."
3. Sauvegarder la session avec Research Gate en état "pending"

**Si recherche rapide :**
1. Exécuter les queries web search
2. Synthétiser les résultats en 3-5 points
3. Intégrer dans la proposition de stack
4. Continuer la Phase 3 normalement

**Output :** Section §3 de discovery.md

**Critères de sortie (tous requis) :**

- [ ] Langage/runtime choisi
- [ ] Framework principal choisi
- [ ] Base de données choisie (si applicable)
- [ ] Versions spécifiées (ou "latest stable")
- [ ] Chaque choix lié à une contrainte ou justifié
</phase-3-stack>

---

<phase-4-architecture>
## Phase 4 — Architecture

**Objectif :** Définir le pattern architectural et les composants.

**Questions types (une à la fois) :**

1. Monolithe ou services séparés ?
2. Quels sont les composants principaux ?
3. Comment communiquent-ils ?
4. Où sont stockées les données ?

**Règle :** Toujours produire un schéma ASCII, même minimal.

**Exemple de sortie :**

```
[Browser] → [API:8080] → [PostgreSQL]
              ↓
         [S3 Files]
```

Si l'utilisateur dit "c'est plus complexe" → itérer sur le schéma, pas sur du texte.

**Output :** Section §4 de discovery.md

**Critères de sortie (tous requis) :**

- [ ] Pattern architectural nommé (monolithe, API+SPA, etc.)
- [ ] Composants principaux listés
- [ ] Schéma ASCII présent
- [ ] Flux de données décrit
- [ ] Points d'entrée identifiés (API, CLI, UI)
</phase-4-architecture>

---

<phase-5-scope>
## Phase 5 — Scope

**Objectif :** Définir le MVP, les nice-to-have, les exclusions, et les risques.

### 5a — MVP & Nice-to-have

**Questions types :**
- Quelles features pour le MVP ? (le minimum qui apporte de la valeur)
- Qu'est-ce qui serait bien mais pas essentiel ?

**Règle :** Si > 8 items MVP → forcer la priorisation :
"Ça fait [N] features MVP. Laquelle est vraiment indispensable pour v1 ?"

### 5b — Exclusions

**Questions types :**
- Qu'est-ce qu'on ne fait explicitement PAS ?
- Pattern : "On ne fait PAS [X] parce que [Y]"

**Règle :** Au moins 1 exclusion explicite obligatoire.
Si 0 → "Il faut au moins une exclusion. Ça aide à cadrer le scope. Par exemple, [suggestion contextuelle basée sur le projet] ?"

### 5c — Risques

**Questions types :**
- Quels sont les rabbit holes potentiels ?
- Où pourrait-on perdre du temps ?

**Règle :** Si aucun risque identifié → challenge :
"Vraiment aucun risque ? Même [suggestion contextuelle basée sur stack/scope/architecture] ?"

**Research Gate — Phase 5c :**

Déclencheurs (au moins un) :
- Aucun risque malgré challenge ET projet non-trivial (stack > 2 composants OU MVP > 4 features OU timeline < 3 semaines)
- Stack récente ou non-standard retenue en Phase 3
- Architecture complexe (> 3 composants, communication inter-services)

Comportement :
```
Les risques sont importants à anticiper sur ce type de projet.
Je peux chercher les pitfalls connus pour ta stack.

[A] Recherche rapide — pitfalls courants (~30s)
[B] Deep Research — analyse approfondie des risques (~15-30min)
[C] Continuer sans — je note "aucun risque identifié"
```

Si A ou B → spawn `research-prompt-agent` avec `type=RISK_DISCOVERY`

**Output :** Sections §5, §6, §7 de discovery.md

**Critères de sortie (tous requis) :**

- [ ] MVP défini (1-8 items recommandé)
- [ ] Priorité assignée à chaque feature MVP
- [ ] Au moins 1 exclusion explicite
- [ ] Au moins 1 rabbit hole identifié (ou justification documentée si aucun)
</phase-5-scope>

---

<phase-6-synthesis>
## Phase 6 — Synthèse

**Objectif :** Générer le discovery.md complet et le valider.

### 6a — Génération brute

Compiler toutes les informations des phases 1-5 et générer discovery.md au format défini dans `<discovery-template>` de `discovery-output.md`.

### 6b — Validation complétude

**Champs REQUIS (bloquants si manquants) :**
- [ ] Problème statement
- [ ] Utilisateur cible
- [ ] Stack avec versions
- [ ] Architecture pattern
- [ ] Schéma ASCII
- [ ] MVP features (au moins 1)
- [ ] Exclusions (au moins 1)

**Champs RECOMMANDÉS (warning si manquants) :**
- [ ] Rabbit holes / risques
- [ ] Timeline
- [ ] Nice-to-have documentés

Si champ REQUIS manquant → retour à la phase concernée.
Si champ RECOMMANDÉ manquant → warning + possibilité de continuer.

### 6c — Validation cohérence

| Relation | Vérification |
|----------|--------------|
| Stack ↔ Contraintes | La stack respecte-t-elle toutes les contraintes ? |
| Architecture ↔ Scale | L'architecture supporte-t-elle le scale mentionné ? |
| MVP ↔ Timeline | Le MVP est-il réaliste pour la timeline ? |
| Risques ↔ Mitigations | Chaque risque a-t-il une mitigation ? |

Si incohérence détectée :
```
## ⚠️ Incohérence détectée

| Conflit | Détail | Impact potentiel |
|---------|--------|------------------|
| [X ↔ Y] | [Détail] | [Impact] |

Options :
A) Ajuster [composant] → [détail]
B) Revoir [autre composant]
C) Accepter le risque et continuer

Que préfères-tu ?
```

Si C → warning persistant dans discovery.md final avec "Risque accepté".

### 6d — Auto-critique (conditionnelle)

**Format de proposition :**
```
Veux-tu que je fasse une auto-critique du discovery ?

Recommandation : [OUI/NON] — [raison]

[Oui] [Non, finaliser discovery.md]
```

**Proposer si :** MVP > 8 items, aucun risque malgré complexité, timeline serrée, ou zones d'incertitude.
**Ne pas proposer si :** projet simple, scope clair, ≤ 5 MVP, stack standard.

**Contenu de l'auto-critique :**
```
## Auto-critique

### Hypothèses implicites
- [hypothèse] — impact si fausse : [impact]

### Questions non posées
- [question pertinente non posée]

### Edge cases non discutés
- [edge case]

### Évaluation globale
[Synthèse en 2-3 phrases]
```

### Finalisation

Après toutes les validations → écrire le fichier `discovery.md` dans le répertoire du projet.
Proposer : "Discovery terminée. Lance `/gsr:bootstrap` pour générer la structure projet."
</phase-6-synthesis>
