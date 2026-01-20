# AIX-Boost Frontend

군산대학교 맞춤형 공지 큐레이션 플랫폼의 Flutter 프론트엔드입니다.

## 시작하기

1. 의존성 설치:
```bash
flutter pub get
```

2. 환경 변수 설정:
- `.env` 파일을 프로젝트 루트에 생성하고 Backend URL을 설정하세요.

3. 앱 실행:
```bash
flutter run
```

## 프로젝트 구조

- `lib/main.dart`: 앱 진입점
- `lib/services/`: API 통신 및 비즈니스 로직
- `lib/models/`: 데이터 모델
- `lib/screens/`: 화면 UI
- `lib/widgets/`: 재사용 가능한 위젯
