
class AppConfig {
  static String _normalize(String url) {
    final u = url.trim();
    if (u.endsWith('/')) return u.substring(0, u.length - 1);
    return u;
  }

  /// Orden de prioridad:
  /// 1) --dart-define=API_BASE_URL=...
  /// 2) Default: Railway (producción)
  ///    (así en DEBUG también funciona si NO tienes backend local)
  /// 3) Opcional: si quieres usar backend local en DEBUG, pasa API_BASE_URL.
  static String get apiBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.trim().isNotEmpty) return _normalize(defined);

    // ✅ Default SIEMPRE: Railway
    // (en debug mucha gente prueba en el celular y 10.0.2.2/localhost NO sirve)
    return 'https://cobrosapp-backend-production.up.railway.app';
  }

  static String get apiBase => _normalize(apiBaseUrl);

  /// Tu ApiClient usa rutas como /auth/admin/login, por eso aquí agregamos /api
  static String get api => '$apiBase/api';

  static const Duration locationInterval = Duration(minutes: 3);

  static String get hintLocalApi => '';
}
