# Execute — Session File

Reference pour le format du fichier de session d'execution (reprise apres interruption).

---

<session-template>
## Template execute-session.md

Le fichier de session est cree au debut de l'execution et mis a jour incrementalement.
Il permet la reprise en cas d'interruption (crash, timeout, `/clear`).

```markdown
# Execute Session

## Metadata
- **Story :** [epic-slug]/[story-slug]
- **Phase :** [phase-slug] (si execute-phase) | all (si execute)
- **Started :** [ISO timestamp]
- **Updated :** [ISO timestamp]
- **Status :** in-progress | completed | failed | interrupted
- **Ref commit :** [hash du commit avant execution]
- **Branch :** [nom de la branche si branching active]

## Config snapshot
- **Profile :** [quality|balanced|budget]
- **Quality gates :** [run_after] — lint:[on/off] format:[on/off] tests:[on/off] coverage:[seuil]
- **Review :** [enabled] — criteria:[liste] — checkpoint_on:[critical|warning|none]
- **Branching :** [none|phase|milestone]

## Progress

### Phase [NN]: [slug]
- **Status :** pending | in-progress | completed | failed
- **Plans :**
  | Plan | Status | Commits | Notes |
  |------|--------|---------|-------|
  | [NN-MM] | completed | [hashes] | — |
  | [NN-MM+1] | in-progress | [hashes] | Task 3/5 |
  | [NN-MM+2] | pending | — | — |
- **Review :** pending | completed ([N] findings)
- **Verification :** pending | completed

### Phase [NN+1]: [slug]
[Repeter pour chaque phase si execute story]

## Recovery

En cas de reprise :
1. Lire ce fichier pour determiner ou on en est
2. Identifier la derniere task completee (via commits + ce fichier)
3. Reprendre a la task suivante
4. Les commits sont la source de verite — si un commit existe mais le session file dit "pending", faire confiance au commit
```
</session-template>

<session-rules>
## Regles de gestion de la session

### Creation
- Cree au debut de `/gsr:execute` ou `/gsr:execute-phase`
- Ecrit dans `.claude/execute-session.md`
- Contient un snapshot de la config active

### Mise a jour
- Apres chaque task completee → mettre a jour le plan correspondant
- Apres chaque plan complete → mettre a jour le statut du plan
- Apres review → mettre a jour le statut review
- Apres verification → mettre a jour le statut verification
- Timestamp `Updated` rafraichi a chaque ecriture

### Reprise
- Si `.claude/execute-session.md` existe quand on lance execute :
  1. Detecter le statut : `in-progress` ou `interrupted`
  2. Proposer : [Reprendre] ou [Recommencer]
  3. Si reprendre → lire le fichier, identifier le point de reprise
  4. Si recommencer → archiver l'ancien fichier, creer un nouveau

### Nettoyage
- A la fin d'une execution reussie → laisser le fichier avec status `completed`
- Le fichier est ecrase a la prochaine execution de la meme story
</session-rules>
