# AIX-Boost 프로젝트 Handoff 문서

> 작성일: 2026-02-08 (최종 업데이트: 2026-02-12)
> 목적: 새로운 AI 세션이 프로젝트 컨텍스트를 이해할 수 있도록 진행 상황 정리

---

## 1. 프로젝트 개요

**AIX-Boost**는 군산대학교 학생들을 위한 맞춤형 공지사항 큐레이션 플랫폼입니다.

### 핵심 기능

- 학내 공지사항 자동 크롤링 (공지사항, 학사/장학, 모집공고)
- **Gemini AI** 기반 공지 분석 (요약, 카테고리 분류, 마감일 추출)
- **벡터 임베딩 + 하이브리드 검색**으로 의미 기반 검색 및 AI 추천
- 사용자 맞춤형 푸시 알림
- 북마크 기반 캘린더 연동 (D-day 표시)

### 기술 스택

| 영역      | 기술                              |
| --------- | --------------------------------- |
| Frontend  | Flutter (Dart), Provider          |
| Backend   | Flask (Python 3.10+)              |
| Database  | Supabase (PostgreSQL + pgvector)  |
| AI        | Gemini 2.0 Flash (Text + Vision)  |
| Embedding | text-embedding-004 (768차원)      |
| 배포      | Render (Backend), Flutter Web/APK |

---

## 2. 세션 6~8 (2026-02-12) 완료 작업

### 2.1 FCM 푸시 알림 버그 수정

| 변경 | 내용 |
|------|------|
| `notification_priority` 제거 | `AndroidNotification`의 `notification_priority="PRIORITY_HIGH"` 파라미터가 설치된 `firebase-admin` 버전에서 미지원하여 제거. `AndroidConfig(priority="high")`로 이미 충분 |
| 적용 위치 | `send_to_token()`, `send_to_multiple_users()` 양쪽 모두 수정 |

### 2.2 알림 화면 자동 새로고침

| 변경 | 내용 |
|------|------|
| StatefulWidget 전환 | `NotificationScreen`을 `StatelessWidget` → `StatefulWidget`으로 변경 |
| 자동 fetch | `initState`에서 `addPostFrameCallback`으로 `fetchFromBackend()` 호출하여 화면 진입 시 최신 알림 자동 조회 |

### 2.3 보안 취약점 전체 스캔 및 패치

전체 백엔드/프론트엔드 코드 보안 스캔을 수행하여 치명적 취약점을 식별하고 즉시 수정 가능한 항목을 패치했습니다.

**수정 완료:**

| # | 취약점 | 수정 내용 |
|---|--------|-----------|
| 1 | SSRF 이미지 프록시 | `startswith` → `urlparse` 호스트명 정확 검증으로 도메인 우회 차단 (`kunsan.ac.kr@attacker.com` 등), `@login_required` 추가로 비인증 접근 차단 |
| 2 | search.py 구문 오류 | 닫는 `}` 중복 제거 (서버 시작 불가 버그) |
| 3 | ApiService 인증 누락 | `SettingsProvider`, `SearchScreen`에서 `ApiService()` 직접 생성 → Provider 공유 인스턴스 주입으로 변경하여 인증 토큰 정상 포함 |

**식별되었으나 미수정 (의도적 보류):**

| # | 취약점 | 보류 사유 |
|---|--------|-----------|
| 1 | 공지 삭제/크롤링 트리거 권한 미체크 | 앱 내 해당 기능 UI 없음, DB 직접 관리로 대응 |
| 2 | Supabase service_role 키 분리 | 백엔드는 이미 anon 키 사용 중 |
| 3 | SECRET_KEY 하드코딩 폴백 | 현재 프로덕션 환경변수 설정 완료 상태 |

### 2.4 Render 메모리 최적화 (512MB OOM 해결)

Render 무료 플랜(512MB)에서 파이프라인 실행 시 메모리 초과로 인스턴스가 죽는 문제를 해결했습니다.

| 파일 | 변경 내용 | 절약 효과 |
|------|-----------|-----------|
| `analyzer.py` | 이미지 5MB 크기 제한, 2048px 리사이즈, 스트리밍 다운로드, `finally`에서 이미지 객체 해제 | ~20MB |
| `crawl_and_notify.py` | 파이프라인 단계별 `del` + `gc.collect()`, OCR 임시 데이터 즉시 삭제, soup 즉시 해제 | ~15MB |
| `notice_crawler.py` | 상세 페이지 파싱 후 `finally`에서 soup 객체 삭제 | ~10MB |
| `base_crawler.py` | HTML 파싱 후 response/html_text 즉시 해제 (이중 보관 방지) | ~15MB |

**메모리 사용량 (최적화 전→후):**
- 파이프라인 피크: ~52MB → ~22MB
- 5명 동시 접속 + 파이프라인 최악 시나리오: ~240MB (512MB 내 안전)

### 2.5 파이프라인 정리

| 변경 | 내용 |
|------|------|
| step0 제거 | `_step0_update_view_counts()` 호출을 `run()`에서 제거 |
| Supabase 싱글턴 | `create_client()` 직접 호출 → `get_supabase_client()` 싱글턴으로 변경 |
| timezone-aware | `datetime.now()` → `datetime.now(timezone.utc)` 적용 |
| 단계 번호 정리 | 6단계→5단계 라벨 통일 |

### 2.6 Markdown 정렬 보존

| 변경 | 내용 |
|------|------|
| `AlignPreservingConverter` | `MarkdownConverter` 상속 — `text-align: center/right` CSS를 `{=center=}...{=/center=}` 마커로 보존 |
| `md_with_align()` | 정렬 보존 Markdown 변환 헬퍼 함수 추가 |
| 크롤러 적용 | `_crawl_notice_detail()`에서 `md()` → `md_with_align()` 변경 |

### 2.7 MyBro 탭 대대적 개편

| 변경 | 내용 |
|------|------|
| 무한 환형 스크롤 | YouTube Shorts/TikTok 스타일 세로 무한 스크롤 — `PageView.builder(itemCount: items.length * 10000)` + 모듈러 인덱싱, pull-to-refresh/리롤 전면 제거 |
| MyBro API 분리 (뷔페→주문식) | 4개 탭이 각각 독립 API 호출 — 탭 진입 시에만 fetch, 5분 TTL 캐시, `_fetchForTab(index)` |
| 오늘 필수 API | `fetchEssentialNotices()` — 백엔드 점수 기반 정렬 (긴급+10, 중요+5, 마감임박+8, 신규+5, 조회수상위+3) |
| 마감 임박 API | `fetchDeadlineSoonNotices()` — 백엔드에서 오늘~D+7 마감 공지 조회, 마감일 오름차순 |
| 추천 30개 한번에 로드 | `_fetchSize: 10` → `30`, 프리페치 제거 — 인디케이터 총 개수 실시간 변동 문제 해결 |
| 탭 UI 변경 | 필 탭 → 언더라인 탭 스타일 (`_buildHeaderWithTabs`) |
| AI 추천 폴백 표시 | `isRecommendedFallback` 플래그 — AI 실패 시 "최신순" 구분 가능 |

### 2.8 알림 수신/클릭 버그 수정 (TODO #8, #9)

| 변경 | 내용 |
|------|------|
| `flutter_local_notifications` 도입 | Android 채널 `Importance.high` → 헤드업(팝업) 알림 + 소리 + 진동 |
| 포그라운드 알림 표시 | FCM은 포그라운드에서 알림을 안 보여줌 → `_handleForegroundMessage()`에서 로컬 알림으로 직접 표시 |
| WAKE_LOCK 퍼미션 | AndroidManifest.xml에 `WAKE_LOCK`, `USE_FULL_SCREEN_INTENT` 추가 |
| 백엔드 알림 설정 강화 | AndroidNotification에 `default_sound`, `default_vibrate_timings`, `visibility="public"` 추가 |
| 알림 클릭 → 상세 화면 | `GlobalKey<NavigatorState> navigatorKey` (main.dart) → FCMService에 주입 → `_navigateToNoticeDetail()` |
| 종료 상태 알림 탭 | `_pendingMessage` 보류 메커니즘 — 앱 종료 상태에서 알림 탭 시 로그인 후 네비게이션 |
| intent-filter | AndroidManifest.xml에 `FLUTTER_NOTIFICATION_CLICK` intent-filter 추가 |
| FCM 리소스 정리 | `dispose()` — 스트림 구독 해제, 콜백 초기화 (메모리 누수 방지) |

### 2.9 홈 화면 최적화 (그룹 A-2)

| 변경 | 내용 |
|------|------|
| 카드별 독립 로딩 플래그 | `_isPopularLoading`, `_isBookmarkedLoading`, `_isWeeklyDeadlineLoading` 추가 |
| 이번 주 마감 API | `fetchWeeklyDeadlineNotices()` — 홈 카드4용 경량 API |
| 북마크 공지 API | `fetchBookmarkedNotices()` — 홈 카드2용 경량 API |
| 북마크 토글 리팩토링 | `_rebuildBookmarkedNotices()`, `_updateBookmarkInList()` 헬퍼 — 모든 리스트(9개) 동기화 |
| 웹 드래그 스크롤 | `AppScrollBehavior` — 마우스/트랙패드 스크롤 (웹 대응) |
| D-day 텍스트 개선 | `deadlineDDayText` getter — D-3, D-Day, D+1 형식 |

### 2.10 변경 파일 요약 (2026-02-12 전체)

**백엔드 (8개):**
- `backend/services/fcm_service.py` — `notification_priority` 제거 + `default_sound`/`default_vibrate_timings`/`visibility` 추가
- `backend/services/supabase_service.py` — `deadline_from` 필터 지원
- `backend/routes/notices.py` — SSRF 방지, `deadline_from` 파라미터, essential/deadline-soon 엔드포인트
- `backend/routes/search.py` — 구문 오류 수정
- `backend/ai/analyzer.py` — 이미지 처리 메모리 최적화
- `backend/scripts/crawl_and_notify.py` — 단계별 gc.collect(), step0 제거, Supabase 싱글턴
- `backend/crawler/notice_crawler.py` — `AlignPreservingConverter`, soup 메모리 해제
- `backend/crawler/base_crawler.py` — response/html_text 즉시 해제

**프론트엔드 (14개+):**
- `frontend/lib/services/fcm_service.dart` — **대폭 리라이트** (flutter_local_notifications, navigatorKey, 포그라운드 알림, 클릭 네비게이션, dispose)
- `frontend/lib/main.dart` — `navigatorKey`, `AppScrollBehavior`, SettingsProvider ProxyProvider
- `frontend/lib/screens/auth_wrapper.dart` — `setNavigatorKey()`, `dispose()`
- `frontend/lib/screens/recommend_screen.dart` — 언더라인 탭, `_fetchForTab()`, `_loadData()` 제거
- `frontend/lib/providers/notice_provider.dart` — `fetchEssentialNotices()`, `fetchDeadlineSoonNotices()`, `fetchWeeklyDeadlineNotices()`, `fetchBookmarkedNotices()`, 북마크 리팩토링, 프리페치 제거
- `frontend/lib/services/api_service.dart` — `getEssentialNotices()`, `getDeadlineSoonNotices()`, `getDeadlineNotices()`, `getBookmarkedNotices()`, `deadlineFrom`
- `frontend/lib/widgets/flip_card/flip_card_section.dart` — 무한 환형 스크롤, pull-to-refresh 제거
- `frontend/lib/models/notice.dart` — `deadlineDDayText` getter
- `frontend/lib/screens/notification_screen.dart` — StatefulWidget + 자동 fetch
- `frontend/lib/screens/search_screen.dart` — Provider ApiService 주입
- `frontend/lib/providers/settings_provider.dart` — `updateApiService()` 외부 주입
- `frontend/android/app/src/main/AndroidManifest.xml` — WAKE_LOCK, USE_FULL_SCREEN_INTENT, FLUTTER_NOTIFICATION_CLICK
- `frontend/pubspec.yaml` — `flutter_local_notifications` 추가 (**팀 공지 필요**)

### 2.11 코드 리뷰 기반 대규모 수정 (76건 이슈 → 13건 수정)

전체 코드 리뷰를 수행하여 76건의 이슈를 발견하고 13건의 코드 수정을 적용했습니다.

| 변경 | 내용 |
|------|------|
| FCM 서비스 | 스트림 구독 해제 (`dispose`), 토큰 갱신 리스너, 보류 메시지 처리 |
| Auth 미들웨어 | `optional_login` 데코레이터 토큰 검증 개선 |
| 크롤러 안정성 | `notice_crawler.py` 예외 처리 강화 |
| 백엔드 라우트 | `bookmarks`, `calendar`, `crawl`, `notices`, `notifications`, `search`, `users` 안정성 개선 |
| 스케줄러/Supabase 서비스 | 안정성 개선 |
| 디데이 알림 스크립트 | `send_deadline_reminders.py` JOIN 쿼리 최적화 |

### 2.12 이미지 프록시 401 오류 수정

| 변경 | 내용 |
|------|------|
| 문제 | `Image.network`는 인증 헤더 전송 불가 → image-proxy의 `@login_required`에서 401 |
| 해결 | `backend/routes/notices.py` image-proxy `@login_required` → `@optional_login` |

### 2.13 회원가입 401 오류 수정

| 변경 | 내용 |
|------|------|
| 문제 | Supabase `signUp()` 후 `createUserProfile()` 호출 시 토큰 미설정 상태 |
| 해결 | `signup_screen.dart`에서 `authResponse.session`으로 토큰을 `ApiService`에 수동 설정 |

### 2.14 캘린더 콘텐츠 표시 수정

| 변경 | 내용 |
|------|------|
| 문제 | 캘린더 리스트에서 `notice.content` 그대로 표시 → `![]` 등 마크다운 아티팩트 노출 |
| 해결 | `calendar_screen.dart` 2곳에서 `notice.content` → `notice.aiSummary ?? notice.content` |

### 2.15 마감 공지 정렬 개선

| 변경 | 내용 |
|------|------|
| 홈 이번 주 일정 | `notice_provider.dart` `fetchWeeklyDeadlineNotices`에서 만료건 맨 뒤로 정렬 |
| 전체보기 모달 | `full_list_modal.dart` `showWeeklySchedule`에서 동일 정렬 적용 |

### 2.16 다크모드 다이얼로그 버튼 가시성 수정

| 변경 | 내용 |
|------|------|
| 문제 | 다크모드에서 캐시초기화, 설정초기화, 로그아웃, 회원탈퇴 다이얼로그의 취소 버튼 안 보임 |
| 해결 | 모든 다이얼로그 취소 버튼에 다크모드용 `Colors.white70` 명시적 색상 지정 |
| 버튼 위치 | 캐시/설정 초기화 다이얼로그에서 확인/취소 버튼 위치 교체 (확인 좌측, 취소 우측) |
| 적용 파일 | `settings_screen.dart` (캐시초기화, 설정초기화, 회원탈퇴), `profile_screen.dart` (로그아웃) |

### 2.17 버전 정보 아이콘 변경

| 변경 | 내용 |
|------|------|
| 문제 | 버전 정보 모달에 학사모(`Icons.school`) 아이콘 표시 |
| 해결 | `version_info_modal.dart`에서 `Image.asset('assets/images/icon_main.png')`으로 HeyBro 앱 아이콘 적용 |

### 2.18 추가 변경 파일 (2.11~2.17)

**백엔드:**
- `backend/routes/notices.py` — image-proxy `@optional_login` 변경
- `backend/routes/bookmarks.py`, `calendar.py`, `crawl.py`, `notifications.py`, `search.py`, `users.py` — 안정성 개선
- `backend/utils/auth_middleware.py` — `optional_login` 개선
- `backend/scripts/send_deadline_reminders.py` — JOIN 최적화
- `backend/scripts/migrate_content_to_markdown.py` — 안정성 개선
- `backend/services/notice_service.py`, `reranking_service.py`, `scheduler_service.py`, `supabase_service.py` — 안정성 개선

**프론트엔드:**
- `frontend/lib/screens/signup_screen.dart` — 토큰 설정 추가
- `frontend/lib/screens/settings_screen.dart` — 다크모드 다이얼로그 버튼 수정
- `frontend/lib/screens/profile_screen.dart` — 로그아웃 다이얼로그 다크모드 수정
- `frontend/lib/screens/calendar_screen.dart` — AI 요약 표시
- `frontend/lib/screens/home_screen.dart` — D-day 텍스트 수정 (3곳)
- `frontend/lib/screens/bookmark_screen.dart` — D-day 텍스트 수정
- `frontend/lib/screens/notice_detail_screen.dart` — D-day 텍스트 수정
- `frontend/lib/widgets/modals/full_list_modal.dart` — D-day, 만료건 정렬
- `frontend/lib/widgets/modals/version_info_modal.dart` — 앱 아이콘 변경

### 2.19 북마크 버그 수정 (4건 + 화면 수정)

| # | 버그 | 수정 내용 |
|---|------|-----------|
| 1 | `toggleBookmark` 9개 리스트 중 4개만 업데이트 | `_updateBookmarkInList()` 헬퍼로 9개 리스트 전체 동기화 |
| 2 | `_findCurrentBookmarkState` 반전 | `notice.isBookmarked` 필드값 대신 `_bookmarkedNotices.any()` 멤버십 체크로 수정 |
| 3 | 롤백용 `previousBookmarks` 캡처 시점 오류 | 수정 후가 아닌 수정 전에 캡처하도록 순서 변경 |
| 4 | `fetchBookmarkedNotices`가 `isBookmarked: true` 미설정 | `.copyWith(isBookmarked: true)` 보장 |
| 5 | 북마크 화면 RefreshIndicator가 `fetchNotices()` 호출 | `fetchBookmarkedNotices(limit: 50)` DB 직접 조회로 변경 (100개 API 이미 제거됨) |

### 2.20 브랜딩 통일 (aix-boost → HeyBro)

| 파일 | 변경 내용 |
|------|-----------|
| `frontend/lib/services/fcm_service.dart` | 알림 채널 표시명 `'AIX Boost 알림'` → `'HeyBro 알림'` (2곳) |
| `frontend/web/index.html` | `<title>`, `apple-mobile-web-app-title` → HeyBro |
| `frontend/web/manifest.json` | `name`, `short_name` → HeyBro |

> 채널 ID `aix_boost_notifications`는 내부 식별자이므로 변경 안 함. Android 앱명은 이미 `HeyBro` (AndroidManifest.xml).

### 2.21 앱 아이콘 교체 + 빌드 설정

| 변경 | 내용 |
|------|------|
| 아이콘 원인 | 기존 foreground 이미지에 "HeyBro" 텍스트 포함 → 시각적 중심이 위로 치우침 |
| 아이콘 수정 | 텍스트 없는 일러스트 전용 이미지로 5개 밀도별 교체 (mdpi 108px ~ xxxhdpi 432px) |
| Core Library Desugaring | `build.gradle.kts`에 `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4` 추가 (`flutter_local_notifications` 요구사항) |

### 2.22 APK 빌드 (공모전 제출용)

| 변경 | 내용 |
|------|------|
| 빌드 방식 | `.env` 파일 파싱 → `--dart-define` 플래그로 12개 환경변수 주입 |
| 결과물 | `build/app/outputs/flutter-apk/app-release.apk` (55.2MB) |

### 2.23 추가 변경 파일 (2.19~2.22)

**프론트엔드:**
- `frontend/lib/providers/notice_provider.dart` — 북마크 버그 4건 수정 (멤버십 체크, 롤백 순서, isBookmarked 보장)
- `frontend/lib/screens/bookmark_screen.dart` — RefreshIndicator `fetchBookmarkedNotices(limit: 50)`로 변경
- `frontend/lib/services/fcm_service.dart` — 알림 채널명 `'HeyBro 알림'`으로 변경
- `frontend/web/index.html`, `frontend/web/manifest.json` — 타이틀 HeyBro로 변경
- `frontend/android/app/build.gradle.kts` — Core Library Desugaring 추가

**에셋:**
- `frontend/android/app/src/main/res/drawable-*/ic_launcher_foreground.png` — 텍스트 없는 아이콘으로 교체 (5개 밀도)

---

## 3. 세션 4~5 (2026-02-10) 완료 작업

### 2.1 알림 시스템 고도화 (Full-Stack)

| 변경 | 내용 |
|------|------|
| 이중 임계값 필터링 | 카테고리 기반 알림 필터링 — 관심 카테고리 0.4 / 비관심 0.75 임계값 |
| 전체 검색 API | `GET /api/search/notices/all` — ILIKE, 카테고리, 날짜, 페이지네이션 지원 |
| 인기 공지 API | `GET /api/notices/popular-in-my-group` — 학과/학년 기반 인기 공지 |
| 조회 기록 API | `POST /api/notices/<id>/view` — 공지 조회 기록 저장 |
| 알림 설정 API | `PUT/GET /api/users/preferences/<id>/notification-settings` |
| 디데이 알림 | `send_deadline_reminders.py` — 마감일 임박 알림 스크립트 |
| 크롤러 알림 개선 | 알림 발송 시 `notification_mode` 체크 |
| FCM 버그 수정 | WebpushConfig `fcm_options` 제거 (HTTPS URL 필요 오류), ValueError 처리 추가 |
| Firebase 보안 | `firebase_options.dart`를 dotenv 사용하도록 변경, API 키를 `.env`로 이전 |
| 프론트엔드 알림 연동 | 알림 화면 백엔드 연동 (`fetchFromBackend`, `fromBackendJson`), 읽음 상태 동기화, 알림 설정 동기화, FCM 포그라운드 핸들러 유형 구분 (deadline vs new_notice), 당겨서 새로고침 |

### 2.2 검색/리랭킹 서비스 최적화

| 변경 | 내용 |
|------|------|
| 싱글턴 캐싱 | 검색/리랭킹 서비스를 싱글턴으로 변경하여 매 요청 재초기화 방지 |
| 리랭킹 프롬프트 간결화 | 토큰 제한으로 비용/응답시간 절감 |
| 추천 API 안정성 | 자동 재시도(2회) 및 최신순 폴백 로직 추가, API 타임아웃 10초→30초 확대 |
| user_preferences 방어 | 조회 실패 시 graceful 처리 |
| 리랭킹 파라미터 | 프론트엔드에서 `rerank=true` 파라미터 추가 |

### 2.3 서비스 리브랜딩 및 UI 전면 개편

| 변경 | 내용 |
|------|------|
| 서비스명 변경 | **AIX-Boost → HeyBro** 전체 변경 |
| 컬러 테마 교체 | 보라색(`#6C63FF`) → 딥 네이비 블루(`#0F2854`) 팔레트 전면 교체 (14개 파일) |
| 다크모드 가시성 수정 | `colorScheme.primary == surface` 문제 해결, `AppTheme.primaryLight` 분기, AI 요약 카드/북마크/D-Day 뱃지/MyBro 헤더 다크모드 대비 보장 |
| 스플래시 리디자인 | 손 모양 애니메이션 리디자인, 아이콘을 `icon_transparency.png`로 변경, 로고 등장 타이밍 앞당김 + `precacheImage` 추가 |
| 홈 화면 개선 | 추천정보 4개 카드 레이아웃 통일, 이번 주 일정 D-day 뱃지 우측 이동, 추천정보 섹션 배경 회색 변경, AppBar 사용자명 탭 시 홈 탭 이동 + 스크롤 최상단 |
| D-day 개선 | 캘린더 같은 날짜 개수 표시 제거, D-day 계산 자정 기준 통일 |

### 2.4 추천화면 리뉴얼 및 검색화면 추가

| 변경 | 내용 |
|------|------|
| 추천화면 개편 | 쇼츠 스타일 세로 카드 + 좌우 카테고리 전환 방식으로 리뉴얼 |
| 검색화면 신규 | `search_screen.dart` — 전체 검색 기능 UI 구현 |
| 플립카드 위젯 | `flip_card_section.dart`, `modern_flip_card.dart` — 카드 플립 애니메이션 |
| 플립 카운트다운 위젯 | `flip_countdown.dart`, `flip_digit.dart`, `flip_notice_card.dart` — D-day 카운트다운 |

### 2.5 마이페이지 개편 및 기타

| 변경 | 내용 |
|------|------|
| 마이페이지 개편 | 프로필 강조, 알림 섹션 삭제, 프로필 편집 독립 섹션, 고객센터→앱 정보로 이동 |
| AppBar 스크롤 | `scrolledUnderElevation: 0`으로 스크롤 시 색상 변경 방지 |
| 웹 아이콘 통일 | Icon-main 기반으로 192/512/maskable 아이콘 통일 |
| 카테고리 상세 카드 | 날짜 위치 고정 (`SizedBox height 22/40`) |
| 관련 링크 | 외부 URL 열기 (`url_launcher`) |
| Pillow 패키지 | `requirements.txt`에 Pillow 추가 (PIL import 누락 수정) |

### 2.6 DB 마이그레이션

| 파일 | 내용 |
|------|------|
| `docs/migrations/014_add_notice_views.sql` | `notice_views` 테이블 + RPC 함수 |
| `docs/migrations/015_add_notification_settings.sql` | 알림 설정 컬럼 + 중복 방지 인덱스 |
| `docs/database_schema.sql` | `notification_type` 컬럼 추가 |

### 2.7 변경 파일 요약 (2026-02-10)

**백엔드 (10개):**
- `backend/config.py` — 알림 임계값 설정
- `backend/routes/notices.py` — 인기 공지, 조회 기록 API
- `backend/routes/search.py` — 전체 검색 API, 싱글턴 캐싱
- `backend/routes/users.py` — 알림 설정 API
- `backend/scripts/crawl_and_notify.py` — 알림 필터링 개선
- `backend/scripts/send_deadline_reminders.py` — **신규** (디데이 알림)
- `backend/services/fcm_service.py` — FCM 버그 수정
- `backend/services/hybrid_search_service.py` — 싱글턴, 날짜 계산 수정
- `backend/services/reranking_service.py` — 프롬프트 간결화
- `backend/requirements.txt` — markdownify, Pillow 추가

**프론트엔드 (25개+):**
- `frontend/lib/models/notice.dart` — D-day 자정 기준 통일
- `frontend/lib/models/app_notification.dart` — 백엔드 연동 추가
- `frontend/lib/providers/notice_provider.dart` — 추천 API 재시도, 검색 기능
- `frontend/lib/providers/notification_provider.dart` — 백엔드 동기화
- `frontend/lib/providers/settings_provider.dart` — 알림 설정 동기화
- `frontend/lib/services/api_service.dart` — 검색/알림/인기공지 API 메서드
- `frontend/lib/screens/home_screen.dart` — 추천카드 통일, 테마 변경
- `frontend/lib/screens/recommend_screen.dart` — 쇼츠 스타일 개편
- `frontend/lib/screens/search_screen.dart` — **신규** (검색화면)
- `frontend/lib/screens/profile_screen.dart` — 마이페이지 개편
- `frontend/lib/screens/splash_screen.dart` — 리디자인
- `frontend/lib/screens/category_notice_screen.dart` — 카드 날짜 위치 고정
- `frontend/lib/screens/notification_screen.dart` — 백엔드 연동
- `frontend/lib/screens/notice_detail_screen.dart` — 테마 변경
- `frontend/lib/screens/settings_screen.dart` — 테마 변경
- `frontend/lib/screens/bookmark_screen.dart` — 테마 변경
- `frontend/lib/screens/calendar_screen.dart` — 테마 변경
- `frontend/lib/theme/app_theme.dart` — 네이비 블루 팔레트
- `frontend/lib/widgets/flip_card/` — **신규** (플립카드 위젯 2개)
- `frontend/lib/widgets/flip_clock/` — **신규** (플립 카운트다운 위젯 3개)
- `frontend/lib/firebase_options.dart` — dotenv 보안 설정
- `frontend/lib/screens/login_screen.dart` — HeyBro 서비스명 변경

**문서 (4개):**
- `TODO.md` — 작업 목록 업데이트
- `docs/database_schema.sql` — notification_type 컬럼
- `docs/migrations/014_add_notice_views.sql` — **신규**
- `docs/migrations/015_add_notification_settings.sql` — **신규**

---

## 4. 세션 2~3 (2026-02-08) 완료 작업

### 2.0 백엔드 환경 수정

- `google-generativeai` 0.3.2 → 0.8.6 업그레이드 (`output_dimensionality` 지원)
- `Pillow` 설치 (이미지 분석용)
- `backend/app.py`에 `strict_slashes = False` 추가 (CORS 리다이렉트 문제 해결)
- `frontend/.env`의 `BACKEND_URL`을 `http://localhost:5000`으로 변경 (로컬 개발용)

### 2.1 크롤링 파이프라인 개선

| 변경 | 내용 |
|------|------|
| 이미지 분석 확대 | 이미지가 있는 공지는 **무조건** Vision 분석 (기존: 본문 50자 미만일 때만) |
| 캘린더 단계 제거 | `calendar_events` 테이블 삭제되어 5단계 캘린더 이벤트 생성 로직 제거 |
| 파이프라인 단순화 | 6단계 → 5단계 (크롤링→분석→저장→관련도→알림) |

### 2.2 프론트엔드 버그 수정 (8건)

| # | 버그 | 수정 파일 | 내용 |
|---|------|----------|------|
| 1 | 캘린더 모달 북마크 미표시 | `notice_detail_screen.dart` | `provider.bookmarkedNotices`에서 DB 상태 확인, `fetchBookmarks()` 선호출 |
| 2 | 마감일순 정렬 오류 | `calendar_screen.dart`, `category_notice_screen.dart` | 지난 마감일 뒤로, 임박한 순서 우선 정렬 |
| 3 | 마감일 없는 북마크 미표시 | `calendar_screen.dart`, `home_screen.dart` | 마감일 없는 북마크도 리스트에 포함 |
| 4 | MYBRO AI 추천 Null 에러 | `notice.dart`, `notice_provider.dart` | `fromJson()` null safety 강화 |
| 5 | 마이페이지 카테고리 불일치 | `profile_screen.dart`, `signup_screen.dart` | 백엔드 카테고리와 통일 (학사,장학,취업,행사,교육,공모전) |
| 6 | MYBRO 긴급 공지사항 섹션 | `recommend_screen.dart` | priority 제거에 따라 긴급 섹션 및 관련 메서드 삭제 |
| 7 | MYBRO 카테고리 변경 미반영 | `recommend_screen.dart`, `profile_screen.dart` | 카테고리 저장 시 추천 갱신, 탭 전환 시 재로드 |
| 8 | 홈 화면 Notice import 누락 | `home_screen.dart` | `notice.dart` import 추가 |

---

## 5. 세션 3 (2026-02-08 오후~저녁) 완료 작업

### 3.1 이미지 표시 기능 구현

| 변경 | 내용 |
|------|------|
| 이미지 프록시 | `backend/app.py`에 `/api/notices/image-proxy` 엔드포인트 추가 (학교 서버 CORS/핫링크 우회) |
| HTML→Markdown 변환 | 크롤러에 `markdownify` 도입, `content` 컬럼을 순수 Markdown으로 저장 |
| `clean_markdown()` | bold 마커 파편화 수정 (`**2026****년**` → `**2026년**`) |
| 마이그레이션 스크립트 | `migrate_content_to_markdown.py` — 기존 DB content를 source_url에서 재크롤링하여 Markdown 변환 |

### 3.2 AI display_mode 기능 (POSTER/DOCUMENT/HYBRID)

| 변경 | 내용 |
|------|------|
| DB 마이그레이션 | `notices` 테이블에 `display_mode`, `has_important_image` 컬럼 추가 |
| AI 프롬프트 | `prompts.py`에 display_mode, has_important_image 판별 규칙 추가 |
| OCR 분리 | `crawl_and_notify.py` — OCR 텍스트를 `_ocr_text`에 별도 저장, `content`에 섞지 않음 |
| AI 분석기 | `analyzer.py` — display_mode 파싱 + 유효성 검증 (이미지 없으면 강제 DOCUMENT) |
| DB 매핑 | `notice_service.py` — 3개 메서드에 display_mode, has_important_image 매핑 추가 |
| Flutter 모델 | `notice.dart` — displayMode, hasImportantImage 필드 + 헬퍼 getter |
| Flutter UI | `notice_detail_screen.dart` — 유형별 레이아웃 분기 + 이미지 캐러셀 + 원문 접기 |
| 백필 스크립트 | `backfill_display_mode.py` — 휴리스틱 기반 기존 데이터 display_mode 결정 |

### 3.3 Markdown 서식 정리

| 변경 | 내용 |
|------|------|
| `\*` 복원 | markdownify가 `*`를 `\*`로 이스케이프하는 문제 수정 |
| 파편화 bold 제거 | `**※**`, `**‧**` 같은 특수문자 주위 bold 마커 제거 |
| 짝 없는 bold 제거 | 줄 단위로 `**` 개수가 홀수면 해당 줄의 `**` 전부 제거 |
| 프론트엔드 방어 | `_buildMarkdownContent()`에서 렌더링 전 짝 없는 `**` 제거 |

### 3.4 변경 파일 요약

**백엔드:**
- `backend/ai/prompts.py` — display_mode 프롬프트 추가
- `backend/ai/analyzer.py` — OCR 분리, display_mode 파싱
- `backend/scripts/crawl_and_notify.py` — OCR→content 오염 제거
- `backend/services/notice_service.py` — display_mode DB 매핑
- `backend/crawler/notice_crawler.py` — clean_markdown() 개선
- `backend/scripts/migrate_content_to_markdown.py` — 신규 (HTML→MD 마이그레이션)
- `backend/scripts/backfill_display_mode.py` — 신규 (display_mode 백필)

**프론트엔드:**
- `frontend/lib/models/notice.dart` — displayMode, hasImportantImage 필드
- `frontend/lib/screens/notice_detail_screen.dart` — 유형별 레이아웃 + 캐러셀 + bold 정리

**문서:**
- `docs/database_schema.sql` — display_mode, has_important_image, content_images 컬럼
- `docs/migrations/010_add_display_mode.sql` — 신규

---

## 6. 세션 1 완료 작업 (이전 세션)

### 4.1 DB 구조조정

불필요한 테이블과 컬럼을 정리하여 스키마를 단순화했습니다.

| 항목 | 변경 내용 |
|------|-----------|
| 삭제된 테이블 | `calendar_events`, `extracted_events` (미사용/고장 상태) |
| 삭제된 컬럼 | `notices.crawled_at` (created_at과 중복), `notices.extracted_dates` (deadline으로 대체) |
| 추가된 컬럼 | `notices.deadline DATE` (마감일 단일 필드) |
| 데이터 초기화 | `notices`, `user_bookmarks`, `notification_logs` TRUNCATE (유저 데이터 보존) |

#### 마이그레이션 파일
- `docs/migrations/007_add_user_bookmarks.sql` — user_bookmarks 테이블 추가
- `docs/migrations/008_restructure_db.sql` — DB 구조조정 (테이블 삭제, 컬럼 변경, 데이터 초기화)

#### 실행 방법
Supabase 대시보드 → SQL Editor에서 순서대로 실행:
1. `007_add_user_bookmarks.sql`
2. `008_restructure_db.sql`

### 4.2 캘린더 기능 버그 수정

**근본 원인 2가지:**
1. DB에 `deadline` 컬럼이 없어서 프론트엔드에서 항상 null
2. 캘린더가 모든 공지사항을 표시 (북마크된 것만 표시해야 함)

**해결:**
- DB에 `deadline DATE` 컬럼 추가 (마이그레이션)
- 캘린더 화면: `provider.bookmarkedNotices` 사용, deadline만 매칭
- `CalendarBuilders.markerBuilder`로 D-day 마커 표시
- calendar.py 라우트: `user_bookmarks` + `notices.deadline` 직접 조인

### 4.3 크롤러 개선 (게시판당 10개 제한)

- `crawl()`, `crawl_optimized()`에 `max_notices` 파라미터 추가
- **첫 크롤링** (DB 비어있음): 게시판당 최대 10개 × 3개 = 총 30개
- **정기 크롤링** (15분마다): 새 공지 전부 수집 (제한 없음, `max_notices=100`)
- 기존 TEST_LIMIT(5개 하드코딩) 제거

### 4.4 프론트엔드-백엔드 API 연동

- 북마크 API 연동 (`addBookmark`, `removeBookmark`, `getBookmarks`)
- AI 추천 공지 API 연동 (`getRecommendedNotices`)
- 캘린더 이벤트 API 연동
- `extractedDates` 필드 완전 제거 → `deadline` 단일 필드로 통일

---

## 7. 변경된 파일 목록 (세션 1~2)

### 백엔드 (10개)

| 파일 | 변경 내용 |
|------|-----------|
| `backend/app.py` | bookmarks, calendar 블루프린트 등록 |
| `backend/routes/bookmarks.py` | **신규** - 북마크 CRUD API |
| `backend/routes/calendar.py` | **신규** - 캘린더 API (user_bookmarks + notices.deadline 조인) |
| `backend/crawler/notice_crawler.py` | `max_notices` 파라미터 추가 |
| `backend/crawler/crawler_manager.py` | `max_notices` 파라미터 전달 |
| `backend/crawler/base_crawler.py` | `crawled_at` 제거 |
| `backend/scripts/crawl_and_notify.py` | 첫 크롤링/정기 크롤링 자동 분기, TEST_LIMIT 제거 |
| `backend/services/notice_service.py` | `extracted_dates` → `deadline`, `crawled_at` 제거 |
| `backend/services/supabase_service.py` | `crawled_at` 제거 |
| `backend/services/hybrid_search_service.py` | 하이브리드 검색 서비스 개선 |

### 프론트엔드 (8개)

| 파일 | 변경 내용 |
|------|-----------|
| `frontend/lib/models/notice.dart` | `extractedDates` 제거, `deadline` 통일 |
| `frontend/lib/providers/notice_provider.dart` | 캘린더 상태 제거, 북마크/추천 API 연동, 더미 데이터 정리 |
| `frontend/lib/services/api_service.dart` | 북마크/추천/캘린더 API 메서드 추가 |
| `frontend/lib/screens/calendar_screen.dart` | 북마크 기반 deadline 표시, D-day 마커 |
| `frontend/lib/screens/notice_detail_screen.dart` | 추출된 일정 → 마감일/D-day UI |
| `frontend/lib/screens/home_screen.dart` | `extractedDates` → `deadline` 참조 변경 |
| `frontend/lib/screens/recommend_screen.dart` | AI 추천 화면 개선 |
| `frontend/lib/screens/home_screen.dart` | `extractedDates` → `deadline` |

### 문서 (4개)

| 파일 | 변경 내용 |
|------|-----------|
| `docs/database_schema.sql` | 전체 스키마 재작성 (5개 테이블) |
| `docs/migrations/007_add_user_bookmarks.sql` | **신규** |
| `docs/migrations/008_restructure_db.sql` | **신규** |
| `handoff.md` | 이번 세션 작업 내용 반영 |

---

## 8. 현재 DB 스키마 (5개 테이블)

```
users              — 사용자 (Supabase Auth 연동)
user_preferences   — 사용자 관심 설정 (학과, 학년, 키워드)
notices            — 공지사항 (deadline 컬럼 추가, 벡터 임베딩)
user_bookmarks     — 사용자 북마크
notification_logs  — 알림 이력
```

### notices 테이블 주요 컬럼

```sql
id UUID PRIMARY KEY,
title TEXT NOT NULL,
content TEXT,                         -- 순수 Markdown (OCR 텍스트 미포함)
category TEXT,
source_url TEXT UNIQUE,
published_at TIMESTAMPTZ,
author TEXT,
view_count INTEGER DEFAULT 0,
ai_summary TEXT,
deadline DATE,                        -- 마감일 (AI가 추출)
is_processed BOOLEAN DEFAULT FALSE,
content_images TEXT[],                -- 본문 내 이미지 URL 배열
display_mode TEXT DEFAULT 'DOCUMENT', -- POSTER / DOCUMENT / HYBRID
has_important_image BOOLEAN DEFAULT FALSE,
content_embedding vector(768),        -- 벡터 임베딩
source_board TEXT,                    -- 원본 게시판명
board_seq INTEGER,                    -- 게시판 내 순번
created_at TIMESTAMPTZ DEFAULT NOW(),
updated_at TIMESTAMPTZ DEFAULT NOW()
```

---

## 9. 주요 API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/notices` | 공지사항 목록 조회 |
| GET | `/api/notices/<id>` | 공지사항 상세 조회 |
| POST | `/api/notices/<id>/view` | 공지 조회 기록 저장 |
| GET | `/api/notices/popular-in-my-group` | 학과/학년 인기 공지 |
| GET | `/api/search` | 하이브리드 검색 (BM25 + 벡터) |
| GET | `/api/search/notices/all` | 전체 검색 (ILIKE, 카테고리, 날짜, 페이지네이션) |
| GET | `/api/bookmarks` | 북마크 목록 조회 (로그인 필요) |
| POST | `/api/bookmarks` | 북마크 추가 (로그인 필요) |
| DELETE | `/api/bookmarks/<notice_id>` | 북마크 삭제 (로그인 필요) |
| GET | `/api/calendar/events` | 캘린더 이벤트 조회 (로그인 필요) |
| POST | `/api/users/preferences` | 사용자 선호도 설정 |
| GET | `/api/users/preferences/<id>/notification-settings` | 알림 설정 조회 |
| PUT | `/api/users/preferences/<id>/notification-settings` | 알림 설정 변경 |
| POST | `/api/crawl` | 수동 크롤링 트리거 |

---

## 10. 크롤링 파이프라인 흐름

```
스케줄러 (15분마다) → CrawlAndNotifyPipeline.run()
  1. _step1_crawl()     — 3개 게시판 크롤링 (HTML→Markdown 변환 포함)
  2. _step2_analyze()   — Gemini AI 분석 (OCR은 _ocr_text에 별도 저장) + display_mode 판별 + 임베딩 생성
  3. _step3_save_to_db() — DB 저장 (임베딩 + display_mode 포함)
  4. _step4_calculate_relevance() — 하이브리드 검색으로 관련 사용자 매칭
  5. _step5_send_notifications() — FCM 푸시 알림 (이중 임계값 필터링 + notification_mode 체크)
```

---

### 남은 작업

| # | 작업 | 상세 | 상태 |
|---|------|------|------|
| ~~1~~ | ~~알림 기능 구현~~ | ~~FCM 푸시 알림 연동 + 알림 화면 UI 구현~~ | **완료** (세션 4~5) |
| ~~2~~ | ~~전체 검색 API~~ | ~~ILIKE 기반 전체 검색 + 검색화면 UI~~ | **완료** (세션 4~5) |
| ~~3~~ | ~~관련 링크 클릭~~ | ~~url_launcher로 외부 URL 열기~~ | **완료** (세션 4~5) |
| 4 | 복수 날짜 처리 | 신청일/수납일 등 날짜가 2개 이상인 공지에서 캘린더 안내를 분리 표시 | 미완료 |
| 5 | 카테고리 아이콘 하이라이트 버그 | 홈에서 카테고리 선택 → 모달 닫기 후에도 아이콘이 선택 상태로 남는 문제 | 미완료 |

---

## 11. 환경 설정

### 필수 환경 변수 (.env)

```
GEMINI_API_KEY=...          # Gemini AI API 키
SUPABASE_URL=...            # Supabase 프로젝트 URL
SUPABASE_KEY=...            # Supabase anon/service 키
```

### 로컬 실행

```bash
# Backend
cd backend && python app.py   # http://localhost:5000

# Frontend
cd frontend && flutter run -d chrome
```

---

## 12. 수정 금지 파일

- `.env` - API 키/DB 보안 설정
- `backend/app.py` - 메인 서버 진입점 (구조 변경 시 팀 합의)
- `frontend/pubspec.yaml` - 패키지 버전 관리

---

_이 문서는 Claude Code 세션 간 컨텍스트 전달을 위해 작성되었습니다._
