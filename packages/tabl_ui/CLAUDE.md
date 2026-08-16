# tabl_ui — design system de Tabl

Ce package contient **uniquement du visuel**. C'est le territoire du design :
on peut y travailler sans aucun risque de casser le fonctionnement de l'app.

## Ce qu'on fait ici

- Modifier les couleurs, espacements, arrondis et typographie → `lib/src/theme/tokens.dart`
- Modifier l'apparence d'un composant → `lib/src/components/`
- Créer un nouveau composant visuel

## Ce qu'on ne fait JAMAIS ici

- Un appel réseau, une requête Supabase, une lecture de base
- Une règle métier (calcul de badge, formatage de date, validation)
- Ajouter une dépendance dans `pubspec.yaml`

Ces trois interdits ne sont pas des préférences de style : le `pubspec.yaml`
ne déclare que `flutter`, donc le compilateur **refuse** tout import de code
métier. Le test `test/mur_ui_metier_test.dart` échoue si quelqu'un ajoute une
dépendance. Si tu as besoin d'une donnée, ce n'est pas ici que ça se règle :
le composant doit la recevoir en paramètre, et c'est `app/` qui la lui passe.

## Règles d'écriture

1. **Jamais de valeur en dur.** Pas de `Color(0xFF...)`, pas de `EdgeInsets.all(12)`
   dans un composant. Tout vient de `TablTokens`. Si la valeur voulue n'existe
   pas dans les tokens, l'ajouter là-bas d'abord.
2. **Composants purs.** Les données arrivent par le constructeur, les actions
   repartent par des callbacks (`VoidCallback onTapAuteur`). Un composant ne
   décide de rien : il affiche et il signale.
3. **Rien de pré-mâché à faire côté UI.** Un composant reçoit
   `dateLisible: 'il y a 2 h'`, pas un `DateTime` à formater — décider du format
   est une règle métier.
4. **Tout composant public s'exporte** depuis `lib/tabl_ui.dart`.
5. **Le français** pour les noms de classes, paramètres et commentaires, comme
   le reste du projet.

## Vérifier son travail

```
flutter test       # dont le garde-fou du mur
flutter analyze
```
