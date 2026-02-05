# 크롤링 최적화 작업 계획 (2026-02-06 예정)

## 🎯 작업 영역: Backend (AI/크롤링)

---

## 현재 문제점

### 1. 카테고리 혼동
- **원본 게시판**: 공지사항, 학사/장학, 채용/공고/모집 (3개)
- **AI 변환 카테고리**: 학사, 장학, 취업, 행사, 교육, 공모전 (6개)
- 문제: 원본 게시판 정보가 저장되지 않아 "마지막 크롤링 순번"을 게시판별로 체크할 수 없음

### 2. 순번 미활용
- 군산대 게시판에는 순번이 있음: `<td class="pcv_moh_768">5125</td>`
- 현재 `original_id`에 `nttId` (URL 파라미터)를 저장 중이나, 이는 순차적이지 않음
- 순번은 게시판 내에서 순차적으로 증가하므로 최적화에 활용 가능

### 3. 현재 URL 기반 방식의 단점
- DB에서 URL 500개를 조회해야 함
- 메모리 사용량 증가
- 쿼리 비용 발생

---

## 우선순위(priority) 기준 (참고)

Gemini AI가 공지사항 분석 시 아래 기준으로 결정:

| 등급 | 기준 | 예시 |
|------|------|------|
| 긴급 | 마감일 3일 이내 또는 즉시 조치 필요 | 오늘까지 신청, 긴급 공지 |
| 중요 | 대부분 학생에게 영향, 필수 확인 | 수강신청, 등록금 납부 |
| 일반 | 특정 학생만 해당, 선택 사항 | 동아리 모집, 선택 특강 |

---

## 해결 방안

### DB 스키마 변경

```sql
ALTER TABLE notices ADD COLUMN source_board TEXT;  -- 원본 게시판 (공지사항/학사장학/모집공고)
ALTER TABLE notices ADD COLUMN board_seq INTEGER;  -- 게시판 내 순번

-- 인덱스 추가
CREATE INDEX idx_notices_source_board ON notices(source_board);
CREATE INDEX idx_notices_board_seq ON notices(source_board, board_seq DESC);
```

### 새로운 크롤링 플로우

```
1. DB에서 해당 게시판의 마지막 순번 조회
   SELECT MAX(board_seq) FROM notices WHERE source_board = '공지사항'

2. 목록 페이지 1페이지만 확인

3. 각 공지의 순번 추출 (<td class="pcv_moh_768">)

4. 마지막 순번보다 큰 것만 상세 크롤링

5. 저장 시 source_board, board_seq 함께 저장
```

---

## 🚀 내일 할 일

### 1단계: DB 마이그레이션
- [ ] `source_board` 컬럼 추가
- [ ] `board_seq` 컬럼 추가
- [ ] 인덱스 생성
- [ ] 마이그레이션 SQL 파일 생성: `docs/migrations/005_add_board_seq.sql`

### 2단계: 크롤러 수정
- [ ] `_extract_notice_list`에서 순번 추출 로직 추가
  - `<td class="pcv_moh_768">` 태그에서 순번 파싱
- [ ] `crawl_optimized` 메서드 수정
  - URL 기반 → 순번 기반으로 변경
  - `_get_existing_urls` → `_get_last_board_seq`로 변경
- [ ] `save_to_dict`에 `source_board`, `board_seq` 추가

### 3단계: 서비스 수정
- [ ] `notice_service.py`에 `get_last_board_seq(source_board)` 메서드 추가
- [ ] `save_analyzed_notice`에서 `source_board`, `board_seq` 저장
- [ ] `save_notice_with_embedding`에서도 동일 적용

### 4단계: 파이프라인 수정
- [ ] `crawl_and_notify.py`에서 새 로직 적용
- [ ] 크롤러 키를 `source_board` 값과 매핑

### 5단계: 테스트
- [ ] 단일 게시판 크롤링 테스트
- [ ] 전체 파이프라인 테스트
- [ ] 중복 크롤링 방지 확인

---

## 📁 수정 대상 파일

| 파일 | 변경 내용 |
|------|----------|
| `docs/migrations/005_add_board_seq.sql` | 신규 생성 |
| `docs/database_schema.sql` | 스키마 업데이트 |
| `backend/crawler/notice_crawler.py` | 순번 추출, crawl_optimized 수정 |
| `backend/crawler/base_crawler.py` | save_to_dict에 필드 추가 |
| `backend/services/notice_service.py` | get_last_board_seq 추가 |
| `backend/scripts/crawl_and_notify.py` | 파이프라인 수정 |

---

## 📋 기존 데이터 마이그레이션

기존 데이터의 `source_board`와 `board_seq`는 비워둠 (NULL)
- 다음 크롤링부터 새 공지에만 적용
- 필요시 URL 패턴으로 역추적 가능 (boardId로 source_board 유추)

---

## ⚠️ 주의사항

1. `.env` 파일은 절대 커밋하지 않기
2. `requirements.txt` 수정 시 팀원에게 즉시 공지
3. Gemini API 호출 시 비용 고려 (Flash 모델 사용)
4. 학교 서버 부담 최소화 (목록 페이지만 확인, 딜레이 추가)
