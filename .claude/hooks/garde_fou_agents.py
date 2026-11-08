#!/usr/bin/env python3
"""Garde-fou des agents automatiques (Paperclip, ou tout autre orchestrateur).

Version réécrite (TAB-32, corrige le rapport TAB-9). Même interface que
l'ancien hook : JSON PreToolUse sur stdin, sortie 2 = outil refusé, message
sur stderr, mêmes identifiants de garde-fous, mêmes réglages
(~/.config/tabl/garde_fous.json, relus à chaque appel).

Différences de fond :
- la commande Bash est ANALYSÉE (découpage shell réel : ; && || | & $( ) `…`
  sous-shells, bash -c, eval, heredocs, quotes, échappements, variables
  affectées dans la ligne, globs, accolades), au lieu d'une recherche de
  texte. Une commande qui ne fait que CITER un mot réservé (message de
  commit, grep, corps d'un commentaire, echo) passe ;
- on regarde la commande réellement lancée, après les enveloppes (env, sudo,
  time, command, xargs, npx, bunx, pnpm dlx, bash -c…) ;
- ce qui ne s'analyse pas proprement (variable ou substitution en position
  de commande, eval dynamique, script lu sur stdin sans source connue…) est
  refusé : en cas de doute, on refuse ;
- les chemins sont normalisés (~, $HOME, .., liens symboliques, chemins
  relatifs, cd précédents, globs, accolades) avant d'être comparés ;
- un script lancé (bash fichier, python3 fichier, ./fichier) est lu au moment
  du lancement : un script écrit puis exécuté est vérifié sur son contenu ;
- Read, Grep, Glob, Edit, Write, MultiEdit, NotebookEdit et WebFetch sont
  couverts.

Limite assumée : un agent déterminé peut encore construire une commande dans
du code qu'on ne peut pas lire (programme compilé, chaîne reconstruite à
l'exécution). Les vraies barrières restent côté propriétaire : CLI Supabase
déconnectée, protection de la branche main.

Sortie 2 = outil refusé ; le message (stderr) est renvoyé à l'agent.
"""

from __future__ import annotations

import fnmatch
import glob
import json
import os
import posixpath
import pwd
import re
import shutil
import subprocess
import sys
import unicodedata
from typing import Dict, List, Optional, Set, Tuple
from urllib.parse import unquote, urlparse

A_POUSSER = "Prépare le changement, puis signale dans ta tâche ce que le propriétaire du projet doit lancer lui-même."

# Le vrai dossier personnel, même si un orchestrateur change HOME.
DOSSIER_PERSO = pwd.getpwuid(os.getuid()).pw_dir
REGLAGES = os.path.join(DOSSIER_PERSO, ".config", "tabl", "garde_fous.json")

# Identifiants partagés avec l'app « Garde-fous Tabl » (scripts/garde_fous_app/).
GARDE_FOUS = ("supabase", "testflight", "scripts_prod", "api_supabase", "secrets", "push_main")

PROFONDEUR_MAX = 6
TAILLE_SCRIPT_MAX = 1_000_000


# --------------------------------------------------------------------------
# Analyse syntaxique du shell
# --------------------------------------------------------------------------

REDIRECTION = re.compile(r"(\d+|\{\w+\})?(&>>|&>|>>|>\||>&|<<<|<<-|<<|<&|<>|>|<)")
AFFECTATION = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\+?=")
NOM_VARIABLE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
SPECIAUX_INOFFENSIFS = {"?": "0", "$": "0", "#": "0", "!": "0", "-": "x"}
SEPARATEURS_MOT = " \t\n;&|()<>"


class Mot:
    """Un mot de la ligne de commande, après retrait des guillemets."""

    __slots__ = ("texte", "dynamique", "glob", "accolades", "cite", "trous")

    def __init__(self) -> None:
        self.texte = ""
        self.dynamique = False  # contient une valeur inconnue (variable, substitution…)
        self.glob = False  # contient un joker non cité
        self.accolades = False  # contient une accolade non citée
        self.cite = False
        self.trous: List[int] = []  # positions du texte où une valeur inconnue s'insère

    def marquer(self) -> None:
        self.dynamique = True
        self.trous.append(len(self.texte))

    def __repr__(self) -> str:  # utile aux tests
        return f"Mot({self.texte!r}{', dyn' if self.dynamique else ''})"


def mot_litteral(texte: str) -> Mot:
    mot = Mot()
    mot.texte = texte
    return mot


class Commande:
    """Une commande simple : mots, redirections, affectations, entrée standard."""

    def __init__(self) -> None:
        self.mots: List[Mot] = []
        self.redirections: List[Tuple[str, Mot]] = []
        self.affectations: List[Tuple[str, Mot]] = []
        self.heredoc: Optional[str] = None  # texte de l'entrée, si connu
        self.entree_inconnue = False  # stdin vient d'ailleurs (tube, fichier illisible…)
        self.producteur: Optional["Commande"] = None  # commande à gauche d'un tube
        self.dossier: Optional[str] = None  # dossier courant au moment du lancement
        self.dossier_connu = True

    def vide(self) -> bool:
        return not (self.mots or self.redirections or self.affectations)


def variables_d_environnement_connues() -> Dict[str, str]:
    connues = {nom: valeur for nom, valeur in os.environ.items()
               if nom.startswith("PAPERCLIP_") or nom in ("CLAUDE_PROJECT_DIR", "USER", "TMPDIR", "LOGNAME")}
    connues["HOME"] = DOSSIER_PERSO
    connues["CLAUDE_CONFIG_DIR"] = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(DOSSIER_PERSO, ".claude")
    return connues


class Analyseur:
    def __init__(self, texte: str, variables: Optional[Dict[str, Optional[str]]] = None) -> None:
        self.s = texte
        self.i = 0
        self.commandes: List[Commande] = []
        self.erreurs: List[str] = []
        base: Dict[str, Optional[str]] = dict(variables_d_environnement_connues())
        base.update(variables or {})
        self.variables = base
        self.entre_guillemets = False

    # -- utilitaires -------------------------------------------------------
    def erreur(self, message: str) -> None:
        if message not in self.erreurs:
            self.erreurs.append(message)

    def _blancs(self) -> None:
        s, n = self.s, len(self.s)
        while self.i < n:
            c = s[self.i]
            if c in " \t\r":
                self.i += 1
            elif c == "\\" and s.startswith("\n", self.i + 1):
                self.i += 2
            elif c == "#":
                while self.i < n and s[self.i] != "\n":
                    self.i += 1
            else:
                break

    # -- structure ----------------------------------------------------------
    def analyser(self) -> None:
        self.liste(None)

    def liste(self, fin: Optional[str]) -> None:
        s = self.s
        n = len(s)
        courante = Commande()
        producteur: Optional[Commande] = None
        heredocs_en_attente: List[Tuple[Commande, str, bool, bool]] = []

        def clore() -> None:
            nonlocal courante
            if not courante.vide():
                self._enregistrer(courante)
            courante = Commande()

        while True:
            self._blancs()
            if self.i >= n:
                if fin:
                    self.erreur("parenthèse non fermée")
                break
            c = s[self.i]
            if fin and c == fin:
                self.i += 1
                break
            if c == "\n":
                self.i += 1
                clore()
                producteur = None
                for cmd, delimiteur, tabs, cite in heredocs_en_attente:
                    self._corps_heredoc(cmd, delimiteur, tabs, cite)
                heredocs_en_attente = []
                continue
            if c == ";" or c == "&" and not s.startswith("&>", self.i):
                if s.startswith("&&", self.i) or s.startswith(";;", self.i):
                    self.i += 2
                else:
                    self.i += 1
                clore()
                producteur = None
                continue
            if c == "|":
                if s.startswith("||", self.i):
                    self.i += 2
                    est_tube = False
                else:
                    self.i += 2 if s.startswith("|&", self.i) else 1
                    est_tube = True
                gauche = courante if (est_tube and not courante.vide()) else None
                clore()
                producteur = gauche
                continue
            if c == "(":
                self.i += 1
                if not courante.vide():
                    clore()
                self.liste(")")
                continue
            if c == ")":
                self.i += 1
                self.erreur("parenthèse fermante inattendue (motif case ?)")
                clore()
                continue
            if c in "<>" and s.startswith("(", self.i + 1):
                self.i += 2
                self.liste(")")
                mot = Mot()
                mot.dynamique = True
                courante.mots.append(mot)
                continue
            redirection = REDIRECTION.match(s, self.i)
            if redirection:
                self.i = redirection.end()
                operateur = redirection.group(2)
                self._blancs()
                cible = self.mot()
                courante.redirections.append((operateur, cible))
                if operateur in ("<<", "<<-"):
                    heredocs_en_attente.append((courante, cible.texte, operateur == "<<-", cible.cite))
                elif operateur == "<<<":
                    courante.heredoc = (courante.heredoc or "") + cible.texte + "\n"
                    if cible.dynamique:
                        courante.entree_inconnue = True
                elif operateur == "<":
                    self._entree_depuis_fichier(courante, cible)
                continue
            mot = self.mot()
            if not mot.texte and not mot.dynamique and not mot.cite:
                self.i += 1  # caractère inattendu : on avance
                continue
            if producteur is not None and courante.producteur is None:
                courante.producteur = producteur
            courante.mots.append(mot)
            # NOM=valeur en tête de commande = affectation
            if len(courante.mots) == len(courante.affectations) + 1 and AFFECTATION.match(mot.texte):
                courante.mots.pop()
                nom, _, valeur = mot.texte.partition("=")
                m2 = Mot()
                m2.texte, m2.dynamique = valeur, mot.dynamique
                courante.affectations.append((nom.rstrip("+"), m2))
            self._affectation_interne(courante)
            if producteur is not None:
                courante.producteur = producteur
        clore()

    def _affectation_interne(self, cmd: Commande) -> None:
        """`export X=…`, `declare X=…` : mémorise la variable."""
        if len(cmd.mots) >= 2 and cmd.mots[0].texte in ("export", "declare", "local", "readonly", "typeset"):
            dernier = cmd.mots[-1]
            if AFFECTATION.match(dernier.texte):
                nom, _, valeur = dernier.texte.partition("=")
                self.variables[nom.rstrip("+")] = None if dernier.dynamique else valeur

    def _enregistrer(self, cmd: Commande) -> None:
        if cmd.producteur is not None:
            cmd.entree_inconnue = cmd.entree_inconnue or cmd.heredoc is None
        if not cmd.mots:  # affectations seules : elles valent pour la suite de la ligne
            for nom, valeur in cmd.affectations:
                self.variables[nom] = None if valeur.dynamique else valeur.texte
        self.commandes.append(cmd)

    def _entree_depuis_fichier(self, cmd: Commande, cible: Mot) -> None:
        if cible.dynamique:
            cmd.entree_inconnue = True
            return
        try:
            chemin = chemin_absolu(cible.texte, None)
            with open(chemin, encoding="utf-8", errors="replace") as f:
                cmd.heredoc = (cmd.heredoc or "") + f.read(TAILLE_SCRIPT_MAX)
        except OSError:
            cmd.entree_inconnue = True

    def _corps_heredoc(self, cmd: Commande, delimiteur: str, tabs: bool, cite: bool) -> None:
        s = self.s
        lignes: List[str] = []
        while self.i < len(s):
            fin = s.find("\n", self.i)
            ligne = s[self.i:] if fin == -1 else s[self.i:fin]
            self.i = len(s) if fin == -1 else fin + 1
            if (ligne.lstrip("\t") if tabs else ligne) == delimiteur:
                break
            lignes.append(ligne.lstrip("\t") if tabs else ligne)
        corps = "\n".join(lignes) + "\n"
        if not cite:  # délimiteur non cité : $( ) et `…` du corps s'exécutent
            sous = Analyseur(corps, self.variables)
            sous.lire_dq(Mot(), None)
            self.commandes.extend(sous.commandes)
            self.erreurs.extend(e for e in sous.erreurs if e not in self.erreurs)
        cmd.heredoc = (cmd.heredoc or "") + corps

    # -- mots ---------------------------------------------------------------
    def mot(self) -> Mot:
        m = Mot()
        s, n = self.s, len(self.s)
        premier = True
        while self.i < n:
            c = s[self.i]
            if c in SEPARATEURS_MOT:
                break
            if c == "'":
                j = s.find("'", self.i + 1)
                if j == -1:
                    self.erreur("apostrophe non fermée")
                    m.texte += s[self.i + 1:]
                    self.i = n
                else:
                    m.texte += s[self.i + 1:j]
                    self.i = j + 1
                m.cite = True
            elif c == '"':
                self.i += 1
                self.lire_dq(m, '"')
                m.cite = True
            elif c == "\\":
                if self.i + 1 < n:
                    if s[self.i + 1] != "\n":
                        m.texte += s[self.i + 1]
                        m.cite = True
                    self.i += 2
                else:
                    self.i += 1
            elif c == "$":
                self.dollar(m)
            elif c == "`":
                self.accent_grave(m)
            elif c == "~" and premier:
                self.tilde(m)
            else:
                if c in "*?[":
                    m.glob = True
                elif c == "{":
                    m.accolades = True
                m.texte += c
                self.i += 1
            premier = False
        return m

    def tilde(self, m: Mot) -> None:
        s = self.s
        j = self.i + 1
        while j < len(s) and (s[j].isalnum() or s[j] in "_-."):
            j += 1
        nom = s[self.i + 1:j]
        if j < len(s) and s[j] not in "/" + SEPARATEURS_MOT:
            m.texte += "~"
            self.i += 1
            return
        if nom == "":
            m.texte += self.variables.get("HOME") or DOSSIER_PERSO
        else:
            try:
                m.texte += pwd.getpwnam(nom).pw_dir
            except KeyError:
                m.texte += "~" + nom
        self.i = j

    def accent_grave(self, m: Mot) -> None:
        s = self.s
        j = self.i + 1
        contenu = []
        while j < len(s) and s[j] != "`":
            if s[j] == "\\" and j + 1 < len(s) and s[j + 1] in "`\\$":
                contenu.append(s[j + 1])
                j += 2
            else:
                contenu.append(s[j])
                j += 1
        if j >= len(s):
            self.erreur("accent grave non fermé")
        sous = Analyseur("".join(contenu), self.variables)
        sous.analyser()
        self.commandes.extend(sous.commandes)
        self.erreurs.extend(e for e in sous.erreurs if e not in self.erreurs)
        self.i = j + 1
        m.marquer()

    def lire_dq(self, m: Mot, fin: Optional[str]) -> None:
        """Contenu entre guillemets doubles (fin='\"'), ou corps de heredoc (fin=None)."""
        avant = self.entre_guillemets
        self.entre_guillemets = True
        try:
            self._lire_dq(m, fin)
        finally:
            self.entre_guillemets = avant

    def _lire_dq(self, m: Mot, fin: Optional[str]) -> None:
        s, n = self.s, len(self.s)
        while self.i < n:
            c = s[self.i]
            if fin and c == fin:
                self.i += 1
                return
            if c == "\\" and self.i + 1 < n:
                suivant = s[self.i + 1]
                if suivant in '"\\$`':
                    m.texte += suivant
                    self.i += 2
                elif suivant == "\n":
                    self.i += 2
                else:
                    m.texte += c
                    self.i += 1
            elif c == "$":
                self.dollar(m)
            elif c == "`":
                self.accent_grave(m)
            else:
                m.texte += c
                self.i += 1
        if fin:
            self.erreur("guillemet non fermé")

    def analyser_contenu(self, texte: str) -> None:
        """Les $( ) et `…` cachés dans un $(( )) ou un ${ } s'exécutent : on les analyse."""
        if "$" not in texte and "`" not in texte:
            return
        sous = Analyseur(texte, self.variables)
        sous.lire_dq(Mot(), None)
        self.commandes.extend(sous.commandes)
        self.erreurs.extend(e for e in sous.erreurs if e not in self.erreurs)

    def dollar(self, m: Mot) -> None:
        s, n = self.s, len(self.s)
        suite = s[self.i + 1:self.i + 2]
        if s.startswith("$((", self.i):
            profondeur, j = 0, self.i + 1
            while j < n:
                if s[j] == "(":
                    profondeur += 1
                elif s[j] == ")":
                    profondeur -= 1
                    if profondeur == 0:
                        break
                j += 1
            self.analyser_contenu(s[self.i + 3:max(self.i + 3, j - 1)])
            self.i = min(n, j + 1)
            m.marquer()
        elif suite == "(":
            self.i += 2
            avant = self.entre_guillemets
            self.entre_guillemets = False
            self.liste(")")
            self.entre_guillemets = avant
            m.marquer()
        elif suite == "{":
            j = s.find("}", self.i + 2)
            while j != -1 and s.count("{", self.i + 2, j) > s.count("}", self.i + 2, j):
                j = s.find("}", j + 1)
            if j == -1:
                self.erreur("${ non fermé")
                self.i = n
                m.marquer()
                return
            interieur = s[self.i + 2:j]
            self.i = j + 1
            nom = NOM_VARIABLE.match(interieur)
            if nom and nom.end() == len(interieur):
                self.variable(m, nom.group(0))
            elif nom and nom.group(0).startswith("PAPERCLIP_") and self.variables.get(nom.group(0)) is not None:
                m.texte += self.variables[nom.group(0)]  # ${PAPERCLIP_API_URL%/} : valeur approchée suffisante
            else:
                self.analyser_contenu(interieur)
                m.marquer()
        elif suite == "'":
            j = self.i + 2
            tampon = []
            while j < n and s[j] != "'":
                if s[j] == "\\" and j + 1 < n:
                    code = s[j + 1]
                    if code in "xX" and re.match(r"[0-9a-fA-F]{1,2}", s[j + 2:j + 4]):
                        h = re.match(r"[0-9a-fA-F]{1,2}", s[j + 2:j + 4]).group(0)
                        tampon.append(chr(int(h, 16)))
                        j += 2 + len(h)
                        continue
                    if code in "uU":
                        h = re.match(r"[0-9a-fA-F]{1,%d}" % (4 if code == "u" else 8), s[j + 2:j + 10])
                        if h:
                            try:
                                tampon.append(chr(int(h.group(0), 16)))
                            except (ValueError, OverflowError):
                                tampon.append("\ufffd")
                            j += 2 + len(h.group(0))
                            continue
                    if code == "c" and j + 2 < n:
                        tampon.append(chr(ord(s[j + 2].upper()) & 0x1F))
                        j += 3
                        continue
                    if code in "01234567":
                        o = re.match(r"[0-7]{1,3}", s[j + 1:j + 4]).group(0)
                        tampon.append(chr(int(o, 8) & 0xFF))
                        j += 1 + len(o)
                        continue
                    tampon.append({"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "e": "\x1b", "E": "\x1b",
                                   "f": "\f", "v": "\v"}.get(code, code))
                    j += 2
                else:
                    tampon.append(s[j])
                    j += 1
            m.texte += "".join(tampon)
            m.cite = True
            self.i = min(n, j + 1)
        elif suite == '"':
            self.i += 2
            self.lire_dq(m, '"')
            m.cite = True
        else:
            nom = NOM_VARIABLE.match(s, self.i + 1)
            if nom:
                self.i = nom.end()
                self.variable(m, nom.group(0))
            elif suite and suite in SPECIAUX_INOFFENSIFS:
                m.texte += SPECIAUX_INOFFENSIFS[suite]
                self.i += 2
            elif suite and (suite.isdigit() or suite in "@*"):
                self.i += 2
                m.marquer()
            else:
                m.texte += "$"
                self.i += 1

    def variable(self, m: Mot, nom: str) -> None:
        if nom in self.variables:
            valeur = self.variables[nom]
            if valeur is None:
                m.marquer()
            elif not self.entre_guillemets and re.search(r"\s", valeur):
                m.texte += valeur  # non citée : bash la découpe en plusieurs mots
                m.marquer()
            else:
                m.texte += valeur
        else:
            m.marquer()


def analyser_commande(texte: str, variables: Optional[Dict[str, Optional[str]]] = None) -> Analyseur:
    analyseur = Analyseur(texte, variables)
    analyseur.analyser()
    return analyseur


# --------------------------------------------------------------------------
# Chemins : normalisation et zones protégées
# --------------------------------------------------------------------------

# Secrets : un agent n'y lit ni n'y écrit rien (garde-fou « secrets »).
SECRETS_RELATIFS = (".config/tabl", ".supabase", ".config/supabase", ".ssh", ".aws", ".gnupg", ".netrc",
                    ".config/gh", "Library/Keychains", ".docker/config.json")

# Le garde-fou lui-même, les réglages de Claude Code, tout ce que Claude Code, git ou le shell lancent plus tard :
# protégés en écriture quel que soit le réglage.
RE_GARDE_FOU = re.compile(r"(^|/)garde_fous\.json$|(^|/)\.claude\.json$|(^|/)\.mcp\.json$")
# .claude/ en entier (skills, agents, commandes « !… », hooks, réglages, plugins) : seule la mémoire des agents en sort.
RE_DOSSIER_CLAUDE_TEXTE = re.compile(r"(^|/)\.claude(/|$)")
RE_MEMOIRE_AGENT = re.compile(r"^/?projects/[^/]+/memory(/|$)")
# Zones où une écriture se déclenche plus tard, hors de portée du garde-fou : démarrage du shell, dossier .git (hooks,
# configuration, références, attributs), instantanés de shell de Claude Code, lancement à la connexion, démarrage de
# Python, direnv/mise.
RE_ZONES_DIFFEREES = re.compile(
    r"(^|/)\.git(/|$)|(^|/)\.gitconfig$|(^|/)\.config/git(/|$)|(^|/)\.config/fish(/|$)"
    r"|(^|/)shell-snapshots(/|$)|(^|/)node_modules(/|$)|(^|/)\.envrc$|(^|/)\.?mise\.toml$"
    r"|(^|/)\.(zshenv|zprofile|zshrc|zlogin|zlogout|bashrc|bash_profile|bash_login|bash_logout|profile)$"
    r"|(^|/)library/(launchagents|launchdaemons|services|scripts|workflows)(/|$)|\.pth$|(^|/)(site|user)customize\.py$")
RE_DOSSIER_CLAUDE = re.compile(r"(^|/)\.claude/?$")
# Dossiers dont un fichier se lance sans être lu (binaires système, paquets) : une seule liste pour la confiance ET
# pour la protection en écriture (un dossier de confiance où l'agent peut écrire ne l'est plus).
RACINES_DE_CONFIANCE = ("/usr", "/bin", "/sbin", "/opt", "/nix", "/System", "/Library", "/Applications", "/Developer")
DOSSIERS_PAQUETS_PERSO = (".local/bin", ".local/share", ".cargo", ".rustup", ".pub-cache", "development/flutter",
                          ".nvm", ".bun", ".deno", ".pyenv", ".rbenv", ".volta", ".gem", "go/bin", "Library/pnpm",
                          ".asdf", ".mise", ".fvm", "Library/Android", "Library/Developer", ".npm", ".yarn")
RE_ZONES_CONFIANCE_TEXTE = re.compile(
    r"^(" + "|".join(re.escape(r.casefold()) for r in RACINES_DE_CONFIANCE) + r")(/|$)"
    r"|(^|/)(" + "|".join(re.escape(d.casefold()) for d in DOSSIERS_PAQUETS_PERSO) + r")(/|$)")
RE_SECRET_TEXTE = re.compile(r"\.config/tabl|(^|/)\.supabase(/|$)|(^|/)\.ssh(/|$)|(^|/)\.aws(/|$)|(^|/)\.netrc$"
                             r"|\.config/gh(/|$)|Library/Keychains|\.config/supabase", re.I)


def cle(chemin: str) -> str:
    """Forme comparable : Unicode normalisé, sans casse (APFS ignore la casse)."""
    return unicodedata.normalize("NFC", chemin).casefold().rstrip("/") or "/"


def chemin_absolu(chemin: str, dossier: Optional[str]) -> str:
    if chemin == "~" or chemin.startswith("~/"):
        chemin = DOSSIER_PERSO + chemin[1:]
    elif chemin.startswith("$HOME") or chemin.startswith("${HOME}"):
        chemin = DOSSIER_PERSO + chemin.split("HOME", 1)[1].lstrip("}")
    base = dossier or os.getcwd()
    return os.path.realpath(os.path.join(base, chemin))


def chemin_sans_liens(chemin: str, dossier: Optional[str]) -> str:
    """Le chemin tel que tapé (~ développé, .. résolus) mais sans suivre les liens : une écriture via un lien
    `node_modules/.bin/x` vise aussi le lien lui-même."""
    if chemin == "~" or chemin.startswith("~/"):
        chemin = DOSSIER_PERSO + chemin[1:]
    return os.path.normpath(os.path.join(dossier or os.getcwd(), chemin))


def _formes(chemin: str) -> List[str]:
    return list({cle(chemin), cle(os.path.realpath(chemin))})


def dossiers_secrets() -> List[str]:
    sorties: List[str] = []
    for relatif in SECRETS_RELATIFS:
        sorties.extend(_formes(os.path.join(DOSSIER_PERSO, relatif)))
    return sorties


def dossiers_du_projet() -> List[str]:
    sorties = []
    for base in (os.environ.get("CLAUDE_PROJECT_DIR"), os.getcwd()):
        if base:
            sorties.extend(_formes(base))
    return sorties


def est_dans(chemin_cle: str, racine_cle: str) -> bool:
    return chemin_cle == racine_cle or chemin_cle.startswith(racine_cle.rstrip("/") + "/")


def est_secret(chemin: str) -> bool:
    k = cle(chemin)
    return any(est_dans(k, racine) for racine in dossiers_secrets())


def dossiers_perso() -> List[str]:
    """Le vrai dossier personnel et celui que l'environnement annonce (un orchestrateur peut changer HOME)."""
    sorties = [DOSSIER_PERSO]
    home = os.environ.get("HOME")
    if home and home not in sorties:
        sorties.append(home)
    return sorties


def dossiers_config_claude() -> List[str]:
    sorties = [os.path.join(h, ".claude") for h in dossiers_perso()]
    for var in ("CLAUDE_CONFIG_DIR",):
        valeur = os.environ.get(var)
        if valeur:
            sorties.append(valeur)
    return sorties


def dossiers_du_path() -> List[str]:
    """Dossiers dont un fichier se lance en tapant son nom : on n'y écrit rien (un faux `git` s'y cacherait)."""
    candidats = [d for d in os.environ.get("PATH", "").split(os.pathsep) if d.startswith("/")]
    for h in dossiers_perso():
        candidats += [os.path.join(h, "bin"), os.path.join(h, ".local", "bin")]
    candidats += ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"]
    for base in dossiers_du_projet():
        candidats.append(os.path.join(base, "node_modules", ".bin"))
    projets = [cle(p) for p in dossiers_du_projet()]
    sorties: List[str] = []
    for d in candidats:
        for forme in _formes(d):
            englobe_le_projet = any(est_dans(p, forme) for p in projets)
            if forme in ("/", "") or forme in (cle(h) for h in dossiers_perso()) or englobe_le_projet:
                continue
            if forme not in sorties:
                sorties.append(forme)
    return sorties


def _dans_dossier_claude(k: str) -> bool:
    """Un chemin sous un dossier `.claude` (projet ou personnel), hors la mémoire des agents."""
    m = RE_DOSSIER_CLAUDE_TEXTE.search(k)
    if not m:
        return False
    reste = k[m.end():]
    return not (RE_MEMOIRE_AGENT.match(reste) and ".." not in reste.split("/"))


def est_garde_fou_texte(k: str) -> bool:
    """Zone où un agent n'écrit jamais : garde-fou, réglages, dossiers lancés plus tard, dossiers de confiance."""
    return bool(RE_GARDE_FOU.search(k) or RE_ZONES_DIFFEREES.search(k) or RE_ZONES_CONFIANCE_TEXTE.search(k)
                or _dans_dossier_claude(k))


def est_garde_fou(chemin: str) -> bool:
    k = cle(chemin)
    if est_garde_fou_texte(k):
        return True
    for dossier in dossiers_config_claude():
        for forme in _formes(dossier):
            if est_dans(k, forme):
                reste = k[len(forme):].lstrip("/")
                if not (RE_MEMOIRE_AGENT.match(reste) and ".." not in reste.split("/")):
                    return True
    return any(est_dans(k, d) for d in dossiers_du_path())


def contient_une_zone_protegee(chemin: str) -> bool:
    """Le chemin est un dossier qui CONTIENT un secret ou le garde-fou (ou le dossier .claude lui-même)."""
    k = cle(chemin)
    if k == "/":
        return True
    if RE_DOSSIER_CLAUDE.search(k):
        return True
    zones = dossiers_secrets() + [cle(os.path.join(DOSSIER_PERSO, ".claude")),
                                  cle(os.path.join(DOSSIER_PERSO, ".claude.json"))]
    zones += [cle(os.path.join(p, ".claude")) for p in dossiers_du_projet()]
    zones += dossiers_du_path()
    if any(z.startswith(k.rstrip("/") + "/") for z in zones):
        return True
    try:
        return os.path.isdir(os.path.join(chemin, ".claude"))
    except OSError:
        return False


def contient_un_secret(chemin: str) -> bool:
    """Le chemin est un dossier qui CONTIENT un secret (une recherche récursive le lirait)."""
    k = cle(chemin)
    return k == "/" or any(z.startswith(k.rstrip("/") + "/") for z in dossiers_secrets())


def glob_vise_un_secret(mot: Mot, dossier: Optional[str], recursif: bool) -> bool:
    """Un motif à jokers qui PEUT désigner un secret, qu'il existe ou non au moment du contrôle."""
    if not mot.glob:
        return False
    zones = [z for z in dossiers_secrets()]
    for texte in textes_du_mot(mot):
        absolu = posixpath.normpath(texte if os.path.isabs(texte) else posixpath.join(dossier or os.getcwd(), texte))
        morceaux = [m for m in cle(absolu).split("/") if m]
        for zone in zones:
            zone_morceaux = [m for m in zone.split("/") if m]
            n, m = len(morceaux), len(zone_morceaux)
            commun = min(n, m)
            if "**" in morceaux:
                commun = min(commun, morceaux.index("**"))
                if all(fnmatch.fnmatchcase(z, p) for z, p in zip(zone_morceaux[:commun], morceaux[:commun])):
                    return True
                continue
            if n < m and not recursif:
                continue
            if all(fnmatch.fnmatchcase(z, p) for z, p in zip(zone_morceaux[:commun], morceaux[:commun])):
                return True
    return False


def developper_accolades(texte: str, limite: int = 64) -> List[str]:
    m = re.search(r"\{([^{}]*)\}", texte)
    if not m:
        return [texte]
    corps = m.group(1)
    if "," in corps:
        options = corps.split(",")
    else:
        suite = re.fullmatch(r"(-?\d+)\.\.(-?\d+)", corps)
        lettres = re.fullmatch(r"([a-zA-Z])\.\.([a-zA-Z])", corps)
        if suite and abs(int(suite.group(2)) - int(suite.group(1))) < 64:
            a, b = int(suite.group(1)), int(suite.group(2))
            options = [str(x) for x in (range(a, b + 1) if a <= b else range(a, b - 1, -1))]
        elif lettres:
            a, b = ord(lettres.group(1)), ord(lettres.group(2))
            options = [chr(x) for x in (range(a, b + 1) if a <= b else range(a, b - 1, -1))]
        else:
            return [texte]
    sorties: List[str] = []
    for option in options:
        sorties.extend(developper_accolades(texte[:m.start()] + option + texte[m.end():], limite))
        if len(sorties) >= limite:
            break
    return sorties[:limite]


def textes_du_mot(mot: Mot) -> List[str]:
    return developper_accolades(mot.texte) if mot.accolades else [mot.texte]


def chemins_du_mot(mot: Mot, dossier: Optional[str]) -> List[str]:
    """Tous les chemins réels que ce mot peut désigner : accolades, jokers, ~, .., liens, valeur d'une option."""
    chemins: List[str] = []
    for texte in textes_du_mot(mot):
        morceaux = [texte]
        if texte.startswith("-") and "=" in texte:
            morceaux.append(texte.split("=", 1)[1])
        for morceau in morceaux:
            if not morceau:
                continue
            chemins.append(chemin_absolu(morceau, dossier))
            chemins.append(chemin_sans_liens(morceau, dossier))
            if mot.glob:
                try:
                    base = dossier or os.getcwd()
                    modele = morceau if os.path.isabs(morceau) else os.path.join(base, morceau)
                    if morceau.startswith("~"):
                        modele = chemin_absolu(morceau, dossier) if not any(c in morceau for c in "*?[") \
                            else DOSSIER_PERSO + morceau[1:]
                    chemins.extend(os.path.realpath(p) for p in sorted(glob.glob(modele))[:200])
                except Exception:
                    pass
    return chemins


# --------------------------------------------------------------------------
# Règles
# --------------------------------------------------------------------------

REFUS_GARDE_FOU = "Le garde-fou des agents, ses réglages et ceux de Claude Code ne se modifient pas depuis un agent."
MSG_SECRETS = "Ces fichiers et commandes contiennent des secrets : un agent n'y touche pas."
MSG_OPAQUE = ("Commande impossible à analyser avec certitude (%s). Écris la commande en clair, sans variable ni "
              "substitution à la place du nom de la commande ou de ses arguments sensibles.")

BRANCHES_PROTEGEES = ("main", "master", "mac-mini")
SCRIPTS_DE_PROD = ("constellation_demo", "donnees_demo", "importer_annuaire", "nettoyer_photos", "photos_demo",
                   "supabase_cli")
RE_SCRIPT_PROD = re.compile(r"(?<![a-z0-9_])(" + "|".join(SCRIPTS_DE_PROD) + r")(?![a-z0-9_])")
# Serveurs de prod : API et base d'un projet (*.supabase.co…), pooler, API de gestion. La doc (supabase.com) reste lisible.
RE_HOTE_SUPABASE = re.compile(r"(^|\.)supabase\.(co|in|net|io|red)$|(^|\.)pooler\.supabase\.com$"
                              r"|^api\.supabase\.com$", re.I)
RE_HOTE_DANS_TEXTE = re.compile(r"supabase\.(co|in|net|io|red)(?![a-z0-9])|pooler\.supabase\.com"
                                r"|api\.supabase\.com", re.I)

MOTS_RESERVES = {"!", "{", "}", "if", "then", "elif", "else", "fi", "while", "until", "do", "done", "time",
                 "coproc", "function", "always", "-"}
ENTETES_SANS_COMMANDE = {"for", "select"}

SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "csh", "tcsh", "fish", "ash"}
RE_INTERPRETE_CODE = re.compile(r"^(python[0-9.]*|pypy[0-9]*|node|nodejs|deno|bun|ruby|perl|php[0-9.]*|lua|dart|"
                                r"osascript|swift|java|groovy|tclsh|expect|awk|gawk|nawk|R|Rscript|julia)$")
INLINE_CODE = {"-c", "-e", "-E", "-p", "-r", "--eval", "--print", "-x"}
RE_CODE_OFFUSQUE = re.compile(r"b64decode|fromhex|rot13|atob\(|fromCharCode|marshal\.loads|zlib\.decompress|__import__", re.I)
RE_CODE_DYNAMIQUE = re.compile(r"\beval\s*\(|\bexec\s*\(|\bcompile\s*\(|importlib")
RE_PROCESSUS = re.compile(
    r"subprocess|popen|posix_spawn|\bspawn\w*|\bexec[lv]\w*|\bfork(pty)?\b|\bsystem\b|\bpty\b|\bctypes\b|\bcffi\b"
    r"|\bgetattr\b|__builtins__|\bpexpect\b|\bos\.startfile|child_process|\bexecsync\b|deno\.command|bun\.spawn"
    r"|\bshell_exec\b|\bpassthru\b|proc_open|open3|\bnstask\b|\bprocess\s*\(\s*\)|do shell script|\bfunction\s*\("
    r"|(?<![.\w])exec\s*[(\"'\s]|\brequire\s*\(\s*[^'\"\s)]|\bimport\s*\(\s*[^'\"\s)]|\bprocess\.binding"
    r"|\bnew\s+function\b", re.I)
RE_PROCESSUS_COMPACT = re.compile(r"subprocess|popen|child_process|posix_spawn|\.system|os\.exec|os\.spawn|shell_exec|"
                                  r"proc_open|passthru|ctypes|getattr")
RE_PROCESSUS_ACCENTS = re.compile(r"`|%x[({\[<|!/]|\bqx\b", re.I)
RE_PROCESSUS_AWK = re.compile(r"\bsystem\b|\bgetline\b|(?<!\|)\|(?!\|)", re.I)
LANGAGES_A_ACCENTS = {"ruby", "perl", "php", "irb", "pl", "rb"}
MSG_PROCESSUS = ("Ce code lance un autre programme (subprocess, system, exec, child_process…) : il échapperait au "
                 "garde-fou. Écris la commande en clair dans le terminal.")
MSG_TESTFLIGHT = "Les builds pour TestFlight / les stores ne partent que sur demande explicite du propriétaire."
# Motifs cherchés dans du code (texte sans espaces ni guillemets) : (garde-fou, motif, message)
CODE_INTERDIT: List[Tuple[Optional[str], "re.Pattern[str]", str]] = [
    ("supabase", re.compile(r"supabase(db|functions|secrets|link|login|logout|projects|branches|migration(up|repair|"
                            r"squash|fetch)|storage|config|gen|inspect|sso|domains|vanity|network|orgs|postgres|"
                            r"seed|init|bootstrap|unlink|start|stop)"),
     "Le code lance la CLI Supabase (prod). " + A_POUSSER),
    ("scripts_prod", re.compile(r"constellation_demo|donnees_demo|importer_annuaire|nettoyer_photos|photos_demo|"
                                r"supabase_cli"),
     "Ce code appelle un script qui écrit dans la vraie base Supabase. " + A_POUSSER),
    ("api_supabase", re.compile(r"supabase\.(co|in|net|io|red)(?![a-z0-9])|pooler\.supabase\.com|api\.supabase\.com"),
     "Pas d'appel direct aux serveurs Supabase (prod) depuis un agent. " + A_POUSSER),
    ("secrets", re.compile(r"\.config/?tabl|\.supabase/|\.config/?supabase|\.ssh/|\.aws/|\.netrc|library/keychains|"
                           r"api-keys|security(find|dump|export)|ghauthtoken"),
     MSG_SECRETS),
    (None, re.compile(r"garde_fous?\.json|garde_fou_agents|\.claude/?(hooks|settings)|shell-snapshots|"
                      r"\.(zshenv|zprofile|zshrc|zlogin|bashrc|bash_profile|profile)(?![a-z0-9_])|\.gitconfig|"
                      r"\.config/?git|\.git/?(hooks|config)|library/launch(agents|daemons)|sitecustomize|"
                      r"usercustomize|\.pth(?![a-z0-9_])|\.local/bin|opt/homebrew/s?bin|usr/local/bin|"
                      r"node_modules/\.bin|~/bin/"), REFUS_GARDE_FOU),
    ("testflight", re.compile(r"flutterbuild(ipa|appbundle)|xcodebuild.{0,60}archive|altool|itmstransporter|fastlane"),
     MSG_TESTFLIGHT),
    ("push_main", re.compile(r"gitpush.{0,80}?(main|master|mac-mini|force|-f)|ghprmerge|ghapi.{0,80}(refs|merge)"),
     "Pas de push sur main/master ni de push forcé : travaille sur une branche, le propriétaire fusionne."),
]

LECTURE_SEULE_SIMPLE = {"cat", "head", "tail", "less", "more", "ls", "wc", "grep", "egrep", "fgrep", "rg", "ag",
                        "diff", "cmp", "file", "stat", "md5", "md5sum", "shasum", "sha256sum", "nl", "od", "xxd",
                        "hexdump", "strings", "bat", "realpath", "readlink", "test", "[", "[[", "true", "false",
                        "echo", "printf", "pwd", "which", "type", "tree", "du", "df", "basename", "dirname", "wait",
                        "sleep", "date", "id", "whoami", "uname", "hostname", "cd", "pushd", "popd", "export",
                        "set", "unset", "local", "declare", "readonly", "typeset", "read", "return", "exit",
                        "shift", "break", "continue", "jobs", "umask", "trap", "alias", "unalias"}
GIT_LECTURE_SEULE = {"log", "diff", "show", "status", "blame", "ls-files", "rev-parse", "describe", "shortlog",
                     "grep", "cat-file", "ls-tree", "rev-list", "show-ref", "for-each-ref", "name-rev",
                     "merge-base", "check-ignore", "count-objects", "diff-tree", "diff-files", "diff-index",
                     "whatchanged", "show-branch", "range-diff", "cherry", "var", "help", "version", "ls-remote",
                     "reflog"}
GIT_CONNUS = GIT_LECTURE_SEULE | {
    "add", "commit", "checkout", "switch", "restore", "reset", "stash", "merge", "rebase", "pull", "fetch", "clone",
    "init", "branch", "tag", "mv", "rm", "clean", "cherry-pick", "revert", "worktree", "submodule", "bisect",
    "remote", "config", "apply", "am", "push", "gc", "prune", "notes", "archive", "bundle", "format-patch",
    "maintenance", "sparse-checkout", "update-index", "update-ref", "symbolic-ref", "write-tree", "read-tree",
    "commit-tree", "hash-object", "mktree", "pack-refs", "repack", "mergetool", "difftool", "citool", "gui",
    "rerere", "fsck", "verify-commit", "verify-tag", "restore", "stage", "unstage", "request-pull", "show-index",
    "lfs", "cvsimport"}
GIT_OPTIONS_C_PERMISES = ("user.", "color.", "advice.", "init.defaultbranch", "commit.gpgsign", "gc.",
                          "core.quotepath", "core.whitespace", "core.autocrlf", "safe.", "diff.", "log.",
                          "pager.", "column.", "status.", "merge.conflictstyle", "rebase.autosquash")
DESTRUCTIFS = {"rm", "rmdir", "mv", "unlink", "shred", "truncate", "chmod", "chown", "chflags", "xattr", "rsync",
               "trash", "srm"}
RECURSIFS = {"grep", "egrep", "fgrep", "rg", "ag", "find", "fd", "cp", "mv", "rm", "tar", "zip", "rsync", "ditto",
             "chmod", "chown", "du", "tree", "ack"}
LECTURE_SEULE_PAR_EXEC = {"grep", "egrep", "fgrep", "rg", "cat", "head", "tail", "wc", "ls", "file", "stat",
                          "shasum", "sha256sum", "md5", "md5sum", "basename", "dirname", "echo", "printf", "test"}
LANCEURS_DIFFERES = {"crontab", "launchctl", "at", "batch", "atrun", "tmux", "screen", "parallel", "expect",
                     "sandbox-exec", "script", "su"}
AGENTS_IMBRIQUES = {"claude", "codex", "gemini", "opencode", "aider", "goose", "cursor-agent", "amp", "droid"}
CLIENTS_RESEAU = {"curl", "wget", "http", "https", "xh", "aria2c", "lynx", "w3m", "httpie", "fetch", "links"}
CLIENTS_BAS_NIVEAU = {"nc", "ncat", "netcat", "telnet", "socat", "ssh", "scp", "sftp", "ftp", "psql", "pg_dump",
                      "pg_restore", "pg_dumpall", "pgcli", "pgbench", "mysql", "openssl", "dig", "nslookup", "host"}
VARIABLES_DANGEREUSES = {"PATH", "BASH_ENV", "ENV", "LD_PRELOAD", "LD_LIBRARY_PATH", "DYLD_INSERT_LIBRARIES",
                         "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH", "GIT_EXEC_PATH", "GIT_SSH", "GIT_SSH_COMMAND",
                         "GIT_PROXY_COMMAND", "GIT_ASKPASS", "PYTHONSTARTUP", "NODE_OPTIONS", "ZDOTDIR",
                         "SHELLOPTS", "PROMPT_COMMAND", "HOME", "XDG_CONFIG_HOME", "GIT_DIR", "GIT_WORK_TREE",
                         "CLAUDE_PROJECT_DIR", "CLAUDE_CONFIG_DIR", "IFS", "PS0", "PS1", "PS2", "PS3", "PS4",
                         "PROMPT", "PROMPT2", "PROMPT3", "PROMPT4", "RPROMPT", "RPS1", "RPS2", "RPROMPT2",
                         "FPATH", "fpath", "path", "module_path", "MAILPATH",
                         # lancent une commande ou chargent du code de l'agent à la place de celui de l'outil
                         "GIT_EXTERNAL_DIFF", "GIT_PAGER", "PAGER", "GIT_EDITOR", "GIT_SEQUENCE_EDITOR", "EDITOR",
                         "VISUAL", "SSH_ASKPASS", "SUDO_ASKPASS", "MANPAGER", "LESSOPEN", "LESSCLOSE", "SHELL",
                         "BROWSER", "GIT_TEMPLATE_DIR",
                         "PYTHONPATH", "PYTHONHOME", "PYTHONUSERBASE", "PYTHONBREAKPOINT", "PERL5OPT", "PERL5LIB",
                         "PERLLIB", "PERL5DB", "RUBYOPT", "RUBYLIB", "NODE_PATH", "DENO_DIR", "GEM_HOME", "GEM_PATH",
                         "BUNDLE_GEMFILE"}
# Familles entières : une variable DYLD_/LD_/BASH_FUNC_ change le chargement du code ; GIT_* sauf l'identité du commit.
PREFIXES_DANGEREUX = ("DYLD_", "LD_", "BASH_FUNC_", "GIT_CONFIG", "NPM_CONFIG_", "npm_config_")
RE_VARIABLE_GIT_PERMISE = re.compile(r"^GIT_(AUTHOR|COMMITTER)_(NAME|EMAIL|DATE)$|^GIT_TERMINAL_PROMPT$"
                                     r"|^GIT_OPTIONAL_LOCKS$")

ENVELOPPES = {  # nom: (options qui prennent une valeur, NOM=valeur permis)
    "env": ({"-u", "-C", "-P", "--unset", "--chdir"}, True),
    "sudo": ({"-u", "-g", "-h", "-p", "-C", "-D", "-R", "-T", "-r", "-t", "-U"}, True),
    "doas": ({"-u", "-C"}, False),
    "nohup": (set(), False), "setsid": (set(), False), "builtin": (set(), False), "unbuffer": (set(), False),
    "exec": ({"-a"}, False), "time": ({"-o", "-f"}, False), "nice": ({"-n"}, False),
    "ionice": ({"-c", "-n", "-p"}, False), "stdbuf": ({"-i", "-o", "-e"}, False),
    "caffeinate": ({"-t", "-w"}, False), "arch": ({"-arch"}, False), "chronic": (set(), False),
    "command": (set(), False), "xcrun": ({"--sdk", "-sdk", "--toolchain"}, False),
    "noglob": (set(), False), "nocorrect": (set(), False),
}
ENVELOPPES_AVEC_SOUS_COMMANDE = {  # nom: mots à sauter après les options
    "bundle": ("exec",), "rbenv": ("exec",), "pyenv": ("exec",), "asdf": ("exec",), "mise": ("exec", "x"),
    "direnv": ("exec",), "poetry": ("run",), "pipenv": ("run",), "pipx": ("run",), "fvm": ("exec",),
    "rtx": ("exec",), "flox": ("activate",),
}


RE_EXECUTABLE_OUVRABLE = re.compile(r"\.(command|app|workflow|terminal|tool|scpt|scptd|action|pkg|mpkg|dmg|sh|zsh|bash|"
                                    r"csh|ksh|py|rb|pl|jar|osax|saver|prefpane|shortcut)$")


RE_CONFIG_PUSH = re.compile(r"^(remote\..*\.push|remote\.pushdefault|push\..*|branch\..*\.(merge|remote|pushremote))$")


def destination_du_push(dossier: Optional[str]) -> str:
    """Où un push sans refspec enverrait la branche courante, d'après la configuration réelle de git."""
    try:
        res = subprocess.run(["git", "rev-parse", "--symbolic-full-name", "@{push}"], cwd=dossier or None,
                             capture_output=True, text=True, timeout=5, env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    except (OSError, subprocess.SubprocessError):
        return ""
    return res.stdout.strip() if res.returncode == 0 else ""


def de_confiance(chemin_reel: str) -> bool:
    """Dossier système ou de paquets connu : on y lance un binaire sans le lire. Tout le dossier est protégé en
    écriture (est_garde_fou), donc rien n'y vient d'un agent : la confiance et la protection ont la même liste."""
    k = cle(chemin_reel)
    if RE_ZONES_CONFIANCE_TEXTE.search(k) or "/node_modules/" in k:
        return True
    return any(est_dans(k, d) for d in dossiers_du_path())


class Refus(Exception):
    pass


def mot_dynamique() -> Mot:
    m = Mot()
    m.marquer()
    return m


# --------------------------------------------------------------------------
# Vérification d'une commande
# --------------------------------------------------------------------------

class Verificateur:
    def __init__(self, actifs: Set[str], dossier: Optional[str], profondeur: int = 0) -> None:
        self.actifs = actifs
        self.strict = bool(actifs)
        self.dossier = dossier or os.getcwd()
        self.connu = True
        self.profondeur = profondeur
        self.ecrits: Set[str] = set()
        self.contenus: Dict[str, str] = {}  # fichiers écrits dans la ligne dont le contenu est connu

    # -- refus ----------------------------------------------------------------
    def refuser(self, garde_fou: Optional[str], message: str) -> None:
        if garde_fou is None or garde_fou in self.actifs:
            raise Refus(message)

    def opaque(self, raison: str) -> None:
        if self.strict:
            raise Refus(MSG_OPAQUE % raison)

    def sous(self) -> "Verificateur":
        enfant = Verificateur(self.actifs, self.dossier, self.profondeur + 1)
        enfant.connu = self.connu
        enfant.ecrits = self.ecrits
        enfant.contenus = self.contenus
        return enfant

    # -- entrée -----------------------------------------------------------------
    def verifier_shell(self, texte: str, variables: Optional[Dict[str, Optional[str]]] = None) -> None:
        if self.profondeur > PROFONDEUR_MAX:
            self.opaque("imbrication trop profonde")
            return
        analyse = analyser_commande(texte, variables)
        if analyse.erreurs:
            self.opaque(analyse.erreurs[0])
        for cmd in analyse.commandes:
            self.verifier_commande(cmd)

    def verifier_commande(self, cmd: Commande) -> None:
        for operateur, cible in cmd.redirections:
            self.verifier_redirection(operateur, cible)
        for nom, _ in cmd.affectations:
            self.variable_permise(nom)
        if cmd.mots and cmd.mots[0].texte in ("export", "declare", "local", "readonly", "typeset"):
            for mot in cmd.mots[1:]:
                if AFFECTATION.match(mot.texte):
                    self.variable_permise(mot.texte.partition("=")[0].rstrip("+"))
        self.memoriser_contenu(cmd)
        if cmd.mots:
            self.executer(list(cmd.mots), cmd)

    def variable_permise(self, nom: str) -> None:
        if nom in VARIABLES_DANGEREUSES or nom.startswith(PREFIXES_DANGEREUX) \
                or (nom.startswith("GIT_") and not RE_VARIABLE_GIT_PERMISE.match(nom)):
            self.refuser(None, f"Pas de modification de la variable {nom} depuis un agent.")

    def memoriser_contenu(self, cmd: Commande) -> None:
        """`cat > fichier <<EOF … EOF` : on connaît le contenu du fichier avant qu'il soit lancé."""
        if cmd.heredoc is None or len(cmd.mots) != 1 or cmd.mots[0].texte != "cat":
            return
        for operateur, cible in cmd.redirections:
            if operateur == ">" and cible.texte and not cible.dynamique and "\n" not in cible.texte:
                self.contenus[cle(chemin_absolu(cible.texte, self.dossier))] = cmd.heredoc

    def verifier_redirection(self, operateur: str, cible: Mot) -> None:
        if operateur in ("<<", "<<-", "<<<"):
            return
        ecriture = operateur in (">", ">>", ">|", "&>", "&>>", "<>") or \
            (operateur == ">&" and not re.fullmatch(r"\d+|-", cible.texte))
        if "\n" in cible.texte or not cible.texte:
            return
        if cible.dynamique or not self.connu:
            for texte in textes_du_mot(cible):
                if ecriture and est_garde_fou_texte(cle(texte)):
                    raise Refus(REFUS_GARDE_FOU)
                if RE_SECRET_TEXTE.search(texte):
                    self.refuser("secrets", MSG_SECRETS)
        for chemin in chemins_du_mot(cible, self.dossier):
            if ecriture and est_garde_fou(chemin):
                raise Refus(REFUS_GARDE_FOU)
            if est_secret(chemin):
                self.refuser("secrets", MSG_SECRETS)
            if ecriture:
                self.ecrits.add(cle(chemin))
                self.contenus.pop(cle(chemin), None)

    # -- déballage des enveloppes ------------------------------------------------
    def apres_options(self, args: List[Mot], avec_valeur=(), assigne: bool = False) -> int:
        i = 0
        while i < len(args):
            mot = args[i]
            texte = mot.texte
            if mot.dynamique and texte.startswith("-") or (mot.dynamique and not texte):
                self.opaque("option ou mot dynamique après un enveloppeur de commande")
                return len(args)
            if texte == "--":
                return i + 1
            if assigne and AFFECTATION.match(texte):
                self.variable_permise(texte.partition("=")[0].rstrip("+"))
                i += 1
                continue
            if texte.startswith("-") and len(texte) > 1:
                i += 2 if texte in avec_valeur else 1
                continue
            return i
        return i

    def executer(self, mots: List[Mot], cmd: Optional[Commande], plus_args: bool = False) -> None:
        if len(mots) > 2 and mots[0].texte == "function" and not mots[0].cite:
            mots = mots[2:]  # « function nom { corps » : le corps s'exécute comme une commande
        while mots:
            premier = mots[0]
            if premier.cite or premier.dynamique:
                break
            if premier.texte in MOTS_RESERVES:
                mots = mots[1:]
            elif premier.texte == "repeat" and len(mots) >= 2:  # zsh : repeat N commande
                mots = mots[2:]
            else:
                break
        if not mots:
            return
        for k in range(1, len(mots)):  # zsh : « if cond { commande } » sans point-virgule
            if mots[k].texte == "{" and not mots[k].cite and not mots[k].dynamique:
                self.executer(mots[k + 1:], cmd)
                break
        if plus_args:
            mots = mots + [mot_dynamique()]
        tete = mots[0]
        if tete.texte.startswith("=") and len(tete.texte) > 1 and not tete.cite and not tete.glob:
            tete = mot_litteral(tete.texte[1:])  # zsh : =nom vaut le chemin de la commande « nom »
            tete.dynamique = mots[0].dynamique
            mots = [tete] + mots[1:]
        if not mots[0].cite and tete.texte in ENTETES_SANS_COMMANDE:
            return
        if tete.texte == "case" and not tete.dynamique:
            self.opaque("motif case")
            return
        if tete.dynamique:
            self.opaque("variable ou substitution utilisée comme nom de commande")
            return
        if tete.glob or len(textes_du_mot(tete)) > 1:
            self.opaque("joker ou accolades dans le nom de la commande")
            return
        brut = tete.texte
        nom = os.path.basename(brut).casefold()
        if nom.endswith(".exe"):
            nom = nom[:-4]
        args = mots[1:]

        if AFFECTATION.match(brut) and not tete.cite:
            return
        nom_reel = self.fichier_lance(brut)
        self.controle_commune(nom, args, cmd)
        self.dispatcher(nom, args, cmd, tete)
        if nom_reel and nom_reel != nom:  # un lien `sb` vers la CLI : on juge aussi sous le vrai nom
            self.controle_commune(nom_reel, args, cmd)
            self.dispatcher(nom_reel, args, cmd, tete)

    def dispatcher(self, nom: str, args: List[Mot], cmd: Optional[Commande], tete: Mot) -> None:
        if nom == "printf":
            for a, valeur in zip(args, args[1:]):
                if a.texte == "-v":
                    if valeur.dynamique:
                        self.opaque("variable dynamique de « printf -v »")
                    self.variable_permise(valeur.texte.split("[")[0])
        elif nom in ("read", "vared", "declare", "typeset", "local", "readonly", "export"):
            for a in args:
                if a.dynamique and not a.texte.startswith("-") and nom in ("read", "vared"):
                    self.opaque("variable dynamique de « %s »" % nom)
                self.variable_permise(re.split(r"[=?\[]", a.texte, 1)[0])
        if nom in ENVELOPPES:
            valeurs, assigne = ENVELOPPES[nom]
            if nom == "command" and any(a.texte in ("-v", "-V") for a in args[:2]):
                return
            if nom == "env" and any(a.texte in ("-S", "--split-string") for a in args):
                self.opaque("env -S")
                return
            if nom == "exec" and not args:
                return
            i = self.apres_options(args, valeurs, assigne)
            self.executer(args[i:], cmd)
        elif nom == "timeout":
            i = self.apres_options(args, {"-s", "-k", "--signal", "--kill-after"})
            self.executer(args[i + 1:], cmd)
        elif nom == "xargs":
            i = self.apres_options(args, {"-I", "-J", "-L", "-n", "-P", "-s", "-E", "-d", "-a", "-R", "-S"})
            commande = list(args[i:])
            remplacement = self.remplacement_xargs(args[:i])
            if remplacement:  # la chaîne de remplacement est remplacée par l'entrée : inconnue à l'analyse
                for k, mot in enumerate(commande):
                    if remplacement in mot.texte:
                        copie = Mot()
                        copie.texte, copie.cite, copie.glob = mot.texte, mot.cite, mot.glob
                        copie.marquer()
                        commande[k] = copie
            self.executer(commande, cmd, plus_args=True)
        elif nom == "trap":
            positionnels = [a for a in args if not (a.texte.startswith("-") and len(a.texte) > 1)]
            if positionnels and (positionnels[0].dynamique or positionnels[0].texte not in ("-", "")):
                self.texte_de_commande(positionnels[:1])
        elif nom == "autoload":
            if any("/" in a.texte or a.dynamique for a in args):
                self.refuser(None, "« autoload » d'un fichier hors des dossiers de fonctions : refusé.")
        elif nom == "open":
            self.ouvrir(args)
        elif nom in ("shortcuts", "automator"):
            self.refuser(None, f"« {nom} » lance des actions hors de portée du garde-fou : lance les commandes directement.")
        elif nom in ENVELOPPES_AVEC_SOUS_COMMANDE:
            i = self.apres_options(args)
            if i < len(args) and args[i].texte in ENVELOPPES_AVEC_SOUS_COMMANDE[nom]:
                i += 1
            if nom == "direnv" and i < len(args):
                i += 1
            self.executer(args[i:], cmd)
        elif nom == "watch":
            i = self.apres_options(args, {"-n", "--interval"})
            self.texte_de_commande(args[i:])
        elif nom in ("eval",):
            self.texte_de_commande(args)
        elif nom in ("source", "."):
            self.source(args)
        elif nom in SHELLS:
            self.shell(nom, args, cmd)
        elif nom in ("npx", "bunx", "pnpx", "uvx"):
            self.lanceur_de_paquet(args)
        elif nom in ("npm", "pnpm", "yarn", "bun", "uv", "deno"):
            self.gestionnaire(nom, args, cmd)
        elif nom == "find":
            self.find(args, cmd)
        elif nom == "git":
            self.git(args, cmd)
        elif nom == "gh":
            self.gh(args)
        elif nom == "supabase":
            self.supabase(args)
        elif nom in ("flutter", "dart") and self.flutter(nom, args):
            pass
        elif nom == "xcodebuild":
            if any(a.texte in ("archive", "-exportArchive", "-archivePath", "-exportOptionsPlist") or a.dynamique or not a.texte
                   for a in args):
                self.refuser("testflight", "Les builds pour TestFlight / les stores ne partent que sur demande "
                                           "explicite du propriétaire.")
        elif nom in ("altool", "itmstransporter", "transporter", "fastlane", "pilot", "deliver", "notarytool"):
            self.refuser("testflight", "Les builds pour TestFlight / les stores ne partent que sur demande "
                                       "explicite du propriétaire.")
        elif nom == "security":
            self.refuser("secrets", MSG_SECRETS)
        elif nom in AGENTS_IMBRIQUES:
            self.refuser(None, "Pas de session d'agent imbriquée : elle échapperait au garde-fou.")
        elif nom in LANCEURS_DIFFERES:
            self.refuser(None, f"« {nom} » lance des commandes hors de portée du garde-fou : lance-les directement.")
        elif nom in ("make", "just", "rake", "task", "gradle", "gradlew", "ninja", "cmake"):
            self.opaque(f"{nom} exécute des recettes qu'on ne peut pas lire")
        elif nom in CLIENTS_RESEAU:
            self.reseau(nom, args, cmd)
        elif nom in CLIENTS_BAS_NIVEAU:
            self.reseau_bas_niveau(nom, args)
        elif RE_INTERPRETE_CODE.match(nom):
            self.interprete(nom, args, cmd)
        elif nom in ("cd", "pushd"):
            self.changer_de_dossier(args)
        elif nom == "alias" and any("=" in a.texte for a in args):
            self.refuser(None, "Pas de définition d'alias depuis un agent : écris la commande en clair.")

    # -- vérifications communes à toute commande -----------------------------------
    def est_lecture_seule(self, nom: str, args: List[Mot]) -> bool:
        if any(a.texte.startswith("--output") for a in args):
            return False
        if nom in LECTURE_SEULE_SIMPLE:
            return True
        if nom == "git":
            return self.analyse_git(args)[1] in GIT_LECTURE_SEULE
        if nom == "sed":
            for a in args:
                if re.match(r"^-[a-zA-Z]*i|^--in-place", a.texte) or a.dynamique:
                    return False
                if re.search(r"/[gIiMm0-9]*[wWeE]\s*\S+$|(^|[;{}\n])\s*[0-9$,]*[wWeE]\s*\S", a.texte):
                    return False
            return True
        if nom == "find":
            for i, a in enumerate(args):
                if a.texte in ("-delete", "-fprint", "-fprint0", "-fprintf", "-fls"):
                    return False
                if a.texte in ("-exec", "-execdir", "-ok", "-okdir"):
                    lance = args[i + 1] if i + 1 < len(args) else None
                    if lance is None or lance.dynamique or \
                            os.path.basename(lance.texte).casefold() not in LECTURE_SEULE_PAR_EXEC:
                        return False
            return True
        return False

    def controle_commune(self, nom: str, args: List[Mot], cmd: Optional[Commande]) -> None:
        if nom in ("echo", "printf"):
            return
        lecture_seule = self.est_lecture_seule(nom, args)
        destructif = nom in DESTRUCTIFS or (nom == "find" and not lecture_seule)
        recursif = nom in RECURSIFS or any(re.fullmatch(r"-[a-zA-Z]*[rR][a-zA-Z]*|--recursive|-d", a.texte)
                                           for a in args if not a.dynamique)
        saute = False
        for mot in args:
            if saute:
                saute = False
                continue
            if mot.texte in ("-m", "--message"):
                saute = True
                continue
            if not mot.texte or '"' in mot.texte or "\n" in mot.texte:
                continue  # texte (corps JSON, message…), pas un chemin
            avec_blancs = any(c.isspace() for c in mot.texte)
            if mot.dynamique or not self.connu:
                for texte in textes_du_mot(mot):
                    if not lecture_seule and not avec_blancs and est_garde_fou_texte(cle(texte)):
                        raise Refus(REFUS_GARDE_FOU)
                    if RE_SECRET_TEXTE.search(texte) and not avec_blancs:
                        self.refuser("secrets", MSG_SECRETS)
            if not avec_blancs and glob_vise_un_secret(mot, self.dossier, recursif):
                self.refuser("secrets", MSG_SECRETS)
            for chemin in chemins_du_mot(mot, self.dossier):
                if not lecture_seule and not avec_blancs and est_garde_fou(chemin):
                    raise Refus(REFUS_GARDE_FOU)
                if est_secret(chemin):
                    self.refuser("secrets", MSG_SECRETS)
                if avec_blancs:
                    continue
                if destructif and contient_une_zone_protegee(chemin):
                    raise Refus(REFUS_GARDE_FOU)
                if recursif and "secrets" in self.actifs and contient_un_secret(chemin):
                    raise Refus(MSG_SECRETS)
        if nom == "tee" or nom in ("cp", "mv", "install", "ln") and args:
            cibles = args if nom == "tee" else args[-1:]
            for mot in cibles:
                if not mot.texte.startswith("-"):
                    for chemin in chemins_du_mot(mot, self.dossier):
                        self.ecrits.add(cle(chemin))

    # -- texte exécuté : shells, scripts, interpréteurs -----------------------------
    def texte_de_commande(self, args: List[Mot]) -> None:
        if any(a.dynamique for a in args):
            self.opaque("commande construite avec une variable ou une substitution")
            return
        self.sous().verifier_shell(" ".join(a.texte for a in args))

    @staticmethod
    def remplacement_xargs(options: List[Mot]) -> Optional[str]:
        remplacement = None
        j = 0
        while j < len(options):
            t = options[j].texte
            if t in ("-I", "-J") and j + 1 < len(options):
                remplacement = options[j + 1].texte
                j += 1
            elif t.startswith(("-I", "-J")) and len(t) > 2:
                remplacement = t[2:]
            elif t in ("-i", "--replace"):
                remplacement = "{}"
            elif t.startswith("--replace="):
                remplacement = t.split("=", 1)[1]
            elif t.startswith("-i") and len(t) > 2 and not t.startswith("--"):
                remplacement = t[2:]
            j += 1
        return remplacement or None

    def entree_connue(self, cmd: Optional[Commande]) -> Optional[str]:
        """Le texte lu sur l'entrée standard, s'il est connu (heredoc, echo/printf/cat en tube)."""
        if cmd is None:
            return None
        if cmd.heredoc is not None and not cmd.entree_inconnue:
            return cmd.heredoc
        prod = cmd.producteur
        if prod is not None and prod.mots and not any(m.dynamique for m in prod.mots):
            tete = os.path.basename(prod.mots[0].texte)
            if tete in ("echo", "printf"):
                return " ".join(m.texte for m in prod.mots[1:])
            if tete == "cat" and prod.heredoc is not None and len(prod.mots) == 1:
                return prod.heredoc
        return None

    def shell(self, nom: str, args: List[Mot], cmd: Optional[Commande]) -> None:
        i = 0
        while i < len(args):
            texte = args[i].texte
            if args[i].dynamique and (not texte or texte.startswith("-")):
                self.opaque("option dynamique d'un shell")
                return
            if texte == "--":
                i += 1
                break
            if texte.startswith("-") and len(texte) > 1 and not texte.startswith("--") and "c" in texte[1:]:
                if i + 1 >= len(args):
                    return
                self.texte_de_commande([args[i + 1]])
                return
            if texte in ("-o", "-O", "--rcfile", "--init-file"):
                i += 2
                continue
            if texte.startswith("-"):
                i += 1
                continue
            break
        if i < len(args):
            if args[i].dynamique or args[i].glob or args[i].accolades:
                self.opaque("script de shell dont le nom est dynamique")
                return
            self.script_fichier(args[i].texte, direct=False, type_script="shell")
            return
        self.lire_stdin(cmd, "shell")

    def fichier_lance(self, brut: str) -> Optional[str]:
        """Le fichier que le shell lancerait : résolu par le PATH réel, lien suivi. Renvoie son vrai nom."""
        if "/" in brut or brut.startswith("."):
            chemin = chemin_sans_liens(brut, self.dossier)
            avec_chemin = True
        else:
            trouve = shutil.which(brut, path=os.environ.get("PATH"))
            if not trouve:
                return None
            chemin = os.path.abspath(trouve)
            avec_chemin = False
        reel = os.path.realpath(chemin)
        nom_reel = os.path.basename(reel).casefold()
        if nom_reel.endswith(".exe"):
            nom_reel = nom_reel[:-4]
        if RE_SCRIPT_PROD.search(nom_reel) or RE_SCRIPT_PROD.search(os.path.basename(chemin).casefold()):
            self.refuser("scripts_prod", "Ce script écrit dans la vraie base Supabase. " + A_POUSSER)
        if not os.path.exists(reel):
            if avec_chemin and cle(reel) not in self.contenus:
                self.opaque("exécutable absent au moment du contrôle (écrit ou compilé pendant la ligne ?)")
            elif cle(reel) in self.contenus:
                self.script_fichier(reel, direct=True)
            return nom_reel
        if not de_confiance(reel):
            self.script_fichier(reel, direct=True)
        return nom_reel

    def ouvrir(self, args: List[Mot]) -> None:
        """`open` lance les scripts .command, les applications, les automatisations : hors de tout hook."""
        saute = False
        for mot in args:
            if saute:
                saute = False
                continue
            texte = mot.texte
            if texte in ("-a", "-b"):
                saute = True
                continue
            if texte == "--args":
                self.refuser(None, "« open --args » lance une application avec des arguments : refusé.")
            if mot.dynamique:
                self.opaque("argument dynamique de « open »")
                continue
            if texte.startswith("-") or "://" in texte:
                continue
            if RE_EXECUTABLE_OUVRABLE.search(texte.casefold().rstrip("/")):
                self.refuser(None, "« open » d'un script ou d'une application : refusé (il s'exécute hors du "
                                   "garde-fou).")
            try:
                absolu = chemin_absolu(texte, self.dossier)
                if os.path.isfile(absolu) and os.access(absolu, os.X_OK):
                    self.refuser(None, "« open » d'un fichier exécutable : refusé (il s'exécute hors du garde-fou).")
            except OSError:
                pass

    def lire_stdin(self, cmd: Optional[Commande], genre: str, langage: str = "") -> None:
        texte = self.entree_connue(cmd)
        if texte is None:
            self.opaque("programme lu sur l'entrée standard, dont on ne connaît pas le contenu")
            return
        if genre == "shell":
            self.sous().verifier_shell(texte)
        else:
            self.verifier_code(texte, inline=True, langage=langage)

    def source(self, args: List[Mot]) -> None:
        if not args:
            return
        if args[0].dynamique or args[0].glob or args[0].accolades:
            self.opaque("source d'un fichier dont le nom est dynamique")
            return
        self.script_fichier(args[0].texte, direct=False, type_script="shell")

    def script_fichier(self, chemin: str, direct: bool, type_script: Optional[str] = None,
                       langage: str = "") -> None:
        base = os.path.basename(chemin).casefold()
        if RE_SCRIPT_PROD.search(base):
            self.refuser("scripts_prod", "Ce script écrit dans la vraie base Supabase. " + A_POUSSER)
        absolu = chemin_absolu(chemin, self.dossier)
        k = cle(absolu)
        contenu = self.contenus.get(k)
        if contenu is None:
            if k in self.ecrits:
                self.opaque("script écrit puis lancé dans la même commande")
                return
            if not os.path.isfile(absolu):
                return
            if RE_SCRIPT_PROD.search(os.path.basename(absolu).casefold()):
                self.refuser("scripts_prod", "Ce script écrit dans la vraie base Supabase. " + A_POUSSER)
            try:
                with open(absolu, "rb") as f:
                    brut = f.read(TAILLE_SCRIPT_MAX + 1)
            except OSError:
                self.opaque("script illisible")
                return
            if b"\0" in brut[:4096]:
                if direct and not de_confiance(absolu):
                    self.opaque("programme compilé hors des dossiers système et de paquets : impossible à vérifier")
                return  # binaire : hors de portée
            if len(brut) > TAILLE_SCRIPT_MAX:
                self.opaque("script trop gros pour être vérifié")
                return
            contenu = brut.decode("utf-8", errors="replace")
        if self.profondeur > PROFONDEUR_MAX:
            self.opaque("imbrication trop profonde")
            return
        premiere = contenu.split("\n", 1)[0]
        if type_script is None:
            if premiere.startswith("#!"):
                interprete = os.path.basename(premiere[2:].split()[-1] if premiere[2:].split() else "")
                type_script = "shell" if interprete in SHELLS else "code"
            elif base.endswith((".sh", ".bash", ".zsh", ".command")):
                type_script = "shell"
            else:
                type_script = "code"
        if type_script == "shell":
            self.sous().verifier_shell(contenu)
        else:
            if not langage:
                if premiere.startswith("#!") and premiere[2:].split():
                    langage = os.path.basename(premiere[2:].split()[-1])
                else:
                    langage = base.rsplit(".", 1)[-1]
            hors_depot = not any(est_dans(k, cle(d)) for d in dossiers_du_projet()) and not de_confiance(absolu)
            self.sous().verifier_code(contenu, inline=False, langage=langage, hors_depot=hors_depot)

    def verifier_code(self, texte: str, inline: bool, langage: str = "", hors_depot: bool = False) -> None:
        """Code Python/Node/Ruby… : on cherche ce qu'il pourrait lancer, quotes et « + » ignorés."""
        compact = re.sub(r"[\s'\"+,()\[\]{}\\`]", "", texte.casefold())
        if inline or hors_depot:  # code qu'on ne peut pas relire dans le dépôt : aucun lancement de processus
            if RE_PROCESSUS.search(texte) or RE_PROCESSUS_COMPACT.search(compact):
                raise Refus(MSG_PROCESSUS)
            if langage in LANGAGES_A_ACCENTS and RE_PROCESSUS_ACCENTS.search(texte):
                raise Refus(MSG_PROCESSUS)
            if langage in ("awk", "gawk", "nawk") and RE_PROCESSUS_AWK.search(texte):
                raise Refus(MSG_PROCESSUS)
        if RE_CODE_OFFUSQUE.search(texte) or (inline and RE_CODE_DYNAMIQUE.search(texte)):
            self.opaque("code qui reconstruit ses commandes (base64, exec, eval…)")
        for garde_fou, motif, message in CODE_INTERDIT:
            if (garde_fou is None or garde_fou in self.actifs) and motif.search(compact):
                raise Refus(message)

    def interprete(self, nom: str, args: List[Mot], cmd: Optional[Commande]) -> None:
        if nom == "dart" and args and args[0].texte in ("run", "compile", "test", "analyze", "format", "pub"):
            if args[0].texte in ("run", "compile"):
                args = args[1:]
            else:
                return
        if nom in ("awk", "gawk", "nawk"):
            i = self.apres_options(args, {"-f", "-v", "-F"})
            if any(a.texte == "-f" for a in args):
                for a, suivant in zip(args, args[1:]):
                    if a.texte == "-f":
                        self.script_fichier(suivant.texte, direct=False, type_script="code", langage="awk")
                return
            if i < len(args):
                if args[i].dynamique:
                    self.opaque("programme awk dynamique")
                else:
                    self.verifier_code(args[i].texte, inline=True, langage="awk")
            return
        i = 0
        while i < len(args):
            a = args[i]
            texte = a.texte
            if a.dynamique and (not texte or texte.startswith("-")):
                self.opaque("option dynamique d'un interpréteur")
                return
            if texte in INLINE_CODE or (texte.startswith("-") and not texte.startswith("--") and len(texte) > 2
                                         and texte[-1] in "ce" and nom in ("python", "python3", "perl", "ruby", "node")):
                if i + 1 >= len(args):
                    return
                if args[i + 1].dynamique:
                    self.opaque("code passé en argument, construit dynamiquement")
                    return
                self.verifier_code(args[i + 1].texte, inline=True, langage=nom)
                return
            if texte in ("--eval", "--print"):
                if i + 1 < len(args):
                    if args[i + 1].dynamique:
                        self.opaque("code passé en argument, construit dynamiquement")
                        return
                    self.verifier_code(args[i + 1].texte, inline=True, langage=nom)
                return
            if texte == "-m" or texte == "-mrun":
                if i + 1 < len(args):
                    module = args[i + 1].texte
                    if RE_SCRIPT_PROD.search(module.casefold()):
                        self.refuser("scripts_prod", "Ce script écrit dans la vraie base Supabase. " + A_POUSSER)
                    if args[i + 1].dynamique:
                        self.opaque("module dynamique")
                return
            if texte in ("-W", "-X", "-I", "-r", "--require", "--import", "--loader"):
                i += 2
                continue
            if texte == "-" and i + 1 >= len(args):
                self.lire_stdin(cmd, "code", nom)
                return
            if texte.startswith("-") and len(texte) > 1:
                i += 1
                continue
            break
        if i < len(args):
            if args[i].dynamique or args[i].glob or args[i].accolades:
                self.opaque("script dont le nom est dynamique")
                return
            if args[i].texte in ("run", "exec") and nom in ("deno", "bun"):
                i += 1
                while i < len(args) and args[i].texte.startswith("-"):
                    i += 1
                if i >= len(args):
                    return
            self.script_fichier(args[i].texte, direct=False, type_script="code", langage=nom)
        elif cmd is not None and (cmd.heredoc is not None or cmd.producteur is not None):
            self.lire_stdin(cmd, "code", nom)

    def changer_de_dossier(self, args: List[Mot]) -> None:
        cibles = [a for a in args if not a.texte.startswith("-") or a.dynamique]
        if not cibles:
            self.dossier = DOSSIER_PERSO
            return
        cible = cibles[0]
        if cible.dynamique or cible.texte == "-":
            self.opaque("cd vers un dossier dont on ne connaît pas le nom")
            self.connu = False
            return
        textes = textes_du_mot(cible)
        if len(textes) > 1 or cible.glob:
            self.opaque("cd avec joker ou accolades")
            self.connu = False
            return
        self.dossier = chemin_absolu(cible.texte, self.dossier)

    # -- commandes précises ------------------------------------------------------------
    def supabase(self, args: List[Mot]) -> None:
        if "supabase" not in self.actifs:
            return
        if any(a.dynamique for a in args):
            self.opaque("argument dynamique de la CLI Supabase")
        positionnels = [a.texte for a in args if not a.texte.startswith("-")]
        options = [a.texte for a in args if a.texte.startswith("-")]
        permis = (not positionnels and all(o in ("--version", "-v", "--help", "-h") for o in options)) \
            or positionnels in (["help"], ["migration", "new"], ["migration", "list"]) \
            or (positionnels[:2] == ["migration", "new"] and len(positionnels) == 3)
        if not permis:
            raise Refus("La CLI Supabase agit sur la base de prod (db push, db query --linked, functions deploy, "
                        "secrets…). Seuls « supabase migration new/list » sont permis. " + A_POUSSER)

    def flutter(self, nom: str, args: List[Mot]) -> bool:
        if nom != "flutter":
            return False
        i = self.apres_options(args, {"-d", "--device-id", "--suppress-analytics"})
        if i >= len(args):
            return True
        if args[i].texte == "build":
            cibles = args[i + 1:]
            if any(a.dynamique for a in cibles[:1]):
                self.opaque("cible de « flutter build » dynamique")
            if cibles and cibles[0].texte in ("ipa", "appbundle", "aab", "ios-framework"):
                self.refuser("testflight", MSG_TESTFLIGHT)
        elif args[i].texte == "pub" and any(RE_SCRIPT_PROD.search(a.texte.casefold()) for a in args[i + 1:]):
            self.refuser("scripts_prod", "Ce script écrit dans la vraie base Supabase. " + A_POUSSER)
        return True

    def find(self, args: List[Mot], cmd: Optional[Commande]) -> None:
        i = 0
        while i < len(args):
            if args[i].texte in ("-exec", "-execdir", "-ok", "-okdir"):
                j = i + 1
                while j < len(args) and not (args[j].texte in (";", "+") and (args[j].cite or args[j].texte == "+")):
                    j += 1
                self.executer(args[i + 1:j], cmd, plus_args=True)
                i = j
            i += 1

    def git(self, args: List[Mot], cmd: Optional[Commande]) -> None:
        indice, sous_commande, dossier = self.analyse_git(args)
        if sous_commande is None:
            return
        reste = args[indice + 1:]
        if sous_commande not in GIT_CONNUS:
            self.opaque(f"sous-commande git inconnue ou alias « {sous_commande} »")
            return
        if sous_commande in ("apply", "am"):
            self.opaque("git apply/am applique un patch qu'on ne peut pas lire")
        elif sous_commande == "config":
            self.git_config(reste)
        elif sous_commande == "branch":
            self.git_branch(reste)
        elif sous_commande in ("checkout", "switch"):
            self.git_suivi(reste)
        elif sous_commande == "push":
            self.git_push(reste, dossier)
        elif sous_commande in ("remote", "submodule", "worktree", "bundle", "archive", "maintenance", "mergetool",
                               "difftool", "citool", "gui", "lfs", "cvsimport"):
            if sous_commande in ("mergetool", "difftool", "citool", "gui", "cvsimport"):
                self.opaque(f"git {sous_commande} lance un programme externe")

    def git_config(self, reste: List[Mot]) -> None:
        if any(re.match(r"^(alias\.|core\.(sshcommand|hookspath|fsmonitor|editor|pager)|credential\.|url\.|"
                        r"include|filter\.|diff\..*(command|textconv)|gpg\.program)", a.texte.casefold().lstrip("-"))
               for a in reste if not a.texte.startswith("--")):
            self.refuser(None, "Pas de modification de la configuration git qui lance des commandes (alias, "
                               "hooks, credential…).")
        lecture = {"--get", "--get-all", "--get-regexp", "--get-urlmatch", "--list", "-l", "--unset", "--unset-all",
                   "--remove-section", "--rename-section", "--show-origin", "--show-scope", "--name-only"}
        if any(a.texte in lecture for a in reste if not a.dynamique):
            return
        for a in reste:
            if a.texte.startswith("-") and not a.dynamique:
                continue
            if a.dynamique:
                self.opaque("clé de configuration git dynamique")
                return
            if RE_CONFIG_PUSH.match(a.texte.casefold()):
                self.refuser("push_main", "Pas de réglage git qui change la destination d'un push (remote.*.push, "
                                          "push.*, branch.*.merge/remote) : travaille sur une branche.")
            break

    @staticmethod
    def branche_protegee(nom: str) -> bool:
        nom = re.sub(r"^refs/(heads|remotes)/", "", nom.casefold())
        nom = re.sub(r"^remotes/", "", nom)
        return nom in BRANCHES_PROTEGEES or ("/" in nom and nom.split("/", 1)[1] in BRANCHES_PROTEGEES)

    def git_amont(self, mot: Mot) -> None:
        if mot.dynamique or mot.glob or mot.accolades:
            self.opaque("branche amont dynamique")
        elif self.branche_protegee(mot.texte):
            self.refuser("push_main", "Pas de branche suivant main/master : un push y enverrait tes commits.")

    def git_branch(self, reste: List[Mot]) -> None:
        saute = False
        positionnels: List[Mot] = []
        suivi = False
        for k, mot in enumerate(reste):
            if saute:
                saute = False
                continue
            texte = mot.texte
            if texte in ("-u", "--set-upstream-to"):
                if k + 1 < len(reste):
                    self.git_amont(reste[k + 1])
                saute = True
            elif texte.startswith("--set-upstream-to="):
                self.git_amont(mot_litteral(texte.split("=", 1)[1]))
            elif re.match(r"^-u.", texte) and not texte.startswith("--"):
                self.git_amont(mot_litteral(texte[2:]))
            elif texte in ("-t", "--track") or texte.startswith("--track="):
                suivi = True
            elif not texte.startswith("-") or mot.dynamique:
                positionnels.append(mot)
        if suivi:
            for mot in positionnels[1:]:
                self.git_amont(mot)

    def git_suivi(self, reste: List[Mot]) -> None:
        if any(a.texte in ("-t", "--track") or a.texte.startswith("--track=") for a in reste):
            for mot in reste:
                if not mot.texte.startswith("-") or mot.dynamique:
                    self.git_amont(mot)

    def analyse_git(self, args: List[Mot]) -> Tuple[int, Optional[str], str]:
        """Saute les options globales de git ; renvoie (indice de la sous-commande, nom, dossier)."""
        dossier = self.dossier
        i = 0
        while i < len(args):
            mot = args[i]
            texte = mot.texte
            if mot.dynamique and (not texte or texte.startswith("-")):
                self.opaque("option dynamique de git")
                return len(args), None, dossier
            if texte == "-C":
                if i + 1 >= len(args) or args[i + 1].dynamique:
                    self.opaque("dossier dynamique de « git -C »")
                    return len(args), None, dossier
                dossier = chemin_absolu(args[i + 1].texte, dossier)
                i += 2
            elif texte == "-c":
                if i + 1 >= len(args) or args[i + 1].dynamique:
                    self.opaque("réglage dynamique de « git -c »")
                    return len(args), None, dossier
                reglage = args[i + 1].texte.casefold()
                if not reglage.startswith(GIT_OPTIONS_C_PERMISES):
                    self.refuser(None, "« git -c » avec ce réglage peut lancer une commande : refusé.")
                i += 2
            elif texte in ("--git-dir", "--work-tree", "--namespace", "--exec-path", "--super-prefix", "--config-env"):
                self.refuser(None, "Pas de « git %s » depuis un agent." % texte)
                i += 2
            elif texte.startswith(("--git-dir=", "--work-tree=", "--exec-path", "--config-env")):
                self.refuser(None, "Pas de modification du dépôt git cible depuis un agent.")
                i += 1
            elif texte.startswith("-"):
                i += 1
            else:
                return i, texte.casefold(), dossier
        return len(args), None, dossier

    def git_push(self, reste: List[Mot], dossier: str) -> None:
        if "push_main" not in self.actifs:
            return
        positionnels: List[Mot] = []
        saute = False
        for mot in reste:
            if saute:
                saute = False
                continue
            texte = mot.texte
            if mot.dynamique and (not texte or texte.startswith("-")):
                self.opaque("option dynamique de git push")
                return
            if texte in ("--repo", "-o", "--push-option", "--receive-pack", "--exec"):
                saute = True
                continue
            if texte.startswith("--"):
                if texte in ("--force", "--mirror", "--delete", "--prune", "--all", "--branches") \
                        or texte.startswith("--force"):
                    raise Refus("Pas de push forcé, de suppression ni de push global : travaille sur une branche.")
                continue
            if texte.startswith("-") and len(texte) > 1:
                if any(c in texte[1:] for c in "fd"):
                    raise Refus("Pas de push forcé ni de suppression de branche : travaille sur une branche.")
                continue
            positionnels.append(mot)
        branche = branche_courante(dossier)
        refspecs = positionnels[1:]
        if not refspecs:
            if branche in BRANCHES_PROTEGEES or not branche:
                raise Refus("Tu es sur main/master : pas de push depuis cette branche. Travaille sur une branche à toi.")
            destination = destination_du_push(dossier)
            if destination and self.branche_protegee(destination):
                raise Refus("La configuration git enverrait ce push sur main/master : refusé. Travaille sur une "
                            "branche à toi.")
            return
        for mot in refspecs:
            if mot.dynamique or mot.glob or mot.accolades:
                self.opaque("refspec de push dynamique")
                return
            spec = mot.texte
            if spec.startswith("+"):
                raise Refus("Pas de push forcé (refspec « + ») : travaille sur une branche.")
            source, deux_points, destination = spec.partition(":")
            if not deux_points:
                destination = source
            if not destination:
                raise Refus("Pas de suppression de branche distante par push.")
            if destination in ("HEAD", "@") or (not deux_points and source in ("HEAD", "@")):
                destination = branche
            destination = re.sub(r"^refs/(heads|remotes/[^/]+)/", "", destination)
            if not destination or destination.casefold() in BRANCHES_PROTEGEES:
                raise Refus("Pas de push sur main/master : travaille sur une branche, le propriétaire fusionne.")

    def gh(self, args: List[Mot]) -> None:
        if "push_main" not in self.actifs and "secrets" not in self.actifs:
            return
        positionnels = []
        saute = False
        for a in args:
            if saute:
                saute = False
                continue
            if a.texte in ("-R", "--repo", "--hostname", "-H", "--header", "-q", "--jq", "-t", "--template", "-X",
                           "--method", "-f", "-F", "--field", "--raw-field", "--input", "-p", "--preview"):
                saute = True
                if a.texte not in ("-X", "--method"):
                    continue
            if not a.texte.startswith("-"):
                positionnels.append(a)
        textes = [a.texte for a in positionnels]
        if textes[:2] == ["pr", "merge"]:
            self.refuser("push_main", "Pas de « gh pr merge » depuis un agent : le propriétaire fusionne.")
        if textes[:2] == ["auth", "token"] or (textes[:1] == ["auth"] and any(a.texte in ("-t", "--show-token")
                                                                              for a in args)):
            self.refuser("secrets", MSG_SECRETS)
        if textes[:1] == ["api"]:
            methode = None
            champs = False
            for i, a in enumerate(args):
                if a.texte in ("-X", "--method") and i + 1 < len(args):
                    methode = args[i + 1].texte.upper()
                    if args[i + 1].dynamique:
                        self.opaque("méthode HTTP dynamique de gh api")
                elif a.texte.startswith("--method="):
                    methode = a.texte.split("=", 1)[1].upper()
                elif a.texte in ("-f", "-F", "--field", "--raw-field", "--input") or a.texte.startswith(
                        ("--field=", "--raw-field=", "--input=")):
                    champs = True
            methode = methode or ("POST" if champs else "GET")
            if methode != "GET":
                chemin = textes[1] if len(textes) > 1 else ""
                if len(positionnels) > 1 and positionnels[1].dynamique:
                    self.opaque("point d'accès dynamique de gh api")
                if not re.match(r"^/?repos/[^/]+/[^/]+/(issues|pulls)(/\d+)?(/comments)?$", chemin) \
                        or methode == "DELETE":
                    self.refuser("push_main", "« gh api » en écriture peut fusionner ou modifier main : refusé. "
                                              "Seuls les commentaires et tickets passent.")

    def hote_dans_valeur(self, mot: Mot) -> None:
        if mot.dynamique and not mot.texte:
            self.opaque("valeur d'option réseau construite dynamiquement")
        elif RE_HOTE_DANS_TEXTE.search(mot.texte):
            self.refuser("api_supabase", "Pas d'appel direct aux serveurs Supabase (prod) depuis un agent. " + A_POUSSER)

    def fichier_d_adresses(self, nom_fichier: Mot, cmd: Optional[Commande]) -> None:
        """wget -i : chaque ligne du fichier est une adresse à télécharger."""
        if nom_fichier.dynamique or nom_fichier.glob or nom_fichier.accolades:
            self.opaque("fichier d'adresses dont le nom est dynamique")
            return
        if nom_fichier.texte == "-":
            texte = self.entree_connue(cmd)
            if texte is None:
                self.opaque("liste d'adresses lue sur l'entrée standard, dont on ne connaît pas le contenu")
                return
        else:
            absolu = chemin_absolu(nom_fichier.texte, self.dossier)
            texte = self.contenus.get(cle(absolu))
            if texte is None:
                if cle(absolu) in self.ecrits:
                    self.opaque("liste d'adresses écrite dans la même commande")
                    return
                try:
                    with open(absolu, "r", encoding="utf-8", errors="replace") as f:
                        texte = f.read(TAILLE_SCRIPT_MAX + 1)
                except OSError:
                    self.opaque("liste d'adresses illisible ou absente")
                    return
                if len(texte) > TAILLE_SCRIPT_MAX:
                    self.opaque("liste d'adresses trop grosse pour être vérifiée")
                    return
        for ligne in texte.splitlines():
            ligne = ligne.strip()
            if ligne and not ligne.startswith("#"):
                self.verifier_url(mot_litteral(ligne))

    def reseau(self, nom: str, args: List[Mot], cmd: Optional[Commande] = None) -> None:
        avec_valeur = {"-d", "--data", "--data-raw", "--data-binary", "--data-urlencode", "--data-ascii", "--json",
                       "-F", "--form", "--form-string", "-H", "--header", "-A", "--user-agent", "-u", "--user",
                       "-X", "--request", "-o", "--output", "-T", "--upload-file", "-e", "--referer", "-b",
                       "--cookie", "-c", "--cookie-jar", "--proxy", "-x", "-w", "--write-out", "--connect-timeout",
                       "-m", "--max-time", "--retry", "--limit-rate", "-O", "--post-data", "--post-file",
                       "--body-data", "--body-file", "--header-file", "-P", "--directory-prefix", "-t",
                       "--output-document", "-U", "--cacert", "--cert", "--key", "-E"}
        urls_reelles: List[Mot] = []
        saute = False
        prochain_est_url = False
        prochain_est_hote = False
        prochain_est_liste = False
        prochain_est_sortie = False
        if nom == "wget":
            options_hote = ("--header", "-e", "--execute", "--referer", "--bind-address")
            courtes_hote = "e"
        else:
            options_hote = ("-H", "--header", "--resolve", "--connect-to", "-x", "--proxy", "--preproxy",
                            "--proxy-header", "--doh-url", "--referer", "-e")
            courtes_hote = "Hxe"
        for a in args:
            if saute:
                saute = False
                if prochain_est_url:
                    urls_reelles.append(a)
                    prochain_est_url = False
                if prochain_est_hote:
                    self.hote_dans_valeur(a)
                    prochain_est_hote = False
                if prochain_est_liste:
                    self.fichier_d_adresses(a, cmd)
                    prochain_est_liste = False
                if prochain_est_sortie:
                    for chemin in chemins_du_mot(a, self.dossier):
                        self.ecrits.add(cle(chemin))
                    prochain_est_sortie = False
                continue
            if a.texte == "--url":
                saute = prochain_est_url = True
            elif a.texte in options_hote:
                saute = prochain_est_hote = True
            elif a.texte.startswith("--") and a.texte.split("=", 1)[0] in options_hote and "=" in a.texte:
                self.hote_dans_valeur(mot_litteral(a.texte.split("=", 1)[1]))
            elif re.match(r"^-[%s]." % courtes_hote, a.texte) and not a.texte.startswith("--"):
                self.hote_dans_valeur(mot_litteral(a.texte[2:]))
            elif nom in ("wget", "aria2c") and a.texte in ("-i", "--input-file"):
                saute = prochain_est_liste = True
            elif nom in ("wget", "aria2c") and a.texte.startswith("--input-file="):
                self.fichier_d_adresses(mot_litteral(a.texte.split("=", 1)[1]), cmd)
            elif nom in ("wget", "aria2c") and re.match(r"^-i.", a.texte) and not a.texte.startswith("--"):
                self.fichier_d_adresses(mot_litteral(a.texte[2:]), cmd)
            elif a.texte in ("-o", "--output") or (nom == "wget" and a.texte in ("-O", "--output-document")):
                saute = prochain_est_sortie = True
            elif a.texte in avec_valeur:
                saute = True
            elif a.texte.startswith("--url="):
                urls_reelles.append(mot_litteral(a.texte.split("=", 1)[1]))
            elif a.texte.startswith("-") and not a.dynamique:
                continue
            else:
                urls_reelles.append(a)
        for u in urls_reelles:
            self.verifier_url(u)
        if any(a.texte in ("-K", "--config") for a in args):
            self.opaque("fichier de configuration de curl")

    def verifier_url(self, mot: Mot) -> None:
        texte = mot.texte
        if not texte and mot.dynamique:
            self.opaque("adresse construite dynamiquement")
            return
        sans_schema = re.sub(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", "", texte)
        decalage = len(texte) - len(sans_schema)
        fin_hote = decalage + re.search(r"[/?#]|$", sans_schema).start()
        if any(t <= fin_hote for t in mot.trous):
            self.opaque("adresse dont le nom de serveur est construit dynamiquement")
            return
        if "file://" in texte.casefold():
            chemin = unquote(urlparse(texte).path)
            if est_secret(chemin_absolu(chemin, self.dossier)):
                self.refuser("secrets", MSG_SECRETS)
            return
        hote = (urlparse("//" + sans_schema).hostname or "").casefold().rstrip(".")
        if RE_HOTE_SUPABASE.search(hote) or RE_HOTE_DANS_TEXTE.search(hote):
            self.refuser("api_supabase", "Pas d'appel direct aux serveurs Supabase (prod) depuis un agent. " + A_POUSSER)

    def reseau_bas_niveau(self, nom: str, args: List[Mot]) -> None:
        if nom in ("psql", "pg_dump", "pg_restore", "pg_dumpall", "pgcli", "pgbench", "mysql"):
            locaux = [a for a in args if not a.dynamique and re.search(r"(^|[@/=:\s])(localhost|127\.0\.0\.1|\[?::1\]?)"
                                                                       r"([:/\s]|$)", a.texte)]
            if not locaux or any(RE_HOTE_DANS_TEXTE.search(a.texte) for a in args):
                self.refuser("api_supabase", "Pas de connexion directe à une base de données depuis un agent "
                                             "(seul localhost est permis). " + A_POUSSER)
            return
        for a in args:
            if RE_HOTE_DANS_TEXTE.search(a.texte):
                self.refuser("api_supabase", "Pas d'appel direct aux serveurs Supabase (prod) depuis un agent. "
                             + A_POUSSER)
            if a.dynamique and not a.texte.startswith("-"):
                self.opaque("adresse construite dynamiquement")

    # -- gestionnaires de paquets ----------------------------------------------------------
    def lanceur_de_paquet(self, args: List[Mot]) -> None:
        i = 0
        paquets: List[str] = []
        while i < len(args):
            a = args[i]
            if a.dynamique and (not a.texte or a.texte.startswith("-")):
                self.opaque("option dynamique d'un lanceur de paquet")
                return
            if a.texte in ("-c", "--call"):
                if i + 1 < len(args):
                    self.texte_de_commande([args[i + 1]])
                return
            if a.texte in ("-p", "--package"):
                if i + 1 < len(args):
                    paquets.append(args[i + 1].texte)
                i += 2
                continue
            if a.texte.startswith("--package="):
                paquets.append(a.texte.split("=", 1)[1])
            if a.texte == "--":
                i += 1
                break
            if a.texte.startswith("-"):
                i += 1
                continue
            break
        if any("supabase" in p.casefold() for p in paquets):
            self.supabase(args[i + 1:])
        if i >= len(args):
            return
        tete = args[i]
        if tete.dynamique:
            self.opaque("nom de paquet dynamique")
            return
        spec = tete.texte
        if re.match(r"^(https?:|git\+|github:|gitlab:|file:|\.{0,2}/)", spec):
            self.opaque("paquet lancé depuis une adresse ou un chemin")
            return
        sans_version = re.sub(r"(?<=.)@[^/@]*$", "", spec)
        binaire = sans_version.rsplit("/", 1)[-1]
        nouveau = mot_litteral(binaire)
        self.executer([nouveau] + list(args[i + 1:]), None)

    def gestionnaire(self, nom: str, args: List[Mot], cmd: Optional[Commande]) -> None:
        if nom == "bun" and any(a.texte in ("-e", "--eval", "-p", "--print") for a in args):
            self.interprete("bun", args, cmd)
            return
        i = self.apres_options(args, {"--prefix", "--cwd", "-C", "--dir", "--filter", "-w", "--workspace", "-F"})
        if i >= len(args):
            return
        sous = args[i].texte
        reste = args[i + 1:]
        if args[i].dynamique:
            self.opaque("sous-commande dynamique")
            return
        if sous in ("exec", "x", "dlx", "create", "init") and nom in ("npm", "pnpm", "yarn", "bun"):
            if sous in ("create", "init") and nom != "bun":
                return
            if nom == "pnpm" and sous == "exec" or nom in ("npm", "yarn") and sous in ("exec", "x") or sous == "dlx" \
                    or (nom == "bun" and sous == "x"):
                self.lanceur_de_paquet(reste)
            return
        if nom == "uv" and sous in ("run", "tool"):
            if sous == "tool":
                if reste and reste[0].texte in ("run",):
                    self.lanceur_de_paquet(reste[1:])
                return
            j = self.apres_options(reste, {"--with", "--python", "-p", "--directory", "--project", "--env-file"})
            self.executer(reste[j:], cmd)
            return
        if nom == "deno" and sous in ("run", "task", "eval"):
            if sous == "eval":
                self.texte_de_commande_code(reste)
            elif sous == "run":
                self.interprete("deno", args, cmd)
            else:
                self.script_npm(reste[0].texte if reste else "", "deno")
            return
        if nom == "bun" and sous in ("run",) and reste and ("/" in reste[0].texte or "." in reste[0].texte):
            self.interprete("bun", args, cmd)
            return
        if sous in ("run", "run-script", "test", "start", "build", "dev", "lint", "stop", "restart", "t", "tst") \
                or (nom in ("yarn", "pnpm", "bun") and sous not in ("install", "i", "add", "remove", "ci", "list",
                                                                      "ls", "why", "outdated", "info", "version",
                                                                      "audit", "config", "cache", "link", "upgrade",
                                                                      "up", "publish", "pack", "login", "logout",
                                                                      "whoami", "help")):
            demande = reste[0].texte if sous in ("run", "run-script") and reste else sous
            if sous in ("run", "run-script") and reste and reste[0].dynamique:
                self.opaque("nom de script dynamique")
                return
            self.script_npm(demande, nom)

    def texte_de_commande_code(self, args: List[Mot]) -> None:
        if any(a.dynamique for a in args):
            self.opaque("code construit dynamiquement")
            return
        self.verifier_code(" ".join(a.texte for a in args), inline=True)

    def script_npm(self, nom_script: str, gestionnaire: str) -> None:
        dossier = self.dossier
        for _ in range(8):
            chemin = os.path.join(dossier, "package.json")
            if os.path.isfile(chemin):
                break
            parent = os.path.dirname(dossier)
            if parent == dossier:
                return
            dossier = parent
        else:
            return
        try:
            with open(chemin, encoding="utf-8") as f:
                scripts = json.load(f).get("scripts", {})
        except Exception:
            self.opaque("package.json illisible")
            return
        if not isinstance(scripts, dict):
            return
        a_verifier = [nom_script] + [f"{prefixe}{nom_script}" for prefixe in ("pre", "post")]
        for nom in a_verifier:
            ligne = scripts.get(nom)
            if isinstance(ligne, str):
                enfant = self.sous()
                enfant.dossier = dossier
                enfant.verifier_shell(ligne)

# --------------------------------------------------------------------------
# Outils autres que Bash
# --------------------------------------------------------------------------

OUTILS_ECRITURE = ("Edit", "Write", "MultiEdit", "NotebookEdit")


def prefixe_statique(motif: str) -> str:
    """Partie d'un motif glob avant le premier joker : le dossier que la recherche parcourt."""
    m = re.search(r"[*?\[{]", motif)
    debut = motif if not m else motif[:m.start()]
    return debut if (not m or debut.endswith("/")) else os.path.dirname(debut)


def verifier_chemin_fichier(chemin: str, dossier: Optional[str], ecriture: bool, actifs: Set[str]) -> Optional[str]:
    if not chemin:
        return None
    absolu = chemin_absolu(chemin, dossier)
    if ecriture and (est_garde_fou(absolu) or est_garde_fou(chemin_sans_liens(chemin, dossier))):
        return REFUS_GARDE_FOU
    if "secrets" in actifs and est_secret(absolu):
        return MSG_SECRETS
    return None


def motif_de_refus_fichier(outil: str, entree: dict, actifs: Set[str], dossier: Optional[str] = None) -> Optional[str]:
    ecriture = outil in OUTILS_ECRITURE
    dossier = dossier or os.getcwd()

    if outil == "WebFetch":
        url = str(entree.get("url", ""))
        v = Verificateur(actifs, dossier)
        try:
            v.verifier_url(mot_litteral(url))
        except Refus as refus:
            return str(refus)
        return None

    if outil in ("Grep", "Glob"):
        base = str(entree.get("path") or "")
        motifs = [str(entree.get("glob") or ""), str(entree.get("pattern") or "") if outil == "Glob" else ""]
        if "secrets" in actifs:
            absolu = chemin_absolu(base, dossier) if base else dossier
            if est_secret(absolu) or contient_un_secret(absolu):
                return MSG_SECRETS
            for motif in motifs:
                if not motif:
                    continue
                if RE_SECRET_TEXTE.search(motif):
                    return MSG_SECRETS
                racine = prefixe_statique(motif)
                if racine:
                    cible = chemin_absolu(racine, absolu)
                    if est_secret(cible) or contient_un_secret(cible):
                        return MSG_SECRETS
                elif ".." in motif.split("/"):
                    return MSG_SECRETS
        return None

    for nom_champ in ("file_path", "path", "notebook_path"):
        refus = verifier_chemin_fichier(str(entree.get(nom_champ, "")), dossier, ecriture, actifs)
        if refus:
            return refus
    return None


def motif_de_refus_bash(commande: str, dossier: Optional[str], actifs: Set[str]) -> Optional[str]:
    try:
        Verificateur(actifs, dossier).verifier_shell(commande)
    except Refus as refus:
        return str(refus)
    return None


def motif_de_refus(outil: str, entree: dict, dossier: Optional[str], actifs: Set[str]) -> Optional[str]:
    if outil == "Bash":
        return motif_de_refus_bash(str(entree.get("command", "")), dossier, actifs)
    return motif_de_refus_fichier(outil, entree, actifs, dossier)


# --------------------------------------------------------------------------
# Réglages et point d'entrée (même interface que l'ancien hook)
# --------------------------------------------------------------------------

def lance_par_un_agent() -> bool:
    if os.environ.get("TABL_AGENT_AUTOMATIQUE") == "1":
        return True
    return any(nom.startswith("PAPERCLIP_") for nom in os.environ)


def garde_fous_actifs() -> Set[str]:
    """Les garde-fous cochés. Tout ce qui n'est pas explicitement décoché reste actif."""
    try:
        with open(REGLAGES, encoding="utf-8") as fichier:
            reglages = json.load(fichier)
        if not isinstance(reglages, dict):
            raise ValueError
    except Exception:
        return set(GARDE_FOUS)
    return {nom for nom in GARDE_FOUS if reglages.get(nom, True) is not False}


def branche_courante(dossier: Optional[str]) -> str:
    try:
        return subprocess.run(
            ["git", "-C", dossier or ".", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
    except Exception:
        return ""


def main() -> int:
    if not lance_par_un_agent():
        return 0
    try:
        donnees = json.load(sys.stdin)
        outil = donnees.get("tool_name", "")
        entree = donnees.get("tool_input") or {}
        refus = motif_de_refus(outil, entree, donnees.get("cwd"), garde_fous_actifs())
    except Exception as erreur:  # en cas de doute, on refuse
        refus = f"Garde-fou des agents : entrée illisible ({erreur.__class__.__name__}), outil refusé par prudence."
    if refus:
        print(f"Refusé par le garde-fou des agents de Tabl : {refus} "
              "Si ce geste est voulu, le propriétaire peut le permettre dans l'app « Garde-fous Tabl ».",
              file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
