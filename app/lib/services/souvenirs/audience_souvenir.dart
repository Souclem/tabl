/// Qui peut voir une publication — trois modes exclusifs, jamais
/// combinés, pour qu'on comprenne toujours d'un coup d'œil qui voit
/// quoi (décision produit du 2026-10-16).
enum ModeAudience {
  /// Tous ceux qui ont le droit de voir le profil : les abonnés si le
  /// profil est privé, tous les utilisateurs de Tabl s'il est public.
  toutLeMonde('tout_le_monde'),

  /// Uniquement des Tables et/ou des personnes choisies.
  seulement('seulement'),

  /// Tout le monde, sauf des personnes choisies.
  sauf('sauf');

  const ModeAudience(this.valeur);

  /// Valeur de la colonne `souvenirs.visibilite`.
  final String valeur;

  static ModeAudience depuisValeur(String? valeur) => ModeAudience.values
      .firstWhere((m) => m.valeur == valeur, orElse: () => toutLeMonde);
}

/// L'audience choisie pour une publication.
///
/// [tableIds] ne compte qu'en mode [ModeAudience.seulement] ;
/// [personneIds] désigne les personnes autorisées en
/// [ModeAudience.seulement] et les personnes exclues en
/// [ModeAudience.sauf]. Les listes non pertinentes pour le mode sont
/// vidées par [normalisee] avant tout enregistrement.
class AudienceSouvenir {
  const AudienceSouvenir({
    required this.mode,
    this.tableIds = const {},
    this.personneIds = const {},
  });

  static const toutLeMonde = AudienceSouvenir(mode: ModeAudience.toutLeMonde);

  final ModeAudience mode;
  final Set<String> tableIds;
  final Set<String> personneIds;

  /// "Seulement…" sans personne ni Table ne montrerait le post à
  /// personne : on ne laisse pas enregistrer ça.
  bool get estValide =>
      mode != ModeAudience.seulement ||
      tableIds.isNotEmpty ||
      personneIds.isNotEmpty;

  /// La même audience, débarrassée de ce qui ne compte pas pour son mode.
  AudienceSouvenir normalisee() => switch (mode) {
    ModeAudience.toutLeMonde => toutLeMonde,
    ModeAudience.seulement => this,
    ModeAudience.sauf => AudienceSouvenir(
      mode: ModeAudience.sauf,
      personneIds: personneIds,
    ),
  };

  AudienceSouvenir copierAvec({
    ModeAudience? mode,
    Set<String>? tableIds,
    Set<String>? personneIds,
  }) {
    return AudienceSouvenir(
      mode: mode ?? this.mode,
      tableIds: tableIds ?? this.tableIds,
      personneIds: personneIds ?? this.personneIds,
    );
  }
}

/// Ce qu'il faut savoir sur le compte courant pour calculer la portée
/// d'une audience — chargé une fois à l'ouverture de la feuille "Qui
/// peut voir ?", puis tous les calculs sont instantanés.
class ContexteAudience {
  const ContexteAudience({
    required this.profilPrive,
    required this.abonnesIds,
    required this.membresParTable,
  });

  final bool profilPrive;

  /// Abonnés acceptés (ceux qui me suivent).
  final Set<String> abonnesIds;

  /// Membres actifs de chacune de mes Tables, moi exclu.
  final Map<String, Set<String>> membresParTable;

  /// Les personnes qui verront la publication, ou `null` si c'est "tous
  /// les utilisateurs de Tabl" (profil public, hors "Seulement…") — pas
  /// un nombre qu'on peut afficher.
  Set<String>? personnesVisibles(AudienceSouvenir audience) {
    switch (audience.mode) {
      case ModeAudience.seulement:
        return {
          ...audience.personneIds,
          for (final id in audience.tableIds) ...?membresParTable[id],
        };
      case ModeAudience.toutLeMonde:
      case ModeAudience.sauf:
        if (!profilPrive) return null;
        return audience.mode == ModeAudience.sauf
            ? abonnesIds.difference(audience.personneIds)
            : abonnesIds;
    }
  }

  /// Phrase sous la feuille : la réponse directe à "qui va voir ?".
  String libellePortee(AudienceSouvenir audience) {
    final visibles = personnesVisibles(audience);
    if (visibles == null) {
      final exclus = audience.mode == ModeAudience.sauf
          ? audience.personneIds.length
          : 0;
      return exclus == 0
          ? 'Visible par tous les utilisateurs de Tabl'
          : 'Visible par tous les utilisateurs de Tabl, '
                'sauf $exclus personne${exclus > 1 ? 's' : ''}';
    }
    if (visibles.isEmpty) return 'Visible uniquement par vous';
    final n = visibles.length;
    return 'Visible par $n personne${n > 1 ? 's' : ''}';
  }

  /// Amis tagués comme présents qui ne verront pas la publication — le
  /// tag n'élargit jamais l'audience (comme Instagram), on prévient
  /// seulement l'auteur.
  Set<String> taguesHorsAudience(
    AudienceSouvenir audience,
    Set<String> taguesIds,
  ) {
    final visibles = personnesVisibles(audience);
    if (visibles == null) {
      return audience.mode == ModeAudience.sauf
          ? taguesIds.intersection(audience.personneIds)
          : const {};
    }
    return taguesIds.difference(visibles);
  }
}

/// Libellé court d'une audience, pour la ligne "👁 …" du formulaire de
/// publication.
String libelleAudience(
  AudienceSouvenir audience, {
  required Map<String, String> nomsTables,
  required Map<String, String> pseudos,
}) {
  switch (audience.mode) {
    case ModeAudience.toutLeMonde:
      return 'Tout le monde';
    case ModeAudience.sauf:
      final n = audience.personneIds.length;
      return n == 0
          ? 'Tout le monde'
          : 'Tout le monde sauf $n personne${n > 1 ? 's' : ''}';
    case ModeAudience.seulement:
      final noms = [
        for (final id in audience.tableIds) ?nomsTables[id],
        for (final id in audience.personneIds) ?pseudos[id],
      ];
      if (noms.isEmpty) return 'Seulement…';
      if (noms.length <= 2) return 'Seulement ${noms.join(', ')}';
      return 'Seulement ${noms.take(2).join(', ')} +${noms.length - 2}';
  }
}
