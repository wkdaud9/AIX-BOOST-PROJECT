// File generated manually (flutterfire CLI Windows 호환 이슈로 수동 생성)
// Firebase 프로젝트: heybro-7ff89
// 환경 변수로 관리 (.env 파일 사용)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase 초기화 옵션 (플랫폼별 설정)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS 플랫폼은 지원하지 않습니다. (웹으로 배포)',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'macOS 플랫폼은 지원하지 않습니다.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Windows 플랫폼은 지원하지 않습니다.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Linux 플랫폼은 지원하지 않습니다.',
        );
      default:
        throw UnsupportedError(
          '지원하지 않는 플랫폼입니다.',
        );
    }
  }

  /// Android 앱 설정
  static FirebaseOptions get android => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_ANDROID_API_KEY']!,
    appId: dotenv.env['FIREBASE_ANDROID_APP_ID']!,
    messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
    projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
  );

  /// 웹 앱 설정 (iPhone PWA 배포용)
  static FirebaseOptions get web => FirebaseOptions(
    apiKey: dotenv.env['FIREBASE_WEB_API_KEY']!,
    appId: dotenv.env['FIREBASE_WEB_APP_ID']!,
    messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
    projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
    authDomain: dotenv.env['FIREBASE_WEB_AUTH_DOMAIN']!,
    measurementId: dotenv.env['FIREBASE_WEB_MEASUREMENT_ID']!,
  );
}
