# 작업 목록 (2026-02-04 예정)

## 🎯 작업 영역: Backend (AI/크롤링)

---

## ✅ 어제 완료 (2026-02-03)

- [x] Gemini API 연결 및 공지사항 분석 구현
- [x] 분석 정보 DB 저장 로직 구현
- [x] 캘린더 이벤트 서비스
- [x] APScheduler 기반 15분 자동 크롤링
- [x] Render 배포 완료: `https://aix-boost-backend.onrender.com`

---

## 🚀 오늘 할 일 (2026-02-04)

### 1. 크롤링 최적화 (4.3)

#### 목표: 학교 서버 부담 최소화 + 효율적 크롤링

- [ ] 목록 페이지만 먼저 확인하는 로직
  - 1페이지 목록 크롤링 (1회 요청)
  - DB의 마지막 `original_id`와 비교
  - 새 글 있을 때만 상세 페이지 크롤링
- [ ] 요청 간 딜레이 (1~2초) 추가
- [ ] User-Agent 헤더 정상 설정
- [ ] 에러 시 백오프 로직

---

### 2. 사용자별 맞춤 관련도 계산 (4.4)

#### 목표: 같은 공지도 사용자마다 다른 관련도 점수 부여

- [ ] `ai_analysis` 테이블 활용 설계
  - `user_id` + `notice_id` + `relevance_score` 저장
- [ ] 관련도 계산 프롬프트 작성
  - 입력: 사용자 정보 (학과, 학년, 관심 키워드) + 공지 내용
  - 출력: 0~1 관련도 점수
- [ ] 배치 처리로 API 호출 최적화
  - 사용자 1명 + 공지 여러 개 한 번에 처리

---

### 3. 북마크 기능 구현 (신규)

#### 목표: 푸시 알림 전에 사용자 북마크 기능 확립

- [ ] `bookmarks` 테이블 스키마 설계 (또는 기존 테이블 확인)
- [ ] 북마크 API 엔드포인트 구현
  - `POST /api/bookmarks` - 북마크 추가
  - `DELETE /api/bookmarks/{id}` - 북마크 삭제
  - `GET /api/bookmarks` - 내 북마크 목록 조회
- [ ] 북마크 서비스 로직 구현 (`backend/services/bookmark_service.py`)

---

### 4. 푸시 알림 구현 준비 (4.5) - 시간 되면

- [ ] FCM (Firebase Cloud Messaging) 연동 조사
- [ ] `notification_logs` 테이블 확인
- [ ] 알림 발송 조건 설계: `relevance_score > 0.5`

---

## 📋 DB 테이블 참고

### `ai_analysis` 테이블
```sql
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

### `bookmarks` 테이블 (예상)
```sql
CREATE TABLE bookmarks (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    notice_id UUID REFERENCES notices(id),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, notice_id)
);
```

---

## ⚠️ 주의사항

1. `.env` 파일은 절대 커밋하지 않기
2. `requirements.txt` 수정 시 팀원에게 즉시 공지
3. Gemini API 호출 시 비용 고려 (Flash 모델 사용)
4. 학교 서버 부담 최소화 (목록 페이지만 확인, 딜레이 추가)

---

## ⏳ 기술 부채 (나중에)

- [ ] `google.generativeai` → `google.genai` 마이그레이션
- [ ] Flask 개발 서버 → Gunicorn 전환

---

## 🔗 참고 자료

- [Gemini API 공식 문서](https://ai.google.dev/docs)
- [Supabase Python Client](https://supabase.com/docs/reference/python/introduction)
- 프로젝트 API 명세서: `docs/api_spec.md`
- 데이터베이스 스키마: `docs/database_schema.sql`
