# GSR (Get Shit Right) Workflow — Synthese Complete

**Version :** 2026-03-27
**Repo :** github.com/sebc-dev/gsr
**Architecture :** Command + Agents + References (pattern GSD)

---

## 1. Vue d'ensemble

GSR est un plugin Claude Code qui structure le cycle de vie d'un projet solo dev, de l'idee au deploiement. Il s'installe dans n'importe quel projet via `curl | bash` et fournit des slash commands pour chaque phase.

### Pipeline

```
  DISCOVERY          BOOTSTRAP          PLAN                 EXECUTE        SHIP
  (interview)        (scaffolding)      (planification)      (code)         (deploy)
       |                  |                  |                  |              |
  /gsr:discover      /gsr:bootstrap    /gsr:plan           (planned)      (planned)
       |                  |             /gsr:plan-story
       v                  v             /gsr:plan-phases
  discovery.md       CLAUDE.md              |
                     SPEC.md                v
                     architecture.md   ROADMAP.md
                                       EPIC.md
                                       STORY.md
                                       PLAN.md + CONTEXT.md
```

### Principes d'architecture

1. **Commands = orchestrateurs legers** (~5-15% contexte). Parsent les args, valident les prerequis, spawnent les agents, gerent l'interaction utilisateur.
2. **Agents = travailleurs specialises** avec contexte frais de 200k tokens. Chaque agent recoit un prompt cible, fait son travail, retourne un resultat structure.
3. **References = connaissances chargees a la demande** par les agents. Pas de skill intermediaire.
4. **Pas de skill-orchestrateur.** Le declenchement est toujours explicite (slash command), jamais par detection automatique.
5. **Planification progressive (JIT).** On ne planifie pas tout d'un coup — chaque niveau se declenche au moment opportun.

### Phases

| Phase | Statut | Commands | Agents | References |
|-------|--------|----------|--------|------------|
| Discovery | Done | 5 | 3 | 3 |
| Plan | Done | 5 | 3 (+1 partage) | 2 |
| Execute | Planned | — | — | — |
| Ship | Planned | — | — | — |

---

## 2. Structure des fichiers

```
.claude/
├── commands/gsr/                    # Slash commands (10 total)
│   ├── discover.md                  # Interface conversationnelle discovery
│   ├── discover-resume.md           # Reprendre session interrompue
│   ├── discover-save.md             # Sauvegarder discovery partiel
│   ├── discover-abort.md            # Annuler session discovery
│   ├── bootstrap.md                 # Thin dispatcher → gsr-bootstrapper
│   ├── plan.md                      # Niveau 1 : ROADMAP (Epics + Stories)
│   ├── plan-story.md                # Niveau 2 : Detail story
│   ├── plan-phases.md               # Niveau 3 : Phases atomiques
│   ├── plan-status.md               # Vue progression planification
│   └── plan-abort.md                # Annuler session planification
│
├── agents/                          # Agents specialises (6 total)
│   ├── research-prompt-agent.md     # Prompts de recherche (discovery + plan)
│   ├── gsr-synthesizer.md           # Phase 6 discovery : synthese + validation
│   ├── gsr-bootstrapper.md          # Bootstrap : CLAUDE.md, SPEC.md, etc.
│   ├── gsr-analyst.md               # Plan : analyse docs bootstrap
│   ├── gsr-planner.md               # Plan : decomposition multi-mode
│   └── gsr-generator.md             # Plan : generation fichiers multi-mode
│
└── gsr/                             # References partagees (5 total)
    ├── discovery-phases.md          # 6 phases interview (sections XML)
    ├── discovery-output.md          # Templates discovery.md, session, SPEC, etc.
    ├── discovery-research.md        # Research Gates discovery
    ├── plan-output.md               # Templates ROADMAP, EPIC, STORY, PLAN, CONTEXT
    └── plan-research.md             # Research Gates planification
```

---

## 3. Phase Discovery

### 3.1 Objectif

Cadrer un projet avant d'ecrire du code via une interview structuree en 6 phases. Produit un `discovery.md` exploitable pour le developpement.

### 3.2 Flow

```
/gsr:discover "description"
│
├─ Phases 1-5 : COMMAND gere la boucle conversationnelle
│   │
│   ├─ Phase 1 — Probleme
│   │   Ref: <phase-1-problem> dans discovery-phases.md
│   │   Objectif: quoi, pour qui, situation actuelle, motivation
│   │   Criteres: probleme en 1 phrase ("X ne peut pas Y a cause de Z"),
│   │             cible nommable, douleur observable, motivation claire
│   │
│   ├─ Phase 2 — Contraintes
│   │   Ref: <phase-2-constraints>
│   │   Objectif: identifier fixe vs ouvert
│   │   Research Gate: CONSTRAINT_VALIDATION si affirmation douteuse
│   │   Suivi: Checkpoint mi-parcours (recapitulatif conditionnel)
│   │
│   ├─ Phase 3 — Stack
│   │   Ref: <phase-3-stack>
│   │   Objectif: proposer choix technologiques bases sur contraintes
│   │   Research Gate: STACK_COMPARISON si >= 2 options viables
│   │
│   ├─ Phase 4 — Architecture
│   │   Ref: <phase-4-architecture>
│   │   Objectif: pattern architectural + schema ASCII obligatoire
│   │
│   └─ Phase 5 — Scope
│       Ref: <phase-5-scope>
│       Objectif: MVP, exclusions, risques
│       Research Gate: RISK_DISCOVERY si aucun risque malgre complexite
│
├─ Phase 6 : AGENT gsr-synthesizer (contexte frais)
│   └─ Lit session complete → valide completude + coherence
│   └─ Genere discovery.md final (7 sections)
│   └─ Signale incoherences (ne les resout pas)
│
└─ Command presente le resultat → utilisateur valide
```

### 3.3 Regles de conversation

| Regle | Description |
|-------|-------------|
| UNE question a la fois | Jamais de questions multiples |
| Attendre la reponse | Ne pas enchainer sans input |
| Reformuler pour confirmer | "Si je comprends bien, tu veux [X]. Correct ?" |
| Proposer, ne pas imposer | "Je suggere [X]. Qu'en penses-tu ?" |
| Acquittement minimal | Si reco ignoree → "Compris, on continue." |

### 3.4 Garde-fous

| Limite | Valeur | Comportement |
|--------|--------|-------------|
| Questions par phase | 5 max | "On tourne en rond. Passons." |
| Retours par phase | 3 max | "3eme retour. Je resume et on avance." |
| Cycles validation | 3 max | "Validation bloquee. Generation avec warnings." |
| Total interview | ~30 echanges | Proposition de sauvegarde |
| Duree | < 45 min | "On approche des 45 min." |
| Recherches | 3 deep + 5 quick | "Continuons avec ce qu'on a." |

### 3.5 Challenges proactifs

| Signal | Challenge |
|--------|-----------|
| Over-engineering | "C'est peut-etre overkill pour le MVP." |
| Techno hype | "Tu mentionnes [X] qui est recent. Tu l'as deja utilise ?" |
| Scope creep | "Ca fait N features MVP. Laquelle est indispensable ?" |
| Contrainte floue | "Tu dis 'performant'. C'est quoi le seuil ?" |
| Risque nie | "Vraiment aucun risque ? Meme [suggestion] ?" |

### 3.6 Research Gates (Discovery)

4 types de declencheurs :

| Type | Quand | Phase |
|------|-------|-------|
| CONSTRAINT_VALIDATION | Contrainte irrealiste ou affirmation douteuse | 2 |
| STACK_COMPARISON | >= 2 options viables, contradiction, hesitation | 3 |
| RISK_DISCOVERY | Aucun risque malgre complexite | 5c |
| UNKNOWN_RESOLUTION | "Je ne sais pas" sur point bloquant | Toute |

**Comportement :** 3 options proposees a l'utilisateur :
- [A] Recherche rapide (~30s) → web search
- [B] Deep Research (~15-30min) → prompt pour Claude Desktop
- [C] Continuer sans recherche

### 3.7 Output : discovery.md (7 sections)

```
## §1 Probleme         → Statement, cible, situation, motivation
## §2 Contraintes      → Fixees, ouvertes, timeline
## §3 Stack            → Composant, techno, version, contrainte liee
## §4 Architecture     → Pattern, composants, schema ASCII, flux
## §5 Scope MVP        → Features MVP (priorite+complexite), nice-to-have
## §6 Hors Scope       → Exclusions explicites
## §7 Risques          → Risque, probabilite, impact, mitigation
```

### 3.8 Session management

Fichier : `.claude/discovery-session.md` (auto-genere)

Contient : phase courante, donnees capturees, questions ouvertes, research log, checklist completude, timestamps. Persiste entre les `/clear` et les interruptions. Permet `/gsr:discover-resume`.

---

## 4. Phase Bootstrap

### 4.1 Objectif

Generer la structure projet a partir du `discovery.md` valide.

### 4.2 Flow

```
/gsr:bootstrap [discovery.md] [--dry-run] [--no-adr] [--minimal]
│
├─ Command : parse args, verifie discovery.md
│
└─ Spawn gsr-bootstrapper (agent)
    ├─ Parse discovery.md → extraction structuree
    ├─ Genere CLAUDE.md (< 60 lignes)
    ├─ Genere SPEC.md (lean, 1-2 pages)
    ├─ Copie docs/discovery.md
    ├─ Genere docs/agent_docs/architecture.md
    ├─ [conditionnel] docs/agent_docs/database.md (si BDD dans stack)
    ├─ [conditionnel] docs/adr/0001-initial-stack.md (si stack non-standard)
    ├─ Cree structure dossiers (src/, tests/)
    └─ Met a jour .claude/settings.json (permissions)
```

### 4.3 Fichiers generes

| Fichier | Condition | Source |
|---------|-----------|--------|
| `CLAUDE.md` | Toujours | §1+§3+§4 — < 60 lignes |
| `SPEC.md` | Toujours | §1+§2+§3+§5+§6 — lean |
| `docs/discovery.md` | Toujours | Copie de reference |
| `docs/agent_docs/architecture.md` | Toujours | §4 |
| `docs/agent_docs/database.md` | Si BDD dans §3 | §3+§4+§5 |
| `docs/adr/0001-initial-stack.md` | Si stack non-standard | §2+§3 |

---

## 5. Phase Plan (Progressive / JIT)

### 5.1 Concept cle

La planification est **progressive** — on ne planifie pas tout d'un coup :

```
Temps ──────────────────────────────────────────────────────►

/gsr:plan                  /gsr:plan-story E1/S1     /gsr:plan-phases E1/S1
│                          │                          │
▼                          ▼                          ▼
┌─────────────────┐       ┌──────────────────┐       ┌──────────────────────┐
│ ROADMAP.md      │       │ STORY.md detaille │       │ phases/01-.../PLAN.md│
│ ─ Epics listes  │       │ ─ Acceptance crit │       │ phases/01-.../CTX.md │
│ ─ Stories listes│       │ ─ Composants      │       │ phases/02-.../PLAN.md│
│ ─ Dependances   │       │ ─ Risques story   │       │ ...                  │
│ ─ Ordonnancement│       │ ─ Estimations     │       │                      │
└─────────────────┘       └──────────────────┘       └──────────────────────┘

     Planifie en amont         Quand on attaque          Juste avant
     (vue d'ensemble)          l'epic concerne            d'executer
```

**Pourquoi :**
- Le plan detaille vieillit mal
- Planifier des phases qu'on executera dans 3 semaines = gaspillage
- La review humaine est plus efficace sur un scope reduit
- On integre les apprentissages des phases precedentes

### 5.2 Hierarchie Epic → Story → Phase

| Niveau | Definition | Planifie quand | Command |
|--------|-----------|----------------|---------|
| **Epic** | Groupement fonctionnel ≈ 1 feature MVP | Upfront | `/gsr:plan` |
| **Story** | User story avec acceptance criteria (Given-When-Then) | Quand on attaque l'epic | `/gsr:plan-story` |
| **Phase** | Unite atomique, reviewable, increment fonctionnel | Juste avant execution | `/gsr:plan-phases` |

### 5.3 Niveaux de granularite (appliques aux phases)

| Niveau | Taille phase | Cas d'usage |
|--------|-------------|-------------|
| `fine` | 1-2h Claude | Controle maximal, projet critique |
| `standard` | 2-4h Claude | Bon equilibre atomicite/productivite |
| `flexible` | Variable | Adapte a la complexite (defaut) |

### 5.4 Flow Niveau 1 — /gsr:plan

```
/gsr:plan [SPEC.md] [--granularity=flexible]
│
├─ Spawn gsr-analyst
│   └─ Lit SPEC.md + architecture.md + discovery.md + CLAUDE.md
│   └─ Produit plan-session.md §Analyse
│
├─ Spawn gsr-planner (mode=roadmap)
│   └─ Features MVP → Epics → Stories (SANS phases)
│   └─ Ordonnancement + dependances + parallelisme
│   └─ Research Gates si necessaire
│
├─ Review interactive (command, pas agent)
│   └─ Presente chaque epic pour validation
│   └─ L'utilisateur ajuste (reordonne, fusionne, decoupe)
│
├─ Spawn gsr-generator (mode=roadmap)
│   └─ Genere ROADMAP.md + EPIC.md par epic + dossiers stories
│
└─ Resume : "N epics, N stories. → /gsr:plan-story ..."
```

### 5.5 Flow Niveau 2 — /gsr:plan-story

```
/gsr:plan-story [epic-slug/story-slug]
│
├─ Spawn gsr-planner (mode=story)
│   └─ Lit EPIC.md + session + etat actuel du projet
│   └─ Detaille : acceptance criteria, composants, risques, estimation
│   └─ Research Gates si decision technique bloquante
│
├─ Review interactive
│   └─ Utilisateur valide ou ajuste les acceptance criteria
│
├─ Spawn gsr-generator (mode=story)
│   └─ Genere STORY.md
│
└─ "Story detaillee. → /gsr:plan-phases ..."
```

### 5.6 Flow Niveau 3 — /gsr:plan-phases

```
/gsr:plan-phases [epic-slug/story-slug] [--granularity=flexible]
│
├─ Spawn gsr-planner (mode=phases)
│   └─ Lit STORY.md + etat actuel du projet
│   └─ Decoupe en phases atomiques selon granularite
│   └─ Research Gates : IMPLEMENTATION_PATTERN, LIBRARY_CHOICE
│
├─ Review interactive
│   └─ Chaque phase : [OK] [Ajuster] [Fusionner] [Decouper]
│
├─ Spawn gsr-generator (mode=phases)
│   └─ Genere PLAN.md + CONTEXT.md par phase
│
└─ "N phases generees. → /gsr:execute ..."
```

### 5.7 Artefacts generes

```
docs/plan/
├── ROADMAP.md                              # Niveau 1
└── epics/
    ├── 01-[epic-slug]/
    │   ├── EPIC.md                         # Resume epic
    │   └── stories/
    │       ├── 01-[story-slug]/
    │       │   ├── STORY.md                # Niveau 2
    │       │   └── phases/                 # Niveau 3
    │       │       ├── 01-[phase-slug]/
    │       │       │   ├── PLAN.md         # Plan executable (XML tasks)
    │       │       │   └── CONTEXT.md      # Contexte cible
    │       │       └── 02-[phase-slug]/
    │       └── 02-[story-slug]/
    └── 02-[epic-slug]/
```

L'arborescence se construit progressivement — seuls les niveaux planifies existent.

### 5.8 Format PLAN.md (par phase)

```xml
<phase id="[NN]" name="[slug]" epic="[epic]" story="[story]" depends="[ids]">
  <estimate>[Nh]</estimate>
  <objective>[1 phrase]</objective>

  <task type="[setup|tdd|integration|config]">
    <n>[Nom]</n>
    <files>[fichiers]</files>
    <criteria>
      Given [contexte], when [action], then [resultat]
    </criteria>
    <verify>[commande de verification]</verify>
  </task>

  <review>
    <checklist>
      - [ ] Critere 1
      - [ ] Critere 2
      - [ ] Tests passent
    </checklist>
  </review>
</phase>
```

### 5.9 Format CONTEXT.md (par phase)

Contient uniquement le contexte pertinent pour cette phase :
- Objectif (1-2 phrases)
- Stack pertinente (extrait cible CLAUDE.md)
- Architecture pertinente (composants concernes uniquement)
- Contraintes applicables
- Dependances (output des phases precedentes)
- Fichiers cles (a lire/creer/modifier)

### 5.10 Research Gates (Plan)

| Type | Quand | Niveaux |
|------|-------|---------|
| IMPLEMENTATION_PATTERN | Feature implementable de plusieurs facons | 2-3 |
| LIBRARY_CHOICE | Lib necessaire non definie dans la stack | 2-3 |
| INTEGRATION_RISK | Interface entre composants pas claire | 3 |
| UNKNOWN_RESOLUTION | "Je ne sais pas" sur point structurant | Tous |

### 5.11 Garde-fous (Plan)

| Limite | Valeur | Comportement |
|--------|--------|-------------|
| Stories par epic | 6 max | "Epic trop gros. Decouper en 2 ?" |
| Phases par story | 8 max | "Story trop grosse. Decouper ?" |
| Total epics | 10 max | "Projet tres ambitieux pour solo dev." |
| Cycles review / niveau | 3 max | "On valide et ajuste plus tard." |
| Recherches / session | 3 deep + 5 quick | "Continuons avec ce qu'on a." |
| Duree par niveau | < 30 min | "On approche de 30 min." |

---

## 6. Agents — Reference

### 6.1 research-prompt-agent

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Grep, Glob, Write |
| Interactive | Non |

**Role :** Genere des prompts de recherche optimises (Deep Research ou web search queries). Supporte 2 modes : discovery et planification. Detecte le mode via le fichier session passe en input.

**Input :** chemin session + bloc `<research_trigger>` (type, mode, contexte, question)
**Output :** `.claude/research-prompt.md` avec prompt XML (deep) et/ou queries (quick)

**Types discovery :** STACK_COMPARISON, RISK_DISCOVERY, UNKNOWN_RESOLUTION, CONSTRAINT_VALIDATION
**Types plan :** IMPLEMENTATION_PATTERN, LIBRARY_CHOICE, INTEGRATION_RISK, UNKNOWN_RESOLUTION

### 6.2 gsr-synthesizer

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Write, Grep |
| Interactive | Non |

**Role :** Agregation phase 6 discovery. Lit la session complete, compile les 7 sections, valide completude + coherence, genere discovery.md. Signale les problemes sans les resoudre.

**Input :** `.claude/discovery-session.md`
**Output :** `discovery.md` + resume structure (completude, coherence, auto-critique)

### 6.3 gsr-bootstrapper

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Write, Bash, Glob |
| Interactive | Non |

**Role :** Genere la structure projet depuis discovery.md. CLAUDE.md, SPEC.md, architecture.md, database.md (conditionnel), ADR (conditionnel).

**Input :** `discovery.md` + flags
**Output :** fichiers projet + resume

### 6.4 gsr-analyst

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Glob, Grep, Write |
| Interactive | Non |

**Role :** Analyse les docs bootstrap (SPEC.md, architecture.md, discovery.md, CLAUDE.md, database.md, ADR) et produit une extraction structuree dans plan-session.md. Detecte les incoherences.

**Input :** chemins docs bootstrap + granularite
**Output :** `plan-session.md` §Analyse

### 6.5 gsr-planner

| Champ | Valeur |
|-------|--------|
| Model | opus |
| Tools | Read, Write, Grep, Glob, WebSearch, WebFetch |
| Interactive | Non |

**Role :** Decomposition et ordonnancement adaptatif en 3 modes.

| Mode | Input | Output |
|------|-------|--------|
| `roadmap` | plan-session §Analyse | Epics + Stories + dependances + ordre |
| `story` | EPIC.md + session + etat projet | STORY.md detaille |
| `phases` | STORY.md + etat projet + granularite | Phases atomiques avec tasks |

**Adaptativite :** en modes story/phases, lit l'etat actuel du projet (code deja ecrit) pour s'adapter aux changements.

### 6.6 gsr-generator

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Write, Bash |
| Interactive | Non |

**Role :** Generation fichiers de sortie en 3 modes.

| Mode | Genere |
|------|--------|
| `roadmap` | ROADMAP.md + EPIC.md par epic + dossiers stories vides |
| `story` | STORY.md dans le dossier de la story |
| `phases` | PLAN.md + CONTEXT.md par phase |

Met a jour en cascade : chaque generation met a jour les fichiers parents (STORY → EPIC → ROADMAP).

---

## 7. References — Index des sections XML

### 7.1 discovery-phases.md

| Section XML | Contenu |
|-------------|---------|
| `<phase-1-problem>` | Questions types, criteres de sortie, comportement |
| `<phase-2-constraints>` | Questions, template de capture, research gate |
| `<checkpoint>` | Recap mi-parcours conditionnel (apres phase 2) |
| `<phase-3-stack>` | Proposition basee sur contraintes, research gate |
| `<phase-4-architecture>` | Schema ASCII obligatoire, composants |
| `<phase-5-scope>` | MVP, exclusions, risques, research gate |
| `<phase-6-synthesis>` | Validation completude + coherence + auto-critique |

### 7.2 discovery-output.md

| Section XML | Contenu |
|-------------|---------|
| `<discovery-template>` | Template discovery.md (7 sections) |
| `<session-template>` | Template discovery-session.md |
| `<spec-template>` | Template SPEC.md lean |
| `<claude-md-template>` | Template CLAUDE.md (< 60 lignes) |
| `<database-template>` | Template database.md (conditionnel) |
| `<adr-template>` | Template ADR-0001 (conditionnel) |
| `<bootstrap-logic>` | Etapes d'execution du bootstrap |

### 7.3 discovery-research.md

| Section XML | Contenu |
|-------------|---------|
| `<trigger-types>` | STACK_COMPARISON, RISK_DISCOVERY, CONSTRAINT_VALIDATION, UNKNOWN_RESOLUTION — quand, content, output, queries |
| `<integration-flow>` | Comment invoquer research-prompt-agent et integrer les resultats |

### 7.4 plan-output.md

| Section XML | Contenu |
|-------------|---------|
| `<roadmap-template>` | Template ROADMAP.md |
| `<epic-template>` | Template EPIC.md |
| `<story-template>` | Template STORY.md (Given-When-Then) |
| `<plan-template>` | Template PLAN.md (XML tasks) |
| `<context-template>` | Template CONTEXT.md (extraits cibles) |
| `<session-template>` | Template plan-session.md |

### 7.5 plan-research.md

| Section XML | Contenu |
|-------------|---------|
| `<trigger-types>` | IMPLEMENTATION_PATTERN, LIBRARY_CHOICE, INTEGRATION_RISK, UNKNOWN_RESOLUTION |
| `<integration-flow>` | Meme mecanisme que discovery adapte au planning |

---

## 8. Session management

Deux fichiers session independants :

| Session | Phase | Contenu cle |
|---------|-------|-------------|
| `.claude/discovery-session.md` | Discovery | Phase courante, donnees capturees (§1-§7), questions ouvertes, research log, checklist completude, timestamps |
| `.claude/plan-session.md` | Plan | Niveau courant (1/2/3), analyse bootstrap, roadmap, story en cours, phases en cours, research log, historique |

Les sessions persistent entre les `/clear` et les interruptions. Elles permettent le resume via les commandes dediees.

---

## 9. Installation

```bash
# Tout installer
curl -fsSL https://raw.githubusercontent.com/sebc-dev/gsr/main/install.sh | bash

# Phase specifique
GSR_PHASES=discovery curl -fsSL ... | bash
GSR_PHASES=plan curl -fsSL ... | bash

# Options
GSR_TARGET=/path/to/project   # Repertoire cible
GSR_FORCE=1                    # Ecraser les fichiers existants
GSR_DRY_RUN=1                  # Afficher sans installer
GSR_LIST=1                     # Lister les phases disponibles
GSR_BRANCH=dev                 # Branche git (defaut: main)
```

Le script telecharge les fichiers depuis GitHub et les installe dans `.claude/` du projet cible.

---

## 10. Prochaines etapes (Execute + Ship)

### Phase Execute (a concevoir)

D'apres `docs/workflow.md`, la phase d'execution devrait couvrir :

- **TDD par phase** : RED → GREEN → REFACTOR pour chaque task du PLAN.md
- **Commits atomiques** : 1 task = 1 commit (conventional commits)
- **Quality gates** : coverage, lint, format, vuln check
- **Gestion contexte** : `/clear` + rechargement CONTEXT.md si saturation
- **Branches par phase** : `phase/NN-slug` depuis develop
- **Execution parallele** : worktrees pour phases independantes
- **Review humaine** : entre chaque phase (VERIFICATION.md + SUMMARY.md + diff resume)

### Phase Ship (a concevoir)

- Merge develop → main
- Tag de version
- Deploiement (selon stack)
- Smoke tests post-deploy
- Archivage phases

### Points d'attention pour la conception

1. **Execute est le plus complexe** — il touche au code reel, pas juste aux documents
2. **L'interaction agent ↔ code** necessite des hooks (pre-commit, post-tool-use)
3. **La parallelisation via worktrees** est un pattern avance a valider
4. **Les quality gates** dependent de la stack (generes a l'init)
5. **Le contexte frais par phase** (CONTEXT.md) est le pont entre Plan et Execute

---

## 11. Decisions d'architecture documentees

| Decision | Raison | Alternative rejetee |
|----------|--------|---------------------|
| Command + Agents + References (pas de skill) | Declenchement 100% explicite, contexte frais par agent, 0 tokens inactif | Skill-orchestrateur (50-80% detection, contexte accumule) |
| Planification progressive JIT | Plan detaille vieillit mal, review plus efficace sur scope reduit | Planification upfront complete |
| Command gere la boucle conversationnelle discovery | Sub-agents ne peuvent pas dialoguer en multi-turn avec l'utilisateur | Agent interviewer re-spawne par phase |
| Agent synthesizer pour phase 6 uniquement | Phases 1-5 sont des interactions legeres, seule la synthese justifie un contexte frais | Tout dans la command (trop lourd) |
| References dans .claude/gsr/ | Centralisees, partagees entre phases, coherent | Dossier par phase (dispersion) |
| gsr-planner en model opus | Decomposition = travail cognitif lourd, meilleur resultat avec opus | Sonnet (suffisant pour generation, pas pour decomposition) |
| 3 niveaux de granularite au choix | Flexibilite maximale pour l'utilisateur | Granularite fixe (trop rigide) |
