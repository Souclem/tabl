/// La portée sociale d'une lecture de carte (megaprompt Bloc 1, règles 8
/// et 14) : qui compte dans "combien de proches connaissent cette
/// adresse ?".
///
/// [reseauEtendu] et [lesDeux] sont réservés aux comptes Premium — voir
/// `EntitlementService.aReseauEtendu`. Un compte gratuit ne peut
/// sélectionner que [procheDirect].
enum PorteeSociale { procheDirect, reseauEtendu, lesDeux }
