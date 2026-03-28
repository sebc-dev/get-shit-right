# GSR (Get Shit Right) Workflow — Synthese Complete

**Version :** 2026-03-28
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
| Config | Done | 2 (settings, set-profile) | — | 2 (config-defaults, gsr-config.sh) |
| Discovery | Done | 5 | 3 | 3 |
| Plan | Done | 5 | 3 (+1 partage) | 2 |
| Suivi | Done | 1 (status) | — | 1 (status-output) |
| Execute | Planned | — | — | — |
| Ship | Planned | — | — | — |

---

## 2. Structure des fichiers

```
.claude/
├── commands/gsr/                    # Slash commands (15 total)
│   ├── settings.md                  # Configuration interactive
│   ├── set-profile.md               # Switch profil modeles (quality/balanced/budget)
│   ├── discover.md                  # Interface conversationnelle discovery
│   ├── discover-resume.md           # Reprendre session interrompue
│   ├── discover-save.md             # Sauvegarder discovery partiel
│   ├── discover-abort.md            # Annuler session discovery
│   ├── bootstrap.md                 # Thin dispatcher → gsr-bootstrapper
│   ├── plan.md                      # Niveau 1 : ROADMAP (Epics + Stories)
│   ├── plan-story.md                # Niveau 2 : Detail story
│   ├── plan-phases.md               # Niveau 3 : Phases atomiques
│   ├── plan-status.md               # Vue progression planification
│   ├── plan-abort.md                # Annuler session planification
│   ├── status.md                    # Vue avancement global du workflow
│   ├── version.md                   # Version installee
│   └── update.md                    # Mise a jour depuis GitHub
│
├── agents/gsr/                      # Agents specialises (6 total)
│   ├── research-prompt-agent.md     # Prompts de recherche (discovery + plan)
│   ├── gsr-synthesizer.md           # Phase 6 discovery : synthese + validation
│   ├── gsr-bootstrapper.md          # Bootstrap : CLAUDE.md, SPEC.md, etc.
│   ├── gsr-analyst.md               # Plan : analyse docs bootstrap
│   ├── gsr-planner.md               # Plan : decomposition multi-mode
│   └── gsr-generator.md             # Plan : generation fichiers multi-mode
│
└── gsr/                             # References + config (8 total)
    ├── config-defaults.json         # Valeurs par defaut (commite dans le repo)
    ├── config.json                  # Config projet (runtime, non commite)
    ├── bin/gsr-config.sh            # Utilitaire config (ensure, scan, get, set, dump)
    ├── discovery-phases.md          # 6 phases interview (sections XML)
    ├── discovery-output.md          # Templates discovery.md, session, SPEC, etc.
    ├── discovery-research.md        # Research Gates discovery
    ├── plan-output.md               # Templates ROADMAP, EPIC, STORY, PLAN, CONTEXT
    ├── plan-research.md             # Research Gates planification
    └── status-output.md             # Template + logique mise a jour GSR-STATUS.md
```

---

## 3. Systeme de configuration

### 3.1 Objectif

Centraliser les preferences (modeles, garde-fous, workflow, git) dans un fichier `config.json` lu par toutes les commands. Supporte deux modes : `jq` (CLI complet) et `claude` (fallback via Read/Write de Claude Code).

### 3.2 Fichiers

| Fichier | Role | Commite |
|---------|------|---------|
| `.claude/gsr/config-defaults.json` | Valeurs par defaut, reference du schema | Oui |
| `.claude/gsr/config.json` | Config projet (cree au premier run) | Non |
| `.claude/gsr/bin/gsr-config.sh` | Utilitaire bash (8 sous-commandes) | Oui |

### 3.3 Sections de config

```json
{
  "version": "1.0.0",
  "environment": { },      // Resultat du scan (jq, gh/glab, MCP, auth)
  "models": { },            // Profil actif + overrides par agent
  "git": { },               // Provider, branching, conventional commits
  "workflow": { },           // Mode, granularite, limites discovery/plan/research
  "output": { }              // CLAUDE.md max lignes, format spec/plan
}
```

### 3.4 Scan d'environnement

Execute a l'installation (`install.sh`) et a la demande (`/gsr:settings`). Detecte :

| Element | Detection | Stocke dans |
|---------|-----------|-------------|
| `jq` | `command -v jq` | `environment.jq_available`, `environment.config_mode` |
| Git CLI | `command -v gh` / `command -v glab` | `environment.git_cli`, `environment.git_provider` |
| Git CLI auth | `gh auth status` / `glab auth status` | `environment.git_cli_authenticated` |
| Git MCP | Scan `.claude/settings.json` et `~/.claude/settings.json` | `environment.git_mcp`, `environment.git_mcp_authenticated` |

### 3.5 Profils de modeles

3 profils predefinis qui mappent chaque role d'agent a un modele :

| Profil | orchestrator | worker | generator |
|--------|-------------|--------|-----------|
| `quality` | opus | opus | sonnet |
| `balanced` (defaut) | opus | sonnet | sonnet |
| `budget` | sonnet | sonnet | haiku |

Mapping agent → role :

| Agent | Role |
|-------|------|
| gsr-planner | orchestrator |
| gsr-analyst | worker |
| gsr-synthesizer | worker |
| research-prompt-agent | worker |
| gsr-generator | generator |
| gsr-bootstrapper | generator |

`/gsr:set-profile` change le profil et modifie directement le `model:` dans le frontmatter YAML de chaque agent. Les overrides par agent (`models.overrides.<agent>`) sont prioritaires.

### 3.6 Injection dans les commands

Toutes les commands workflow (discover, bootstrap, plan, plan-story, plan-phases) chargent la config en section "0. Charger la configuration" :

1. `gsr-config.sh dump <section>` (mode jq) ou Read config.json (mode claude)
2. Les garde-fous deviennent dynamiques (avec fallback sur les valeurs par defaut)
3. Les agents recoivent un bloc `<config>` dans leur prompt d'invocation

**Principe :** la command lit la config, l'agent ne touche jamais au fichier config.

### 3.7 Utilitaire gsr-config.sh

| Commande | Description |
|----------|-------------|
| `ensure` | Cree config.json depuis defaults si absent |
| `scan` | Scanne l'environnement (jq, git CLI, MCP, auth) |
| `get <key>` | Lit une valeur (requiert jq) |
| `set <key> <value>` | Ecrit une valeur avec validation (requiert jq) |
| `dump <section>` | Dump une section en key=value (1 appel) |
| `resolve-model <agent>` | Modele effectif (profil + overrides) |
| `profile` | Nom du profil actif |
| `config-mode` | `jq` ou `claude` |

### 3.8 Commands de configuration

| Command | Role |
|---------|------|
| `/gsr:settings` | Affiche toute la config groupee par categorie, permet modification en langage naturel |
| `/gsr:set-profile <profil>` | Switch rapide quality/balanced/budget, modifie les frontmatters agents |

---

## 4. Phase Discovery

### 4.1 Objectif

Cadrer un projet avant d'ecrire du code via une interview structuree en 6 phases. Produit un `discovery.md` exploitable pour le developpement.

### 4.2 Flow

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

### 4.3 Regles de conversation

| Regle | Description |
|-------|-------------|
| UNE question a la fois | Jamais de questions multiples |
| Attendre la reponse | Ne pas enchainer sans input |
| Reformuler pour confirmer | "Si je comprends bien, tu veux [X]. Correct ?" |
| Proposer, ne pas imposer | "Je suggere [X]. Qu'en penses-tu ?" |
| Acquittement minimal | Si reco ignoree → "Compris, on continue." |

### 4.4 Garde-fous (configurables via `config.json`)

| Limite | Cle config | Defaut | Comportement |
|--------|-----------|--------|-------------|
| Questions par phase | `workflow.discovery.max_questions_per_phase` | 5 | "On tourne en rond. Passons." |
| Retours par phase | `workflow.discovery.max_returns_per_phase` | 3 | "3eme retour. Je resume et on avance." |
| Cycles validation | `workflow.discovery.max_returns_per_phase` | 3 | "Validation bloquee. Generation avec warnings." |
| Total interview | `workflow.discovery.max_interview_exchanges` | 30 | Proposition de sauvegarde |
| Duree | `workflow.discovery.timeout_minutes` | 45 min | "On approche des N min." |
| Recherches deep | `workflow.research.max_deep` | 3 | "Continuons avec ce qu'on a." |
| Recherches quick | `workflow.research.max_quick` | 5 | "Continuons avec ce qu'on a." |

### 4.5 Challenges proactifs

| Signal | Challenge |
|--------|-----------|
| Over-engineering | "C'est peut-etre overkill pour le MVP." |
| Techno hype | "Tu mentionnes [X] qui est recent. Tu l'as deja utilise ?" |
| Scope creep | "Ca fait N features MVP. Laquelle est indispensable ?" |
| Contrainte floue | "Tu dis 'performant'. C'est quoi le seuil ?" |
| Risque nie | "Vraiment aucun risque ? Meme [suggestion] ?" |

### 4.6 Research Gates (Discovery)

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

### 4.7 Output : discovery.md (7 sections)

```
## §1 Probleme         → Statement, cible, situation, motivation
## §2 Contraintes      → Fixees, ouvertes, timeline
## §3 Stack            → Composant, techno, version, contrainte liee
## §4 Architecture     → Pattern, composants, schema ASCII, flux
## §5 Scope MVP        → Features MVP (priorite+complexite), nice-to-have
## §6 Hors Scope       → Exclusions explicites
## §7 Risques          → Risque, probabilite, impact, mitigation
```

### 4.8 Session management

Fichier : `.claude/discovery-session.md` (auto-genere)

Contient : phase courante, donnees capturees, questions ouvertes, research log, checklist completude, timestamps. Persiste entre les `/clear` et les interruptions. Permet `/gsr:discover-resume`.

---

## 5. Phase Bootstrap

### 5.1 Objectif

Generer la structure projet a partir du `discovery.md` valide.

### 5.2 Flow

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

### 5.3 Fichiers generes

| Fichier | Condition | Source |
|---------|-----------|--------|
| `CLAUDE.md` | Toujours | §1+§3+§4 — < 60 lignes |
| `SPEC.md` | Toujours | §1+§2+§3+§5+§6 — lean |
| `docs/discovery.md` | Toujours | Copie de reference |
| `docs/agent_docs/architecture.md` | Toujours | §4 |
| `docs/agent_docs/database.md` | Si BDD dans §3 | §3+§4+§5 |
| `docs/adr/0001-initial-stack.md` | Si stack non-standard | §2+§3 |

---

## 6. Phase Plan (Progressive / JIT)

### 6.1 Concept cle

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

### 6.2 Hierarchie Epic → Story → Phase

| Niveau | Definition | Planifie quand | Command |
|--------|-----------|----------------|---------|
| **Epic** | Groupement fonctionnel ≈ 1 feature MVP | Upfront | `/gsr:plan` |
| **Story** | User story avec acceptance criteria (Given-When-Then) | Quand on attaque l'epic | `/gsr:plan-story` |
| **Phase** | Unite atomique, reviewable, increment fonctionnel | Juste avant execution | `/gsr:plan-phases` |

### 6.3 Niveaux de granularite (appliques aux phases)

| Niveau | Taille phase | Cas d'usage |
|--------|-------------|-------------|
| `fine` | 1-2h Claude | Controle maximal, projet critique |
| `standard` | 2-4h Claude | Bon equilibre atomicite/productivite |
| `flexible` | Variable | Adapte a la complexite (defaut) |

### 6.4 Flow Niveau 1 — /gsr:plan

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

### 6.5 Flow Niveau 2 — /gsr:plan-story

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

### 6.6 Flow Niveau 3 — /gsr:plan-phases

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

### 6.7 Artefacts generes

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

### 6.8 Format PLAN.md (par phase)

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

### 6.9 Format CONTEXT.md (par phase)

Contient uniquement le contexte pertinent pour cette phase :
- Objectif (1-2 phrases)
- Stack pertinente (extrait cible CLAUDE.md)
- Architecture pertinente (composants concernes uniquement)
- Contraintes applicables
- Dependances (output des phases precedentes)
- Fichiers cles (a lire/creer/modifier)

### 6.10 Research Gates (Plan)

| Type | Quand | Niveaux |
|------|-------|---------|
| IMPLEMENTATION_PATTERN | Feature implementable de plusieurs facons | 2-3 |
| LIBRARY_CHOICE | Lib necessaire non definie dans la stack | 2-3 |
| INTEGRATION_RISK | Interface entre composants pas claire | 3 |
| UNKNOWN_RESOLUTION | "Je ne sais pas" sur point structurant | Tous |

### 6.11 Garde-fous (configurables via `config.json`)

| Limite | Cle config | Defaut | Comportement |
|--------|-----------|--------|-------------|
| Stories par epic | `workflow.plan.max_stories_per_epic` | 6 | "Epic trop gros. Decouper en 2 ?" |
| Phases par story | `workflow.plan.max_phases_per_story` | 8 | "Story trop grosse. Decouper ?" |
| Total epics | `workflow.plan.max_epics` | 10 | "Projet tres ambitieux pour solo dev." |
| Cycles review / niveau | `workflow.plan.max_review_cycles` | 3 | "On valide et ajuste plus tard." |
| Recherches deep | `workflow.research.max_deep` | 3 | "Continuons avec ce qu'on a." |
| Recherches quick | `workflow.research.max_quick` | 5 | "Continuons avec ce qu'on a." |
| Duree par niveau | `workflow.plan.timeout_minutes` | 30 min | "On approche de N min." |

---

## 7. Agents — Reference

**Note :** les modeles des agents sont configurables via `/gsr:set-profile` (voir §3.5). Les valeurs ci-dessous correspondent au profil `balanced` (defaut).

### 7.1 research-prompt-agent

| Champ | Valeur |
|-------|--------|
| Model | sonnet (role: worker) |
| Tools | Read, Grep, Glob, Write |
| Interactive | Non |

**Role :** Genere des prompts de recherche optimises (Deep Research ou web search queries). Supporte 2 modes : discovery et planification. Detecte le mode via le fichier session passe en input.

**Input :** chemin session + bloc `<research_trigger>` (type, mode, contexte, question)
**Output :** `.claude/research-prompt.md` avec prompt XML (deep) et/ou queries (quick)

**Types discovery :** STACK_COMPARISON, RISK_DISCOVERY, UNKNOWN_RESOLUTION, CONSTRAINT_VALIDATION
**Types plan :** IMPLEMENTATION_PATTERN, LIBRARY_CHOICE, INTEGRATION_RISK, UNKNOWN_RESOLUTION

### 7.2 gsr-synthesizer

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Write, Grep |
| Interactive | Non |

**Role :** Agregation phase 6 discovery. Lit la session complete, compile les 7 sections, valide completude + coherence, genere discovery.md. Signale les problemes sans les resoudre.

**Input :** `.claude/discovery-session.md`
**Output :** `discovery.md` + resume structure (completude, coherence, auto-critique)

### 7.3 gsr-bootstrapper

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Write, Bash, Glob |
| Interactive | Non |

**Role :** Genere la structure projet depuis discovery.md. CLAUDE.md, SPEC.md, architecture.md, database.md (conditionnel), ADR (conditionnel).

**Input :** `discovery.md` + flags
**Output :** fichiers projet + resume

### 7.4 gsr-analyst

| Champ | Valeur |
|-------|--------|
| Model | sonnet |
| Tools | Read, Glob, Grep, Write |
| Interactive | Non |

**Role :** Analyse les docs bootstrap (SPEC.md, architecture.md, discovery.md, CLAUDE.md, database.md, ADR) et produit une extraction structuree dans plan-session.md. Detecte les incoherences.

**Input :** chemins docs bootstrap + granularite
**Output :** `plan-session.md` §Analyse

### 7.5 gsr-planner

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

### 7.6 gsr-generator

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

## 8. References — Index des sections XML

### 8.1 discovery-phases.md

| Section XML | Contenu |
|-------------|---------|
| `<phase-1-problem>` | Questions types, criteres de sortie, comportement |
| `<phase-2-constraints>` | Questions, template de capture, research gate |
| `<checkpoint>` | Recap mi-parcours conditionnel (apres phase 2) |
| `<phase-3-stack>` | Proposition basee sur contraintes, research gate |
| `<phase-4-architecture>` | Schema ASCII obligatoire, composants |
| `<phase-5-scope>` | MVP, exclusions, risques, research gate |
| `<phase-6-synthesis>` | Validation completude + coherence + auto-critique |

### 8.2 discovery-output.md

| Section XML | Contenu |
|-------------|---------|
| `<discovery-template>` | Template discovery.md (7 sections) |
| `<session-template>` | Template discovery-session.md |
| `<spec-template>` | Template SPEC.md lean |
| `<claude-md-template>` | Template CLAUDE.md (< 60 lignes) |
| `<database-template>` | Template database.md (conditionnel) |
| `<adr-template>` | Template ADR-0001 (conditionnel) |
| `<bootstrap-logic>` | Etapes d'execution du bootstrap |

### 8.3 discovery-research.md

| Section XML | Contenu |
|-------------|---------|
| `<trigger-types>` | STACK_COMPARISON, RISK_DISCOVERY, CONSTRAINT_VALIDATION, UNKNOWN_RESOLUTION — quand, content, output, queries |
| `<integration-flow>` | Comment invoquer research-prompt-agent et integrer les resultats |

### 8.4 plan-output.md

| Section XML | Contenu |
|-------------|---------|
| `<roadmap-template>` | Template ROADMAP.md |
| `<epic-template>` | Template EPIC.md |
| `<story-template>` | Template STORY.md (Given-When-Then) |
| `<plan-template>` | Template PLAN.md (XML tasks) |
| `<context-template>` | Template CONTEXT.md (extraits cibles) |
| `<session-template>` | Template plan-session.md |

### 8.5 plan-research.md

| Section XML | Contenu |
|-------------|---------|
| `<trigger-types>` | IMPLEMENTATION_PATTERN, LIBRARY_CHOICE, INTEGRATION_RISK, UNKNOWN_RESOLUTION |
| `<integration-flow>` | Meme mecanisme que discovery adapte au planning |

### 8.6 status-output.md

| Section XML | Contenu |
|-------------|---------|
| `<status-template>` | Template complet de `docs/GSR-STATUS.md` (pipeline, discovery, bootstrap, plan, historique) |
| `<statut-icons>` | Icones de statut (`--`, `En cours`, `OK`, `Partiel`, `Annule`, `N/A`) |
| `<update-discovery>` | Logique de mise a jour pour les 4 commandes discovery |
| `<update-bootstrap>` | Logique de mise a jour pour /gsr:bootstrap |
| `<update-plan>` | Logique de mise a jour pour les 4 commandes plan |
| `<update-plan-epic-statut>` | Calcul du statut par epic (Stories OK, En cours, etc.) |
| `<rebuild-logic>` | Regeneration complete depuis l'etat reel du projet |

---

## 9. Suivi d'avancement — GSR-STATUS.md

### 9.1 Objectif

Fichier persistant `docs/GSR-STATUS.md` qui donne a tout moment l'etat d'avancement du workflow. Mis a jour automatiquement par chaque commande GSR.

### 9.2 Contenu

- **Pipeline** : statut de chaque phase (Discovery → Bootstrap → Plan → Execute → Ship)
- **Discovery** : phase courante, sections completees, research gates
- **Bootstrap** : fichiers generes
- **Plan** : progression par niveau, detail par epic/story/phases
- **Historique** : log chronologique des actions (commande + detail)

### 9.3 Commandes qui mettent a jour le fichier

| Commande | Action sur le suivi |
|----------|---------------------|
| `/gsr:discover` | Cree le fichier, progression phase par phase, `OK` a la fin |
| `/gsr:discover-resume` | Reprend la progression |
| `/gsr:discover-save` | Pipeline Discovery → `Partiel` |
| `/gsr:discover-abort` | Pipeline Discovery → `Annule` |
| `/gsr:bootstrap` | Pipeline Bootstrap → `OK`, liste fichiers crees |
| `/gsr:plan` | Pipeline Plan → `En cours`, table epics/stories |
| `/gsr:plan-story` | Incremente stories detaillees |
| `/gsr:plan-phases` | Incremente phases generees, `OK` si tout planifie |
| `/gsr:plan-abort` | Session seule ou tout supprimer |
| `/gsr:status` | Affiche le fichier, ou le regenere avec `--rebuild` |

### 9.4 Regeneration

Si le fichier est absent ou corrompu, `/gsr:status --rebuild` le reconstruit en scannant les fichiers existants du projet (discovery.md, CLAUDE.md, docs/plan/, etc.).

---

## 10. Session management

Deux fichiers session independants :

| Session | Phase | Contenu cle |
|---------|-------|-------------|
| `.claude/discovery-session.md` | Discovery | Phase courante, donnees capturees (§1-§7), questions ouvertes, research log, checklist completude, timestamps |
| `.claude/plan-session.md` | Plan | Niveau courant (1/2/3), analyse bootstrap, roadmap, story en cours, phases en cours, research log, historique |

Les sessions persistent entre les `/clear` et les interruptions. Elles permettent le resume via les commandes dediees.

---

## 11. Installation

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

**Phases disponibles :** `config` (toujours inclus), `discovery`, `plan`

**Post-installation :** le script execute automatiquement un scan d'environnement (`gsr-config.sh ensure && scan`) qui detecte `jq`, `gh`/`glab`, les MCP servers, et stocke les resultats dans `config.json`. Si `jq` est absent, un warning est affiche avec l'option de laisser Claude Code gerer la config via Read/Write.

---

## 12. Prochaines etapes (Execute + Ship)

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

## 13. Decisions d'architecture documentees

| Decision | Raison | Alternative rejetee |
|----------|--------|---------------------|
| Command + Agents + References (pas de skill) | Declenchement 100% explicite, contexte frais par agent, 0 tokens inactif | Skill-orchestrateur (50-80% detection, contexte accumule) |
| Planification progressive JIT | Plan detaille vieillit mal, review plus efficace sur scope reduit | Planification upfront complete |
| Command gere la boucle conversationnelle discovery | Sub-agents ne peuvent pas dialoguer en multi-turn avec l'utilisateur | Agent interviewer re-spawne par phase |
| Agent synthesizer pour phase 6 uniquement | Phases 1-5 sont des interactions legeres, seule la synthese justifie un contexte frais | Tout dans la command (trop lourd) |
| References dans .claude/gsr/ | Centralisees, partagees entre phases, coherent | Dossier par phase (dispersion) |
| gsr-planner en model opus | Decomposition = travail cognitif lourd, meilleur resultat avec opus | Sonnet (suffisant pour generation, pas pour decomposition) |
| 3 niveaux de granularite au choix | Flexibilite maximale pour l'utilisateur | Granularite fixe (trop rigide) |
| Suivi persistant (GSR-STATUS.md) mis a jour par chaque commande | Consultable sans Claude Code, historique des actions, regenerable | Scan a la volee (pas d'historique, necessite Claude Code) |
| Config centralisee (config.json + gsr-config.sh) | Garde-fous et modeles configurables sans modifier les commands/agents | Hardcoded dans chaque fichier (pas d'adaptation utilisateur) |
| Dual mode jq/claude pour config | Zero dependance obligatoire — jq pour CLI, Read/Write pour fallback | jq obligatoire (exclut certains environnements) |
| set-profile modifie les frontmatters agents | Modele resolu de facon deterministe avant invocation, pas pendant | Variable bash passee dynamiquement a l'agent (fragile, non-deterministe) |
| Scan d'environnement a l'install | Detecte git CLI/MCP/auth une seule fois, stocke dans config | Re-detection a chaque command (lent, redondant) |
| Profils de modeles (quality/balanced/budget) | Abstraction simple pour un choix cout/qualite | Configuration modele par modele (complexe pour l'utilisateur) |
