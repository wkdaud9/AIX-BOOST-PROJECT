# AIX-Boost 프로젝트 TODO

## 📋 진행 예정 작업

### 🔌 그룹 A: MyBro API 분리 — "뷔페 → 주문식" 전환

> **핵심 원칙**: 100접시를 한 번에 떠오는 뷔페가 아니라, 손님이 주문할 때마다 한 접시씩 요리해서 내오는 방식.
> - 기존 (BAD): 앱 켜자마자 / 탭 이동하자마자 공지 100개를 통으로 가져와서 `list.filter`로 4개 메뉴에 나눠담음
> - 변경 (GOOD): 4개 메뉴가 각각 독립 API를 갖고, 사용자가 해당 탭을 클릭했을 때만 서버에 요청
> - **캐시 규칙**: 이미 데이터를 가져온 적이 있다면 (List가 안 비어있다면) API를 다시 부르지 않는다

#### 동작 시나리오 (MyBro 탭 진입 시)

| 탭 | 진입 시점 | API 엔드포인트 | 동작 |
|---|---|---|---|
| AI 맞춤 추천 (기본 탭) | MyBro 진입 즉시 | `GET /api/notices/recommend?limit=10` | 자동 호출 |
| 오늘 필수 | 탭 클릭 시 | `GET /api/notices/essential?limit=10` | 클릭 시에만 호출 |
| 학과 인기 | 탭 클릭 시 | `GET /api/notices/popular-in-my-group?limit=10` | 클릭 시에만 호출 |
| 마감 임박 | 탭 클릭 시 | `GET /api/notices/deadline-soon?limit=10` | 클릭 시에만 호출 |

#### 📌 상세 구현 계획

**1. 백엔드: 신규 API 2개 추가** (`backend/routes/notices.py`)
   - `GET /api/notices/essential?limit=10` — 오늘 필수 공지
     - 최근 7일 공지 조회 → 긴급(+10), 중요(+5), 마감3일이내(+8), 신규3일이내(+5), 상위20%조회수(+3) 점수 계산 → 상위 N개 반환
   - `GET /api/notices/deadline-soon?limit=10` — 마감 임박 공지
     - 오늘~D+7 범위의 마감 공지만 조회, 마감일 오름차순 정렬
   - 기존 API 활용 (수정 없음):
     - `GET /api/search/notices` → AI 맞춤 추천 (기존 하이브리드 검색)
     - `GET /api/notices/popular-in-my-group` → 학과 인기 (기존 RPC)

**2. 프론트 API Service: 신규 메서드 2개 추가** (`frontend/lib/services/api_service.dart`)
   - `getEssentialNotices({int limit = 10})` → `GET /api/notices/essential`
   - `getDeadlineSoonNotices({int limit = 10})` → `GET /api/notices/deadline-soon`

**3. 프론트 Provider: 탭별 독립 상태 + 캐시** (`frontend/lib/providers/notice_provider.dart`)
   - 탭별 독립 리스트 4개:
     - `_recommendedPool` (기존) — AI 맞춤 추천
     - `_essentialNotices` (신규) — 오늘 필수
     - `_departmentPopularNotices` (기존) — 학과 인기
     - `_deadlineSoonNotices` (신규) — 마감 임박
   - 탭별 독립 로딩 플래그 4개:
     - `_isRecommendedLoading` (기존)
     - `_isEssentialLoading` (신규)
     - `_isDepartmentPopularLoading` (기존)
     - `_isDeadlineSoonLoading` (신규)
   - fetch 메서드 4개 (각각 캐시 체크: 리스트가 비어있지 않으면 스킵):
     - `fetchRecommendedNotices()` (기존, 캐시 로직 이미 있음)
     - `fetchEssentialNotices()` (신규) — 빈 리스트일 때만 API 호출
     - `fetchDepartmentPopularNotices()` (기존, 캐시 로직 이미 있음)
     - `fetchDeadlineSoonNotices()` (신규) — 빈 리스트일 때만 API 호출
   - **제거 대상**:
     - `todayMustSeeNotices` getter (클라이언트 점수 계산 로직) → 백엔드 API로 대체
     - `fetchUpcomingDeadlineNotices()` (통으로 가져오기) → `fetchDeadlineSoonNotices()`로 대체
     - `_upcomingDeadlineNotices` 리스트 → `_deadlineSoonNotices`로 대체
     - `deadlineSoonNotices` getter (클라이언트 필터링) → 직접 API 결과 사용

**4. 프론트 MyBro 화면: 탭 클릭 시 개별 호출** (`frontend/lib/screens/recommend_screen.dart`)
   - `onPageChanged` 콜백에서 탭 인덱스별 fetch 호출:
     - index 0: `fetchRecommendedNotices()` (MyBro 진입 시 자동)
     - index 1: `fetchEssentialNotices()` (탭 클릭 시)
     - index 2: `fetchDepartmentPopularNotices()` (탭 클릭 시)
     - index 3: `fetchDeadlineSoonNotices()` (탭 클릭 시)
   - 탭 클릭 핸들러(`onTap`)에서도 동일하게 호출
   - `categoryData` 매핑에서 새로운 provider 데이터 소스 연결:
     - index 1: `provider.todayMustSeeNotices` → `provider.essentialNotices`
     - index 3: `provider.deadlineSoonNotices` → `provider.deadlineSoonNoticesApi`
   - `initState`에서 기본 탭(AI 추천)만 자동 로드

**5. 홈 화면: MyBro 탭 이동 시 일괄 호출 제거** (`frontend/lib/screens/home_screen.dart`)
   - `_onItemTapped(2)` 에서 3개 API 일괄 호출 제거
   - MyBro 진입 시 AI 추천 1개만 호출하거나, 아예 호출 안 함 (RecommendScreen.initState에서 처리)

#### 기대 효과
- 초기 로딩 속도 급상승: 100개 → 10개 (데이터 양 1/10)
- 데이터 요금 절약: 안 보는 탭의 데이터는 다운로드하지 않음
- 서버 부하 감소: 4개 무거운 쿼리 동시 실행 → 사용자 행동에 따라 분산

#### 주의사항
- 캐시 정책: 리스트가 비어있지 않으면 재호출 스킵, `force: true`로 강제 갱신 가능
- 홈 화면 카드(HOT/북마크/AI추천/이번주마감)는 기존대로 유지 (이미 개별 경량 API 사용 중)
- `fetchNotices()` (100개 통으로 가져오기)는 더 이상 사용하지 않음

### 🏠 그룹 A-2: 홈 화면 최적화 — "각개전투" (Independent Card Loading)

> **핵심 원칙**: 4개 카드가 각각 독립 API를 호출하고, 먼저 도착한 데이터가 먼저 렌더링됨.
> 느린 API(AI 추천 ~3초)가 빠른 API(HOT 게시물 ~0.5초)를 블로킹하지 않음.

#### 현재 상태 (이미 구현 완료)

| 단계 | 설명 | 상태 |
|---|---|---|
| fetchNotices(100) 제거 | 통으로 가져오기 제거, 4개 개별 API로 전환 | ✅ 완료 |
| Fire-and-forget | initState에서 4개 API를 await 없이 병렬 호출 | ✅ 완료 |
| Consumer 독립 렌더링 | 4개 카드 각각 개별 Consumer&lt;NoticeProvider&gt; 사용 | ✅ 완료 |

현재 initState 호출 구조:
- `fetchPopularNotices()` → 카드1: HOT 게시물
- `fetchBookmarkedNotices()` → 카드2: 저장한 일정
- `fetchRecommendedNotices(limit: 10)` → 카드3: AI 추천
- `fetchWeeklyDeadlineNotices()` → 카드4: 이번 주 마감

#### 📌 남은 개선 작업

**1. 카드별 로딩 스켈레톤 추가** (`notice_provider.dart`, `home_screen.dart`)
   - 현재 문제: AI 추천 카드만 `isRecommendedLoading`으로 로딩 표시, 나머지 3개 카드는 로딩 상태 없음
   - Provider에 로딩 플래그 3개 추가:
     - `_isPopularLoading` → HOT 게시물 카드
     - `_isBookmarkedLoading` → 저장한 일정 카드
     - `_isWeeklyDeadlineLoading` → 이번 주 마감 카드
   - 각 fetch 메서드에서 `_isXxxLoading = true` → API 호출 → `_isXxxLoading = false` + `notifyListeners()`
   - 각 카드 위젯에서 로딩 중일 때 shimmer 스켈레톤 또는 CircularProgressIndicator 표시

**2. MyBro 탭 일괄 호출 제거** (`home_screen.dart`)
   - `_onItemTapped(2)`에서 3개 API 일괄 호출(lines 70-76) 제거
   - MyBro 화면(`recommend_screen.dart`)의 initState 또는 onPageChanged에서 자체 처리
   - 그룹 A (MyBro 주문식 전환)과 연계 작업

**3. (선택) Selector 최적화** (`home_screen.dart`)
   - Consumer → Selector로 교체하여 불필요한 리빌드 방지
   - 예: `Selector<NoticeProvider, List<Notice>>(selector: (_, p) => p.popularNotices, ...)`
   - 다른 카드 데이터 변경 시 해당 카드만 리빌드됨 (현재 Consumer도 충분히 동작하므로 우선순위 낮음)

#### 기대 효과
- HOT 게시물(0.5초) → 먼저 표시, AI 추천(3초) → 나중에 표시 (서로 독립)
- 각 카드에 로딩 스켈레톤이 있어 UX 개선
- MyBro 탭 진입 시 불필요한 사전 호출 제거로 네트워크 절약

#### 주의사항
- RefreshIndicator의 onRefresh는 `Future.wait()`로 4개 모두 완료 대기 → 이건 유지 (당겨서 새로고침은 전체 완료 후 인디케이터 닫혀야 함)
- Selector 교체 시 `List` 비교는 참조 동일성 기반이므로, Provider에서 새 리스트 할당 확인 필요

### 🎨 그룹 B: UI/UX 개선 (항목 3, 4, 5, 7)

4. **메인 홈 카드 UI 수정**
   - 홈 화면에 나눠진 카드들 UI 개선()
   - 📌 **상세 구현 계획**
     - **수정 파일**: `frontend/lib/screens/home_screen.dart`, `frontend/lib/theme/app_theme.dart`
     - PageView `viewportFraction`을 1.0 → 0.88로 변경 → 양쪽 카드 미리보기(peek) 효과
     - 활성 카드 풀사이즈, 비활성 카드 0.93x 스케일 + 낮은 opacity 애니메이션 적용
     - 카드 높이 340 → 360으로 여유 있게 조정
     - 하단 인디케이터를 캡슐 스타일로 변경 (활성: 넓은 pill, 비활성: 작은 dot)
     - 로딩 중 shimmer 스켈레톤 추가
     - **주의**: 다크모드 테스트 필수, 5인치 소형 화면 확인, shimmer 패키지 추가 시 `pubspec.yaml` 팀 공지 필요

5. **스플래시 스크린 1번 손 모양 이모지 깨짐 수정**
   - 크롬(웹)에서 스플래시 스크린 첫 번째 화면의 손 모양 이모지가 간헐적으로 깨져서 표시되는 문제 수정
   - 📌 **상세 구현 계획**
     - **수정 파일**: `frontend/lib/screens/splash_screen.dart`, `frontend/assets/images/` (에셋 추가)
     - **원인**: `_whiteEmoji()`가 `ColorFilter.mode(Colors.white, BlendMode.srcIn)`으로 이모지를 흰색 실루엣으로 렌더링 → 크롬에서 이모지가 비트맵으로 렌더링되어 ColorFilter 호환 안 됨
     - **방법 A (권장)**: 이모지 대신 PNG 이미지 에셋으로 교체
       - `hand_wave_white.png`, `fist_left_white.png`, `fist_right_white.png` 생성 → `assets/images/`에 배치
       - `_whiteEmoji()` → `_splashIcon(String assetName, double size)` 변경, `Image.asset()` 사용
       - `didChangeDependencies`에서 새 이미지도 `precacheImage()` 추가
     - **방법 B (대안)**: Material Icons 사용 (`Icons.waving_hand` 등) → 에셋 생성 불필요
     - **주의**: `pubspec.yaml`에 에셋 등록 필요 (팀 공지), 1x/2x/3x 해상도 대응, 크롬+안드로이드 테스트

6. **알림 비어있을 때 테스트 알림 생성 메뉴 제거**
   - 알림이 없을 때 표시되는 테스트 알림 생성 버튼 제거
   - 📌 **상세 구현 계획**
     - **수정 파일**: `frontend/lib/screens/notification_screen.dart`
     - AppBar `PopupMenuButton`에서 `PopupMenuItem(value: 'test', ...)` 제거
     - `onSelected` 핸들러에서 `else if (value == 'test')` 분기 제거
     - 빈 상태 UI의 `OutlinedButton`("테스트 알림 생성") 제거
     - `NotificationProvider.createSampleNotifications()` 메서드는 개발용으로 유지
     - 선택적: `kDebugMode` 분기로 디버그 빌드에서만 표시
     - **주의**: 팝업 메뉴에 test 외에 다른 항목 확인, 없으면 팝업 메뉴 자체 정리

7. **MyBro 탭 상단 헤더 투명도 적용**
   - 고정된 상단 헤더에 투명도를 높여서 뒷배경이 살짝 보이도록 수정
   - 📌 **상세 구현 계획**
     - **수정 파일**: `frontend/lib/screens/recommend_screen.dart`
     - 헤더 Container의 `color: colorScheme.surface` → `color: colorScheme.surface.withOpacity(0.85)` 변경
     - `ClipRect` + `BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10))` 감싸서 글래스모피즘(frosted glass) 효과
     - 현재 Column 레이아웃 → Stack 레이아웃으로 변경하여 카드 콘텐츠가 헤더 뒤로 스크롤되도록
     - PageView 콘텐츠에 헤더 높이만큼 상단 패딩 추가
     - `import 'dart:ui'` 추가 (ImageFilter용)
     - **주의**: 저사양 안드로이드에서 BackdropFilter 성능 이슈 가능 → 단순 opacity로 폴백 고려, 라이트/다크모드별 투명도 값 차등 (라이트: 0.88, 다크: 0.92)

### 🔔 그룹 C: 알림 시스템 (항목 8, 9, 10)

8. **알림 수신 시 핸드폰 화면 안 켜지는 문제 수정**
   - 푸시 알림 도착 시 화면이 깨어나지 않는 문제 해결
   - 📌 **상세 구현 계획**
     - **수정 파일**: `frontend/android/app/src/main/AndroidManifest.xml`, `frontend/lib/services/fcm_service.dart`, `backend/services/fcm_service.py`
     - AndroidManifest.xml에 `WAKE_LOCK`, `USE_FULL_SCREEN_INTENT` 퍼미션 추가
     - `fcm_service.dart`의 `initialize()`에서 알림 채널 생성: `AndroidNotificationChannel('aix_boost_notifications', importance: Importance.high, enableVibration: true, playSound: true)`
     - 백엔드 `fcm_service.py`의 AndroidNotification에 `default_sound=True`, `default_vibrate_timings=True`, `visibility="public"` 추가
     - **주의**: `flutter_local_notifications` 패키지 필요 여부 확인 (`pubspec.lock` 체크), 제조사별 배터리 최적화 설정은 앱에서 해결 불가 → 사용자 안내 필요

9. **알림 클릭 시 앱으로 이동하지 않는 문제 수정**
   - 알림 탭 시 앱이 열리지 않거나 해당 화면으로 이동하지 않는 문제 해결
   - 📌 **상세 구현 계획**
     - **수정 파일**: `frontend/lib/main.dart`, `frontend/lib/services/fcm_service.dart`, `frontend/android/app/src/main/AndroidManifest.xml`, `frontend/lib/screens/auth_wrapper.dart`
     - `main.dart`에 `GlobalKey<NavigatorState> navigatorKey` 생성 → `MaterialApp`에 전달
     - `fcm_service.dart`에 navigatorKey 프로퍼티 추가, initialize 시 주입
     - `_handleMessageOpenedApp()` 구현: `message.data['notice_id']`로 `NoticeDetailScreen` 네비게이션
     - 앱 종료 상태: `getInitialMessage()` 결과를 1.5초 딜레이 후 네비게이션 (위젯 트리 빌드 대기)
     - AndroidManifest.xml `<activity>`에 `FLUTTER_NOTIFICATION_CLICK` intent-filter 추가
     - **주의**: 로그인 전 알림 클릭 시 인증 상태 확인 필요, 종료 상태에서의 네비게이션은 스플래시→인증→상세 순서 보장 필요

10. **D-day 알림 기능 수정 (북마크 기반으로 변경)**
    - 현재: 마감 임박 공지 전체에 대해 D-day 알림을 보내는 방식
    - 변경: 사용자가 북마크한 공지에 한해서만 D-day 알림 발송
    - 사용자가 설정한 "며칠 전 알림 받기" 값에 따라 알림 시점 결정
    - 예: 사용자가 3일 전으로 설정 → 마감 D-3에 알림 발송
    - 📌 **상세 구현 계획**
      - **수정 파일**: `backend/scripts/send_deadline_reminders.py`
      - `_find_upcoming_deadlines()` → `_find_bookmarked_upcoming_deadlines()`로 변경
        - `user_bookmarks` 테이블과 `notices` 테이블 JOIN
        - WHERE `notices.deadline` BETWEEN D-1 ~ D-7
        - SELECT `user_id, notice_id, notices(id, title, deadline, category)`
      - `_send_reminders()` 루프를 user-bookmark 쌍 기반으로 재구성:
        - 각 (user_id, notice_id)별로: `notification_mode` 확인 → `deadline_reminder_days` 확인 → 중복 확인 → FCM 발송
      - 알림 메시지 변경: "북마크한 공지 마감 D-X: {제목}"
      - **주의**: Supabase PostgREST foreign table select 문법 확인 (`user_bookmarks` → `notices` 관계), 안 되면 2단계 쿼리로 대체

---

## ✅ 완료된 작업

### 2026-02-11

#### 🎨 프론트엔드 UI/UX 개선
- ✅ UI/UX 전체 개선 (다크모드/라이트모드 가시성 및 디자인)
- ✅ 카테고리 모달창 날짜 우측 정렬 수정
- ✅ 로그인 후 로딩 화면 추가 (빈 화면 방지)
- ✅ 카테고리 아이콘 변경

#### 🐛 버그 수정
- ✅ 스플래시 스크린 투명 이미지 로드 실패 수정
  - `frontend/assets/images/icon_transparency.png` 교체
  - `frontend/web/icons/Icon-transparency.png` 웹 아이콘 추가

#### 🚀 배포/운영 작업
- ✅ 디데이 알림 스케줄러 등록 (APScheduler cron, 매일 09:00 KST)
  - `backend/services/scheduler_service.py` 수정

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
