/// 환경변수 설정 (--dart-define으로 빌드 시 주입)
class EnvConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:5000');

  // Firebase Android
  static const firebaseAndroidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  // Firebase Web
  static const firebaseWebApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const firebaseWebAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const firebaseWebAuthDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
  static const firebaseWebMeasurementId = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');
}
