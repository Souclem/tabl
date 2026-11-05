#!/usr/bin/env python3
"""Garde-fou des agents automatiques (Paperclip, ou tout autre orchestrateur).

Claude Code appelle ce script avant chaque outil (hook PreToolUse, voir
.claude/settings.json). Dans une session normale — le propriétaire du projet,
ou Claude en conversation avec lui — il ne fait rien.

Quand l'outil est appelé par un agent automatique (variables PAPERCLIP_*
présentes, ou TABL_AGENT_AUTOMATIQUE=1), il refuse ce qui touche à la
production, part chez les testeurs ou lit des secrets. Ces gestes restent
humains : l'agent prépare, le propriétaire exécute.

Chaque garde-fou s'active ou se coupe dans l'app « Garde-fous Tabl », qui
écrit ~/.config/tabl/garde_fous.json (relu à chaque appel : effet immédiat).
Fichier absent ou illisible = tous les garde-fous actifs. Un seul ne se coupe
jamais : un agent ne modifie ni ce réglage, ni le garde-fou lui-même.

Le garde-fou protège des accidents, pas d'un agent qui chercherait à le
contourner. Il ne couvre que les agents qui passent par Claude Code (pas
Codex ni Gemini).

Sortie 2 = outil refusé ; le message (stderr) est renvoyé à l'agent.
"""

from __future__ import annotations

import json
import os
import pwd
import re
import subprocess
import sys

A_POUSSER = "Prépare le changement, puis signale dans ta tâche ce que le propriétaire du projet doit lancer lui-même."

# Le vrai dossier personnel, même si un orchestrateur change HOME.
DOSSIER_PERSO = pwd.getpwuid(os.getuid()).pw_dir
REGLAGES = os.path.join(DOSSIER_PERSO, ".config", "tabl", "garde_fous.json")

# Identifiants partagés avec l'app « Garde-fous Tabl » (scripts/garde_fous_app/).
GARDE_FOUS = ("supabase", "testflight", "scripts_prod", "api_supabase", "secrets", "push_main")

# Ce que la CLI Supabase peut faire sans toucher à la base de prod.
SUPABASE_PERMIS = re.compile(r"^(migration\s+(new|list)\b|--version\b|--help\b|help\b|$)")

# Position de commande : début, ou après ; & | ( $( ` " ' — avec un chemin ou npx/env éventuels.
POSITION_COMMANDE = r"(?:^|[;&|(`\"'\n]|\$\()\s*(?:sudo\s+)?(?:env\s+(?:\S+=\S*\s+)*)?(?:npx\s+(?:--yes\s+)?)?(?:\S*/)?"

SCRIPTS_DE_PROD = r"(constellation_demo|donnees_demo|importer_annuaire|nettoyer_photos|photos_demo|supabase_cli)"

INTERDITS_BASH: list[tuple[str, re.Pattern[str], str]] = [
    (
        "testflight",
        re.compile(r"\bflutter\s+build\s+(ipa|appbundle)\b|\bxcodebuild\b.*\b(archive|-exportArchive)\b"
                   r"|\bxcrun\s+altool\b|\biTMSTransporter\b|\bfastlane\b", re.I),
        "Les builds pour TestFlight / les stores ne partent que sur demande explicite du propriétaire.",
    ),
    (
        "scripts_prod",
        re.compile(r"(python3?|dart(\s+run)?|uv\s+run|\bsh|\bbash|\./scripts/)[^;&|\n]*\b" + SCRIPTS_DE_PROD + r"\b", re.I),
        "Ce script écrit dans la vraie base Supabase. " + A_POUSSER,
    ),
    (
        "api_supabase",
        re.compile(r"supabase\.co", re.I),
        "Pas d'appel direct aux serveurs Supabase (prod) depuis un agent. " + A_POUSSER,
    ),
    (
        "secrets",
        re.compile(r"\.config/tabl\b|api-keys|security\s+find-(generic|internet)-password", re.I),
        "Ces fichiers et commandes contiennent des secrets : un agent n'y touche pas.",
    ),
    (
        "push_main",
        re.compile(r"\bgit\b[^;&|\n]*\bpush\b[^;&|\n]*(\s(--force\S*|-f|--mirror|--delete)\b|[\s:+](main|master)\b)", re.I),
        "Pas de push sur main/master ni de push forcé : travaille sur une branche, le propriétaire fusionne.",
    ),
]

LECTURE_SEULE = re.compile(r"^\s*(cat|head|tail|less|ls|wc|grep|rg|git\s+(log|diff|show|status|blame))\b")
# Toujours protégés, quel que soit le réglage.
FICHIERS_DU_GARDE_FOU = re.compile(r"\.claude/(hooks|settings[^/\s]*\.json)|garde_fous\.json")
REFUS_GARDE_FOU = "Le garde-fou des agents, ses réglages et ceux de Claude Code ne se modifient pas depuis un agent."


def lance_par_un_agent() -> bool:
    if os.environ.get("TABL_AGENT_AUTOMATIQUE") == "1":
        return True
    return any(nom.startswith("PAPERCLIP_") for nom in os.environ)


def garde_fous_actifs() -> set[str]:
    """Les garde-fous cochés. Tout ce qui n'est pas explicitement décoché reste actif."""
    try:
        with open(REGLAGES, encoding="utf-8") as fichier:
            reglages = json.load(fichier)
        if not isinstance(reglages, dict):
            raise ValueError
    except Exception:
        return set(GARDE_FOUS)
    return {nom for nom in GARDE_FOUS if reglages.get(nom, True) is not False}


def branche_courante(dossier: str | None) -> str:
    try:
        return subprocess.run(
            ["git", "-C", dossier or ".", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
    except Exception:
        return ""


def motif_de_refus_bash(commande: str, dossier: str | None, actifs: set[str]) -> str | None:
    if FICHIERS_DU_GARDE_FOU.search(commande) and not LECTURE_SEULE.match(commande):
        return REFUS_GARDE_FOU

    if "supabase" in actifs:
        for appel in re.finditer(POSITION_COMMANDE + r"supabase(?=\s|$)([^;&|\n`]*)", commande):
            if not SUPABASE_PERMIS.match(appel.group(1).strip()):
                return ("La CLI Supabase agit sur la base de prod (db push, db query --linked, functions deploy, "
                        "secrets…). Seuls « supabase migration new/list » sont permis. " + A_POUSSER)

    for nom, motif, raison in INTERDITS_BASH:
        if nom in actifs and motif.search(commande):
            return raison

    # « git push » sans branche précisée, depuis main/master.
    if "push_main" in actifs and re.search(r"\bgit\b[^;&|\n]*\bpush\b", commande) \
            and branche_courante(dossier) in ("main", "master") \
            and not re.search(r"\bpush\s+\S+\s+[^-\s]", commande):
        return "Tu es sur main/master : pas de push depuis cette branche. Travaille sur une branche à toi."
    return None


def motif_de_refus_fichier(outil: str, entree: dict, actifs: set[str]) -> str | None:
    ecriture = outil in ("Edit", "Write", "MultiEdit", "NotebookEdit")
    for cle in ("file_path", "path", "notebook_path"):
        chemin = str(entree.get(cle, ""))
        if ecriture and FICHIERS_DU_GARDE_FOU.search(chemin):
            return REFUS_GARDE_FOU
        if "secrets" in actifs and re.search(r"\.config/tabl\b", chemin):
            return "Ce dossier contient des secrets : un agent n'y touche pas."
    return None


def main() -> int:
    if not lance_par_un_agent():
        return 0
    try:
        donnees = json.load(sys.stdin)
        outil = donnees.get("tool_name", "")
        entree = donnees.get("tool_input") or {}
        actifs = garde_fous_actifs()
        if outil == "Bash":
            refus = motif_de_refus_bash(str(entree.get("command", "")), donnees.get("cwd"), actifs)
        else:
            refus = motif_de_refus_fichier(outil, entree, actifs)
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
