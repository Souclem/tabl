/**
 * Feuille « Tabl · Retours » : reçoit les messages d'« Aide et contact »
 * envoyés par la fonction Supabase `transmettre-retours`, et les range
 * pour l'équipe.
 *
 * Trois onglets :
 *  - Messages : un message par ligne. Les colonnes de l'app (Reçu le →
 *    Appareil) se remplissent seules ; les colonnes dorées (Statut →
 *    Clos le) sont celles de l'équipe, avec listes déroulantes et
 *    couleurs. Un filtre sur chaque en-tête permet de trier et filtrer.
 *  - Tableau de bord : les comptes par type et statut, et la liste de
 *    ce qui reste à traiter, déjà triée.
 *  - Listes : les choix des listes déroulantes (statuts, priorités,
 *    types, prénoms de l'équipe), à modifier librement.
 *
 * Mise en place, une seule fois :
 *  1. Créer une Google Sheet dans un dossier Drive partagé avec l'équipe
 *     (les captures d'écran seront rangées à côté, avec le même partage).
 *  2. Extensions → Apps Script : remplacer le contenu par ce fichier.
 *  3. Paramètres du projet (roue dentée) → Propriétés du script →
 *     ajouter JETON avec le jeton secret (le même que
 *     FEUILLE_RETOURS_JETON côté Supabase).
 *  4. Choisir la fonction `installer`, Exécuter, accepter les
 *     autorisations : les onglets, colonnes, listes et couleurs se créent.
 *  5. Déployer → Nouveau déploiement → type « Application Web » ;
 *     Exécuter en tant que : moi ; Qui a accès : Tout le monde.
 *     L'URL obtenue va dans FEUILLE_RETOURS_URL côté Supabase.
 *     (« Tout le monde » : sans le jeton, l'adresse ne sert à rien.)
 *
 * Relancer `installer` plus tard est sans risque : les messages et les
 * prénoms de l'équipe sont gardés, seule la mise en forme est refaite.
 */

const ONGLET = 'Messages';

const ENTETES = [
  'Reçu le', 'Type', 'Message', 'Captures', 'De', 'Appareil',
  'Statut', 'Priorité', 'Responsable', 'Notes de l’équipe', 'Clos le',
  'Identifiant',
];

/** Numéro (à partir de 1) de chaque colonne de l'onglet Messages. */
const COL = {
  recu: 1, type: 2, message: 3, captures: 4, de: 5, appareil: 6,
  statut: 7, priorite: 8, responsable: 9, notes: 10, clos: 11, id: 12,
};

const LARGEURS = {
  recu: 120, type: 125, message: 380, captures: 170, de: 110,
  appareil: 150, statut: 115, priorite: 115, responsable: 120,
  notes: 260, clos: 100, id: 80,
};

const STATUTS = ['Nouveau', 'À l’étude', 'Planifié', 'En cours', 'Fait', 'Écarté'];
/** Un message passé à l'un de ces statuts reçoit sa date « Clos le ». */
const STATUTS_CLOS = ['Fait', 'Écarté'];
// Les pastilles trient dans le bon ordre : 🔴 avant 🟠 avant 🟢.
const PRIORITES = ['🔴 Haute', '🟠 Moyenne', '🟢 Basse'];
const TYPES = ['Bug', 'Idée', 'Pas clair', 'Lieu à corriger', 'Signalement', 'Autre'];

const COULEURS_STATUT = {
  'Nouveau': '#fce8b2', 'À l’étude': '#e8eaf6', 'Planifié': '#d2e3fc',
  'En cours': '#ffe0b2', 'Fait': '#ceead6', 'Écarté': '#e8e8e8',
};
const COULEURS_TYPE = {
  'Bug': '#fad2cf', 'Idée': '#fef7cd', 'Pas clair': '#d2e3fc',
  'Lieu à corriger': '#ceead6', 'Signalement': '#e9d2fd', 'Autre': '#e8e8e8',
};
const COULEURS_PRIORITE = {
  '🔴 Haute': '#fad2cf', '🟠 Moyenne': '#ffe0b2', '🟢 Basse': '#ceead6',
};

/** Lignes préparées (listes, couleurs, filtre) dans l'onglet Messages. */
const LIGNES = 5000;


// ------------------------------------------------------------------
//  Mise en place
// ------------------------------------------------------------------

function installer() {
  const classeur = SpreadsheetApp.getActive();
  classeur.setSpreadsheetLocale('fr_FR');
  classeur.setSpreadsheetTimeZone('Europe/Brussels');
  PropertiesService.getScriptProperties()
      .setProperty('CLASSEUR', classeur.getId());

  const listes = installerListes_(classeur);
  const messages = installerMessages_(classeur, listes);
  const tableau = installerTableauDeBord_(classeur);

  // Dans l'ordre : Messages, Tableau de bord, Listes.
  [messages, tableau, listes].forEach((onglet, i) => {
    classeur.setActiveSheet(onglet);
    classeur.moveActiveSheet(i + 1);
  });
  // L'onglet vide d'origine, s'il est encore là.
  ['Feuille 1', 'Sheet1'].forEach((nom) => {
    const onglet = classeur.getSheetByName(nom);
    if (onglet && onglet.getLastRow() === 0) classeur.deleteSheet(onglet);
  });
  classeur.setActiveSheet(messages);
}

function installerListes_(classeur) {
  const onglet = obtenirOnglet_(classeur, 'Listes');
  // Les colonnes de l'app sont réécrites ; les prénoms (D) sont gardés.
  onglet.getRange('A:C').clearContent();
  onglet.getRange(1, 1, 1, 4)
      .setValues([['Statuts', 'Priorités', 'Types', 'Équipe']])
      .setFontWeight('bold');
  [STATUTS, PRIORITES, TYPES].forEach((valeurs, i) => {
    onglet.getRange(2, i + 1, valeurs.length, 1)
        .setValues(valeurs.map((v) => [v]));
  });
  onglet.getRange('D1').setNote(
      'Les prénoms de l’équipe, un par ligne : ils apparaissent dans la ' +
      'liste déroulante de la colonne Responsable.');
  onglet.setFrozenRows(1);
  onglet.setColumnWidths(1, 4, 150);
  return onglet;
}

function installerMessages_(classeur, listes) {
  const onglet = obtenirOnglet_(classeur, ONGLET);
  const nbColonnes = ENTETES.length;
  if (onglet.getMaxRows() < LIGNES + 1) {
    onglet.insertRowsAfter(onglet.getMaxRows(), LIGNES + 1 - onglet.getMaxRows());
  }
  if (onglet.getMaxColumns() > nbColonnes) {
    onglet.deleteColumns(nbColonnes + 1, onglet.getMaxColumns() - nbColonnes);
  }

  // En-têtes : foncés pour ce que remplit l'app, dorés pour l'équipe.
  onglet.getRange(1, 1, 1, nbColonnes)
      .setValues([ENTETES])
      .setFontWeight('bold')
      .setFontColor('#ffffff')
      .setBackground('#2b241d')
      .setVerticalAlignment('middle');
  onglet.getRange(1, COL.statut, 1, COL.clos - COL.statut + 1)
      .setBackground('#b8893f');
  onglet.setRowHeight(1, 34);
  onglet.setFrozenRows(1);
  Object.keys(LARGEURS).forEach((cle) => {
    onglet.setColumnWidth(COL[cle], LARGEURS[cle]);
  });

  const colonne = (c) => onglet.getRange(2, c, LIGNES, 1);
  const tout = onglet.getRange(2, 1, LIGNES, nbColonnes);
  tout.setVerticalAlignment('top');
  colonne(COL.recu).setNumberFormat('dd/mm/yyyy hh:mm');
  colonne(COL.clos).setNumberFormat('dd/mm/yyyy');
  colonne(COL.message).setWrap(true);
  colonne(COL.notes).setWrap(true);
  colonne(COL.id).setFontColor('#9aa0a6').setFontSize(8);

  // Listes déroulantes, alimentées par l'onglet Listes.
  const liste = (plage, strict) => SpreadsheetApp.newDataValidation()
      .requireValueInRange(listes.getRange(plage), true)
      .setAllowInvalid(!strict)
      .build();
  colonne(COL.type).setDataValidation(liste('C2:C', true));
  colonne(COL.statut).setDataValidation(liste('A2:A', true));
  colonne(COL.priorite).setDataValidation(liste('B2:B', true));
  // Un prénom pas encore dans la liste reste accepté.
  colonne(COL.responsable).setDataValidation(liste('D2:D', false));

  // Couleurs : la première règle qui s'applique à une case l'emporte.
  const regles = [];
  const colorer = (couleurs, c) => Object.keys(couleurs).forEach((valeur) => {
    regles.push(SpreadsheetApp.newConditionalFormatRule()
        .whenTextEqualTo(valeur)
        .setBackground(couleurs[valeur])
        .setRanges([colonne(c)])
        .build());
  });
  colorer(COULEURS_STATUT, COL.statut);
  colorer(COULEURS_TYPE, COL.type);
  colorer(COULEURS_PRIORITE, COL.priorite);
  // Une fois clos, le reste de la ligne passe au gris.
  regles.push(SpreadsheetApp.newConditionalFormatRule()
      .whenFormulaSatisfied('=$K2<>""')
      .setFontColor('#9aa0a6')
      .setRanges([tout])
      .build());
  onglet.setConditionalFormatRules(regles);

  // Un filtre sur chaque en-tête : trier, filtrer par type, statut,
  // priorité, responsable… et combiner les critères.
  const filtre = onglet.getFilter();
  if (filtre) filtre.remove();
  onglet.getRange(1, 1, LIGNES + 1, nbColonnes).createFilter();
  return onglet;
}

function installerTableauDeBord_(classeur) {
  const onglet = obtenirOnglet_(classeur, 'Tableau de bord');
  onglet.clear();
  const source = `${ONGLET}!A1:L`;
  const titre = (cellule, texte) => onglet.getRange(cellule)
      .setValue(texte).setFontWeight('bold').setFontColor('#b8893f');

  onglet.getRange('A1').setValue('Tableau de bord')
      .setFontSize(18).setFontWeight('bold');
  onglet.getRange('A2')
      .setValue('Se met à jour tout seul. Pour trier autrement : filtres de ' +
          'l’onglet Messages, ou Données → Vues filtrées.')
      .setFontColor('#80868b');

  titre('A4', 'Ouverts, par type');
  onglet.getRange('A5').setFormula(
      `=QUERY(${source}, "select B, count(A) where A is not null and K is null ` +
      `group by B order by count(A) desc label B 'Type', count(A) 'Ouverts'", 1)`);

  titre('D4', 'Tous, par type et statut');
  onglet.getRange('D5').setFormula(
      `=QUERY(${source}, "select B, count(A) where A is not null ` +
      `group by B pivot G label B 'Type'", 1)`);

  titre('A15', 'À traiter : sans priorité d’abord (à trier), puis 🔴 🟠 🟢, ' +
      'les plus anciens en premier');
  onglet.getRange('A16').setFormula(
      `=QUERY(${source}, "select H, B, A, C, E, I, G where A is not null ` +
      `and K is null order by H, A", 1)`);
  onglet.getRange('C17:C').setNumberFormat('dd/mm/yyyy hh:mm');
  onglet.getRange('D17:D').setWrap(true);
  onglet.getRange('A16:G16').setFontWeight('bold');

  [115, 125, 120, 380, 110, 120, 115].forEach((largeur, i) => {
    onglet.setColumnWidth(i + 1, largeur);
  });
  return onglet;
}


// ------------------------------------------------------------------
//  Réception d'un message (appelée par Supabase)
// ------------------------------------------------------------------

function doPost(e) {
  try {
    const donnees = JSON.parse(e.postData.contents);
    const proprietes = PropertiesService.getScriptProperties();
    const jeton = proprietes.getProperty('JETON');
    if (!jeton || donnees.jeton !== jeton) {
      return repondre_({ ok: false, erreur: 'jeton invalide' });
    }

    const verrou = LockService.getScriptLock();
    verrou.waitLock(30000);
    try {
      const classeur = SpreadsheetApp.openById(proprietes.getProperty('CLASSEUR'));
      const onglet = classeur.getSheetByName(ONGLET);
      const derniere = onglet.getLastRow();

      // Déjà reçu (un envoi répété après une coupure) : rien à refaire.
      if (derniere >= 2) {
        const deja = onglet.getRange(2, COL.id, derniere - 1, 1)
            .createTextFinder(donnees.id).matchEntireCell(true).findNext();
        if (deja) return repondre_({ ok: true, deja: true });
      }

      const liens = (donnees.captures || []).map((capture) => ({
        nom: capture.nom,
        url: copierDansDrive_(classeur, capture, donnees.id),
      }));

      const ligne = derniere + 1;
      onglet.getRange(ligne, 1, 1, ENTETES.length).setValues([[
        new Date(donnees.recuLe),
        texte_(donnees.type),
        texte_(donnees.message),
        '',
        texte_(donnees.auteur),
        texte_(donnees.appareil),
        'Nouveau',
        '', '', '', '',
        donnees.id,
      ]]);
      if (liens.length) {
        onglet.getRange(ligne, COL.captures).setRichTextValue(avecLiens_(liens));
      }
      return repondre_({ ok: true });
    } finally {
      verrou.releaseLock();
    }
  } catch (erreur) {
    return repondre_({ ok: false, erreur: String(erreur) });
  }
}

/**
 * Copie une capture dans le dossier « Tabl · captures des retours »,
 * à côté de la feuille (même partage) ; renvoie son lien Drive. Le lien
 * reçu de Supabase expire en quelques minutes.
 */
function copierDansDrive_(classeur, capture, id) {
  const reponse = UrlFetchApp.fetch(capture.url, { muteHttpExceptions: true });
  if (reponse.getResponseCode() !== 200) {
    // Le message repartira plus tard avec un lien neuf.
    throw new Error(`capture introuvable (${reponse.getResponseCode()})`);
  }
  const fichier = dossierCaptures_(classeur)
      .createFile(reponse.getBlob().setName(`${id.slice(0, 8)} · ${capture.nom}`));
  return fichier.getUrl();
}

function dossierCaptures_(classeur) {
  const proprietes = PropertiesService.getScriptProperties();
  const id = proprietes.getProperty('DOSSIER');
  if (id) {
    try {
      return DriveApp.getFolderById(id);
    } catch (_) {
      // Supprimé entre-temps : on le recrée.
    }
  }
  const parents = DriveApp.getFileById(classeur.getId()).getParents();
  const parent = parents.hasNext() ? parents.next() : DriveApp.getRootFolder();
  const dossier = parent.createFolder('Tabl · captures des retours');
  proprietes.setProperty('DOSSIER', dossier.getId());
  return dossier;
}

/** "Capture 1  ·  Capture 2", chaque nom cliquable. */
function avecLiens_(liens) {
  const separateur = '  ·  ';
  const constructeur = SpreadsheetApp.newRichTextValue()
      .setText(liens.map((l) => l.nom).join(separateur));
  let debut = 0;
  liens.forEach((l) => {
    constructeur.setLinkUrl(debut, debut + l.nom.length, l.url);
    debut += l.nom.length + separateur.length;
  });
  return constructeur.build();
}

/**
 * Un texte venu de l'app reste du texte : « =… » ne doit jamais devenir
 * une formule exécutée dans la feuille de l'équipe.
 */
function texte_(valeur) {
  const chaine = String(valeur == null ? '' : valeur);
  return /^[=+\-@]/.test(chaine) ? `'${chaine}` : chaine;
}

function repondre_(objet) {
  return ContentService.createTextOutput(JSON.stringify(objet))
      .setMimeType(ContentService.MimeType.JSON);
}


// ------------------------------------------------------------------
//  Suivi par l'équipe
// ------------------------------------------------------------------

/** Passer un message à « Fait » ou « Écarté » date sa clôture. */
function onEdit(e) {
  const plage = e.range;
  const onglet = plage.getSheet();
  const premiere = plage.getColumn();
  const derniere = premiere + plage.getNumColumns() - 1;
  if (onglet.getName() !== ONGLET || plage.getRow() < 2 ||
      premiere > COL.statut || derniere < COL.statut) {
    return;
  }
  for (let i = 0; i < plage.getNumRows(); i++) {
    const ligne = plage.getRow() + i;
    const statut = onglet.getRange(ligne, COL.statut).getValue();
    const clos = onglet.getRange(ligne, COL.clos);
    if (STATUTS_CLOS.indexOf(statut) >= 0) {
      if (!clos.getValue()) clos.setValue(new Date());
    } else {
      clos.clearContent();
    }
  }
}

function obtenirOnglet_(classeur, nom) {
  return classeur.getSheetByName(nom) || classeur.insertSheet(nom);
}
