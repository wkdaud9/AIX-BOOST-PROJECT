# AIX-Boost

> 군산대학교 맞춤형 공지 큐레이션 플랫폼

## 프로젝트 개요

AIX-Boost는 군산대학교의 파편화된 공지사항을 Gemini AI로 분석하여 사용자 맞춤형 알림 및 일정을 제공하는 플랫폼입니다.

### 핵심 기능
- 📢 공지사항 자동 크롤링 및 수집
- 🤖 Gemini AI 기반 맥락 분석 및 일정 추출
- 🔔 사용자 맞춤형 푸시 알림
- 📅 캘린더 자동 연동

## 기술 스택

- **Frontend**: Flutter (Dart)
- **Backend**: Flask (Python 3.10+)
- **Database/Auth**: Supabase (PostgreSQL)
- **AI**: Gemini 1.5 Pro/Flash
- **Deployment**: Render (Backend), Flutter Web/APK (Frontend)

## 프로젝트 구조

```
aix-boost-project/
├── backend/              # Flask 백엔드
│   ├── app.py           # 메인 서버 진입점
│   ├── config.py        # 설정 파일
│   ├── requirements.txt # Python 의존성
│   └── .env.example     # 환경 변수 템플릿
├── frontend/            # Flutter 프론트엔드
│   ├── lib/
│   │   ├── main.dart    # 앱 진입점
│   │   └── services/    # API 통신 로직
│   ├── pubspec.yaml     # Flutter 의존성
│   └── .env.example     # 환경 변수 템플릿
├── docs/                # 문서
│   ├── api_spec.md      # API 명세서
│   └── database_schema.sql  # DB 스키마
├── CLAUDE.md            # Claude AI 개발 가이드
└── README.md            # 프로젝트 소개
```

## 🚀 신규 팀원 빠른 시작

### 📚 역할별 시작 가이드 (복사-붙여넣기만 하세요!)

**본인의 역할을 선택하고 가이드를 따라하세요**:

- 🎨 **Frontend 개발자** → [docs/SETUP_FRONTEND.md](docs/SETUP_FRONTEND.md)
- 🔧 **Backend API 개발자** → [docs/SETUP_BACKEND_API.md](docs/SETUP_BACKEND_API.md)
- 🤖 **Backend AI/크롤링 개발자** → [docs/SETUP_BACKEND_AI.md](docs/SETUP_BACKEND_AI.md)

### 📖 추가 문서
- [QUICKSTART.md](QUICKSTART.md) - 전체 프로젝트 개요
- [docs/CLAUDE_WORKFLOW.md](docs/CLAUDE_WORKFLOW.md) - Claude 자동화 워크플로우
- [docs/COLLABORATION_GUIDE.md](docs/COLLABORATION_GUIDE.md) - 상세 협업 가이드

## 시작하기

### 사전 요구사항
- Python 3.10 이상
- Flutter SDK 3.0 이상
- Supabase 계정
- Gemini API 키

### 1. 환경 변수 설정

Backend와 Frontend의 `.env.example` 파일을 복사하여 `.env` 파일을 생성하고 실제 값으로 변경하세요.

```bash
# Backend
cp backend/.env.example backend/.env

# Frontend
cp frontend/.env.example frontend/.env
```

### 2. Backend 실행

```bash
cd backend
pip install -r requirements.txt
python app.py
```

서버가 `http://localhost:5000`에서 실행됩니다.

### 3. Frontend 실행

```bash
cd frontend
flutter pub get
flutter run
```

## 팀 협업 (Claude Code 사용)

이 프로젝트는 3명의 팀원이 각자 Claude Code를 사용하여 협업합니다.

- **Frontend 개발자 1명**: Flutter 담당
- **Backend 개발자 2명**: API + AI/크롤링 담당

### 필독 문서
- 📘 [협업 가이드](docs/COLLABORATION_GUIDE.md): Git 워크플로우, 브랜치 전략, 작업 영역 분리
- 📗 [빠른 시작](QUICKSTART.md): 신규 팀원 온보딩 가이드
- 📕 [Claude 가이드](CLAUDE.md): Claude Code 사용 시 참고사항

### 핵심 협업 규칙
- 작업 전 항상 `git pull origin develop`
- 본인의 `feature/` 브랜치에서만 작업
- 공유 파일(`api_spec.md`, `requirements.txt`, `pubspec.yaml`) 수정 시 팀원에게 공지
- PR은 최소 1명의 리뷰 후 merge

## 개발 가이드

자세한 개발 가이드는 [CLAUDE.md](CLAUDE.md)를 참조하세요.

### 코딩 컨벤션
- **Python**: PEP 8 준수, snake_case 사용
- **Dart**: 공식 스타일 가이드 준수, camelCase 사용
- **API 응답**: `{"status": "success", "data": {...}}` 형식 유지

### 테스트

```bash
# Backend 테스트
cd backend
pytest

# Frontend 테스트
cd frontend
flutter test
```

## API 명세서

API 명세서는 [docs/api_spec.md](docs/api_spec.md)를 참조하세요.

## 데이터베이스 스키마

데이터베이스 스키마는 [docs/database_schema.sql](docs/database_schema.sql)를 참조하세요.

## 라이선스

MIT License

## 기여하기

이슈나 PR은 언제든 환영합니다!

---

**개발 팀**: 군산대학교 AIX-Boost 팀
