#!/usr/bin/env python3
"""Fabrique app/assets/carte/regions.json : pour chaque province ou région
du monde, son pays et son nom en français, et son contour simplifié. La
Constellation y lit le pays et la région de chaque ville (elle ne les
dessine pas).

Sources (Natural Earth, domaine public), à télécharger à part :
  - ne_10m_admin_1_states_provinces.geojson (provinces, États, départements…)
  - ne_50m_admin_0_countries.geojson (le nom français des pays)

Usage :
  python3 -I scripts/regions_carte.py admin1.geojson pays.geojson app/assets/carte/regions.json

Format : {"noms": [[pays, région, sorte], …], "traces": [[nom, x, y, dx, dy, …], …]}
avec x = longitude × 100, y = latitude × 100, puis les écarts successifs.
"""
from __future__ import annotations

import json
import sys

# Là où les provinces sont trop fines pour regrouper des villes : leurs
# régions (« Île-de-France » plutôt que « Paris », « Val-de-Marne »…).
PAR_REGION = {"France", "Italy", "Spain", "United Kingdom", "Japan"}

REGIONS_FR = {
    # Italie
    "Abruzzo": "Abruzzes", "Apulia": "Pouilles", "Basilicata": "Basilicate",
    "Calabria": "Calabre", "Campania": "Campanie", "Emilia-Romagna": "Émilie-Romagne",
    "Friuli-Venezia Giulia": "Frioul-Vénétie julienne", "Lazio": "Latium",
    "Liguria": "Ligurie", "Lombardia": "Lombardie", "Marche": "Marches",
    "Piemonte": "Piémont", "Sardegna": "Sardaigne", "Sicily": "Sicile",
    "Toscana": "Toscane", "Trentino-Alto Adige": "Trentin-Haut-Adige",
    "Umbria": "Ombrie", "Valle d'Aosta": "Vallée d'Aoste", "Veneto": "Vénétie",
    # Espagne
    "Andalucía": "Andalousie", "Aragón": "Aragon", "Asturias": "Asturies",
    "Canary Is.": "Îles Canaries", "Cantabria": "Cantabrie",
    "Castilla y León": "Castille-et-León", "Castilla-La Mancha": "Castille-La Manche",
    "Cataluña": "Catalogne", "Extremadura": "Estrémadure", "Foral de Navarra": "Navarre",
    "Galicia": "Galice", "Islas Baleares": "Îles Baléares", "Madrid": "Communauté de Madrid",
    "Murcia": "Murcie", "País Vasco": "Pays basque", "Valenciana": "Communauté valencienne",
    # Royaume-Uni (les régions d'Écosse et du pays de Galles, réunies)
    "East": "Est de l'Angleterre", "East Midlands": "Midlands de l'Est",
    "West Midlands": "Midlands de l'Ouest", "Greater London": "Grand Londres",
    "North East": "Nord-Est de l'Angleterre", "North West": "Nord-Ouest de l'Angleterre",
    "South East": "Sud-Est de l'Angleterre", "South West": "Sud-Ouest de l'Angleterre",
    "Yorkshire and the Humber": "Yorkshire", "Northern Ireland": "Irlande du Nord",
    "East Wales": "Pays de Galles", "West Wales and the Valleys": "Pays de Galles",
    "Eastern": "Écosse", "North Eastern": "Écosse", "South Western": "Écosse",
    "Highlands and Islands": "Écosse",
    # Japon
    "Chubu": "Chūbu", "Chugoku": "Chūgoku", "Hokkaido": "Hokkaidō", "Kanto": "Kantō",
    "Kinki": "Kansai", "Kyushu": "Kyūshū", "Tohoku": "Tōhoku",
    # France
    "Guyane française": "Guyane", "Provence-Alpes-Côte-d'Azur": "Provence-Alpes-Côte d'Azur",
}
# Des noms de Natural Earth à reprendre.
NOMS_FR = {"d'Anvers": "Anvers", "Guyane française": "Guyane"}
PAYS_FR = {"République populaire de Chine": "Chine"}

SORTES = {
    "Province": "Province", "State": "État", "Region": "Région",
    "Prefecture": "Préfecture", "Department": "Département",
    "Metropolitan department": "Département", "District": "District",
    "County": "Comté", "Canton": "Canton", "Capital Region": "Région",
}

TOLERANCE = 0.03  # degrés
PETIT = 0.05  # degrés : un îlot plus petit ne garde pas son contour


def simplifier(points: list, tolerance: float) -> list:
    """Douglas-Peucker, sans récursion."""
    if len(points) < 4:
        return points
    garder = [False] * len(points)
    garder[0] = garder[-1] = True
    pile = [(0, len(points) - 1)]
    while pile:
        a, b = pile.pop()
        (ax, ay), (bx, by) = points[a], points[b]
        dx, dy = bx - ax, by - ay
        n = (dx * dx + dy * dy) ** 0.5
        loin, ou = 0.0, -1
        for i in range(a + 1, b):
            px, py = points[i]
            d = abs(dy * (px - ax) - dx * (py - ay)) / n if n else ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
            if d > loin:
                loin, ou = d, i
        if loin > tolerance:
            garder[ou] = True
            pile += [(a, ou), (ou, b)]
    return [p for p, g in zip(points, garder) if g]


def anneaux(geometrie: dict) -> list:
    if geometrie["type"] == "Polygon":
        return [geometrie["coordinates"][0]]
    return [p[0] for p in geometrie["coordinates"]]


def emprise(anneau: list) -> float:
    xs, ys = [p[0] for p in anneau], [p[1] for p in anneau]
    return max(max(xs) - min(xs), max(ys) - min(ys))


def main() -> None:
    admin1, pays_geo, sortie = sys.argv[1:4]
    souverain = lambda p: 1 if p.get("TYPE") in ("Sovereign country", "Country") else 0
    noms_pays: dict[str, dict] = {}
    for f in json.load(open(pays_geo))["features"]:
        p = f["properties"]
        deja = noms_pays.get(p["ADM0_A3"])
        if not deja or souverain(p) > souverain(deja):
            noms_pays[p["ADM0_A3"]] = p

    noms, index, traces = [], {}, []
    for f in json.load(open(admin1))["features"]:
        p, g = f["properties"], f["geometry"]
        if not g:
            continue
        pays = noms_pays.get(p["adm0_a3"])
        nom_pays = PAYS_FR.get(pays["NAME_FR"], pays["NAME_FR"]) if pays else p["admin"]
        if p["admin"] in PAR_REGION and p.get("region"):
            region, sorte = REGIONS_FR.get(p["region"], p["region"]), "Région"
        else:
            nom = p.get("name_fr") or p.get("name") or p.get("gn_name") or nom_pays
            region, sorte = NOMS_FR.get(nom, nom), SORTES.get(p.get("type_en") or "", "Région")
        cle = (nom_pays, region, sorte)
        if cle not in index:
            index[cle] = len(noms)
            noms.append(list(cle))
        tous = anneaux(g)
        plus_grand = max(tous, key=emprise)
        for anneau in tous:
            if anneau is not plus_grand and emprise(anneau) < PETIT:
                continue
            pts = simplifier(anneau, TOLERANCE)
            entiers = []
            for x, y in pts:
                c = (round(x * 100), round(y * 100))
                if not entiers or entiers[-1] != c:
                    entiers.append(c)
            if len(entiers) < 3:
                continue
            trace, px, py = [index[cle]], 0, 0
            for x, y in entiers:
                trace += [x - px, y - py]
                px, py = x, y
            traces.append(trace)
    json.dump({"noms": noms, "traces": traces}, open(sortie, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"{len(noms)} régions, {len(traces)} contours")


if __name__ == "__main__":
    main()
