# 내일 작업 목록 (2026-02-03)

## 🎯 작업 영역: Backend (AI/크롤링)

---

## 1. Gemini API 연결 및 공지사항 분석 구현

### 1.1 환경 설정 및 API 초기화
- [ ] `.env` 파일에서 `GEMINI_API_KEY` 확인
- [ ] `backend/requirements.txt`에 `google-generativeai` 패키지 추가 확인
- [ ] `backend/ai/gemini_client.py` 생성 (또는 수정)
  - Gemini API 클라이언트 초기화 함수 작성
  - API 키 유효성 검증 로직 추가

### 1.2 공지사항 분석 프롬프트 설계
- [ ] 프롬프트 템플릿 작성 (`backend/ai/prompts.py`)
  - 공지사항 요약 생성 (200자 이내)
  - 날짜/일정 정보 추출 (시작일, 종료일, 마감일)
  - 카테고리 분류 (학사, 장학, 취업, 행사 등)
  - 중요도 판단 (긴급, 중요, 일반)
- [ ] JSON 형식 응답 구조 정의
```json
{
  "summary": "요약문",
  "dates": {
    "start_date": "YYYY-MM-DD",
    "end_date": "YYYY-MM-DD",
    "deadline": "YYYY-MM-DD"
  },
  "category": "학사",
  "priority": "중요"
}
```

### 1.3 AI 분석 함수 구현
- [ ] `backend/ai/analyzer.py` 생성
  - `analyze_notice(notice_text: str) -> dict` 함수 구현
  - Gemini API 호출 및 응답 파싱
  - 날짜 형식 정규화 (한글 날짜 → ISO 8601)
  - 에러 핸들링 (API 오류, 타임아웃, 파싱 실패)
- [ ] 재시도 로직 구현 (최대 3회, exponential backoff)
- [ ] 로깅 추가 (API 호출 시간, 토큰 사용량)

### 1.4 테스트 작성
- [ ] `tests/test_gemini_analyzer.py` 작성
  - 샘플 공지사항으로 분석 함수 테스트
  - Mock 데이터로 API 응답 시뮬레이션
  - Edge case 테스트 (날짜 없는 공지, 긴 텍스트 등)

---

## 2. 분석 정보 DB 저장 로직 구현

### 2.1 데이터베이스 스키마 확인
- [ ] `docs/database_schema.sql` 확인
  - `notices` 테이블 구조 파악
  - 필요한 컬럼 확인: `id`, `title`, `content`, `summary`, `category`, `priority`, `source_url`, `created_at`
- [ ] 누락된 컬럼 있으면 마이그레이션 SQL 작성
  - `summary` (TEXT)
  - `ai_analyzed_at` (TIMESTAMP)
  - `priority` (VARCHAR)

### 2.2 Supabase 연결 확인
- [ ] `backend/database/supabase_client.py` 확인
  - Supabase 클라이언트 초기화 코드 검증
  - 연결 테스트 함수 실행
- [ ] `.env`에서 `SUPABASE_URL`, `SUPABASE_KEY` 확인

### 2.3 공지사항 저장 함수 구현
- [ ] `backend/services/notice_service.py` 생성 (또는 수정)
  - `save_analyzed_notice(notice_data: dict) -> int` 함수 구현
  - 중복 체크 로직 (URL 기반 또는 제목+날짜 기반)
  - INSERT/UPDATE 처리 (upsert 사용 검토)
- [ ] 트랜잭션 처리
  - 공지사항 저장 실패 시 롤백
  - AI 분석 결과 누락 시 원본만 저장

### 2.4 배치 처리 구현
- [ ] 크롤링된 공지사항 리스트를 순회하며 AI 분석 + DB 저장
- [ ] `backend/crawler/main.py`에 AI 분석 파이프라인 추가
  - 크롤링 → AI 분석 → DB 저장 플로우 구성
- [ ] 진행 상황 로그 출력 (처리된 공지 수, 실패 수)

### 2.5 테스트
- [ ] `tests/test_notice_service.py` 작성
  - 중복 공지사항 저장 테스트
  - 트랜잭션 롤백 테스트
  - 대량 데이터 INSERT 성능 테스트

---

## 3. 캘린더 이벤트 DB 저장 구현

### 3.1 캘린더 테이블 스키마 설계
- [ ] `calendar_events` 테이블 설계
```sql
CREATE TABLE calendar_events (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id),
  notice_id BIGINT REFERENCES notices(id),
  event_title VARCHAR(255),
  event_type VARCHAR(50), -- '시작일', '종료일', '마감일'
  event_date DATE NOT NULL,
  event_time TIME,
  is_all_day BOOLEAN DEFAULT true,
  is_notified BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);
```
- [ ] 인덱스 추가 (`user_id`, `event_date`)
- [ ] Supabase에 마이그레이션 실행

### 3.2 캘린더 이벤트 변환 로직
- [ ] `backend/services/calendar_service.py` 생성
  - `create_calendar_events(notice_id: int, dates: dict, user_ids: list) -> list` 함수 구현
  - Gemini 분석 결과의 날짜 정보를 이벤트로 변환
  - 사용자 관심 카테고리 필터링 적용
- [ ] 이벤트 타입 매핑
  - `start_date` → "행사 시작"
  - `end_date` → "행사 종료"
  - `deadline` → "신청 마감"

### 3.3 사용자별 캘린더 동기화
- [ ] 사용자 관심 카테고리 확인 (`user_preferences` 테이블)
- [ ] 해당 사용자들에게만 캘린더 이벤트 생성
- [ ] 배치 INSERT 구현 (성능 최적화)

### 3.4 푸시 알림 트리거 설정 (선택 사항)
- [ ] `notifications` 테이블 연동 확인
- [ ] 이벤트 D-3, D-1, D-Day 알림 스케줄링
- [ ] Supabase Edge Function 또는 Cron Job 연동

### 3.5 테스트
- [ ] `tests/test_calendar_service.py` 작성
  - 단일 공지사항에서 여러 이벤트 생성 테스트
  - 사용자 필터링 테스트
  - 중복 이벤트 방지 테스트

---

## 📋 작업 전 체크리스트

- [ ] `develop` 브랜치 최신화 (`git pull origin develop`)
- [ ] 작업 브랜치 생성 (`git checkout -b feature/gemini-calendar-integration`)
- [ ] 팀원에게 작업 시작 공지 (Slack/Discord)

---

## 📝 작업 후 체크리스트

- [ ] 유닛 테스트 실행 (`pytest`)
- [ ] 코드 린팅 (`flake8` 또는 `black`)
- [ ] 한글 주석 추가 확인
- [ ] 변경된 파일 확인 (`git status`)
- [ ] 커밋 메시지 형식 준수: `[Backend/AI] Gemini API 연동 및 캘린더 이벤트 생성 구현`
- [ ] PR 생성 및 템플릿 작성
- [ ] 팀원 리뷰 요청

---

## 🔗 참고 자료

- [Gemini API 공식 문서](https://ai.google.dev/docs)
- [Supabase Python Client](https://supabase.com/docs/reference/python/introduction)
- 프로젝트 API 명세서: `docs/API_SPEC.md`
- 데이터베이스 스키마: `docs/database_schema.sql`

---

## ⚠️ 주의사항

1. `.env` 파일은 절대 커밋하지 않기
2. `requirements.txt` 수정 시 팀원에게 즉시 공지
3. Gemini API 호출 시 비용 고려 (토큰 사용량 모니터링)
4. DB 스키마 변경 시 마이그레이션 스크립트 작성 필수
