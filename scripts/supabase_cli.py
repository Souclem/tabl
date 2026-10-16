"""Accès à la base Supabase distante via la CLI (`supabase db query
--linked`), partagé par les scripts de ce dossier."""
import json
import os
import subprocess
import sys
import tempfile


def executer_fichier(chemin_sql: str) -> str:
    """Exécute un fichier SQL sur la base liée ; arrête le script en cas
    d'échec, avec le message de la base."""
    resultat = subprocess.run(
        ["supabase", "db", "query", "--linked", "-f", chemin_sql],
        capture_output=True,
        text=True,
    )
    if resultat.returncode != 0:
        sys.exit(f"Échec sur {chemin_sql} :\n{resultat.stderr or resultat.stdout}")
    return resultat.stdout


def executer(sql: str) -> str:
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as fichier:
        fichier.write(sql)
        chemin = fichier.name
    try:
        return executer_fichier(chemin)
    finally:
        os.unlink(chemin)


def lignes(sql: str) -> list[dict]:
    """Exécute une requête de lecture et renvoie ses lignes."""
    sortie = executer(sql)
    return json.loads(sortie[sortie.index("{"):sortie.rindex("}") + 1])["rows"]


def texte(valeur) -> str:
    if valeur is None:
        return "null"
    return "'" + str(valeur).replace("'", "''") + "'"


def tableau(valeurs) -> str:
    if not valeurs:
        return "'{}'::text[]"
    return "array[" + ",".join(texte(v) for v in valeurs) + "]::text[]"
