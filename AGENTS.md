# Consignes pour les agents

Avant tout travail sur Tabl, lire dans cet ordre :

1. `CLAUDE.md` : structure du projet, organisation du code, commandes,
   conventions (tout en français).
2. `docs/regles.md` : règles nées de bugs réels, obligatoires. En particulier
   la liste des **gestes réservés au propriétaire du projet** (base de prod,
   déploiements, builds TestFlight, scripts qui écrivent dans la vraie base,
   push sur `main`) : les préparer, puis signaler ce qu'il reste à lancer.
3. `docs/decisions.md` : la section de la fonctionnalité touchée, et la liste
   des décisions en attente.

Travailler sur une branche, jamais sur `main`. Ne commiter qu'avec
`flutter test` vert et `flutter analyze` propre.
