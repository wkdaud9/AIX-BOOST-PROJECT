// File generated manually (flutterfire CLI Windows 호환 이슈로 수동 생성)
// Firebase 프로젝트: heybro-7ff89

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHHUhgq3LzTwEwZvCYvpGVCWNREROm2EY',
    appId: '1:1039066889677:android:4f36660acfeb40751f5884',
    messagingSenderId: '1039066889677',
    projectId: 'heybro-7ff89',
    storageBucket: 'heybro-7ff89.firebasestorage.app',
  );

  /// 웹 앱 설정 (iPhone PWA 배포용)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBiOO61R_dO0ZepsfRdI0dTXmzO_Kzc_8Q',
    appId: '1:1039066889677:web:9ce48088471fa4e11f5884',
    messagingSenderId: '1039066889677',
    projectId: 'heybro-7ff89',
    storageBucket: 'heybro-7ff89.firebasestorage.app',
    authDomain: 'heybro-7ff89.firebaseapp.com',
    measurementId: 'G-0EMYN9KLV6',
  );
}
