#!/usr/bin/env python3
"""Importe (ou met à jour) l'annuaire des lieux de restauration dans Supabase.

Source : Foursquare OS Places (licence Apache 2.0), sur Hugging Face —
https://huggingface.co/datasets/foursquare/fsq-os-places
Nouvelle version chaque mois : relancer ce script pour rafraîchir
l'annuaire (nouveaux lieux ajoutés, fiches mises à jour, lieux fermés
retirés). Les restaurants déjà entrés dans Tabl (`restaurants`) ne sont
jamais touchés.

Prérequis (une seule fois) :
  - un jeton Hugging Face avec accès au dataset, dans ~/.config/tabl/hf_token
  - python3 -m venv scripts/.venv && scripts/.venv/bin/pip install duckdb
  - le projet lié : `supabase link` (déjà fait sur ce Mac)

Usage :
  scripts/.venv/bin/python scripts/importer_annuaire.py            # Belgique
  scripts/.venv/bin/python scripts/importer_annuaire.py BE FR NL   # plusieurs pays
  ... --release dt=2026-11-12   # une version précise (sinon la plus récente)
"""
import argparse
import json
import os
import sys
import tempfile
import urllib.request

import duckdb

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from supabase_cli import executer_fichier as executer, tableau as sql_tableau, texte as sql_texte  # noqa: E402

DATASET = "foursquare/fsq-os-places"
TAILLE_LOT = 4000


def derniere_release(jeton: str) -> str:
    requete = urllib.request.Request(
        f"https://huggingface.co/api/datasets/{DATASET}/tree/main/release",
        headers={"Authorization": f"Bearer {jeton}"},
    )
    with urllib.request.urlopen(requete, timeout=30) as reponse:
        dossiers = [e["path"].split("/")[-1] for e in json.load(reponse)]
    return sorted(d for d in dossiers if d.startswith("dt="))[-1]


def main() -> None:
    arguments = argparse.ArgumentParser()
    arguments.add_argument("pays", nargs="*", default=["BE"])
    arguments.add_argument("--release")
    options = arguments.parse_args()
    pays = [p.upper() for p in options.pays]

    jeton = open(os.path.expanduser("~/.config/tabl/hf_token")).read().strip()
    release = options.release or derniere_release(jeton)
    print(f"Version {release}, pays : {', '.join(pays)}")

    connexion = duckdb.connect()
    connexion.sql("INSTALL httpfs; LOAD httpfs;")
    connexion.sql(f"CREATE SECRET hf (TYPE huggingface, TOKEN '{jeton}')")
    liste_pays = ",".join(sql_texte(p) for p in pays)
    lignes = connexion.sql(f"""
      SELECT fsq_place_id, name, address, locality, postcode, country,
             latitude, longitude,
             list_distinct(list_transform(fsq_category_labels,
                                          x -> split_part(x, ' > ', -1))),
             date_refreshed
      FROM read_parquet('hf://datasets/{DATASET}/release/{release}/places/parquet/*.parquet')
      WHERE country IN ({liste_pays})
        AND date_closed IS NULL
        AND name IS NOT NULL AND latitude IS NOT NULL AND longitude IS NOT NULL
        AND list_has_any(list_transform(fsq_category_labels,
                                        x -> split_part(x, ' > ', 1)),
                         ['Dining and Drinking'])
    """).fetchall()
    print(f"{len(lignes)} lieux ouverts à importer")

    with tempfile.TemporaryDirectory() as dossier:
        def ecrire(nom: str, contenu: str) -> str:
            chemin = os.path.join(dossier, nom)
            with open(chemin, "w") as fichier:
                fichier.write(contenu)
            return chemin

        # 1. Table de transit, remplie par lots.
        executer(ecrire("debut.sql", """
          drop table if exists public.lieux_reference_import;
          create table public.lieux_reference_import
            (like public.lieux_reference including defaults);
          -- RLS sans aucune policy : invisible et non modifiable depuis
          -- l'app pendant toute la durée de l'import.
          alter table public.lieux_reference_import enable row level security;
        """))
        colonnes = ("fsq_place_id,nom,adresse,ville,code_postal,pays,latitude,"
                    "longitude,categories,rafraichi_le,nom_recherche")
        for debut in range(0, len(lignes), TAILLE_LOT):
            valeurs = ",\n".join(
                f"({sql_texte(l[0])},{sql_texte(l[1])},{sql_texte(l[2])},"
                f"{sql_texte(l[3])},{sql_texte(l[4])},{sql_texte(l[5])},"
                f"{l[6]},{l[7]},{sql_tableau(l[8])},{sql_texte(l[9])},'')"
                for l in lignes[debut:debut + TAILLE_LOT]
            )
            executer(ecrire("lot.sql",
                f"insert into public.lieux_reference_import ({colonnes}) "
                f"values\n{valeurs}\non conflict do nothing;"))
            print(f"  {min(debut + TAILLE_LOT, len(lignes))}/{len(lignes)}")

        # 2. Bascule : mise à jour, ajout, retrait des lieux disparus
        #    (fermés ou supprimés de la source) pour ces pays.
        executer(ecrire("fin.sql", f"""
          insert into public.lieux_reference ({colonnes})
          select {colonnes} from public.lieux_reference_import
          on conflict (fsq_place_id) do update set
            nom = excluded.nom, adresse = excluded.adresse,
            ville = excluded.ville, code_postal = excluded.code_postal,
            pays = excluded.pays, latitude = excluded.latitude,
            longitude = excluded.longitude, categories = excluded.categories,
            rafraichi_le = excluded.rafraichi_le, nom_recherche = '';
          delete from public.lieux_reference l
          where l.pays in ({liste_pays})
            and not exists (select 1 from public.lieux_reference_import i
                            where i.fsq_place_id = l.fsq_place_id);
          update public.lieux_reference
            set nom_recherche = lower(extensions.unaccent(nom))
            where nom_recherche = '';
          drop table public.lieux_reference_import;
          analyze public.lieux_reference;
        """))
    print("Annuaire à jour.")


if __name__ == "__main__":
    main()
