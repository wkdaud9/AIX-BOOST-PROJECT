// File generated manually (flutterfire CLI Windows 호환 이슈로 수동 생성)
// Firebase 프로젝트: heybro-7ff89
// 환경 변수로 관리 (.env 파일 사용)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'env_config.dart';

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
    apiKey: EnvConfig.firebaseAndroidApiKey,
    appId: EnvConfig.firebaseAndroidAppId,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
  );

  /// 웹 앱 설정 (iPhone PWA 배포용)
  static FirebaseOptions get web => FirebaseOptions(
    apiKey: EnvConfig.firebaseWebApiKey,
    appId: EnvConfig.firebaseWebAppId,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
    authDomain: EnvConfig.firebaseWebAuthDomain,
    measurementId: EnvConfig.firebaseWebMeasurementId,
  );
}
