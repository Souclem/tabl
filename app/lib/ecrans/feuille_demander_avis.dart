import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// « Demander un avis », d'après le prototype : les proches qui sont
/// allés dans ce restaurant (leur ressenti, leur dernière visite), un ou
/// plusieurs à choisir — ou tous d'un coup —, la question à leur poser,
/// déjà écrite, et l'envoi. Privé : leurs réponses ne seront publiées
/// nulle part. Renvoie `true` une fois envoyé.
Future<bool> demanderUnAvis(
  BuildContext context, {
  required AvisService avisService,
  required String restaurantId,
  required String nom,
  required String detail,
  required List<ProcheFiche> proches,
}) async {
  if (proches.isEmpty) return false;
  final c = TablCouleurs.of(context);
  final envoye = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FeuilleDemanderAvis(
      avisService: avisService,
      restaurantId: restaurantId,
      nom: nom,
      detail: detail,
      proches: proches,
    ),
  );
  return envoye ?? false;
}

class _FeuilleDemanderAvis extends StatefulWidget {
  const _FeuilleDemanderAvis({
    required this.avisService,
    required this.restaurantId,
    required this.nom,
    required this.detail,
    required this.proches,
  });

  final AvisService avisService;
  final String restaurantId;
  final String nom;
  final String detail;
  final List<ProcheFiche> proches;

  @override
  State<_FeuilleDemanderAvis> createState() => _FeuilleDemanderAvisState();
}

class _FeuilleDemanderAvisState extends State<_FeuilleDemanderAvis> {
  /// Le plus fidèle, choisi d'avance : c'est souvent à lui qu'on pense.
  late final Set<String> _choisis = {widget.proches.first.id};
  late final _message = TextEditingController(text: questionAvis(widget.nom));
  bool _enCours = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _tous => _choisis.length == widget.proches.length;

  String get _libelleEnvoi {
    if (_choisis.length == 1) {
      final p = widget.proches.firstWhere((p) => _choisis.contains(p.id));
      return 'Envoyer à ${p.pseudo}';
    }
    return 'Envoyer aux ${_choisis.length}';
  }

  Future<void> _envoyer() async {
    final message = _message.text.trim();
    if (_choisis.isEmpty || message.isEmpty) return;
    setState(() => _enCours = true);
    try {
      await widget.avisService.demander(
        restaurantId: widget.restaurantId,
        destinataireIds: _choisis.toList(),
        message: message,
      );
      if (!mounted) return;
      final premier = widget.proches.firstWhere((p) => _choisis.contains(p.id));
      Navigator.of(context).pop(true);
      afficherMessage(
        context,
        _choisis.length == 1
            ? 'Votre question part à ${premier.pseudo}. Sa réponse restera privée.'
            : 'Votre question part à ${_choisis.length} proches. Leurs réponses resteront privées.',
      );
    } catch (e) {
      debugPrint('FeuilleDemanderAvis: $e');
      if (!mounted) return;
      setState(() => _enCours = false);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final maintenant = DateTime.now();
    final n = widget.proches.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL - 4,
              0,
              TablTokens.espaceL - 4,
              TablTokens.espaceM,
            ),
            children: [
              const TablEtiquetteFiche(texte: 'Demander un avis', doree: true),
              const SizedBox(height: 6),
              Text(
                n == 1 ? '1 proche y est allé' : '$n proches y sont allés',
                style: c.titreAffichage.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  widget.nom,
                  if (widget.detail.isNotEmpty) widget.detail,
                ].join(' · '),
                style: c.legende.copyWith(fontSize: 13),
              ),
              const SizedBox(height: TablTokens.espaceM),
              for (final p in widget.proches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TablChoixProche(
                    pseudo: p.pseudo,
                    photoUrl: p.photoUrl,
                    detail: 'Dernière visite ${ilYA(p.derniere, maintenant)}',
                    emoji: p.emoji,
                    choisi: _choisis.contains(p.id),
                    onPresse: () => setState(() {
                      if (!_choisis.remove(p.id)) _choisis.add(p.id);
                    }),
                  ),
                ),
              if (n > 1)
                TablBoutonTexte(
                  libelle: _tous
                      ? 'Seulement ${widget.proches.first.pseudo}'
                      : 'Demander aux $n',
                  onPresse: () => setState(() {
                    if (_tous) {
                      _choisis
                        ..clear()
                        ..add(widget.proches.first.id);
                    } else {
                      _choisis.addAll([for (final p in widget.proches) p.id]);
                    }
                  }),
                ),
              const SizedBox(height: TablTokens.espaceS),
              TablChampTexte(
                libelle: 'Votre message',
                controleur: _message,
                lignes: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: TablTokens.espaceS),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: c.texteDoux,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Leur réponse restera privée. Rien ne sera publié.',
                      style: c.legende.copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TablTokens.espaceM),
              TablBouton(
                libelle: _choisis.isEmpty
                    ? 'Choisissez un proche'
                    : _libelleEnvoi,
                enCours: _enCours,
                onPresse: _choisis.isEmpty || _message.text.trim().isEmpty
                    ? null
                    : _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
