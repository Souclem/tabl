#!/usr/bin/env python3
"""Remplit la Constellation d'un compte avec ~300 restaurants dans 55 villes
du monde (le jeu d'exemple du prototype, scripts/donnees/constellation_monde
.json), pour voir comment elle rend — ou l'efface.

Ce qui est créé, pour le compte donné seulement :
  - en Belgique, de vrais restaurants de l'annuaire, pris autour de chaque
    ville ; ailleurs (l'annuaire n'a que la Belgique), des restaurants
    inventés, créés par ce compte ;
  - un souvenir par repas (≈ 970), daté du premier repas du jeu puis au
    hasard jusqu'à aujourd'hui. Des souvenirs du passé, jamais dans le
    Feed, en audience « Seulement… » sans personne : le compte seul les
    voit (sa Constellation, son profil) ; une photo de démonstration
    chacun (dossier demo/ du stockage, voir photos_demo.py).

Tout est marqué par un horodatage repère (cree_le = 2001-02-03) pour être
effacé sans toucher au reste.

Usage, depuis la racine du dépôt (projet lié par `supabase link`) :
  python3 scripts/constellation_demo.py                     # le compte de Martin
  python3 scripts/constellation_demo.py --email autre@exemple.be
  python3 scripts/constellation_demo.py --effacer
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import unicodedata
import uuid
from datetime import date, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from supabase_cli import executer, lignes, tableau, texte  # noqa: E402

ICI = os.path.dirname(os.path.abspath(__file__))
JEU = os.path.join(ICI, "donnees", "constellation_monde.json")
EMAIL_MARTIN = "lonneuxclement6@gmail.com"
REPERE = "2001-02-03 00:00:00+00"
AUJOURDHUI = date(2026, 11, 3)
EMOTIONS = ["😍", "🤩", "🙂", "😐"]
POIDS_EMOTIONS = [25, 25, 35, 15]
TAILLE_LOT = 400

# L'annuaire (lieux_reference) couvre la Belgique : ses villes y prennent
# de vrais restaurants.
BELGIQUE = (49.45, 51.55, 2.5, 6.45)  # sud, nord, ouest, est


def normaliser(t: str) -> str:
    s = unicodedata.normalize("NFD", t.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn").strip()


def compte(email: str) -> str:
    trouves = lignes(f"""
      select p.id from public.profils p join auth.users u on u.id = p.id
      where lower(u.email) = lower({texte(email)});
    """)
    if not trouves:
        sys.exit(f"Aucun compte Tabl pour {email}.")
    return trouves[0]["id"]


def inserer(table: str, colonnes: str, valeurs: list[str], suffixe: str = "") -> None:
    for debut in range(0, len(valeurs), TAILLE_LOT):
        lot = ",\n".join(valeurs[debut:debut + TAILLE_LOT])
        executer(f"insert into {table} ({colonnes}) values\n{lot}\n{suffixe};")
    print(f"  {table} : {len(valeurs)}")


def effacer(profil: str) -> None:
    executer(f"""
      delete from public.souvenirs
        where auteur_id = '{profil}' and cree_le = '{REPERE}';
      -- Les restaurants inventés, s'ils ne servent plus à personne.
      delete from public.restaurants r
        where r.cree_par = '{profil}' and r.cree_le = '{REPERE}'
          and not exists (select 1 from public.souvenirs s where s.restaurant_id = r.id);
    """)
    print("Effacé.")


def vrais_restaurants(lat: float, lon: float, nombre: int, graine: str) -> list[dict]:
    """De vrais restaurants de l'annuaire à moins de ~3 km, toujours les
    mêmes pour une même ville."""
    dlat, dlon = 0.027, 0.042
    return lignes(f"""
      select fsq_place_id, latitude, longitude from public.lieux_reference
      where latitude between {lat - dlat} and {lat + dlat}
        and longitude between {lon - dlon} and {lon + dlon}
      order by md5(fsq_place_id || {texte(graine)})
      limit {nombre};
    """)


def remplir(profil: str) -> None:
    hasard = random.Random(20261103)
    villes = json.load(open(JEU))
    photos = [o["name"] for o in lignes(
        "select name from storage.objects "
        "where bucket_id = 'souvenirs' and name like 'demo/%' and name ~* '\\.(jpe?g|png)$';"
    )]
    if not photos:
        sys.exit("Aucune photo de démonstration (lancer d'abord scripts/photos_demo.py).")

    inventes, fsq, souvenirs = [], [], []
    for v in villes:
        restos = v["restos"]
        lat = sum(r["lat"] for r in restos) / len(restos)
        lon = sum(r["lon"] for r in restos) / len(restos)
        sud, nord, ouest, est = BELGIQUE
        reels = vrais_restaurants(lat, lon, len(restos), v["nom"]) \
            if sud <= lat <= nord and ouest <= lon <= est else []
        for i, r in enumerate(restos):
            if i < len(reels):
                cle = ("fsq", reels[i]["fsq_place_id"])
                fsq.append(reels[i]["fsq_place_id"])
            else:
                ident = str(uuid.UUID(int=hasard.getrandbits(128)))
                cle = ("id", ident)
                inventes.append(
                    f"('{ident}', {texte(r['nom'])}, {texte(v['nom'])}, {r['lat']}, {r['lon']}, "
                    f"'{{}}', {texte(normaliser(r['nom']))}, '{profil}', '{REPERE}')"
                )
            premiere = date.fromisoformat(r["premiere"][:10])
            jours = max(1, (AUJOURDHUI - premiere).days)
            dates = [premiere] + sorted(
                premiere + timedelta(days=hasard.randrange(jours)) for _ in range(r["repas"] - 1)
            )
            for d in dates:
                souvenirs.append((cle, d))

    print(f"{len(villes)} villes · {len(inventes) + len(fsq)} restaurants · {len(souvenirs)} repas")
    if fsq:
        executer(
            "insert into public.restaurants "
            "(nom, ville, adresse, latitude, longitude, categories, fsq_place_id, nom_recherche) "
            "select l.nom, coalesce(l.ville, ''), l.adresse, l.latitude, l.longitude, "
            "l.categories, l.fsq_place_id, l.nom_recherche from public.lieux_reference l "
            f"where l.fsq_place_id = any({tableau(fsq)}) on conflict (fsq_place_id) do nothing;"
        )
        print(f"  restaurants de l'annuaire : {len(set(fsq))}")
    inserer(
        "public.restaurants",
        "id, nom, ville, latitude, longitude, categories, nom_recherche, cree_par, cree_le",
        inventes,
    )
    ids = {l["fsq_place_id"]: l["id"] for l in lignes(
        f"select id, fsq_place_id from public.restaurants where fsq_place_id = any({tableau(fsq)});"
    )} if fsq else {}
    valeurs = []
    for (sorte, cle), d in souvenirs:
        resto = ids.get(cle) if sorte == "fsq" else cle
        if resto is None:
            continue
        valeurs.append(
            f"('{profil}', '{resto}', {texte(hasard.choices(EMOTIONS, weights=POIDS_EMOTIONS)[0])}, "
            f"'{hasard.choice(['midi', 'soir'])}', '{d.isoformat()}', 'publie', 'seulement', "
            f"true, true, {texte(hasard.choice(photos))}, '{REPERE}')"
        )
    inserer(
        "public.souvenirs",
        "auteur_id, restaurant_id, emotion, moment, date_visite, statut, visibilite, "
        "est_souvenir, jour_connu, photo_url, cree_le",
        valeurs,
    )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--email", default=EMAIL_MARTIN)
    p.add_argument("--effacer", action="store_true")
    args = p.parse_args()
    profil = compte(args.email)
    # Toujours repartir du même jeu : on efface d'abord ce qui existe.
    effacer(profil)
    if not args.effacer:
        remplir(profil)


if __name__ == "__main__":
    main()
