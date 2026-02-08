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

## 2. 이번 세션에서 완료된 작업

### 2.1 DB 구조조정

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

### 2.2 캘린더 기능 버그 수정

**근본 원인 2가지:**
1. DB에 `deadline` 컬럼이 없어서 프론트엔드에서 항상 null
2. 캘린더가 모든 공지사항을 표시 (북마크된 것만 표시해야 함)

**해결:**
- DB에 `deadline DATE` 컬럼 추가 (마이그레이션)
- 캘린더 화면: `provider.bookmarkedNotices` 사용, deadline만 매칭
- `CalendarBuilders.markerBuilder`로 D-day 마커 표시
- calendar.py 라우트: `user_bookmarks` + `notices.deadline` 직접 조인

### 2.3 크롤러 개선 (게시판당 10개 제한)

- `crawl()`, `crawl_optimized()`에 `max_notices` 파라미터 추가
- **첫 크롤링** (DB 비어있음): 게시판당 최대 10개 × 3개 = 총 30개
- **정기 크롤링** (15분마다): 새 공지 전부 수집 (제한 없음, `max_notices=100`)
- 기존 TEST_LIMIT(5개 하드코딩) 제거

### 2.4 프론트엔드-백엔드 API 연동

- 북마크 API 연동 (`addBookmark`, `removeBookmark`, `getBookmarks`)
- AI 추천 공지 API 연동 (`getRecommendedNotices`)
- 캘린더 이벤트 API 연동
- `extractedDates` 필드 완전 제거 → `deadline` 단일 필드로 통일

---

## 3. 변경된 파일 목록 (22개)

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

## 4. 현재 DB 스키마 (5개 테이블)

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
content TEXT,
category TEXT,
source_url TEXT UNIQUE,
published_at TIMESTAMPTZ,
author TEXT,
view_count INTEGER DEFAULT 0,
ai_summary TEXT,
deadline DATE,                    -- 마감일 (AI가 추출)
is_processed BOOLEAN DEFAULT FALSE,
content_embedding vector(768),    -- 벡터 임베딩
source_board TEXT,                -- 원본 게시판명
board_seq INTEGER,                -- 게시판 내 순번
created_at TIMESTAMPTZ DEFAULT NOW(),
updated_at TIMESTAMPTZ DEFAULT NOW()
```

---

## 5. 주요 API 엔드포인트

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

## 6. 크롤링 파이프라인 흐름

```
스케줄러 (15분마다) → CrawlAndNotifyPipeline.run()
  1. _step1_crawl()     — 3개 게시판 크롤링 (첫 크롤링: 10개씩 / 정기: 새 공지 전부)
  2. _step2_analyze()   — Gemini AI 분석 + 벡터 임베딩 생성
  3. _step3_save_to_db() — DB 저장 (임베딩 포함)
  4. _step4_calculate_relevance() — 하이브리드 검색으로 관련 사용자 매칭
  5. _step5_create_calendar_events() — 캘린더 이벤트 생성
  6. _step6_send_notifications() — 푸시 알림 (FCM 미구현)
```

---

## 7. 남은 작업 / 주의사항

### 즉시 처리 필요
1. **마이그레이션 실행**: Supabase SQL Editor에서 007, 008 실행
2. **서버 재시작**: 마이그레이션 후 백엔드 서버 재시작 → 15분 내 첫 크롤링 자동 실행
3. **캘린더 테스트**: 공지 북마크 → AI가 deadline 추출 → 캘린더에 D-day 표시 확인

### 알려진 이슈
- `CalendarService` 클래스가 삭제된 `calendar_events` 테이블 참조 → `calendar.py` 라우트에서 직접 쿼리로 우회 중
- FCM 푸시 알림 미구현 (notification_logs에 로그만 저장)

### 향후 작업
1. 테스트 코드 보강 (크롤러, 검색, 캘린더)
2. FCM 푸시 알림 연동
3. 사용자 온보딩 플로우 (관심 학과/키워드 설정)
4. 오프라인 캐싱 (Flutter)

---

## 8. 환경 설정

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

## 9. 수정 금지 파일

- `.env` - API 키/DB 보안 설정
- `backend/app.py` - 메인 서버 진입점 (구조 변경 시 팀 합의)
- `frontend/pubspec.yaml` - 패키지 버전 관리

---

_이 문서는 Claude Code 세션 간 컨텍스트 전달을 위해 작성되었습니다._
