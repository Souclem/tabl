#!/usr/bin/env python3
"""Garde-fou des agents automatiques (Paperclip, ou tout autre orchestrateur).

Claude Code appelle ce script avant chaque outil (hook PreToolUse, voir
.claude/settings.json). Dans une session normale — le propriétaire du projet,
ou Claude en conversation avec lui — il ne fait rien.

Quand l'outil est appelé par un agent automatique (variables PAPERCLIP_*
présentes, ou TABL_AGENT_AUTOMATIQUE=1), il refuse ce qui touche à la
production, part chez les testeurs, lit des secrets ou désarme ce garde-fou.
Ces gestes restent humains : l'agent prépare, le propriétaire exécute.

Le garde-fou protège des accidents, pas d'un agent qui chercherait à le
contourner. Il ne couvre que les agents qui passent par Claude Code (pas
Codex ni Gemini).

Sortie 2 = outil refusé ; le message (stderr) est renvoyé à l'agent.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

A_POUSSER = "Prépare le changement, puis signale dans ta tâche ce que le propriétaire du projet doit lancer lui-même."

# Ce que la CLI Supabase peut faire sans toucher à la base de prod.
SUPABASE_PERMIS = re.compile(r"^(migration\s+(new|list)\b|--version\b|--help\b|help\b|$)")

# Position de commande : début, ou après ; & | ( $( ` " ' — avec un chemin ou npx/env éventuels.
POSITION_COMMANDE = r"(?:^|[;&|(`\"'\n]|\$\()\s*(?:sudo\s+)?(?:env\s+(?:\S+=\S*\s+)*)?(?:npx\s+(?:--yes\s+)?)?(?:\S*/)?"

SCRIPTS_DE_PROD = r"(constellation_demo|donnees_demo|importer_annuaire|nettoyer_photos|photos_demo|supabase_cli)"

INTERDITS_BASH: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(r"\bflutter\s+build\s+(ipa|appbundle)\b|\bxcodebuild\b.*\b(archive|-exportArchive)\b"
                   r"|\bxcrun\s+altool\b|\biTMSTransporter\b|\bfastlane\b", re.I),
        "Les builds pour TestFlight / les stores ne partent que sur demande explicite du propriétaire.",
    ),
    (
        re.compile(r"(python3?|dart(\s+run)?|uv\s+run|\bsh|\bbash|\./scripts/)[^;&|\n]*\b" + SCRIPTS_DE_PROD + r"\b", re.I),
        "Ce script écrit dans la vraie base Supabase. " + A_POUSSER,
    ),
    (
        re.compile(r"supabase\.co", re.I),
        "Pas d'appel direct aux serveurs Supabase (prod) depuis un agent. " + A_POUSSER,
    ),
    (
        re.compile(r"\.config/tabl\b|api-keys|security\s+find-(generic|internet)-password", re.I),
        "Ces fichiers et commandes contiennent des secrets : un agent n'y touche pas.",
    ),
    (
        re.compile(r"\bgit\b[^;&|\n]*\bpush\b[^;&|\n]*(\s(--force\S*|-f|--mirror|--delete)\b|[\s:+](main|master)\b)", re.I),
        "Pas de push sur main/master ni de push forcé : travaille sur une branche, le propriétaire fusionne.",
    ),
]

LECTURE_SEULE = re.compile(r"^\s*(cat|head|tail|less|ls|wc|grep|rg|git\s+(log|diff|show|status|blame))\b")
FICHIERS_DU_GARDE_FOU = re.compile(r"\.claude/(hooks|settings[^/\s]*\.json)")


def lance_par_un_agent() -> bool:
    if os.environ.get("TABL_AGENT_AUTOMATIQUE") == "1":
        return True
    return any(nom.startswith("PAPERCLIP_") for nom in os.environ)


def branche_courante(dossier: str | None) -> str:
    try:
        return subprocess.run(
            ["git", "-C", dossier or ".", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
    except Exception:
        return ""


def motif_de_refus_bash(commande: str, dossier: str | None) -> str | None:
    for appel in re.finditer(POSITION_COMMANDE + r"supabase(?=\s|$)([^;&|\n`]*)", commande):
        if not SUPABASE_PERMIS.match(appel.group(1).strip()):
            return ("La CLI Supabase agit sur la base de prod (db push, db query --linked, functions deploy, "
                    "secrets…). Seuls « supabase migration new/list » sont permis. " + A_POUSSER)

    for motif, raison in INTERDITS_BASH:
        if motif.search(commande):
            return raison

    # « git push » sans branche précisée, depuis main/master.
    if re.search(r"\bgit\b[^;&|\n]*\bpush\b", commande) and branche_courante(dossier) in ("main", "master"):
        if not re.search(r"\bpush\s+\S+\s+[^-\s]", commande):
            return "Tu es sur main/master : pas de push depuis cette branche. Travaille sur une branche à toi."

    if FICHIERS_DU_GARDE_FOU.search(commande) and not LECTURE_SEULE.match(commande):
        return "Le garde-fou des agents et les réglages de Claude Code ne se modifient pas depuis un agent."
    return None


def motif_de_refus_fichier(outil: str, entree: dict) -> str | None:
    chemins = [str(entree.get(cle, "")) for cle in ("file_path", "path", "notebook_path")]
    for chemin in chemins:
        if re.search(r"\.config/tabl\b", chemin):
            return "Ce dossier contient des secrets : un agent n'y touche pas."
        if outil in ("Edit", "Write", "MultiEdit", "NotebookEdit") and FICHIERS_DU_GARDE_FOU.search(chemin):
            return "Le garde-fou des agents et les réglages de Claude Code ne se modifient pas depuis un agent."
    return None


def main() -> int:
    if not lance_par_un_agent():
        return 0
    try:
        donnees = json.load(sys.stdin)
        outil = donnees.get("tool_name", "")
        entree = donnees.get("tool_input") or {}
        if outil == "Bash":
            refus = motif_de_refus_bash(str(entree.get("command", "")), donnees.get("cwd"))
        else:
            refus = motif_de_refus_fichier(outil, entree)
    except Exception as erreur:  # en cas de doute, on refuse
        refus = f"Garde-fou des agents : entrée illisible ({erreur.__class__.__name__}), outil refusé par prudence."
    if refus:
        print(f"Refusé par le garde-fou des agents de Tabl : {refus}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
