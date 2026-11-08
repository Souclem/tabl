import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_organisation_table.dart';

/// Le détail d'une proposition (megaprompt Bloc 4) : GO/Je passe déjà
/// couvert par la ligne de "On y va ?" (Bloc 3), ici le sondage de
/// dates, la confirmation, et l'accès au mini-chat.
///
/// Volontairement laissé en dehors du périmètre (voir le plan) : un
/// vrai plugin d'écriture calendrier natif (aucun n'est installé dans
/// le projet) — "Ajouter au calendrier" reste un geste explicite côté
/// UI (règle 57-58 respectées : demande au tap, jamais de lecture du
/// calendrier) mais n'écrit encore rien de réel.
class EcranPropositionTable extends StatefulWidget {
  const EcranPropositionTable({
    super.key,
    required this.propositionId,
    required this.tableService,
  });

  final String propositionId;
  final TableService tableService;

  @override
  State<EcranPropositionTable> createState() => _EcranPropositionTableState();
}

class _EcranPropositionTableState extends State<EcranPropositionTable> {
  bool _chargement = true;
  bool _erreur = false;
  DetailProposition? _detail;

  bool _selectionCreatorOuverte = false;
  bool _selectionParticipantOuverte = false;
  late DateTime _moisAffiche;
  Set<DateTime> _joursEnCoursDeSelection = {};

  @override
  void initState() {
    super.initState();
    final maintenant = DateTime.now();
    _moisAffiche = DateTime(maintenant.year, maintenant.month);
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final detail = await widget.tableService.detailProposition(widget.propositionId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  Future<void> _repondre(bool go) async {
    await widget.tableService.repondreProposition(widget.propositionId, go: go);
    await _charger();
  }

  void _ouvrirSelecteurCreator() {
    final maintenant = DateTime.now();
    setState(() {
      _moisAffiche = DateTime(maintenant.year, maintenant.month);
      _joursEnCoursDeSelection = {
        for (final c in _detail!.candidats)
          if (!c.passee) DateTime(c.date.year, c.date.month, c.date.day),
      };
      _selectionCreatorOuverte = true;
      _selectionParticipantOuverte = false;
    });
  }

  void _ouvrirSelecteurParticipant() {
    final maintenant = DateTime.now();
    setState(() {
      _moisAffiche = DateTime(maintenant.year, maintenant.month);
      _joursEnCoursDeSelection = {
        for (final c in _detail!.candidats)
          if (c.moiDisponible) DateTime(c.date.year, c.date.month, c.date.day),
      };
      _selectionParticipantOuverte = true;
      _selectionCreatorOuverte = false;
    });
  }

  void _toggleJour(DateTime jour) {
    setState(() {
      final existant = _joursEnCoursDeSelection.firstWhere(
        (d) => d.year == jour.year && d.month == jour.month && d.day == jour.day,
        orElse: () => DateTime(0),
      );
      if (existant.year == 0) {
        _joursEnCoursDeSelection = {..._joursEnCoursDeSelection, jour};
      } else {
        _joursEnCoursDeSelection = _joursEnCoursDeSelection.where((d) => d != existant).toSet();
      }
    });
  }

  Future<void> _validerDatesCandidates() async {
    // Règle 7 : éviter 20 dates façon Doodle — 7 maximum.
    if (_joursEnCoursDeSelection.length > 7) {
      afficherMessage(context, 'Maximum 7 dates candidates.');
      return;
    }
    await widget.tableService.definirDatesCandidates(
      widget.propositionId,
      _joursEnCoursDeSelection.toList(),
    );
    setState(() => _selectionCreatorOuverte = false);
    await _charger();
  }

  Future<void> _validerDisponibilites() async {
    final detail = _detail!;
    final idsSelectionnes = [
      for (final c in detail.candidats)
        if (_joursEnCoursDeSelection.any(
          (d) => d.year == c.date.year && d.month == c.date.month && d.day == c.date.day,
        ))
          c.id,
    ];
    await widget.tableService.soumettreDisponibilites(widget.propositionId, idsSelectionnes);
    setState(() => _selectionParticipantOuverte = false);
    await _charger();
  }

  Future<void> _confirmer(String dateCandidateId, {required bool avecAbsents}) async {
    if (avecAbsents) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: TablTokens.surface,
          title: const Text('Confirmer quand même ?', style: TablTokens.sousTitre),
          content: const Text(
            'Certains participants ne pourront pas être présents ce jour-là.',
            style: TablTokens.corps,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: TablTokens.primaire,
                foregroundColor: TablTokens.texteSurPrimaire,
              ),
              child: const Text('Confirmer quand même'),
            ),
          ],
        ),
      );
      if (confirme != true) return;
    }
    await widget.tableService.confirmerDate(
      propositionId: widget.propositionId,
      dateCandidateId: dateCandidateId,
      // Fuseau du créateur au moment de la confirmation — voir la note
      // de la migration `20260917020000...` : pas de géocodage
      // restaurant disponible pour l'instant.
      fuseauHoraire: DateTime.now().timeZoneName,
    );
    await _charger();
  }

  Future<void> _ajouterHeure() async {
    final heure = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 30),
    );
    if (heure == null) return;
    final formatee =
        '${heure.hour.toString().padLeft(2, '0')}:${heure.minute.toString().padLeft(2, '0')}';
    await widget.tableService.ajouterHeure(widget.propositionId, formatee);
    await _charger();
  }

  Future<void> _replanifier() async {
    final confirme = await _confirmerAction(
      titre: 'Replanifier ?',
      message: 'La date confirmée sera retirée et un nouveau sondage de dates commencera.',
      libelleAction: 'Replanifier',
    );
    if (!confirme) return;
    await widget.tableService.replanifier(widget.propositionId);
    await _charger();
  }

  Future<void> _annuler() async {
    final confirme = await _confirmerAction(
      titre: 'Annuler la sortie ?',
      message: 'Les participants en seront informés.',
      libelleAction: 'Annuler la sortie',
    );
    if (!confirme) return;
    await widget.tableService.annulerProposition(widget.propositionId);
    await _charger();
  }

  Future<bool> _confirmerAction({
    required String titre,
    required String message,
    required String libelleAction,
  }) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TablTokens.surface,
        title: Text(titre, style: TablTokens.sousTitre),
        content: Text(message, style: TablTokens.corps),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: TablTokens.primaire,
              foregroundColor: TablTokens.texteSurPrimaire,
            ),
            child: Text(libelleAction),
          ),
        ],
      ),
    );
    return confirme ?? false;
  }

  void _ouvrirOrganisation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranOrganisationTable(
          propositionId: widget.propositionId,
          tableService: widget.tableService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(
        backgroundColor: TablTokens.fond,
        body: Center(child: CircularProgressIndicator(color: TablTokens.primaire)),
      );
    }
    final detail = _detail;
    if (_erreur || detail == null) {
      return Scaffold(
        backgroundColor: TablTokens.fond,
        body: SafeArea(
          child: Column(
            children: [
              _boutonRetour(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Cette proposition n\'est plus disponible.', style: TablTokens.corps),
                      const SizedBox(height: TablTokens.espaceM),
                      OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _boutonRetour(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL,
                  0,
                  TablTokens.espaceL,
                  TablTokens.espaceL,
                ),
                children: [
                  Text(detail.restaurantNom, style: TablTokens.titre),
                  Text(
                    '${detail.ville} · Proposé par ${detail.proposePar}',
                    style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
                  ),
                  const SizedBox(height: TablTokens.espaceM),
                  ..._corpsSelonEtat(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boutonRetour() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceM,
        TablTokens.espaceS,
        TablTokens.espaceM,
        0,
      ),
      child: Row(children: [TablBoutonRetour(onPresse: () => Navigator.of(context).pop())]),
    );
  }

  List<Widget> _corpsSelonEtat(DetailProposition detail) {
    if (!detail.active) {
      return [Text(detail.etatTexte, style: TablTokens.corps)];
    }

    final blocs = <Widget>[];

    // GO / Je passe : possible tant que non confirmé (règle 26-27).
    if (detail.confirmation == null) {
      blocs.addAll(_blocGoPasse(detail));
    }

    if (detail.nombreGo == 0) {
      blocs.add(const Text('En attente de premières réponses.', style: TablTokens.corps));
      return blocs;
    }

    if (detail.confirmation != null) {
      blocs.addAll(_blocConfirme(detail));
    } else if (detail.candidats.isEmpty) {
      blocs.addAll(_blocAvantDates(detail));
    } else {
      blocs.addAll(_blocSondageEnCours(detail));
    }

    if (detail.nombreGo >= 2 && detail.peutAccederChat && !detail.chatArchive()) {
      blocs.add(const SizedBox(height: TablTokens.espaceM));
      blocs.addAll(_blocOrganisationApercu(detail));
    }

    return blocs;
  }

  List<Widget> _blocGoPasse(DetailProposition detail) {
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _repondre(true),
              style: OutlinedButton.styleFrom(
                backgroundColor: detail.monInteret == true ? TablTokens.primaire : null,
                foregroundColor: detail.monInteret == true
                    ? TablTokens.texteSurPrimaire
                    : TablTokens.texte,
                side: BorderSide(
                  color: detail.monInteret == true ? TablTokens.primaire : TablTokens.bordure,
                ),
              ),
              child: const Text('GO'),
            ),
          ),
          const SizedBox(width: TablTokens.espaceS),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _repondre(false),
              style: OutlinedButton.styleFrom(
                backgroundColor: detail.monInteret == false ? TablTokens.primaire : null,
                foregroundColor: detail.monInteret == false
                    ? TablTokens.texteSurPrimaire
                    : TablTokens.texte,
                side: BorderSide(
                  color: detail.monInteret == false ? TablTokens.primaire : TablTokens.bordure,
                ),
              ),
              child: const Text('Je passe'),
            ),
          ),
        ],
      ),
      const SizedBox(height: TablTokens.espaceM),
    ];
  }

  List<Widget> _blocAvantDates(DetailProposition detail) {
    if (detail.parMoi) {
      return [
        if (_selectionCreatorOuverte)
          ..._selecteurCreator()
        else
          TablBouton(libelle: 'Proposer des dates', onPresse: _ouvrirSelecteurCreator),
      ];
    }
    return [
      Text('En attente de dates de la part de ${detail.proposePar}.', style: TablTokens.corps),
    ];
  }

  List<Widget> _selecteurCreator() {
    return [
      TablCalendrierJours(
        mois: _moisAffiche,
        joursSelectionnes: _joursEnCoursDeSelection,
        joursDesactives: const {},
        onToggleJour: _toggleJour,
        onMoisPrecedent: () => setState(
          () => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month - 1),
        ),
        onMoisSuivant: () => setState(
          () => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + 1),
        ),
      ),
      const SizedBox(height: TablTokens.espaceM),
      TablBouton(libelle: 'Continuer', onPresse: _validerDatesCandidates),
    ];
  }

  List<Widget> _blocSondageEnCours(DetailProposition detail) {
    final blocs = <Widget>[
      Text(
        '${detail.progressionSoumis}/${detail.progressionEligibles} ont répondu',
        style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
      ),
      const SizedBox(height: TablTokens.espaceS),
    ];

    if (detail.monInteret == true && detail.confirmation == null) {
      if (_selectionParticipantOuverte) {
        blocs.addAll(_selecteurParticipant());
      } else {
        blocs.add(
          TablBouton(
            libelle: detail.moiAiSoumisReponse
                ? 'Modifier mes disponibilités'
                : 'Vos disponibilités',
            onPresse: _ouvrirSelecteurParticipant,
          ),
        );
      }
      blocs.add(const SizedBox(height: TablTokens.espaceM));
    }

    if (detail.toutesLesDatesSontPassees) {
      blocs.add(const Text('Ces dates sont passées.', style: TablTokens.corps));
      if (detail.parMoi) {
        blocs.add(const SizedBox(height: TablTokens.espaceS));
        blocs.add(
          TablBouton(libelle: 'Proposer de nouvelles dates', onPresse: _ouvrirSelecteurCreator),
        );
      }
      return blocs;
    }

    final communes = detail.datesCommunes;
    if (communes.isNotEmpty) {
      blocs.add(
        Text(
          communes.length == 1
              ? 'Une date convient à tout le monde.'
              : '${communes.length} dates conviennent à tout le monde.',
          style: TablTokens.corps,
        ),
      );
      blocs.add(const SizedBox(height: TablTokens.espaceS));
      for (final c in communes) {
        blocs.add(_ligneResultat(c, detail, compromis: false));
      }
      if (!detail.parMoi) {
        blocs.add(
          Text(
            'En attente de confirmation de ${detail.proposePar}.',
            style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
          ),
        );
      }
    } else {
      blocs.add(const Text('Aucune date ne convient à tout le monde.', style: TablTokens.corps));
      if (detail.parMoi) {
        blocs.add(const SizedBox(height: TablTokens.espaceS));
        blocs.add(const Text('Meilleurs compromis', style: TablTokens.sousTitre));
        for (final c in detail.meilleursCompromis) {
          blocs.add(_ligneResultat(c, detail, compromis: true));
        }
        blocs.add(const SizedBox(height: TablTokens.espaceS));
        blocs.add(
          TablBoutonTexte(libelle: 'Proposer d\'autres dates', onPresse: _ouvrirSelecteurCreator),
        );
      } else {
        blocs.add(
          Text(
            '${detail.proposePar} peut proposer de nouvelles dates.',
            style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
          ),
        );
      }
    }
    return blocs;
  }

  Widget _ligneResultat(
    CandidatDateProposition c,
    DetailProposition detail, {
    required bool compromis,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceXs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_dateLisible(c.date)} · ${c.disponibles}/${c.eligibles}',
              style: TablTokens.corps,
            ),
          ),
          if (detail.parMoi)
            TablBoutonTexte(
              libelle: compromis ? 'Confirmer quand même' : 'Confirmer',
              onPresse: () => _confirmer(c.id, avecAbsents: compromis),
            ),
        ],
      ),
    );
  }

  List<Widget> _selecteurParticipant() {
    return [
      const Text('Vos disponibilités', style: TablTokens.sousTitre),
      const Text(
        'Sélectionnez tous les jours où vous êtes disponible.',
        style: TablTokens.legende,
      ),
      const SizedBox(height: TablTokens.espaceS),
      TablCalendrierJours(
        mois: _moisAffiche,
        joursSelectionnes: _joursEnCoursDeSelection,
        joursDesactives: {
          for (final c in _detail!.candidats)
            if (c.passee) DateTime(c.date.year, c.date.month, c.date.day),
        },
        onToggleJour: _toggleJour,
        onMoisPrecedent: () => setState(
          () => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month - 1),
        ),
        onMoisSuivant: () => setState(
          () => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + 1),
        ),
      ),
      const SizedBox(height: TablTokens.espaceM),
      TablBouton(libelle: 'Envoyer mes disponibilités', onPresse: _validerDisponibilites),
    ];
  }

  List<Widget> _blocConfirme(DetailProposition detail) {
    final confirmation = detail.confirmation!;
    final texte = confirmation.heure == null
        ? 'Prévu ${_dateLisible(confirmation.date)}'
        : 'Prévu ${_dateLisible(confirmation.date)} à ${confirmation.heure}';
    return [
      Text(texte, style: TablTokens.corps),
      if (confirmation.heure == null) ...[
        const Text('Heure à confirmer', style: TablTokens.legende),
        if (detail.parMoi) ...[
          const SizedBox(height: TablTokens.espaceXs),
          TablBoutonTexte(libelle: 'Ajouter une heure', onPresse: _ajouterHeure),
        ],
      ],
      const SizedBox(height: TablTokens.espaceS),
      TablBoutonTexte(
        libelle: 'Ajouter au calendrier',
        onPresse: () => afficherMessage(context, 'Ajout au calendrier bientôt disponible.'),
      ),
      if (detail.parMoi) ...[
        const SizedBox(height: TablTokens.espaceS),
        Row(
          children: [
            TablBoutonTexte(libelle: 'Replanifier', onPresse: _replanifier),
            const SizedBox(width: TablTokens.espaceM),
            TablBoutonTexte(libelle: 'Annuler la sortie', onPresse: _annuler),
          ],
        ),
      ],
    ];
  }

  List<Widget> _blocOrganisationApercu(DetailProposition detail) {
    return [
      const Divider(color: TablTokens.bordure),
      const SizedBox(height: TablTokens.espaceS),
      Row(
        children: [
          Expanded(
            child: Text(
              detail.nombreMessages == 0
                  ? 'Organisation'
                  : 'Organisation · ${detail.nombreMessages} message${detail.nombreMessages > 1 ? "s" : ""}',
              style: TablTokens.sousTitre,
            ),
          ),
          TablBoutonTexte(libelle: 'Discuter', onPresse: _ouvrirOrganisation),
        ],
      ),
    ];
  }

  String _dateLisible(DateTime date) {
    const jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    const mois = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${jours[date.weekday - 1]} ${date.day} ${mois[date.month - 1]}';
  }
}
