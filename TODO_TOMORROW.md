# 작업 목록 (2026-02-03 업데이트)

## 🎯 작업 영역: Backend (AI/크롤링)

---

## ✅ 완료된 작업

### 1. Gemini API 연결 및 공지사항 분석 구현
- [x] `.env` 파일에서 `GEMINI_API_KEY` 확인
- [x] `backend/requirements.txt`에 `google-generativeai` 패키지 추가
- [x] `backend/ai/gemini_client.py` 생성
  - Gemini API 클라이언트 초기화 함수 작성
  - 모델: `gemini-2.0-flash` 사용
- [x] `backend/ai/prompts.py` 프롬프트 템플릿 작성
  - 공지사항 요약 생성
  - 날짜/일정 정보 추출 (시작일, 종료일, 마감일)
  - 카테고리 분류 (학사, 장학, 취업, 행사, 시설, 기타)
  - 중요도 판단 (긴급, 중요, 일반)
- [x] `backend/ai/analyzer.py` 생성
  - `analyze_notice()`, `analyze_notice_comprehensive()` 함수 구현
  - 재시도 로직 구현 (최대 3회, exponential backoff)
  - JSON 파싱 및 날짜 정규화 로직
- [x] `backend/tests/test_gemini_integration.py` 테스트 작성

### 2. 분석 정보 DB 저장 로직 구현
- [x] `docs/database_schema.sql` 스키마 확인
- [x] `docs/migrations/001_add_ai_analysis_fields.sql` 마이그레이션 작성
  - `notices` 테이블에 `ai_analyzed_at`, `priority` 컬럼 추가
  - `calendar_events` 테이블에 `event_type`, `is_all_day`, `is_notified` 컬럼 추가
- [x] `backend/services/notice_service.py` 생성
  - `save_analyzed_notice()` 함수 구현 (중복 체크, upsert)
  - `update_ai_analysis()` 함수 구현
  - `get_unprocessed_notices()` 함수 구현
  - `batch_save_notices()` 함수 구현

### 3. 캘린더 이벤트 서비스
- [x] `backend/services/calendar_service.py` 생성

---

## 🚧 다음 작업 (이어서 할 것)

### 4. 실시간 크롤링 + 알림 파이프라인 구현

#### 4.1 아키텍처 결정사항
- **방식**: Render Cron Job (APScheduler 없이)
- **간격**: 15분마다 크롤링 스크립트 실행
- **비용**: Render 무료 플랜 범위 내 운영 가능 (2달 예정)

#### 4.2 크롤링 최적화 구현
- [ ] 목록 페이지만 먼저 확인하는 로직
  - 1페이지 목록 크롤링 (1회 요청)
  - DB의 마지막 `original_id`와 비교
  - 새 글 있을 때만 상세 페이지 크롤링
- [ ] 요청 간 딜레이 (1~2초) 추가
- [ ] User-Agent 헤더 정상 설정
- [ ] 에러 시 백오프 로직

#### 4.3 전체 파이프라인 스크립트 작성
- [ ] `backend/scripts/crawl_and_notify.py` 생성
  ```
  크롤러 실행 (새 공지 감지)
    ↓
  notices 테이블 저장 (is_processed=False)
    ↓
  AI 전체 분석 (요약, 카테고리, 중요도) → notices 업데이트
    ↓
  사용자별 관련도 계산 (배치) → ai_analysis 저장
    ↓
  relevance_score > 0.5 인 사용자만 푸시 알림
    ↓
  notification_logs 저장
  ```

#### 4.4 사용자별 맞춤 관련도 계산
- [ ] `ai_analysis` 테이블 활용 설계
  - `user_id` + `notice_id` + `relevance_score` 저장
  - 같은 공지도 사용자마다 다른 점수
- [ ] 관련도 계산 프롬프트 작성
  - 사용자 정보 (학과, 학년, 관심 키워드) + 공지 내용 → 0~1 점수
- [ ] 배치 처리로 API 호출 최적화
  - 사용자 1명 + 공지 여러 개 한 번에 처리

#### 4.5 Render Cron Job 설정
- [ ] `render.yaml` 또는 Render 대시보드에서 Cron Job 설정
- [ ] 15분 간격으로 `crawl_and_notify.py` 실행 설정
- [ ] 환경 변수 설정 (GEMINI_API_KEY, SUPABASE_URL, SUPABASE_KEY)

#### 4.6 푸시 알림 구현
- [ ] FCM (Firebase Cloud Messaging) 연동
- [ ] `notification_logs` 테이블에 발송 기록 저장
- [ ] 알림 발송 조건: `relevance_score > 0.5`

---

## 📋 DB 테이블 참고

### `ai_analysis` 테이블 (사용자별 맞춤 분석용)
```sql
-- docs/database_schema.sql:49-59
CREATE TABLE ai_analysis (
    id UUID PRIMARY KEY,
    notice_id UUID REFERENCES notices(id),
    user_id UUID REFERENCES users(id),
    relevance_score DECIMAL(3,2),  -- 0~1 관련도 점수
    summary TEXT,
    action_required BOOLEAN,
    deadline TIMESTAMP,
    analyzed_at TIMESTAMP
);
```

### `notices` vs `ai_analysis` 사용 구분
- **notices 테이블**: 공지 자체의 요약/카테고리/중요도 (모든 사용자 공통)
- **ai_analysis 테이블**: 사용자별 관련도 점수 (개인화)

---

## ⚠️ 주의사항

1. `.env` 파일은 절대 커밋하지 않기
2. `requirements.txt` 수정 시 팀원에게 즉시 공지
3. Gemini API 호출 시 비용 고려 (Flash 모델 사용 권장)
4. 학교 서버 부담 최소화 (목록 페이지만 확인, 딜레이 추가)
5. 2달 운영 후 종료 예정 → 복잡한 인프라 구축 지양

---

## 🔗 참고 자료

- [Gemini API 공식 문서](https://ai.google.dev/docs)
- [Supabase Python Client](https://supabase.com/docs/reference/python/introduction)
- [Render Cron Jobs](https://render.com/docs/cronjobs)
- 프로젝트 API 명세서: `docs/api_spec.md`
- 데이터베이스 스키마: `docs/database_schema.sql`
