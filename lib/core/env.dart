class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static void validar() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Faltan variables de entorno. Define SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY con --dart-define.',
      );
    }
  }
}