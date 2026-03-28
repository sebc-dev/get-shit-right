# Execute — Deviation Rules

Reference chargee par gsr-executor pour gerer les deviations en cours d'execution.

---

<deviation-rules>
## Regles de deviation

L'executor suit le PLAN.md mais peut devier dans ces cas precis :

### Regle 1 — Bug bloquant
**Trigger :** Un test echoue a cause d'un bug dans le code existant (pas dans le code en cours d'ecriture).
**Action :** Corriger le bug, ajouter un test de regression, committer separement avec prefix `fix:`.
**Autonomie :** full-auto.

### Regle 2 — Dependance critique manquante
**Trigger :** Un import, package, ou config indispensable manque et bloque la task.
**Action :** Installer/configurer le minimum necessaire, committer separement avec prefix `chore:`.
**Autonomie :** full-auto.

### Regle 3 — Erreur bloquante repetee
**Trigger :** Meme erreur apres N retries (N = `workflow.execute.max_retries_before_debug` dans config).
**Action :** Escalader vers gsr-debugger. Fournir : erreur, contexte, tentatives precedentes.
**Autonomie :** full-auto (escalade automatique).

### Regle 4 — Changement architectural
**Trigger :** La task necessite une modification qui impacte l'architecture (nouveau pattern, changement d'interface publique, modification de schema DB).
**Action :** STOP. Documenter la deviation proposee et demander confirmation a l'utilisateur.
**Autonomie :** supervisee — checkpoint humain obligatoire.
</deviation-rules>

<deviation-format>
## Format de documentation des deviations

Chaque deviation est documentee dans le SUMMARY.md de la phase :

```markdown
### Deviation [N]
- **Regle :** [1-4]
- **Trigger :** [description courte]
- **Action :** [ce qui a ete fait]
- **Commit :** [hash] (si applicable)
- **Impact :** [fichiers touches hors plan]
```
</deviation-format>

<escalade-debugger>
## Protocole d'escalade vers gsr-debugger

Quand la regle 3 est declenchee :

1. **Capturer le contexte d'echec :**
   - Erreur exacte (message + stack trace)
   - Commande qui echoue
   - Fichiers impliques
   - Les N tentatives precedentes (ce qui a ete essaye)

2. **Spawn gsr-debugger** avec ce contexte (agent frais, pas de contexte pollue).

3. **Attendre le diagnostic :**
   - Si le debugger identifie un fix → l'appliquer et continuer
   - Si le debugger identifie un blocage architectural → regle 4 (checkpoint humain)
   - Si le debugger ne trouve pas de solution → STOP, documenter et passer a la task suivante

4. **Documenter** dans SUMMARY.md (deviation + diagnostic debugger).
</escalade-debugger>
