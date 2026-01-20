# AIX-Boost: 군산대학교 맞춤형 공지 큐레이션 플랫폼

## 1. 프로젝트 개요
- **목적**: 파편화된 학내 공지사항을 Gemini AI로 분석하여 사용자 맞춤형 알림 및 일정을 제공.
- **핵심 기능**: 공지사항 크롤링, Gemini AI 기반 맥락 분석 및 일정 추출, 맞춤형 푸시 알림, 캘린더 자동 연동.

## 2. 기술 스택
- **Frontend**: Flutter (Dart) / State Management: Provider 또는 Riverpod
- **Backend**: Flask (Python 3.10+)
- **Database/Auth**: Supabase (PostgreSQL)
- **AI**: Gemini 1.5 Pro/Flash (Text Analysis & Vision)
- **Deployment**: Render (Backend), Flutter Web/APK (Frontend)

## 3. 코딩 컨벤션
- **공통**: 모든 함수와 클래스에는 한글 주석으로 기능을 명시한다.
- **Python (Flask)**: PEP 8 준수, snake_case 사용, 비동기 처리는 `asyncio` 활용.
- **Dart (Flutter)**: 공식 스타일 가이드 준수, PascalCase(클래스), camelCase(변수/함수).
- **API 응답**: `{"status": "success", "data": {...}}` 형식을 유지한다.

## 4. 주요 파일 위치
- `/frontend`: Flutter 소스 코드
- `/backend`: Flask 서버 및 AI 로직
- `/backend/crawler`: 공지사항 크롤링 스크립트
- `/docs`: API 명세서 및 데이터베이스 스키마 정의

## 5. 절대 수정 금지 파일 (Critical Files)
- `.env`: API 키 및 DB 보안 설정 (로컬 환경 변수)
- `backend/app.py`: 메인 서버 진입점 (구조 변경 시 팀원 합의 필수)
- `frontend/pubspec.yaml`: 패키지 버전 충돌 방지를 위해 수동 관리 금지
- `supabase/schema.sql`: DB 스키마 원본

## 6. 테스트 및 실행 방법
- **Backend**: `pytest` 실행 / 서버 실행: `python app.py`
- **Frontend**: `flutter test` 실행 / 앱 실행: `flutter run`
- **Claude 전용**: `/test` 명령어로 현재 수정 중인 모듈의 유닛 테스트 수행

## 7. 팀 협업 가이드 (Claude Code 사용)
- **팀 구성**: Frontend 1명, Backend 2명 (각자 Claude Code 사용)
- **협업 가이드**: `/docs/COLLABORATION_GUIDE.md` 필독
- **브랜치 전략**: GitHub Flow 기반 (main ← develop ← feature/*)
- **커밋 규칙**: `[영역] 작업 내용` 형식 준수
- **PR 규칙**:
  - 최소 1명의 리뷰어 승인 필요
  - `.github/PULL_REQUEST_TEMPLATE.md` 템플릿 사용
  - GitHub Actions 자동 테스트 통과 필수

## 8. 작업 영역 분리 (충돌 방지)
### Frontend 개발자
- **담당**: `frontend/` 전체
- **주의**: `pubspec.yaml` 수정 시 팀원에게 공지

### Backend 개발자 1 (API)
- **담당**: `backend/routes/`, `backend/services/`
- **주의**: `app.py` 라우트 등록 시 충돌 주의

### Backend 개발자 2 (AI/크롤링)
- **담당**: `backend/crawler/`, `backend/ai/`
- **주의**: `requirements.txt` 수정 시 팀원에게 공지

## 9. Claude Code 협업 핵심 원칙
1. **작업 시작 전**: 항상 `develop` 최신화 후 본인 `feature/` 브랜치에서 작업
2. **커밋 전**: Claude에게 "변경된 파일 확인해줘" 요청
3. **공유 파일 수정 시**: Slack/Discord로 즉시 공지
4. **Claude 지시**: "내 작업 영역(예: backend/ai/)에서만 작업해줘" 명확히 전달
5. **PR 생성**: Claude에게 "PR 만들어줘" 요청 시 템플릿 자동 적용