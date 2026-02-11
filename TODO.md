# AIX-Boost 프로젝트 TODO

## 📋 진행 예정 작업

### 🎨 프론트엔드 UI/UX 개선
- ⬜ UI/UX 전체 개선 (다크모드/라이트모드 가시성 및 디자인)
- ⬜ 카테고리 모달창 날짜 우측 정렬 수정
- ⬜ 로그인 후 로딩 화면 추가 (빈 화면 방지)
- ⬜ 카테고리 아이콘 변경

### 🐛 버그 수정
- ⬜ 스플래시 스크린 투명 이미지 로드 실패 수정

### ✅ 완료된 배포/운영 작업
- ✅ 디데이 알림 스케줄러 등록 (APScheduler cron, 매일 09:00 KST)

---

## ✅ 완료된 작업

### 2026-02-11

#### 🐛 마이페이지 학과/학년 변경 시 DB 미반영 버그 수정
- ✅ `backend/routes/users.py`: `PUT /api/users/profile/<user_id>` 엔드포인트 추가 (name, department, grade 업데이트 + 임베딩 재생성)
- ✅ `frontend/lib/services/api_service.dart`: `updateUserProfile()` 메서드 추가
- ✅ `frontend/lib/widgets/modals/profile_edit_modal.dart`: `_saveProfile()`에서 프로필 + 카테고리 순차 저장

#### 🐛 공지 조회 기록 미저장 버그 수정
- ✅ `frontend/lib/providers/notice_provider.dart`: `getNoticeDetail()`에서 `recordNoticeView()` 호출 추가

#### 🐛 알림 중복 표시 버그 수정
- ✅ `frontend/lib/screens/auth_wrapper.dart`: FCM 포그라운드 핸들러에서 로컬 알림 생성 → `fetchFromBackend()` 호출로 변경
- ✅ `backend/scripts/crawl_and_notify.py`: 알림 로그 insert 전 중복 체크 추가

#### 🗄️ Supabase 마이그레이션 실행
- ✅ `docs/migrations/014_add_notice_views.sql` — Supabase SQL Editor에서 실행 완료
- ✅ `docs/migrations/015_add_notification_settings.sql` — Supabase SQL Editor에서 실행 완료

#### 🎯 백엔드: 카테고리 기반 알림 필터링 (이중 임계값)
- ✅ `backend/config.py`: 환경변수 3개 추가 (`CATEGORY_MATCH_MIN_SCORE`, `CATEGORY_UNMATCH_MIN_SCORE`, `MIN_VECTOR_SCORE`)
- ✅ `backend/scripts/crawl_and_notify.py`: `_load_user_categories()` 헬퍼 추가, `_step4_calculate_relevance()` 이중 임계값 적용
  - 관심 카테고리: min_score=0.4 / 비관심: min_score=0.75 / 벡터 최소: 0.2

#### 🔍 백엔드: 전체 검색 API
- ✅ `backend/routes/search.py`: `GET /api/search/notices/all` 엔드포인트 추가
  - ILIKE 검색, 카테고리 필터, 날짜 범위, 정렬(latest|views), 페이지네이션

#### 👥 백엔드: 학과/학년 인기 공지 API
- ✅ `docs/migrations/014_add_notice_views.sql`: notice_views 테이블 + RPC 함수 생성
- ✅ `backend/routes/notices.py`: `GET /api/notices/popular-in-my-group`, `POST /api/notices/<notice_id>/view` 추가

#### 🔧 프론트엔드: 리랭킹 파라미터 추가
- ✅ `frontend/lib/services/api_service.dart`: `getRecommendedNotices()`에 `'rerank': 'true'` 추가

#### 📱 알림 설정 프론트엔드-백엔드 동기화
- ✅ `docs/migrations/015_add_notification_settings.sql`: notification_mode, deadline_reminder_days 컬럼 추가
- ✅ `backend/routes/users.py`: `PUT/GET /api/users/preferences/<user_id>/notification-settings` 추가
- ✅ `frontend/lib/providers/settings_provider.dart`: 백엔드 동기화 (`_syncFromBackend`, `_syncToBackend`)
- ✅ `frontend/lib/services/api_service.dart`: `getNotificationSettings()`, `updateNotificationSettings()` 추가
- ✅ `backend/scripts/crawl_and_notify.py`: `_step5`에서 `notification_mode` 체크 (all_off/schedule_only 스킵)

#### ⏰ 디데이 알림 시스템
- ✅ `backend/scripts/send_deadline_reminders.py`: 마감 리마인더 스크립트 작성
  - D-1~D-7 공지 조회, 사용자별 설정 확인, 중복 방지, FCM 발송
- ✅ `docs/migrations/015_add_notification_settings.sql`: notification_type 컬럼 + 중복 방지 인덱스

#### 🔔 알림 화면 백엔드 연동 (버그 수정)
- ✅ `frontend/lib/models/app_notification.dart`: `fromBackendJson()` 팩토리 추가 (백엔드 필드명 매핑)
- ✅ `frontend/lib/providers/notification_provider.dart`: `fetchFromBackend()` 추가, `markAsRead`/`markAllAsRead` 백엔드 동기화
- ✅ `frontend/lib/main.dart`: `ChangeNotifierProxyProvider`로 변경하여 ApiService 주입
- ✅ `frontend/lib/screens/auth_wrapper.dart`: 로그인 시 `fetchFromBackend()` 호출 + FCM 알림 유형 구분 (deadline vs new_notice)
- ✅ `frontend/lib/screens/notification_screen.dart`: `RefreshIndicator` 추가 (당겨서 새로고침)
- ✅ `docs/database_schema.sql`: `notification_type` 컬럼 추가 (스키마 문서 동기화)

### 2026-02-09 (저녁)

#### 크롤러 제목 잘림 버그 수정
- ✅ `backend/crawler/notice_crawler.py`: 상세 페이지에서 완전한 제목 추출
  - 문제: 목록 페이지에서 "제목입니다..." 같이 잘린 제목이 DB에 저장됨
  - 해결: 상세 페이지의 제목 영역(`div.bv_title` 등)에서 전체 제목 다시 추출
  - 적용: 다음 크롤링부터 완전한 제목 저장됨
  - 기존 데이터: "..." 포함된 채로 남음 (재크롤링하면 업데이트됨)

### 2026-02-09 (낮)

#### Firebase 환경변수 보안 설정
- ✅ `frontend/.env`: Firebase 키 환경변수로 이전
- ✅ `frontend/lib/firebase_options.dart`: dotenv 사용하도록 수정
- ✅ `backend/.env`: Firebase Admin SDK JSON 추가

#### FCM 푸시 알림 시스템 구축
- ✅ `backend/services/fcm_service.py`: FCM 서비스 구현
- ✅ `backend/test_fcm.py`: FCM 테스트 스크립트 작성
- ✅ FCM 버그 수정 (WebpushConfig, ValueError 처리)

#### ngrok 터널링 설정
- ✅ ngrok 설정으로 외부 접속 가능 (`https://delana-rebuffable-nonurgently.ngrok-free.dev`)
- ✅ `frontend/.env`: ngrok URL로 업데이트
- ✅ APK 빌드 및 폰 테스트 성공

#### 하이브리드 검색 버그 수정
- ✅ `backend/services/hybrid_search_service.py`: PostgreSQL 날짜 계산 오류 수정
  - 문제: `now() - interval '30 days'` 문자열 오류
  - 해결: Python datetime으로 계산하여 ISO 포맷으로 전달

---

## 📝 메모

### ngrok 사용 시 주의사항
- ngrok 터미널 닫으면 서버 연결 끊김
- 무료 플랜은 재시작 시 URL 변경됨 (재빌드 필요)
- Flask 서버(`python app.py`)도 계속 실행 필요

### 빌드 시간
- 첫 APK 빌드: 5-15분
- 이후 재빌드: 1-3분 (Gradle 캐시 활용)

### 리랭킹 동작 방식
- 결과 10개 이하: 리랭킹 스킵
- 상위 5개 점수 차이 0.1 이상: 리랭킹 스킵
- 점수가 비슷비슷할 때만 Gemini AI로 재정렬 (비용 최적화)

### 알림 필터링 로직 (2026-02-11 구현 완료)
**구현된 이중 임계값 (카테고리 기반):**
- 사용자 관심 카테고리 공지: min_score=0.4 (놓치면 안됨)
- 비관심 카테고리 공지: min_score=0.75 (정말 중요한 것만)
- 벡터 점수 최소값: 0.2 이상 (완전히 다른 내용 차단)
- 환경변수: `CATEGORY_MATCH_MIN_SCORE`, `CATEGORY_UNMATCH_MIN_SCORE`, `MIN_VECTOR_SCORE`
