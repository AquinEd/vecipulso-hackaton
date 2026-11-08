abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static String? get problem {
    final uri = Uri.tryParse(url);
    if (url.isEmpty || key.isEmpty) {
      return 'Configura ${[if (url.isEmpty) "SUPABASE_URL", if (key.isEmpty) "SUPABASE_PUBLISHABLE_KEY"].join(" y ")} en config/supabase.dev.json y reinicia con --dart-define-from-file=config/supabase.dev.json.';
    }
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host.endsWith('.invalid') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return 'Revisa SUPABASE_URL. Usa la URL HTTPS de tu proyecto.';
    }
    if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key) ||
        key.endsWith('REEMPLAZAR')) {
      return 'Revisa SUPABASE_PUBLISHABLE_KEY. Usa la clave publicable de tu proyecto.';
    }
    return null;
  }
}
