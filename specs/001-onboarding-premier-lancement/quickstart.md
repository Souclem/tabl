# Quickstart — Validation : Parcours de présentation à la première ouverture

Guide de validation manuelle et automatisée. Pour le détail des
interfaces, voir [`data-model.md`](./data-model.md) et
[`contracts/`](./contracts/) ; pour le détail des tâches
d'implémentation, voir `tasks.md` (généré par `/speckit-tasks`).

## Prérequis

- Flutter SDK installé, dépôt cloné, branche `001-onboarding-premier-lancement`
- Dépendances installées dans les 3 zones :
  ```
  cd app && flutter pub get
  cd ../packages/tabl_ui && flutter pub get
  cd ../tabl_core && flutter pub get
  ```
- Un simulateur/émulateur iOS ou Android disponible

## Validation automatisée

```
flutter analyze                                   # à la racine du dépôt
cd packages/tabl_core && flutter test              # EtatOnboardingPreferences
cd ../tabl_ui && flutter test                      # EtapeOnboarding + mur_ui_metier_test.dart
cd ../../app && flutter test                       # EcranOnboarding + choix de l'écran initial
```

Résultat attendu : toutes les commandes passent sans erreur, y compris
`mur_ui_metier_test.dart` (aucune dépendance ajoutée à `tabl_ui`).

## Validation manuelle — parcours complet (US1)

1. Installer l'app sur un appareil/simulateur n'ayant jamais lancé Tabl
   (ou effacer les données de l'app pour repartir de zéro).
2. Lancer l'app.
3. **Attendu** : l'étape "Bienvenue" s'affiche, pas l'écran de connexion
   ni d'inscription.
4. Progresser étape par étape jusqu'à la fin.
5. **Attendu** : les étapes s'enchaînent dans l'ordre Bienvenue → Profil
   → Feed → Réseau privé entre amis → Publication d'un souvenir, chacune
   avec son visuel et son texte, avec le bouton "Passer" visible en
   permanence en bas de l'écran.
6. Après la dernière étape, **attendu** : arrivée sur l'écran
   d'inscription (`EcranInscription`).
7. Chronométrer l'étape 2 à l'étape 6 (de l'affichage de "Bienvenue" à
   l'arrivée sur l'inscription). **Attendu** (SC-003) : moins de 60
   secondes pour un parcours lu à un rythme normal.

## Validation manuelle — bouton "Passer" (US2)

1. Repartir d'une app sans onboarding vu (réinstaller ou effacer les
   données).
2. Sur l'étape "Bienvenue" (1/5), appuyer sur "Passer".
3. **Attendu** : arrivée immédiate sur l'écran d'inscription, sans avoir
   vu les étapes 2 à 5.
4. Répéter en effaçant les données, cette fois en progressant jusqu'à
   l'étape 5 avant d'appuyer sur "Passer".
5. **Attendu** : même résultat, arrivée sur l'écran d'inscription.

## Validation manuelle — non-réapparition (US3)

1. Terminer (ou passer) le parcours une première fois.
2. Fermer complètement l'app (pas juste mise en arrière-plan).
3. Rouvrir l'app.
4. **Attendu** : l'app démarre directement sur l'écran de connexion
   (`EcranConnexion`), le parcours ne réapparaît pas.

## Validation manuelle — hors-ligne (FR-007, SC-005)

1. Activer le mode avion sur l'appareil.
2. Repartir d'une app sans onboarding vu (réinstaller ou effacer les
   données) puis lancer l'app.
3. **Attendu** : le parcours complet (affichage, progression, "Passer",
   arrivée sur l'inscription) fonctionne sans aucun message d'erreur
   réseau ni blocage.

## Cas limite à vérifier — fermeture en cours de parcours

1. Repartir d'une app sans onboarding vu.
2. Avancer jusqu'à l'étape 3, puis fermer complètement l'app sans
   appuyer sur "Passer" ni atteindre la fin.
3. Rouvrir l'app.
4. **Attendu** : le parcours redémarre à l'étape 1 (voir Assumptions du
   spec — pas de reprise à l'étape interrompue).
