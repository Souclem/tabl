import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('messageErreurAuth', () {
    test('se fie au code quand il y en a un', () {
      expect(
        messageErreurAuth(code: 'invalid_credentials', message: 'whatever'),
        'E-mail ou mot de passe incorrect.',
      );
      expect(
        messageErreurAuth(code: 'weak_password', message: ''),
        'Mot de passe trop simple : choisis-en un plus long.',
      );
    });

    test("un e-mail de confirmation refusé n'est pas montré en anglais", () {
      const attendu =
          "Impossible d'envoyer l'e-mail de confirmation pour l'instant. "
          'Réessaie plus tard, ou continue avec Google.';
      expect(
        messageErreurAuth(
          code: 'email_address_not_authorized',
          message:
              'Email address "a@b.c" cannot be used as it is not authorized',
        ),
        attendu,
      );
      expect(
        messageErreurAuth(message: 'email rate limit exceeded'),
        attendu,
      );
    });

    test('sans code, lit le message', () {
      expect(
        messageErreurAuth(message: 'Invalid login credentials'),
        'E-mail ou mot de passe incorrect.',
      );
      expect(
        messageErreurAuth(message: 'Email not confirmed'),
        startsWith("Confirme d'abord ton adresse e-mail"),
      );
      expect(
        messageErreurAuth(message: 'User already registered'),
        'Un compte existe déjà avec cette adresse.',
      );
    });

    test("un refus inconnu reste en français, jamais l'anglais brut", () {
      expect(
        messageErreurAuth(code: 'unexpected_failure', message: 'Boom'),
        'Connexion impossible pour le moment. Réessaie.',
      );
    });
  });
}
