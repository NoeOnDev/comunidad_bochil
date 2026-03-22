class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const magicLinkRedirectUrl = String.fromEnvironment(
    'MAGIC_LINK_REDIRECT_URL',
    defaultValue: 'comunidadbochil://login-callback',
  );

  static void validar() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Faltan variables de entorno. Define SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY con --dart-define.',
      );
    }

    if (!magicLinkRedirectUrl.contains('://')) {
      throw StateError(
        'MAGIC_LINK_REDIRECT_URL no es válido. Ejemplo: comunidadbochil://login-callback',
      );
    }
  }
}