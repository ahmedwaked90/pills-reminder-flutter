/// Base URL of the Laravel backend.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
///
/// The default `http://10.0.2.2:8000` is the Android emulator's loopback
/// to the host machine — convenient when the Laravel dev server
/// (`php artisan serve`) is running on your laptop.
/// For a physical phone on the same Wi-Fi, use the laptop's LAN IP, e.g.
/// `http://192.168.1.10:8000`.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// OAuth 2.0 **Web** client ID, same one you put in `backend/.env` as
  /// `GOOGLE_CLIENT_ID`. Used as the `serverClientId` on google_sign_in so
  /// that the ID token's `aud` matches the one Laravel accepts.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
}
