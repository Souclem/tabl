"""Retire la position GPS (et toutes les métadonnées, sauf l'orientation)
des photos déjà déposées : avatars, souvenirs, instants, retours.

Depuis la revue de sécurité du 2026-11-02, l'app les retire avant chaque
envoi (`sansMetadonnees`, app/lib/services/stockage/sans_metadonnees.dart).
Ce script rattrape les photos envoyées avant, avec ce même code Dart
(scripts/nettoyer_photos.dart) : une seule façon de nettoyer.

Usage, depuis la racine du dépôt (projet lié par `supabase link`) :
  python3 scripts/nettoyer_photos.py              # essai : télécharge, nettoie, compte
  python3 scripts/nettoyer_photos.py --appliquer  # remplace les photos concernées

Chaque photo remplacée est relue et comparée. Les originaux restent dans
scripts/.cache_nettoyage/originaux (non commité) : à effacer à la main
une fois l'app vérifiée.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from supabase_cli import lignes, tableau  # noqa: E402

BUCKETS = ["avatars", "souvenirs", "instants", "retours"]
ICI = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(ICI, ".cache_nettoyage")
ORIGINAUX = os.path.join(CACHE, "originaux")
PROPRES = os.path.join(CACHE, "propres")
RELUES = os.path.join(CACHE, "relues")


def acces_stockage() -> tuple[str, str]:
    """L'adresse du projet lié et sa clé de service, demandées une seule
    fois à la CLI (`supabase storage cp` la redemande à chaque fichier et
    se fait vite limiter). La clé ne quitte pas la mémoire du script."""
    ref = open(os.path.join(ICI, "..", "supabase", ".temp", "project-ref")).read().strip()
    cles = json.loads(subprocess.run(
        ["supabase", "projects", "api-keys", "--project-ref", ref, "--reveal",
         "--output", "json"],
        capture_output=True, text=True, check=True,
    ).stdout)
    cle = next(c["api_key"] for c in cles if c.get("name") == "service_role")
    return f"https://{ref}.supabase.co/storage/v1/object", cle


ADRESSE, CLE = "", ""


def requete(methode: str, bucket: str, nom: str, corps: bytes | None = None,
            type_mime: str | None = None, sans_cache: bool = False) -> bytes:
    """Un appel à l'API de stockage, retenté si elle fatigue. [sans_cache] :
    une adresse jamais vue, que le CDN ne peut pas servir de mémoire (les
    photos de profil, publiques, y restent une heure)."""
    entetes = {"Authorization": f"Bearer {CLE}", "apikey": CLE}
    if corps is not None:
        entetes |= {"Content-Type": type_mime, "x-upsert": "true",
                    "Cache-Control": "max-age=3600"}
    adresse = f"{ADRESSE}/{bucket}/{urllib.parse.quote(nom)}"
    if sans_cache:
        adresse += f"?relu={time.time_ns()}"
    for essai in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(
                adresse, data=corps, method=methode, headers=entetes,
            ), timeout=60) as reponse:
                return reponse.read()
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or essai == 3:
                raise RuntimeError(f"{e.code} {e.read().decode(errors='replace')[:200]}")
        except urllib.error.URLError as e:
            if essai == 3:
                raise RuntimeError(str(e.reason))
        time.sleep(2 * (essai + 1))
    raise AssertionError


def telecharger(objet: tuple[str, str], dossier: str, sans_cache: bool = False) -> None:
    bucket, nom = objet
    local = os.path.join(dossier, bucket, nom)
    if os.path.exists(local):
        return
    os.makedirs(os.path.dirname(local), exist_ok=True)
    octets = requete("GET", bucket, nom, sans_cache=sans_cache)
    with open(local + ".partiel", "wb") as f:
        f.write(octets)
    os.replace(local + ".partiel", local)


def empreinte(chemin: str) -> str:
    return hashlib.sha256(open(chemin, "rb").read()).hexdigest()


def remplacer(relatif: str) -> str | None:
    """Dépose la version propre, la relit et la compare. Le message
    d'erreur, ou None si tout va bien."""
    bucket, nom = relatif.split(os.sep, 1)
    propre = os.path.join(PROPRES, relatif)
    type_mime = "image/png" if nom.lower().endswith(".png") else "image/jpeg"
    try:
        requete("PUT", bucket, nom, open(propre, "rb").read(), type_mime)
        relue = os.path.join(RELUES, relatif)
        if os.path.exists(relue):
            os.remove(relue)
        telecharger((bucket, nom), RELUES, sans_cache=True)
    except RuntimeError as e:
        return str(e)
    if empreinte(relue) != empreinte(propre):
        return "relue, la photo n'est pas la version propre"
    return None


def main() -> None:
    global ADRESSE, CLE
    appliquer = "--appliquer" in sys.argv[1:]
    ADRESSE, CLE = acces_stockage()
    objets = [
        (o["bucket_id"], o["name"])
        for o in lignes(f"""
          select bucket_id, name from storage.objects
          where bucket_id = any({tableau(BUCKETS)})
            and lower(name) ~ '\\.(jpe?g|png)$'
          order by bucket_id, name;
        """)
    ]
    print(f"{len(objets)} photos dans {', '.join(BUCKETS)}. Téléchargement…")
    with ThreadPoolExecutor(max_workers=4) as file:
        list(file.map(lambda o: telecharger(o, ORIGINAUX), objets))

    shutil.rmtree(PROPRES, ignore_errors=True)
    sortie = subprocess.run(
        ["dart", os.path.join(ICI, "nettoyer_photos.dart"), ORIGINAUX, PROPRES],
        capture_output=True, text=True, check=True,
    ).stdout
    a_remplacer = [l for l in sortie.splitlines() if l.strip()]
    print(f"{len(a_remplacer)} photos portent des métadonnées.")
    if not appliquer:
        print("Essai seulement : relancer avec --appliquer pour les remplacer.")
        return

    with ThreadPoolExecutor(max_workers=4) as file:
        erreurs = [
            (r, e) for r, e in zip(a_remplacer, file.map(remplacer, a_remplacer)) if e
        ]
    print(f"{len(a_remplacer) - len(erreurs)} remplacées et vérifiées.")
    for relatif, erreur in erreurs:
        print(f"  ÉCHEC {relatif} : {erreur}")
    if erreurs:
        sys.exit(1)


if __name__ == "__main__":
    main()
