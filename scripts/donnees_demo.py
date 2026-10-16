#!/usr/bin/env python3
"""
from __future__ import annotations
Remplit la base avec un grand jeu de données FICTIVES, pour tester la
carte, les filtres et le Feed en conditions réelles — ou l'efface.

Ce qui est créé (toujours le même jeu : graine aléatoire fixe) :
  - ~300 comptes fictifs (e-mails @demo.tabl.invalid, aucun mot de passe
    utilisable : personne ne peut s'y connecter), 30 % de profils publics ;
  - un graphe d'abonnements réaliste, dont ~80 personnes suivies par
    `clem` et ~40 qui le suivent (dont quelques demandes en attente) ;
  - ~1 500 restaurants réels de l'annuaire (surtout Liège et Bruxelles),
    avec une popularité très inégale (quelques adresses très fréquentées) ;
  - ~8 000 moments (émotions, midi/soir, impressions, audiences variées),
    des réactions, des commentaires et des amis tagués ;
  - 6 Tables dont `clem` est membre, avec leurs sorties associées ;
  - ~40 moments de `clem` lui-même et ~30 envies.

Tout est marqué pour pouvoir être effacé sans toucher aux vraies données :
comptes par leur domaine d'e-mail, Tables par leur signature, et ce qui
appartient à `clem` par un horodatage repère (2001-01-01).

Usage (depuis la racine du dépôt) :
  scripts/.venv/bin/python scripts/donnees_demo.py            # créer
  scripts/.venv/bin/python scripts/donnees_demo.py --photos   # + photos CC0
  scripts/.venv/bin/python scripts/donnees_demo.py --effacer  # tout effacer
"""
import argparse
import os
import random
import sys
import uuid
from datetime import date, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import photos_demo  # noqa: E402
from supabase_cli import executer, lignes, tableau, texte  # noqa: E402

DOMAINE = "demo.tabl.invalid"
SIGNATURE_TABLE = "Données de démonstration"
REPERE = "2001-01-01 00:00:00+00"
PSEUDO_PRINCIPAL = "clem"
TAILLE_LOT = 1500

PRENOMS = """emma louise alice chloe lea lina mila jade sarah ines julia zoe
camille manon juliette clara eva anna lucie charlotte nora victoria elise
lou margaux noemie pauline marie laura justine celine hugo louis lucas jules
arthur adam victor noah nathan thomas leo raphael gabriel tom maxime antoine
alexandre simon martin baptiste paul romain quentin theo axel julien nicolas
florian mathis sacha robin elias amine youssef mehdi karim sofiane""".split()

LEGENDES = [
    "Le meilleur boulet de Liège, sans discussion.",
    "On y retourne dès que possible.",
    "Service un peu long, mais l'assiette valait le coup.",
    "Petite adresse découverte par hasard.",
    "Anniversaire de Lou, soirée parfaite.",
    "Les desserts sont fous.",
    "Terrasse au soleil, rien à redire.",
    "Un peu cher pour ce que c'est.",
    "Ambiance de folie le samedi soir.",
    "Le chef est venu nous saluer.",
    "Brunch du dimanche, rituel.",
    "La carte des vins est incroyable.",
    "Midi rapide entre deux réunions.",
    "Meilleure pizza de la ville selon moi.",
    "Découverte grâce à Tabl !",
    "Pas convaincu cette fois-ci.",
    "On a pris tout le menu dégustation.",
    "Végé et vraiment savoureux.",
    "Les frites maison, rien que pour ça.",
    "Parfait pour un premier rendez-vous.",
]

IMPRESSIONS = [
    "Assiette · Exceptionnelle",
    "Service · Attentionné",
    "Ambiance · Intime",
    "Ambiance · Festive",
    "Cadre · Élégant",
    "Prix · Correct",
]

EMOTIONS = ["😍", "🤩", "🙂", "😐"]
POIDS_EMOTIONS = [25, 25, 35, 15]

COMMENTAIRES = [
    "Trop envie d'y aller !", "On y va quand ?", "Ah génial, je note.",
    "J'y étais la semaine passée !", "Ça a l'air incroyable 😍",
    "Le meilleur endroit.", "Je confirme, top.", "Tu m'emmènes ?",
]

TABLES = [
    ("Famille", "👨‍👩‍👧"), ("Les copains de l'unif", "🎓"), ("Marbella crew", "🌴"),
    ("Collègues", "💼"), ("Foodies Liège", "🍽️"), ("Brunch du dimanche", "🥞"),
]

# Catégories de restauration (pas les bars ni les boulangeries seules).
CATEGORIES_RESTO = [
    "Restaurant", "Belgian Restaurant", "French Restaurant", "Italian Restaurant",
    "Pizzeria", "Brasserie", "Bistro", "Asian Restaurant", "Chinese Restaurant",
    "Japanese Restaurant", "Sushi Restaurant", "Thai Restaurant",
    "Vietnamese Restaurant", "Indian Restaurant", "Turkish Restaurant",
    "Lebanese Restaurant", "Middle Eastern Restaurant", "Greek Restaurant",
    "Tapas Restaurant", "Spanish Restaurant", "Burger Joint", "Steakhouse",
    "Seafood Restaurant", "Vegan and Vegetarian Restaurant", "Gastropub",
    "Mexican Restaurant", "African Restaurant", "Moroccan Restaurant",
    "Friterie", "Café", "Coffee Shop", "Breakfast Spot", "Cocktail Bar",
    "Wine Bar", "Mediterranean Restaurant", "Korean Restaurant",
]

REGIONS = {
    # nom : (sud, ouest, nord, est, nombre de restaurants)
    "liege": (50.58, 5.48, 50.70, 5.66, 750),
    "bruxelles": (50.79, 4.28, 50.91, 4.46, 500),
    "belgique": (49.50, 2.50, 51.50, 6.40, 300),
}


def inserer(table: str, colonnes: str, valeurs: list[str], suffixe: str = "") -> None:
    for debut in range(0, len(valeurs), TAILLE_LOT):
        lot = ",\n".join(valeurs[debut:debut + TAILLE_LOT])
        executer(f"insert into {table} ({colonnes}) values\n{lot}\n{suffixe};")
    print(f"  {table} : {len(valeurs)}")


def effacer() -> None:
    print("Effacement des données de démonstration…")
    executer(f"""
      -- Ce qui appartient au vrai compte, marqué par l'horodatage repère.
      delete from public.souvenirs where cree_le = '{REPERE}';
      delete from public.restaurants_sauvegardes where cree_le = '{REPERE}';
      -- Tables fictives (leur créateur fictif ne peut pas disparaître
      -- avant elles : cree_par est obligatoire).
      delete from public.tables where signature = {texte(SIGNATURE_TABLE)};
      -- Comptes fictifs : tout le reste suit en cascade (profils,
      -- abonnements, moments, réactions, commentaires...).
      delete from auth.users where email like '%@{DOMAINE}';
      -- Restaurants entrés dans Tabl uniquement pour la démo, plus
      -- utilisés par personne.
      update public.profils set photo_url = null
        where photo_url like '{photos_demo.DOSSIER_STOCKAGE}/%';
      delete from public.restaurants r
      where r.cree_par is null and r.fsq_place_id is not null
        and not exists (select 1 from public.souvenirs s where s.restaurant_id = r.id)
        and not exists (select 1 from public.restaurants_sauvegardes e where e.restaurant_id = r.id)
        and not exists (select 1 from public.table_propositions p where p.restaurant_id = r.id);
    """)
    photos_demo.effacer_stockage()
    print("Fait.")


def creer() -> None:
    hasard = random.Random(42)
    aujourd_hui = date.today()

    moi = lignes(f"select id from public.profils where pseudo = {texte(PSEUDO_PRINCIPAL)}")
    if not moi:
        sys.exit(f"Profil « {PSEUDO_PRINCIPAL} » introuvable.")
    moi = moi[0]["id"]
    deja = lignes(f"select count(*) n from auth.users where email like '%@{DOMAINE}'")[0]["n"]
    if int(deja) > 0:
        sys.exit("Des données de démonstration existent déjà : lancer d'abord --effacer.")

    # --- Restaurants : tirés de l'annuaire, par région -------------------
    print("Choix des restaurants dans l'annuaire…")
    restaurants = []  # (fsq, region)
    for region, (sud, ouest, nord, est, nombre) in REGIONS.items():
        for l in lignes(f"""
          select fsq_place_id from public.lieux_reference
          where latitude between {sud} and {nord} and longitude between {ouest} and {est}
            and categories && {tableau(CATEGORIES_RESTO)}
            and coalesce(rafraichi_le, date '2000-01-01') >= date '2022-01-01'
          order by md5(fsq_place_id || 'tabl-demo') limit {nombre}
        """):
            restaurants.append((l["fsq_place_id"], region))
    existants = {
        l["fsq_place_id"]: l["id"]
        for l in lignes("select id, fsq_place_id from public.restaurants where fsq_place_id is not null")
    }
    id_resto = {fsq: existants.get(fsq) or str(uuid.uuid4()) for fsq, _ in restaurants}
    nouveaux = [fsq for fsq, _ in restaurants if fsq not in existants]
    # Popularité très inégale : quelques adresses concentrent les visites.
    par_region: dict[str, list[tuple[str, float]]] = {}
    for rang, (fsq, region) in enumerate(restaurants):
        par_region.setdefault(region, []).append((id_resto[fsq], 1 / (1 + rang % 200) ** 0.9))

    def resto_dans(region: str) -> str:
        choix = par_region[region]
        return hasard.choices([c[0] for c in choix], weights=[c[1] for c in choix])[0]

    # --- Comptes fictifs ----------------------------------------------
    print("Génération…")
    personnes = []
    pseudos = set()
    for i in range(300):
        pseudo = f"{hasard.choice(PRENOMS)}.{hasard.choice('abcdefghijlmnoprstv')}"
        while pseudo in pseudos:
            pseudo = f"{hasard.choice(PRENOMS)}{hasard.randint(1, 99)}"
        pseudos.add(pseudo)
        region = hasard.choices(["liege", "bruxelles", "belgique"], weights=[70, 20, 10])[0]
        personnes.append({
            "id": str(uuid.uuid4()), "pseudo": pseudo, "region": region,
            "prive": hasard.random() < 0.7, "email": f"demo{i:03d}@{DOMAINE}",
        })
    ids = [p["id"] for p in personnes]

    # --- Abonnements ------------------------------------------------
    abonnements = {}  # (suiveur, suivi) -> statut
    for p in personnes:
        for autre in hasard.sample(personnes, hasard.randint(5, 25)):
            if autre["id"] != p["id"]:
                abonnements[(p["id"], autre["id"])] = "accepte"
    suivis_par_moi = hasard.sample(personnes, 80)
    for p in suivis_par_moi:
        abonnements[(moi, p["id"])] = "accepte"
    for p in hasard.sample(personnes, 40):
        abonnements[(p["id"], moi)] = "accepte"
    for p in hasard.sample([p for p in personnes if (p["id"], moi) not in abonnements], 5):
        abonnements[(p["id"], moi)] = "en_attente"
    abonnes_de = {}
    for (suiveur, suivi), statut in abonnements.items():
        if statut == "accepte":
            abonnes_de.setdefault(suivi, []).append(suiveur)

    # --- Moments --------------------------------------------------
    souvenirs, audiences, tags, reactions, commentaires = [], [], [], [], []

    def moment(auteur: str, region: str, repere: bool = False) -> dict:
        jour = aujourd_hui - timedelta(days=int(hasard.triangular(0, 540, 30)))
        visibilite = hasard.choices(["tout_le_monde", "seulement", "sauf"], weights=[85, 10, 5])[0]
        s = {
            "id": str(uuid.uuid4()), "auteur": auteur, "resto": resto_dans(region),
            "emotion": hasard.choices(EMOTIONS, weights=POIDS_EMOTIONS)[0],
            "moment": "midi" if hasard.random() < 0.45 else "soir",
            "date": jour.isoformat(),
            "legende": hasard.choice(LEGENDES) if hasard.random() < 0.6 else None,
            "impressions": hasard.sample(IMPRESSIONS, hasard.randint(0, 3)),
            "visibilite": visibilite, "repere": repere,
        }
        souvenirs.append(s)
        abonnes = abonnes_de.get(auteur, [])
        if visibilite in ("seulement", "sauf") and abonnes:
            for personne in hasard.sample(abonnes, min(len(abonnes), hasard.randint(1, 6))):
                audiences.append((s["id"], personne))
        if hasard.random() < 0.2:
            for personne in hasard.sample(ids, hasard.randint(1, 3)):
                if personne != auteur:
                    tags.append((s["id"], personne))
        for personne in set(hasard.sample(abonnes or ids, min(len(abonnes or ids), hasard.randint(0, 10)))):
            reactions.append((s["id"], personne))
        if hasard.random() < 0.15:
            commentaires.append((s["id"], hasard.choice(abonnes or ids), hasard.choice(COMMENTAIRES)))
        return s

    for p in personnes:
        for _ in range(hasard.randint(10, 45)):
            region = p["region"] if hasard.random() < 0.85 else hasard.choice(list(REGIONS))
            moment(p["id"], region)
    for _ in range(40):
        moment(moi, "liege" if hasard.random() < 0.8 else "bruxelles", repere=True)

    # --- Tables ---------------------------------------------------
    tables, membres, associations = [], [], []
    for nom, emoji in TABLES:
        createur = hasard.choice(suivis_par_moi)
        table_id = str(uuid.uuid4())
        tables.append((table_id, nom, emoji, createur["id"]))
        groupe = {createur["id"]} | {p["id"] for p in hasard.sample(suivis_par_moi, hasard.randint(4, 9))}
        for personne in groupe:
            membres.append((table_id, personne, personne == createur["id"], False))
        membres.append((table_id, moi, False, True))
        sorties = [s for s in souvenirs if s["auteur"] in groupe or s["auteur"] == moi]
        for s in hasard.sample(sorties, min(len(sorties), 40)):
            associations.append((s["id"], table_id, s["auteur"]))

    # --- Mes envies : visitées par mes amis ou jamais visitées ----------
    envies = set(hasard.sample(sorted({r for r, _ in par_region["liege"]}), 30))

    # --- Écriture -------------------------------------------------
    print("Écriture en base…")
    inserer(
        "auth.users",
        "instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, "
        "raw_app_meta_data, raw_user_meta_data, created_at, updated_at, "
        "confirmation_token, recovery_token, email_change_token_new, email_change",
        [
            f"('00000000-0000-0000-0000-000000000000', '{p['id']}', 'authenticated', "
            f"'authenticated', {texte(p['email'])}, '', now(), "
            "'{\"provider\":\"email\",\"providers\":[\"email\"]}', '{}', now(), now(), '', '', '', '')"
            for p in personnes
        ],
    )
    inserer("public.profils", "id, pseudo, est_prive",
            [f"('{p['id']}', {texte(p['pseudo'])}, {str(p['prive']).lower()})" for p in personnes])
    inserer("public.abonnements", "suiveur_id, suivi_id, statut, cree_le",
            [f"('{a}', '{b}', '{statut}', '{REPERE}')" for (a, b), statut in abonnements.items()])
    if nouveaux:
        executer(
            "insert into public.restaurants "
            "(id, nom, ville, adresse, latitude, longitude, categories, fsq_place_id, nom_recherche) "
            "select v.id::uuid, l.nom, coalesce(l.ville, ''), l.adresse, l.latitude, l.longitude, "
            "l.categories, l.fsq_place_id, l.nom_recherche "
            "from (values " + ",".join(f"({texte(f)}, '{id_resto[f]}')" for f in nouveaux) + ") "
            "v(fsq, id) join public.lieux_reference l on l.fsq_place_id = v.fsq "
            "on conflict (fsq_place_id) do nothing;"
        )
        print(f"  public.restaurants : {len(nouveaux)}")
    inserer(
        "public.souvenirs",
        "id, auteur_id, restaurant_id, legende, emotion, moment, date_visite, "
        "impressions, statut, visibilite, cree_le",
        [
            f"('{s['id']}', '{s['auteur']}', '{s['resto']}', {texte(s['legende'])}, "
            f"{texte(s['emotion'])}, '{s['moment']}', '{s['date']}', {tableau(s['impressions'])}, "
            f"'publie', '{s['visibilite']}', "
            + (f"'{REPERE}'" if s["repere"] else f"'{s['date']} 20:00:00+00'") + ")"
            for s in souvenirs
        ],
    )
    inserer("public.souvenirs_audience", "souvenir_id, profil_id",
            [f"('{a}', '{b}')" for a, b in set(audiences)])
    inserer("public.souvenirs_amis_tagues", "souvenir_id, profil_id",
            [f"('{a}', '{b}')" for a, b in set(tags)])
    inserer("public.reactions", "souvenir_id, profil_id",
            [f"('{a}', '{b}')" for a, b in set(reactions)])
    inserer("public.commentaires", "souvenir_id, auteur_id, texte",
            [f"('{a}', '{b}', {texte(t)})" for a, b, t in commentaires])
    inserer("public.tables", "id, nom, emoji, signature, cree_par",
            [f"('{i}', {texte(n)}, {texte(e)}, {texte(SIGNATURE_TABLE)}, '{c}')" for i, n, e, c in tables])
    inserer("public.membres_table", "table_id, profil_id, statut, est_admin, rejoint_le",
            [f"('{t}', '{p}', 'active', {str(admin).lower()}, "
             + (f"'{REPERE}'" if moi_ else "now()") + ")" for t, p, admin, moi_ in membres])
    inserer("public.associations_experience_table", "souvenir_id, table_id, ajoute_par",
            [f"('{s}', '{t}', '{a}')" for s, t, a in associations])
    inserer("public.restaurants_sauvegardes", "restaurant_id, profil_id, cree_le",
            [f"('{r}', '{moi}', '{REPERE}')" for r in envies], "on conflict do nothing")
    executer("analyze;")
    print(f"Terminé : {len(personnes)} comptes, {len(souvenirs)} moments, "
          f"{len(restaurants)} restaurants, {len(tables)} Tables, {len(envies)} envies.")


def photos() -> None:
    """Ajoute une photo à chaque profil fictif et à chaque moment de
    démonstration (portraits et plats CC0, partagés entre plusieurs)."""
    # Les photos du cache, déjà triées à la main (photos_demo.rejeter) ;
    # téléchargées seulement si le cache est vide.
    portraits = photos_demo.photos_en_cache("portrait") or photos_demo.collecter(
        "portrait", photos_demo.RECHERCHES_PORTRAITS, 120, (320, 320)
    )
    plats = photos_demo.photos_en_cache("plat") or photos_demo.collecter(
        "plat", photos_demo.RECHERCHES_PLATS, 150, (1080, 1146)
    )
    if not portraits or not plats:
        sys.exit("Aucune photo récupérée (Openverse indisponible ?).")
    print("Téléversement…")
    photos_demo.televerser("portrait", "avatars")
    photos_demo.televerser("plat", "souvenirs")
    dossier = photos_demo.DOSSIER_STOCKAGE

    def tableau_sql(noms: list[str]) -> str:
        return "array[" + ",".join(texte(f"{dossier}/{n}") for n in noms) + "]"

    # Répartition stable : chaque profil et chaque moment tire toujours la
    # même photo (dérivée de son identifiant).
    executer(f"""
      -- Les personnes que suit le compte principal d'abord, chacune avec
      -- un portrait différent : jamais deux fois le même visage sur sa
      -- carte. Les autres se partagent ensuite les portraits.
      with suivis as (
        select a.suivi_id as id, row_number() over (order by a.suivi_id) as n
        from public.abonnements a
        join public.profils moi on moi.id = a.suiveur_id
          and moi.pseudo = {texte(PSEUDO_PRINCIPAL)}
        where a.statut = 'accepte'
          and a.suivi_id in (select id from auth.users where email like '%@{DOMAINE}')
      )
      update public.profils p set photo_url = (
        {tableau_sql(portraits)}
      )[1 + (s.n - 1) % {len(portraits)}]
      from suivis s where p.id = s.id;
      update public.profils p set photo_url = (
        {tableau_sql(portraits)}
      )[1 + abs(hashtext(p.id::text)) % {len(portraits)}]
      where p.photo_url is null
        and p.id in (select id from auth.users where email like '%@{DOMAINE}');
      update public.souvenirs s set photo_url = (
        {tableau_sql(plats)}
      )[1 + abs(hashtext(s.id::text)) % {len(plats)}]
      where s.photo_url is null and (
        s.cree_le = '{REPERE}'
        or s.auteur_id in (select id from auth.users where email like '%@{DOMAINE}')
      );
    """)
    print(f"Terminé : {len(portraits)} portraits, {len(plats)} plats.")


if __name__ == "__main__":
    options = argparse.ArgumentParser()
    options.add_argument("--effacer", action="store_true")
    options.add_argument("--photos", action="store_true")
    arguments = options.parse_args()
    if arguments.effacer:
        effacer()
    elif arguments.photos:
        photos()
    else:
        creer()
