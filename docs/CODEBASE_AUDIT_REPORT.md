# AIX-Boost 코드베이스 전체 감사 보고서

> 작성일: 2026-02-08
> 분석 범위: Frontend (Flutter/Dart) + Backend (Flask/Python) + DB/아키텍처
> 분석 방법: 5개 팀 병렬 분석 (Frontend, Backend API, 크롤러/AI, 아키텍처, 통합)

---

## 요약

| 심각도 | 개수 | 설명 |
|--------|------|------|
| CRITICAL | 8개 | 데이터 유실, 기능 장애, API 불일치 |
| HIGH | 14개 | UX 저하, 성능 문제, 보안 |
| MEDIUM | 12개 | 코드 품질, 안정성, 유지보수 |
| LOW | 8개 | 개선 권장, 최적화 |
| **합계** | **42개** | |

---

## PART 1: CRITICAL 버그 (즉시 수정 필요)

### C1. 검색 API 필드명 불일치 (notice_id vs id)

| 항목 | 내용 |
|------|------|
| 파일 | `backend/services/hybrid_search_service.py:757` |
| 영향 | mybro 탭 클릭 시 "공지사항을 불러올 수 없습니다" 에러 |

**문제:** 맞춤 추천(`_combine_notice_scores`)은 `notice_id`로 반환하고, 키워드 검색(`_combine_keyword_search_results`)은 `id`로 반환.

```python
# 맞춤 추천 (Line 757) - notice_id 사용
combined[notice_id] = {
    "notice_id": notice_id,  # ← notice_id
    "title": notice.get("title"),
    ...
}

# 키워드 검색 (Line 344) - id 사용
combined[notice_id] = {
    "id": notice_id,          # ← id
    "title": result["title"],
    ...
}
```

**프론트엔드 영향:** `notice_provider.dart:152`에서 `searchResult['id'] ?? ''` → 빈 문자열 → 상세 조회 실패

---

### C2. 프론트엔드 검색 결과 ID 매핑 실패

| 항목 | 내용 |
|------|------|
| 파일 | `frontend/lib/providers/notice_provider.dart:152` |
| 영향 | 추천/검색 결과 클릭 시 404 에러 |

```dart
Map<String, dynamic> _convertSearchResult(Map<String, dynamic> searchResult) {
  return {
    'id': searchResult['id'] ?? '',  // ← notice_id를 처리하지 않음
    ...
  };
}
```

**수정 필요:**
```dart
'id': searchResult['id'] ?? searchResult['notice_id'] ?? '',
```

---

### C3. 상단 고정 공지(공지) 크롤링 누락

| 항목 | 내용 |
|------|------|
| 파일 | `backend/crawler/notice_crawler.py:203-205` |
| 영향 | 중요 상단 고정 공지 매번 누락 |

```python
if board_seq is None:
    # 순번 없는 공지(상단 고정 등)는 URL 기반으로 중복 체크
    continue  # ← 스킵됨! 처리 안 함!
```

주석에는 "URL 기반으로 중복 체크"라고 되어있지만 실제로는 `continue`로 건너뛰기만 함.

---

### C4. 임베딩 생성 실패 시 빈 벡터([]) 저장

| 항목 | 내용 |
|------|------|
| 파일 | `backend/ai/embedding_service.py:196` |
| 영향 | 벡터 검색 오류, DB 데이터 무결성 훼손 |

```python
except Exception as e:
    embeddings.append([])  # ← 빈 벡터 저장!
```

---

### C5. DB 스키마에 벡터/메타데이터 컬럼 누락

| 항목 | 내용 |
|------|------|
| 파일 | `docs/database_schema.sql` |
| 영향 | 벡터 검색, 메타데이터 기반 필터링 불가 |

```sql
-- notices 테이블에 다음 컬럼 미정의:
-- content_embedding vector(768)
-- enriched_metadata JSONB
-- ai_analyzed_at TIMESTAMPTZ

-- user_preferences 테이블에 다음 컬럼 미정의:
-- interests_embedding vector(768)
```

---

### C6. 벡터 검색 RPC 함수 미구현 (항상 폴백)

| 항목 | 내용 |
|------|------|
| 파일 | `backend/services/hybrid_search_service.py:595-615` |
| 영향 | 매번 Python 폴백 실행 → 모든 공지 메모리 로드 → 성능 저하 |

```python
result = self.supabase.rpc("search_notices_by_vector", {...}).execute()
# ↑ 이 RPC 함수가 Supabase에 없음 → 항상 except로 감
```

---

### C7. supabase_service.insert_notices()에 ai_summary 미포함

| 항목 | 내용 |
|------|------|
| 파일 | `backend/services/supabase_service.py:74-85` |
| 영향 | `/api/notices/crawl` 라우트로 저장 시 AI 요약 없음 |

```python
notice_data = {
    "title": notice.get("title"),
    "content": notice.get("content"),
    "category": notice.get("category", "공지사항"),
    # ... ai_summary 없음, content_embedding 없음
    "is_processed": False,
}
```

`crawl_and_notify.py`는 `notice_service.py`를 사용하므로 정상이지만, API 라우트(`/api/notices/crawl`)는 이 메서드를 사용하여 불완전한 데이터 저장.

---

### C8. 텍스트 자르기 논리 오류

| 항목 | 내용 |
|------|------|
| 파일 | `backend/ai/embedding_service.py:337` |
| 영향 | 단어 경계 자르기가 절대 실행되지 않음 |

```python
if len(text) > self.MAX_CHARS:        # MAX_CHARS = 8000
    text = text[:self.MAX_CHARS]
    last_space = text.rfind(' ')
    if last_space > self.MAX_CHARS * 0.9:  # 7200 < 최대 7999 → 조건 자체는 작동 가능
        text = text[:last_space]
```

---

## PART 2: HIGH 우선순위 버그

### H1. view_count 필드명 불일치

| 항목 | 내용 |
|------|------|
| 파일 | `backend/services/supabase_service.py:82` |
| 영향 | 조회수가 null로 저장될 수 있음 |

```python
"view_count": notice.get("views"),  # 크롤러는 "views"로 전달
```

**데이터 흐름:**
- 크롤러(`notice_crawler.py:581`): `views=150` (kwargs로 전달)
- `base_crawler.py:300`: `**kwargs` → `views: 150`
- `supabase_service.py:82`: `notice.get("views")` → OK
- `notice_service.py:136`: `notice.get("view_count") or notice.get("views")` → OK

**결론:** `supabase_service.py`만 `views` 키에 의존. `notice_service.py`는 양쪽 다 처리. `views` 키가 없는 경우만 문제.

---

### H2. AI 분석 실패 시 요약이 빈 문자열

| 항목 | 내용 |
|------|------|
| 파일 | `backend/ai/analyzer.py:399` |
| 영향 | 사용자에게 AI 요약 없이 표시 |

```python
# 실패 시
fallback_result = {
    "summary": "",  # ← 빈 문자열
    ...
}
```

**개선:** 제목을 fallback 요약으로 사용
```python
"summary": title[:200] if title else "",
```

---

### H3. 날짜 파싱 실패 시 현재 시간 사용

| 항목 | 내용 |
|------|------|
| 파일 | `backend/crawler/notice_crawler.py:554`, `backend/services/notice_service.py:665` |
| 영향 | 잘못된 published_at 저장 → 정렬/필터링 오류 |

```python
# notice_crawler.py:554
if not published_at:
    published_at = datetime.now()  # ← 위험!

# notice_service.py:665
except:
    return datetime.now().isoformat()  # ← 위험!
```

---

### H4. recommend_screen.dart 중복 API 호출

| 항목 | 내용 |
|------|------|
| 파일 | `frontend/lib/screens/recommend_screen.dart:18-28` |
| 영향 | 불필요한 네트워크 요청, 깜빡임 |

```dart
@override
void initState() {
  super.initState();
  _loadRecommendations();  // 1번째 호출
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _loadRecommendations();  // 2번째 호출 (매번)
}
```

---

### H5. 북마크 토글 시 _notices에서 ID 못 찾으면 동기화 실패

| 항목 | 내용 |
|------|------|
| 파일 | `frontend/lib/providers/notice_provider.dart:212-243` |
| 영향 | 검색 결과/추천에서 북마크 토글 시 UI 불일치 |

---

### H6. _handleListResponse() 오류 처리 부족

| 항목 | 내용 |
|------|------|
| 파일 | `frontend/lib/services/api_service.dart:291-310` |
| 영향 | 네트워크 오류와 빈 데이터를 구분 못함 (둘 다 `[]` 반환) |

---

### H7. FCM 푸시 알림 미구현

| 항목 | 내용 |
|------|------|
| 파일 | `backend/scripts/crawl_and_notify.py:365-366` |
| 영향 | 알림이 DB에만 저장, 실제 발송 안 됨 |

```python
# TODO: FCM 푸시 알림 발송 (나중에 구현)
```

---

### H8. Supabase .single() 에러 처리 미흡

| 항목 | 내용 |
|------|------|
| 파일 | `backend/services/hybrid_search_service.py:424-437` |
| 영향 | 데이터 없을 때 예외 발생 → 500 에러 |

---

### H9. 본문 50자 미만 공지 처리 부족

| 항목 | 내용 |
|------|------|
| 파일 | `backend/crawler/notice_crawler.py:510-514` |
| 영향 | 내용 부족한 공지 그대로 저장 → AI 분석 입력 부족 |

---

### H10. 이미지 분석 실패 시 빈 문자열 반환

| 항목 | 내용 |
|------|------|
| 파일 | `backend/ai/analyzer.py:587-589` |
| 영향 | 이미지 공지 내용 유실 → 부정확한 분석 |

---

### H11. 리랭킹 조건 로직 오류

| 항목 | 내용 |
|------|------|
| 파일 | `backend/services/reranking_service.py:80-99` |
| 영향 | should_rerank()가 항상 False 반환 가능 → 리랭킹 미적용 |

---

### H12. 프론트 notice_detail에서 fetchBookmarks() 중복 호출

| 항목 | 내용 |
|------|------|
| 파일 | `frontend/lib/screens/notice_detail_screen.dart:31-45` |
| 영향 | `fetchBookmarks()` + `getNoticeDetail()` 내부 북마크 처리 = 2번 호출 |

---

### H13. API 응답 타입 캐스팅 불안전

| 항목 | 내용 |
|------|------|
| 파일 | `frontend/lib/services/api_service.dart:270, 295` |
| 영향 | 백엔드 예상치 못한 응답 시 `CastError` 런타임 크래시 |

---

### H14. Gemini API 타임아웃 미설정

| 항목 | 내용 |
|------|------|
| 파일 | `backend/ai/gemini_client.py:106-111` |
| 영향 | 네트워크 지연 시 무한 대기 → 크론잡 멈춤 |

---

## PART 3: MEDIUM 우선순위

| # | 파일 | 라인 | 설명 |
|---|------|------|------|
| M1 | `frontend/lib/screens/category_notice_screen.dart` | 247 | 더미 북마크 카운트 (`views * 0.1`) |
| M2 | `frontend/lib/screens/home_screen.dart` | 147-159 | 탭 전환 시 스크롤 위치 초기화 (`IndexedStack` 미사용) |
| M3 | `frontend/lib/screens/home_screen.dart` | 464+ | Consumer 중첩으로 불필요한 재빌드 |
| M4 | `frontend/lib/screens/notice_detail_screen.dart` | 245-410 | 마감일 정보 중복 표시 (2곳) |
| M5 | `backend/services/hybrid_search_service.py` | 388-403 | 벡터 전용 결과 DB 추가 쿼리 (N+1 변형) |
| M6 | `backend/services/reranking_service.py` | 244-249 | user_preferences 개별 쿼리 (N+1) |
| M7 | `backend/services/hybrid_search_service.py` | 481-487 | 200개 공지 메모리 로드 |
| M8 | `backend/ai/enrichment_service.py` | 198-203 | 학과 추출 시 한글만 매칭 |
| M9 | `backend/ai/enrichment_service.py` | 313-315 | 다중 액션 감지 시 첫 번째만 반환 |
| M10 | `backend/ai/analyzer.py` | 630-641 | 비표준 날짜 형식 정규화 미지원 ("2월 1일") |
| M11 | `backend/crawler/scholarship_crawler.py` | 55 | BaseCrawler import가 클래스 뒤에 위치 |
| M12 | `backend/services/notice_service.py` | 411 | 임베딩 차원 주석과 실제 불일치 (3072 vs 768) |

---

## PART 4: 데이터 파이프라인 흐름도

### 정상 흐름 (crawl_and_notify.py)

```
[Step 1: 크롤링]
  NoticeCrawler.crawl_optimized()
  ScholarshipCrawler.crawl_optimized()
  RecruitmentCrawler.crawl_optimized()
    ↓ (title, content, views, published_at, source_url, board_seq)
    ⚠️ 상단 고정 공지 누락 (C3)
    ⚠️ 날짜 파싱 실패 → datetime.now() (H3)

[Step 2: AI 분석]
  analyzer.analyze_notice_comprehensive()
    ↓ (summary, category, dates, ...)
    ⚠️ Gemini 실패 → summary="" (H2)
    ⚠️ 이미지 분석 실패 → content="" (H10)

  embedding_service.create_embedding()
    ↓ (content_embedding)
    ⚠️ 실패 → [] 저장 (C4)

  enrichment_service.enrich_notice()
    ↓ (enriched_metadata)

[Step 3: DB 저장]
  notice_service.save_notice_with_embedding() 또는
  notice_service.save_analyzed_notice()
    ↓ (notices 테이블)
    ✅ summary → ai_summary 매핑 정상
    ✅ views → view_count 매핑 정상

[Step 4: 관련 사용자 검색]
  hybrid_search_service.find_relevant_users()
    ↓ (user_id, total_score)
    ⚠️ RPC 함수 없음 → Python 폴백 (C6)
    ⚠️ 사용자 임베딩 없음 → 벡터 검색 스킵 (C5)

[Step 5: 알림]
  ⚠️ FCM 미구현 (H7)
  → notification_logs만 저장
```

### 프론트엔드 데이터 흐름

```
[홈 화면]
  fetchNotices() → GET /api/notices/ → notices 배열
    ✅ view_count 포함
    ✅ ai_summary 포함

[mybro 추천 탭]
  fetchRecommendedNotices() → GET /api/search/notices → 검색 결과
    ⚠️ 응답에 "notice_id" 사용 (C1)
    → _convertSearchResult() → "id" 키 누락 (C2)
    → Notice.fromJson() → id="" → 클릭 시 에러

[검색]
  searchNotices() → GET /api/search/notices/keyword → 검색 결과
    ✅ 응답에 "id" 사용
    → _convertSearchResult() → 정상

[상세 조회]
  getNoticeDetail() → GET /api/notices/{id} → 단일 공지
    ✅ 정상 작동
    ⚠️ 북마크 상태 보존 로직 필요 (이전 수정 완료)
```

---

## PART 5: view_count가 안 나오는 원인 분석

### 크롤링 단계

```python
# notice_crawler.py:541-543 - 조회수 추출
if '조회수' in span_text:
    views_match = re.search(r'(\d+)', span_text)
    if views_match:
        views = int(views_match.group(1))
```

**가능한 실패 원인:**
1. `div.bv_txt01` 구조가 변경됨 → `bv_txt01 = None` → views = None
2. span 텍스트에 "조회수" 대신 다른 텍스트 사용
3. 조회수가 JavaScript로 동적 로드 → 크롤링 시 없음

### 저장 단계

```python
# base_crawler.py:294-301 - save_to_dict()
return {
    "title": ...,
    "content": ...,
    "source_board": self.category,
    "published_at": ...,
    "source_url": ...,
    **kwargs  # ← views=None이면 포함되지만 None
}

# notice_service.py:135-136
if "view_count" in notice_data or "views" in notice_data:
    db_data["view_count"] = notice_data.get("view_count") or notice_data.get("views")
    # ← views=None이면 view_count도 None
```

### API 반환 단계

```python
# supabase_service.py:148-158 - get_notices()
result = self.client.table("notices").select("*")...
# ← view_count가 NULL이면 프론트에서 0으로 표시
```

### 프론트엔드 표시

```dart
// notice.dart - fromJson()
views: json['view_count'] ?? 0,  // NULL → 0으로 표시

// home_screen.dart - 조회수 표시
Text('${notice.views}'),  // 0 표시
```

**결론:** 크롤러에서 `views`를 추출하지 못하면 None → DB에 NULL → 프론트에서 0 표시. 군산대 홈페이지 HTML 구조 확인 필요.

---

## PART 6: 프론트에서 과거 데이터를 보여주는 원인

### 원인 1: Provider 상태 캐싱

```dart
// notice_provider.dart
List<Notice> _notices = [];           // 메모리에 캐싱
List<Notice> _recommendedNotices = []; // 메모리에 캐싱
```

화면 전환 시 `_notices`가 이전 데이터를 유지. `fetchNotices()`를 다시 호출하지 않으면 이전 데이터 표시.

### 원인 2: didChangeDependencies() 중복 호출

```dart
// recommend_screen.dart:24-28
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _loadRecommendations();  // 탭 전환마다 호출 → 이전 데이터 깜빡 후 갱신
}
```

### 원인 3: getNoticeDetail()에서 로컬 캐시 우선

```dart
// notice_provider.dart - getNoticeDetail()
// API 실패 시 _notices 배열에서 찾기 (kDebugMode)
if (kDebugMode) {
  try { return _notices.firstWhere((n) => n.id == noticeId); }
  catch (_) { return null; }
}
```

개발 모드에서 API 실패 시 로컬 캐시(과거 데이터) 반환.

### 원인 4: 북마크 상태와 실제 데이터 불일치

```dart
// notice_provider.dart:274-280
final existingBookmarkState = _notices[index].isBookmarked;
_notices[index] = notice.copyWith(isBookmarked: existingBookmarkState);
```

API에서 새 데이터를 가져와도 북마크 상태는 이전 값 유지 → "과거 데이터"처럼 보임.

---

## PART 7: 위험 매트릭스

```
           영향도
           높음 ─┬─────────────────────────────────────────────┐
                 │  C1 C2     C3    C5 C6                      │
                 │  (API불일치) (공지누락) (벡터검색불가)          │
                 │                                              │
           중간 ─┤  H2 H7     C4    C7                         │
                 │  (요약없음) (FCM) (빈벡터) (insert경로)        │
                 │                                              │
           낮음 ─┤  M1 M2     H14   H3                         │
                 │  (UI)      (타임아웃)(날짜)                    │
                 └─┬──────────┬──────────┬─────────────────────┘
                  낮음       중간       높음
                           발생 확률
```

---

## PART 8: 수정 우선순위

### Phase 1: 즉시 (1-2일)

| # | 작업 | 파일 | 예상 시간 |
|---|------|------|----------|
| 1 | `_combine_notice_scores()` 반환값 `notice_id` → `id`로 변경 | hybrid_search_service.py:757 | 5분 |
| 2 | `_convertSearchResult()`에 `notice_id` 폴백 추가 | notice_provider.dart:152 | 5분 |
| 3 | 상단 고정 공지 `continue` 제거, URL 기반 중복 체크 구현 | notice_crawler.py:203-210 | 30분 |
| 4 | 임베딩 실패 시 `[]` 대신 `None` 저장 (skip) | embedding_service.py:196 | 10분 |
| 5 | recommend_screen.dart `didChangeDependencies` 중복 제거 | recommend_screen.dart:24-28 | 5분 |

### Phase 2: 이번 주 (3-5일)

| # | 작업 | 예상 시간 |
|---|------|----------|
| 6 | DB 마이그레이션: content_embedding, enriched_metadata, interests_embedding 컬럼 추가 | 1시간 |
| 7 | pgvector RPC 함수 2개 생성 (search_notices_by_vector, search_users_by_notice_vector) | 2시간 |
| 8 | AI 분석 실패 시 제목을 fallback 요약으로 사용 | 30분 |
| 9 | 날짜 파싱 실패 시 None 반환 (datetime.now() 제거) | 30분 |
| 10 | Gemini API 타임아웃 설정 (30초) | 10분 |
| 11 | .single() 호출부 try-except 보강 | 1시간 |

### Phase 3: 다음 주 (1-2주)

| # | 작업 | 예상 시간 |
|---|------|----------|
| 12 | FCM 푸시 알림 구현 | 1-2일 |
| 13 | 사용자 선호도 임베딩 자동 생성 | 3시간 |
| 14 | API 응답 스키마 통일 (검색/추천/키워드) | 2시간 |
| 15 | 로깅 시스템 도입 (print → logging) | 2시간 |
| 16 | N+1 쿼리 최적화 (벡터 보완, user_preferences) | 2시간 |

---

## PART 9: 진척 상황 요약

### 완료된 작업 (이번 세션)
- [x] 북마크 토글 시 아이콘 미갱신 버그 수정 (notice_provider.dart)
- [x] DB category 컬럼에 게시판명 저장 문제 수정 (base_crawler.py)
- [x] 임베딩 실패 시 AI 분석 결과 보존 (crawl_and_notify.py)
- [x] API 응답 List/Map 타입 캐스팅 에러 수정 (api_service.dart)
- [x] DB 데이터 재크롤링 완료 (ai_summary, category 정상 확인)

### 미완료 작업
- [ ] mybro 탭 notice_id → id 매핑 (C1, C2)
- [ ] 상단 고정 공지 크롤링 (C3)
- [ ] 벡터 검색 RPC 함수 생성 (C6)
- [ ] FCM 구현 (H7)
- [ ] view_count 크롤링 확인 (H1)

### 전체 프로젝트 완성도

| 기능 | 상태 | 비고 |
|------|------|------|
| 크롤링 | 90% | 상단 고정 공지 누락 |
| AI 분석 | 85% | 실패 처리 보강 필요 |
| 벡터 검색 | 60% | RPC 함수 미구현, 사용자 임베딩 미생성 |
| 추천 시스템 | 50% | 벡터 검색 의존, 리랭킹 로직 오류 |
| 알림 | 20% | FCM 미구현, notification_logs만 저장 |
| 캘린더 | 80% | 이벤트 업데이트 로직 부재 |
| 프론트 UI | 85% | mybro 탭 버그, 중복 호출 |
| 인증/보안 | 70% | 일부 엔드포인트 미인증 |

---

## 부록: 파일별 문제 요약

### Frontend

| 파일 | 문제 수 | 심각도 |
|------|---------|--------|
| `providers/notice_provider.dart` | 4 | C2, H5 |
| `services/api_service.dart` | 3 | H6, H13 |
| `screens/recommend_screen.dart` | 2 | H4 |
| `screens/notice_detail_screen.dart` | 3 | H12, M4 |
| `screens/home_screen.dart` | 3 | M2, M3 |
| `screens/category_notice_screen.dart` | 1 | M1 |
| `screens/calendar_screen.dart` | 1 | M |
| `screens/profile_screen.dart` | 1 | M |

### Backend

| 파일 | 문제 수 | 심각도 |
|------|---------|--------|
| `services/hybrid_search_service.py` | 7 | C1, C6, H8, M5, M7 |
| `crawler/notice_crawler.py` | 3 | C3, H3, H9 |
| `ai/embedding_service.py` | 2 | C4, C8 |
| `ai/analyzer.py` | 3 | H2, H10, M10 |
| `services/supabase_service.py` | 2 | C7, H1 |
| `services/notice_service.py` | 2 | H3, M12 |
| `services/reranking_service.py` | 2 | H11, M6 |
| `ai/gemini_client.py` | 1 | H14 |
| `scripts/crawl_and_notify.py` | 2 | H7 |
| `ai/enrichment_service.py` | 2 | M8, M9 |
