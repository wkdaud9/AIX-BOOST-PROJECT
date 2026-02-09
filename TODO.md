# AIX-Boost 프로젝트 TODO

## 📋 진행 예정 작업

### 2026-02-11 (내일)

#### 🎯 백엔드: 카테고리 기반 알림 필터링 (이중 임계값)
- **파일**: `backend/scripts/crawl_and_notify.py`
- **위치**: `_step4_calculate_relevance()` 함수
- **핵심 아이디어**:
  - **사용자가 선택한 카테고리**: 낮은 점수로도 알림 (min_score=0.4)
  - **그 외 카테고리**: 유사도 매우 높을 때만 알림 (min_score=0.75)
- **작업 내용**:
  1. 공지사항 카테고리 조회
  2. 사용자 선호 카테고리 조회 (`user_preferences.categories`)
  3. 카테고리 일치 여부에 따라 다른 임계값 적용
  4. 벡터 점수 최소값 체크 (0.2 이상) 추가
- **예상 효과**:
  - 현재: 30개 중 29개 알림 (스팸 수준)
  - 개선: 30개 중 10~15개 알림 (관심사 기반 맞춤형)
- **환경변수 추가** (`.env`):
  ```env
  CATEGORY_MATCH_MIN_SCORE=0.4      # 관심 카테고리 최소 점수
  CATEGORY_UNMATCH_MIN_SCORE=0.75   # 비관심 카테고리 최소 점수
  MIN_VECTOR_SCORE=0.2              # 벡터 유사도 최소값
  ```
- **소요 시간**: 30분~1시간

#### 🔍 백엔드: 전체 검색 API 구현
- **파일**: `backend/routes/search.py`
- **엔드포인트**: `GET /api/search/notices/all`
- **기능**: 공지사항 통합 검색 (제목, 본문, 카테고리 등)
- **작업 내용**:
  ```python
  @search_bp.route('/notices/all', methods=['GET'])
  def search_all_notices():
      """
      공지사항 전체 검색

      쿼리 파라미터:
      - q: 검색어 (제목, 본문 검색)
      - category: 카테고리 필터 (선택)
      - date_from: 시작 날짜 (선택)
      - date_to: 종료 날짜 (선택)
      - sort: 정렬 (latest|views|relevance)
      - page: 페이지 번호 (기본 1)
      - limit: 페이지당 개수 (기본 20)
      """
  ```
- **구현 방식**:
  1. **기본 검색**: PostgreSQL `ILIKE` 사용 (제목, 본문)
  2. **카테고리 필터**: 배열 조건 검색
  3. **날짜 범위**: `published_at` 필터링
  4. **정렬**:
     - `latest`: 최신순 (기본값)
     - `views`: 조회수 높은 순
     - `relevance`: 벡터 유사도 순 (검색어 임베딩 생성)
  5. **페이지네이션**: `offset`/`limit` 사용
- **응답 형식**:
  ```json
  {
    "status": "success",
    "data": {
      "notices": [...],
      "total": 150,
      "page": 1,
      "total_pages": 8
    }
  }
  ```
- **프론트엔드 연동**: 나중에 (백엔드만 먼저 구현)
- **소요 시간**: 1~2시간

#### 👥 백엔드: "우리 학과/학년이 많이 본 공지" API 구현
- **파일**: `backend/routes/notices.py`
- **엔드포인트**: `GET /api/notices/popular-in-my-group`
- **기능**: 같은 학과/학년 학생들이 많이 본 공지 TOP 20
- **작업 내용**:

  1. **DB 스키마 추가** (`docs/database_schema.sql`)
     ```sql
     -- 공지사항 조회 기록 테이블
     CREATE TABLE IF NOT EXISTS notice_views (
         id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
         user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
         notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
         viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
         UNIQUE(user_id, notice_id)  -- 사용자당 공지 1번만 카운트
     );

     CREATE INDEX idx_notice_views_notice_id ON notice_views(notice_id);
     CREATE INDEX idx_notice_views_user_id ON notice_views(user_id);
     ```

  2. **조회수 기록 API** (공지 상세 조회 시 호출)
     ```python
     @notices_bp.route('/<notice_id>/view', methods=['POST'])
     @login_required
     def record_notice_view(notice_id):
         """공지사항 조회 기록 (중복 시 무시)"""
         supabase.table("notice_views").upsert({
             "user_id": g.user_id,
             "notice_id": notice_id
         }, on_conflict="user_id,notice_id").execute()
     ```

  3. **인기 공지 조회 API**
     ```python
     @notices_bp.route('/popular-in-my-group', methods=['GET'])
     @login_required
     def get_popular_in_my_group():
         """
         같은 학과/학년 학생들이 많이 본 공지 TOP 20

         쿼리 파라미터:
         - limit: 최대 개수 (기본 20)
         """
         # 1. 내 학과/학년 조회
         user = supabase.table("users").select("department, grade").eq("id", g.user_id).single()

         # 2. 같은 학과/학년 사용자 ID 목록
         peers = supabase.table("users")\
             .select("id")\
             .eq("department", user["department"])\
             .eq("grade", user["grade"])\
             .execute()

         # 3. 해당 사용자들이 본 공지 조회 (조회수 많은 순)
         popular_notices = supabase.rpc("get_popular_notices_by_users", {
             "user_ids": [p["id"] for p in peers.data],
             "limit": 20
         })
     ```

  4. **PostgreSQL 함수 생성** (Supabase SQL Editor)
     ```sql
     CREATE OR REPLACE FUNCTION get_popular_notices_by_users(
         user_ids UUID[],
         limit_count INTEGER DEFAULT 20
     )
     RETURNS TABLE (
         notice_id UUID,
         title TEXT,
         category TEXT,
         view_count BIGINT,
         published_at TIMESTAMPTZ
     ) AS $$
     BEGIN
         RETURN QUERY
         SELECT
             n.id,
             n.title,
             n.category,
             COUNT(DISTINCT nv.user_id) as view_count,
             n.published_at
         FROM notices n
         INNER JOIN notice_views nv ON n.id = nv.notice_id
         WHERE nv.user_id = ANY(user_ids)
         GROUP BY n.id
         ORDER BY view_count DESC, n.published_at DESC
         LIMIT limit_count;
     END;
     $$ LANGUAGE plpgsql;
     ```

- **프론트엔드 연동**:
  - 공지 상세 화면 진입 시 `POST /api/notices/<id>/view` 호출
  - 마이브로 탭에서 `GET /api/notices/popular-in-my-group` 호출

- **소요 시간**: 1~2시간

#### 🔧 프론트엔드: 리랭킹 파라미터 추가
- **파일**: `frontend/lib/services/api_service.dart`
- **위치**: 192-194번 줄
- **작업 내용**:
  ```dart
  queryParameters: {
    'limit': limit,
    'min_score': minScore,
    'rerank': 'true',  // ← 이 줄 추가
  },
  ```
- **이유**:
  - 현재 리랭킹이 항상 False로 처리됨
  - 백엔드는 리랭킹 지원하지만 프론트엔드에서 파라미터를 전달하지 않음
  - 리랭킹은 결과가 많고 점수가 비슷할 때만 자동 실행됨 (비용 최적화)
- **후속 작업**: APK 재빌드 필요 (1-2분 소요)

---

### 2026-02-11 이후 (우선순위 중간)

#### 📱 알림 설정 프론트엔드-백엔드 동기화
**현재 문제:**
- 프론트엔드 설정이 SharedPreferences에만 저장됨
- 백엔드는 `notification_enabled` (boolean)만 있음
- `NotificationMode` (모두끄기/일정만/공지만/모두켬) 지원 안됨
- `deadlineReminderDays` (1~7일 선택) 지원 안됨

**작업 내용:**
1. **DB 스키마 수정** (`docs/database_schema.sql`)
   ```sql
   ALTER TABLE user_preferences ADD COLUMN
       notification_mode TEXT DEFAULT 'all_on',  -- 'all_off', 'schedule_only', 'notice_only', 'all_on'
       deadline_reminder_days INTEGER DEFAULT 3;  -- 1~7일
   ```

2. **알림 설정 API 추가** (`backend/routes/users.py`)
   - `PUT /api/users/preferences/<user_id>/notification-settings`
   - Body: `{ "notification_mode": "all_on", "deadline_reminder_days": 3 }`

3. **프론트엔드 동기화** (`frontend/lib/screens/settings_screen.dart`)
   - 설정 변경 시 API 호출하여 백엔드에 저장
   - 앱 시작 시 백엔드에서 설정 불러오기

4. **알림 발송 시 설정 체크** (`backend/scripts/crawl_and_notify.py`)
   ```python
   if user_pref["notification_mode"] == "all_off":
       continue
   if user_pref["notification_mode"] == "schedule_only":
       continue  # 새 공지사항 알림 스킵
   ```

- **소요 시간**: 2~3시간

#### ⏰ 디데이 알림 시스템 구현
**현재 문제:**
- 프론트엔드에 디데이 알림 UI만 있고 실제 기능 없음
- 디데이 알림을 보내는 백엔드 스크립트 없음

**작업 내용:**
1. **디데이 알림 스크립트 작성** (`backend/scripts/send_deadline_reminders.py`)
   - 매일 00:00에 실행
   - deadline이 D-1 ~ D-7인 공지 조회
   - 사용자별 `deadline_reminder_days` 설정에 맞춰 알림 발송
   - 예: 사용자가 D-3 설정 → 마감 3일 전에 알림

2. **Cron Job 설정** (`render.yaml` 또는 Render 대시보드)
   ```yaml
   - type: cron
     name: deadline-reminder
     schedule: "0 0 * * *"  # 매일 자정 KST
     command: python backend/scripts/send_deadline_reminders.py
   ```

3. **알림 중복 방지**
   - `notification_logs` 테이블에 `notification_type` 필드 추가 ('new_notice', 'deadline')
   - 같은 공지에 대해 디데이 알림 1번만 발송

- **소요 시간**: 3~4시간

---

## ✅ 완료된 작업

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

### 알림 필터링 로직 (2026-02-11 개선 예정)
**현재 문제점:**
- 모든 공지를 동일한 기준(min_score=0.5)으로 필터링
- 30개 공지 → 29개 알림 (스팸 수준)

**개선 방안 (카테고리 기반 이중 임계값):**
- 사용자 관심 카테고리 공지: min_score=0.4 (놓치면 안됨)
- 비관심 카테고리 공지: min_score=0.75 (정말 중요한 것만)
- 벡터 점수 최소값: 0.2 이상 (완전히 다른 내용 차단)

**예시 (장학금에 관심 있는 학생):**
| 공지 | 카테고리 | 점수 | 현재 | 개선 |
|------|----------|------|------|------|
| 국가장학금 신청 | 장학 | 0.45 | ❌ | ✅ (관심) |
| 타학과 공모전 | 공모전 | 0.52 | ✅ | ❌ (비관심+낮음) |
| 본인학과 취업박람회 | 취업 | 0.85 | ✅ | ✅ (비관심+높음) |
