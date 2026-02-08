# AIX-Boost 프로젝트 Handoff 문서

> 작성일: 2026-02-08
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

## 2. 세션 2 (2026-02-08 오후) 완료 작업

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

## 3. 세션 3 (2026-02-08 오후~저녁) 완료 작업

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

## 4. 세션 1 완료 작업 (이전 세션)

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

## 5. 변경된 파일 목록 (세션 1~2)

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

## 6. 현재 DB 스키마 (5개 테이블)

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

## 7-1. 주요 API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/notices` | 공지사항 목록 조회 |
| GET | `/api/notices/<id>` | 공지사항 상세 조회 |
| GET | `/api/search` | 하이브리드 검색 (BM25 + 벡터) |
| GET | `/api/bookmarks` | 북마크 목록 조회 (로그인 필요) |
| POST | `/api/bookmarks` | 북마크 추가 (로그인 필요) |
| DELETE | `/api/bookmarks/<notice_id>` | 북마크 삭제 (로그인 필요) |
| GET | `/api/calendar/events` | 캘린더 이벤트 조회 (로그인 필요) |
| POST | `/api/users/preferences` | 사용자 선호도 설정 |
| POST | `/api/crawl` | 수동 크롤링 트리거 |

---

## 7. 크롤링 파이프라인 흐름

```
스케줄러 (15분마다) → CrawlAndNotifyPipeline.run()
  1. _step1_crawl()     — 3개 게시판 크롤링 (HTML→Markdown 변환 포함)
  2. _step2_analyze()   — Gemini AI 분석 (OCR은 _ocr_text에 별도 저장) + display_mode 판별 + 임베딩 생성
  3. _step3_save_to_db() — DB 저장 (임베딩 + display_mode 포함)
  4. _step4_calculate_relevance() — 하이브리드 검색으로 관련 사용자 매칭
  5. _step5_send_notifications() — 푸시 알림 (FCM 미구현, 로그만 저장)
```

---

## 8. 남은 작업 / 주의사항

### 알려진 이슈
- ~~`CalendarService` 클래스가 삭제된 `calendar_events` 테이블 참조~~ → **해결 완료**: `calendar_service.py` 삭제, `crawler_manager.py`/`test_gemini_integration.py`/`run_analyze_existing.py`에서 참조 제거
- FCM 푸시 알림 미구현 (notification_logs에 로그만 저장)

### 다음 작업 (2026-02-09 예정)

| # | 작업 | 상세 | 영향 범위 |
|---|------|------|-----------|
| 1 | 복수 날짜 처리 | 신청일/수납일 등 날짜가 2개 이상인 공지에서 ai_summary의 날짜를 파싱하여 캘린더 안내를 분리 표시 | Backend AI, Frontend 캘린더 |
| 2 | 북마크 기반 인기순 정렬 | 카테고리 세부 화면에서 인기순 = 북마크 횟수 기준 정렬. DB에 bookmark_count 집계 또는 실시간 count 쿼리 필요 | DB, Backend API, Frontend |
| 3 | 공지 본문 내 링크 클릭 | notice_detail_screen에서 Markdown 링크/URL 클릭 시 브라우저로 이동 (url_launcher 사용) | Frontend |
| 4 | 홈 화면 AI 추천 카드 데이터 연동 | 메인 화면의 AI 추천 카드에 실제 데이터 표시 (recommend API 연동 확인) | Frontend |
| 5 | 카테고리 아이콘 하이라이트 버그 | 홈에서 카테고리 선택 → 모달 닫기 후에도 아이콘이 선택 상태로 남는 문제 수정 | Frontend (home_screen) |
| 6 | 알림 기능 구현 | FCM 푸시 알림 연동 + 알림 화면 UI 구현 | Full-Stack |

---

## 9. 환경 설정

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

## 10. 수정 금지 파일

- `.env` - API 키/DB 보안 설정
- `backend/app.py` - 메인 서버 진입점 (구조 변경 시 팀 합의)
- `frontend/pubspec.yaml` - 패키지 버전 관리

---

_이 문서는 Claude Code 세션 간 컨텍스트 전달을 위해 작성되었습니다._
