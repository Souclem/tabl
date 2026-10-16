"""Photos des données de démonstration : portraits pour les profils
fictifs, plats pour leurs moments.

Source : StockSnap via Openverse (https://openverse.org), uniquement des
photos sous licence CC0 (domaine public, sans attribution requise). Les
sources sont tout de même gardées dans `scripts/.cache_photos/credits.json`.
"""
from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

from PIL import Image, ImageOps

DOSSIER = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache_photos")

RECHERCHES_PORTRAITS = [
    "portrait", "woman smiling", "man portrait", "young woman", "young man",
    "smiling man", "girl portrait", "face",
]
RECHERCHES_PLATS = [
    "food", "dish", "pasta", "burger", "salad", "dessert", "pizza", "sushi",
    "breakfast", "steak", "restaurant meal", "soup", "cake", "coffee",
]

# Dossier "demo/" dans chaque bucket : facile à retrouver et à effacer.
DOSSIER_STOCKAGE = "demo"


def _openverse(recherche: str, page: int) -> list[dict]:
    parametres = urllib.parse.urlencode({
        "q": recherche, "source": "stocksnap", "license": "cc0",
        "page_size": 20, "page": page, "mature": "false",
    })
    requete = urllib.request.Request(
        f"https://api.openverse.org/v1/images/?{parametres}",
        headers={"User-Agent": "tabl-demo/1.0"},
    )
    for essai in range(4):
        try:
            with urllib.request.urlopen(requete, timeout=60) as reponse:
                return json.load(reponse).get("results", [])
        except Exception as erreur:  # limite de débit anonyme : on patiente
            time.sleep(10 * (essai + 1))
            derniere = erreur
    print(f"  (abandon « {recherche} » p.{page} : {derniere})")
    return []


def _telecharger(url: str) -> Image.Image | None:
    try:
        requete = urllib.request.Request(url, headers={"User-Agent": "tabl-demo/1.0"})
        with urllib.request.urlopen(requete, timeout=60) as reponse:
            return ImageOps.exif_transpose(Image.open(io.BytesIO(reponse.read()))).convert("RGB")
    except Exception:
        return None


def collecter(sorte: str, recherches: list[str], nombre: int, taille: tuple[int, int]) -> list[str]:
    """Télécharge et recadre jusqu'à [nombre] photos ; renvoie les noms de
    fichiers (déjà en cache s'ils existent)."""
    dossier = os.path.join(DOSSIER, sorte)
    os.makedirs(dossier, exist_ok=True)
    credits_chemin = os.path.join(DOSSIER, "credits.json")
    credits = json.load(open(credits_chemin)) if os.path.exists(credits_chemin) else {}
    fichiers = sorted(f for f in os.listdir(dossier) if f.endswith(".jpg"))
    # Photos écartées au tri (pas un visage, pas un plat...) : jamais
    # retéléchargées.
    rejets_chemin = os.path.join(DOSSIER, "rejets.json")
    rejets = set(json.load(open(rejets_chemin))) if os.path.exists(rejets_chemin) else set()
    vus = {c["source"] for c in credits.values()} | rejets
    prochain = 1 + max([int(f.split("_")[1][:3]) for f in fichiers] or [-1])
    page = 1
    while len(fichiers) < nombre and page <= 6:
        for recherche in recherches:
            if len(fichiers) >= nombre:
                break
            for resultat in _openverse(recherche, page):
                if len(fichiers) >= nombre:
                    break
                if resultat["url"] in vus or resultat.get("license") != "cc0":
                    continue
                vus.add(resultat["url"])
                image = _telecharger(resultat["url"])
                if image is None or min(image.size) < 400:
                    continue
                nom = f"{sorte}_{prochain:03d}.jpg"
                prochain += 1
                ImageOps.fit(image, taille, centering=(0.5, 0.35)).save(
                    os.path.join(dossier, nom), quality=82
                )
                fichiers.append(nom)
                credits[f"{sorte}/{nom}"] = {
                    "source": resultat["url"],
                    "page": resultat.get("foreign_landing_url"),
                    "licence": "CC0",
                }
            print(f"  {sorte} : {len(fichiers)}/{nombre}")
        page += 1
    json.dump(credits, open(credits_chemin, "w"), indent=1, ensure_ascii=False)
    return fichiers


def televerser(sorte: str, bucket: str) -> None:
    """Copie le dossier local dans `bucket/demo/` du stockage Supabase."""
    source = os.path.join(DOSSIER, sorte)
    resultat = subprocess.run(
        ["supabase", "storage", "cp", "-r", source,
         f"ss:///{bucket}/{DOSSIER_STOCKAGE}", "--experimental", "--linked",
         "--content-type", "image/jpeg", "--cache-control", "max-age=31536000"],
        capture_output=True, text=True,
    )
    if resultat.returncode != 0:
        sys.exit(f"Échec du téléversement {sorte} :\n{resultat.stderr or resultat.stdout}")


def effacer_stockage() -> None:
    for bucket in ("avatars", "souvenirs"):
        subprocess.run(
            ["supabase", "storage", "rm", "-r", f"ss:///{bucket}/{DOSSIER_STOCKAGE}",
             "--experimental", "--linked", "--yes"],
            capture_output=True, text=True,
        )


def rejeter(sorte: str, numeros: list[int]) -> None:
    """Écarte des photos au tri : supprime les fichiers et mémorise leur
    source pour ne plus jamais les télécharger."""
    credits_chemin = os.path.join(DOSSIER, "credits.json")
    credits = json.load(open(credits_chemin))
    rejets_chemin = os.path.join(DOSSIER, "rejets.json")
    rejets = set(json.load(open(rejets_chemin))) if os.path.exists(rejets_chemin) else set()
    for numero in numeros:
        cle = f"{sorte}/{sorte}_{numero:03d}.jpg"
        chemin = os.path.join(DOSSIER, cle)
        if os.path.exists(chemin):
            os.remove(chemin)
        if cle in credits:
            rejets.add(credits.pop(cle)["source"])
    json.dump(credits, open(credits_chemin, "w"), indent=1, ensure_ascii=False)
    json.dump(sorted(rejets), open(rejets_chemin, "w"), indent=1)


def photos_en_cache(sorte: str) -> list[str]:
    dossier = os.path.join(DOSSIER, sorte)
    if not os.path.isdir(dossier):
        return []
    return sorted(f for f in os.listdir(dossier) if f.endswith(".jpg"))


# Miniatures des portraits : taille exacte d'une bulle de la carte sur un
# écran Retina (44 pt × 3), pour la carte et les petits avatars. Même nom
# que l'original, dans un sous-dossier `mini/` à côté de lui : l'app en
# déduit le chemin (voir `urlPhotoProfil`).
TAILLE_MINIATURE = 132
DOSSIER_MINIATURES = "mini"


def miniatures(sorte: str) -> int:
    source = os.path.join(DOSSIER, sorte)
    cible = os.path.join(DOSSIER, DOSSIER_MINIATURES)
    os.makedirs(cible, exist_ok=True)
    for ancien in os.listdir(cible):
        os.remove(os.path.join(cible, ancien))
    noms = photos_en_cache(sorte)
    for nom in noms:
        image = Image.open(os.path.join(source, nom)).convert("RGB")
        image.thumbnail((TAILLE_MINIATURE, TAILLE_MINIATURE))
        image.save(os.path.join(cible, nom), quality=72, optimize=True)
    return len(noms)
