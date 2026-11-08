# Garde-fou des agents, version réécrite (TAB-32)

Proposition de remplacement de `.claude/hooks/garde_fou_agents.py`, qui corrige
les constats du rapport TAB-9 (contournements et faux positifs). Un agent n'a
pas le droit de modifier le hook en place : c'est au propriétaire de
l'appliquer.

## Appliquer (propriétaire, depuis un terminal hors agent)

```
cp scripts/garde_fou_proposition/garde_fou_agents.py .claude/hooks/garde_fou_agents.py
git add .claude/hooks/garde_fou_agents.py
git commit -m "Garde-fou des agents : analyse réelle de la commande (TAB-32)"
```

Rien d'autre à changer : même interface que l'ancien hook.

- stdin : JSON PreToolUse (`tool_name`, `tool_input`, `cwd`) ; `.claude/settings.json`
  appelle déjà le hook pour tous les outils (`matcher: "*"`), donc pas de réglage à toucher ;
- sortie 2 = outil refusé, message sur stderr (renvoyé à l'agent) ; sortie 0 = permis ;
- actif seulement si `PAPERCLIP_*` ou `TABL_AGENT_AUTOMATIQUE=1` est présent ;
- mêmes identifiants : `supabase`, `testflight`, `scripts_prod`, `api_supabase`,
  `secrets`, `push_main` ; réglages dans `~/.config/tabl/garde_fous.json`, relus à
  chaque appel ; fichier absent ou illisible = tous actifs. L'app « Garde-fous Tabl »
  n'a pas à changer ;
- Python 3.9+ (testé avec le Python du système), aucune dépendance.

Pour revenir en arrière : `git revert` du commit.

## Lancer les tests

```
python3 scripts/garde_fou_proposition/test_garde_fou.py
```

`cas.json` contient plus de 600 cas (outil, entrée, verdict attendu, section du
rapport) : un cas par contournement et par faux positif de TAB-9, plus les gestes
légitimes qui doivent passer (git, flutter, Paperclip API, lecture du hook…), puis un
cas par contournement relevé à la revue de sécurité de TAB-32 (sections « revue
sécurité TAB-32 §1 … §12 »). Les
chaînes réservées sont dans le JSON et non dans le `.py`, pour ne pas faire refuser
le fichier de test à l'ancien hook. `test_garde_fou.py` ajoute les tests de
l'interface (`main()` : sortie, message, entrée illisible), des réglages (décoché,
absent, invalide) et de l'analyse (profondeur, script relu au lancement, lien
symbolique, vrai dépôt git sur `main`).

Attention : une fois la nouvelle version en place, un agent ne pourra plus lancer
ces tests, car le fichier de test cite le garde-fou (`.claude/hooks`, `garde_fou_agents`)
et le garde-fou refuse tout code qui y fait référence. C'est voulu ; le propriétaire
les lance dans son terminal.

## Ce qui change

1. **La commande est analysée, pas cherchée comme du texte.** Découpage shell réel
   (`; && || | &`, `$( )`, backticks, sous-shells, heredocs, quotes, échappements,
   variables affectées dans la ligne, globs, accolades, `$'…'`). Citer un geste
   réservé (message de commit, `grep`, `echo`, corps JSON d'un commentaire
   Paperclip, heredoc de note) ne déclenche plus rien : faux positifs du rapport TAB-9
   corrigés.
2. **On juge la commande réellement lancée**, après déballage de `env`, `sudo`, `time`,
   `command`, `exec`, `nohup`, `timeout`, `xargs`, `find -exec`, `watch`, `npx`/`bunx`/
   `pnpm dlx`/`npm exec`/`uv run`, `bash -c`, `sh -c`, `eval`, `source`, etc., à n'importe
   quelle profondeur (6 niveaux, au-delà : refus).
3. **En cas de doute, refus.** Variable ou substitution en position de commande,
   `eval "$X"`, `bash` lisant un script sans source connue, `git push origin $X`,
   `curl $URL`, `case…esac`, `make`, `git apply`/`am` (patch illisible), alias
   inconnu… Le message dit pourquoi. Conséquence pour les agents : écrire les
   commandes en clair, et définir `PAPERCLIP_API_BASE` dans la même commande que
   le `curl` qui l'utilise (c'est le cas des commandes Paperclip habituelles).
4. **Les scripts sont lus au lancement** (`bash f.sh`, `python3 f.py`, `./f.sh`,
   `source f.sh`) : un script écrit puis exécuté est vérifié sur son contenu, y
   compris quand il est écrit dans la même ligne par heredoc ou `echo`.
5. **Chemins normalisés** : `~`, `$HOME`, `..`, `//`, `./`, majuscules/Unicode,
   liens symboliques, chemins relatifs après `cd`, globs (même vers un secret qui
   n'existe pas encore) et accolades. Couvre aussi `Read`, `Grep`, `Glob`, `Edit`,
   `Write`, `MultiEdit`, `NotebookEdit` et `WebFetch`.
6. **Supabase** : seuls `migration new`, `migration list`, `--version`, `--help` passent. Les
   hôtes `*.supabase.co/in/net/io/red`, `*.pooler.supabase.com` et `api.supabase.com` sont
   refusés (WebFetch, curl, wget, psql, code) ; la doc `supabase.com` reste lisible.
7. **Git** : refus d'un push vers `main`, `master` ou `mac-mini` sous toutes ses formes
   (`HEAD:refs/heads/main`, `+refspec`, `:main`, `-C autre_dépôt`, `HEAD` résolu depuis
   la branche courante réelle, `--all`, `--mirror`, `--delete`, push forcé, alias git,
   `git config alias.*`, `-c alias.*`). `gh pr merge`, `gh auth token` et `gh api` en
   écriture (hors commentaires et tickets) sont refusés.
8. **Zones protégées en écriture, réglage décoché ou non** (éditeur, redirection, `sed -i`,
   `cp`/`mv`/`rm`, `tee`, `git apply`, code `python -c`/`node -e`…) : `.claude/hooks`,
   `.claude/settings*.json` et `garde_fous.json` ; `$CLAUDE_CONFIG_DIR/settings*.json` et
   `shell-snapshots/` ; les fichiers de démarrage du shell (`.zshenv`, `.zprofile`, `.zshrc`,
   `.zlogin`, `.bashrc`, `.bash_profile`, `.profile`, pour le HOME réel et celui de
   l'environnement) ; la configuration git (`.git/hooks`, `.git/config`, `config.worktree`,
   `~/.gitconfig`, `~/.config/git`) ; les dossiers du `PATH` (`~/bin`, `~/.local/bin`,
   `/opt/homebrew/bin`, `node_modules/.bin`…) ; les tâches différées (`~/Library/LaunchAgents`,
   fichiers `.pth`, `sitecustomize.py`). Également refusés : modifier `PATH`, `HOME`, `IFS`,
   `FPATH`, les variables d'invite (`PS1`–`PS4`, `PROMPT`, `PROMPT_COMMAND`…), `BASH_ENV`…
   (`export`, `env`, préfixe, `printf -v`, `read`), poser un `trap`, définir un alias, lancer
   une session d'agent imbriquée (`claude -p`, `codex`…), et les lanceurs différés
   (`crontab`, `at`, `launchctl`, `tmux`, `script`, `shortcuts`, `automator`…).
9. **Push sur `main` par la configuration git** : `git config` sur `remote.*.push`, `push.*`,
   `branch.*.merge|remote|pushremote`, `remote.pushdefault` refusé ; `git branch -u`,
   `--set-upstream-to`, `--track` vers `main`/`master`/`mac-mini` refusés ; un push sans
   refspec est jugé sur sa vraie destination (`git rev-parse --symbolic-full-name @{push}`).
10. **Code inline et scripts hors dépôt** (`-c`, `-e`, stdin, heredoc, script qui n'est ni dans
    le dépôt ni dans un dossier système ou de paquets) : tout lancement de processus est
    refusé (`subprocess`, `os.system`, `exec*`, `spawn*`, `popen`, `pty`, `child_process`,
    `Deno.Command`, `Bun.spawn`, accents graves en ruby/perl/php, `Process`/`NSTask`,
    `do shell script`, `system`/`getline`/`|` d'awk), ainsi que les accès dynamiques
    (`getattr`, `ctypes`, `require` non littéral…).
11. **Quel fichier est réellement lancé** : la commande est résolue avec le vrai `PATH` puis
    `realpath` (un lien `sb` vers la CLI Supabase est jugé sous les deux noms) ; un script
    résolu hors des dossiers de confiance est lu ; un exécutable absent au moment du
    contrôle (compilé ou téléchargé dans la même ligne) est refusé, sauf s'il est écrit avec
    un contenu connu ; un binaire hors des dossiers système, de paquets et du `PATH` est
    refusé. `open` d'un exécutable, d'un `.command`/`.app`/`.workflow`/`.terminal`, ou avec
    `--args` est refusé.
12. **Réseau** : `wget -i` / `--input-file` lit le fichier d'adresses (ou refuse s'il est
    illisible ou sur stdin) ; les hôtes cachés dans `-H`, `--header`, `--resolve`,
    `--connect-to`, `-x`, `--proxy` sont refusés comme les URL.

## Limites assumées (à connaître)

Le garde-fou reste un filet contre les accidents et les contournements courants. Il ne
peut pas voir :

- du code compilé ou téléchargé, une chaîne reconstruite à l'exécution (le code lisible
  qui s'en approche — `base64`, `exec`, `__import__`… — est refusé) ;
- les effets d'un `npm install` / `pip install` (scripts d'installation), ou de
  `npx <paquet arbitraire>` ;
- un alias ou une fonction déjà définis dans le shell de l'utilisateur ;
- le shell zsh (celui de l'outil Bash) a des règles propres (`=cmd`, `noglob`, `repeat`,
  `{ … }` sans `;`, options `setopt`…) : les cas connus sont couverts, pas toutes les
  options de zsh ;
- les dossiers inscriptibles du `PATH` : le script protège ceux qu'il connaît (le `PATH`
  réel au lancement, `~/bin`, `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`,
  `node_modules/.bin`), mais un dossier ajouté au `PATH` plus tard par l'utilisateur, ou un
  dossier inscriptible hors de ces emplacements, laisse un faux `git` ou `supabase`
  s'y cacher ;
- `version:` de `pubspec.yaml` modifié par un `sed` ordinaire : reste détecté seulement
  à la relecture de la branche (ça n'ouvre pas de geste de prod à lui seul).

## Constats de TAB-9 qui ne se corrigent pas dans le script

Le propriétaire reste connecté à la CLI Supabase : tant que c'est le cas, le garde-fou est
la seule barrière contre une poussée en prod, et aucun script ne peut offrir de garantie
absolue. À traiter côté propriétaire (voir la sous-tâche « Suite à donner ») :

- **Déconnecter la CLI Supabase** (`supabase logout`, jeton retiré du trousseau) quand
  aucun geste de prod n'est prévu, et se reconnecter pour pousser : c'est la seule
  protection qui ne dépend pas de l'analyse d'une commande.
- **Protection de la branche `main` sur GitHub**, administrateurs compris (pull request
  obligatoire, push direct interdit) : le script ne voit pas ce qui part par un autre
  chemin que Claude Code.
- **Sortir le hook de la portée des agents** : paramètres gérés de Claude Code
  (`managed-settings.json` avec `allowManagedHooksOnly`), et fichiers du hook en lecture
  seule pour l'utilisateur qui lance les agents. Aujourd'hui `.claude/` est modifiable par
  tout processus du même utilisateur.
- **Agents qui ne passent pas par Claude Code** (Codex, Gemini, Paperclip qui réassigne
  une tâche à un autre adaptateur) et **session `claude -p` lancée hors d'un agent**
  (sans variables `PAPERCLIP_*`) : le hook n'est pas déclenché ou ne se sait pas appelé par
  un agent.
