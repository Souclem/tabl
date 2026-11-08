"""Accès à la base Supabase distante via la CLI (`supabase db query
--linked`), partagé par les scripts de ce dossier."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile


def executer_fichier(chemin_sql: str, en_json: bool = False) -> str:
    """Exécute un fichier SQL sur la base liée ; arrête le script en cas
    d'échec, avec le message de la base. [en_json] : la réponse en JSON
    — sinon la CLI choisit, un tableau quand c'est une personne qui la
    lance."""
    commande = ["supabase", "db", "query", "--linked", "-f", chemin_sql]
    if en_json:
        commande += ["--output-format", "json"]
    resultat = subprocess.run(commande, capture_output=True, text=True)
    if resultat.returncode != 0:
        sys.exit(f"Échec sur {chemin_sql} :\n{resultat.stderr or resultat.stdout}")
    return resultat.stdout


def executer(sql: str, en_json: bool = False) -> str:
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as fichier:
        fichier.write(sql)
        chemin = fichier.name
    try:
        return executer_fichier(chemin, en_json=en_json)
    finally:
        os.unlink(chemin)


def lignes(sql: str) -> list[dict]:
    """Exécute une requête de lecture et renvoie ses lignes. La CLI les
    donne en liste (lancée par une personne) ou dans `{"rows": …}`
    (lancée par un agent) : les deux sont lus."""
    sortie = executer(sql, en_json=True)
    debut = min(i for i in (sortie.find("["), sortie.find("{")) if i >= 0)
    donnees, _ = json.JSONDecoder().raw_decode(sortie[debut:])
    return donnees["rows"] if isinstance(donnees, dict) else donnees


def texte(valeur) -> str:
    if valeur is None:
        return "null"
    return "'" + str(valeur).replace("'", "''") + "'"


def tableau(valeurs) -> str:
    if not valeurs:
        return "'{}'::text[]"
    return "array[" + ",".join(texte(v) for v in valeurs) + "]::text[]"
