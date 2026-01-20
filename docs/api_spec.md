# AIX-Boost API 명세서

## 공통 규칙

### API 응답 포맷
모든 API 응답은 다음 형식을 따릅니다:

```json
{
  "status": "success" | "error",
  "data": { ... } | null,
  "message": "에러 메시지 (에러 시에만)"
}
```

### 인증
- 인증이 필요한 API는 `Authorization: Bearer {token}` 헤더를 포함해야 합니다.
- 토큰은 Supabase Auth를 통해 발급받습니다.

---

## 1. 서버 상태

### `GET /`
서버 상태를 확인합니다.

**응답:**
```json
{
  "status": "success",
  "data": {
    "message": "AIX-Boost API Server is running",
    "version": "1.0.0"
  }
}
```

### `GET /health`
헬스 체크 엔드포인트입니다.

**응답:**
```json
{
  "status": "success",
  "data": {
    "health": "ok"
  }
}
```

---

## 2. 사용자 인증 (예정)

### `POST /auth/signup`
사용자 회원가입

**요청 Body:**
```json
{
  "email": "student@kunsan.ac.kr",
  "password": "password123",
  "student_id": "202012345",
  "department": "컴퓨터정보공학과"
}
```

### `POST /auth/login`
사용자 로그인

**요청 Body:**
```json
{
  "email": "student@kunsan.ac.kr",
  "password": "password123"
}
```

---

## 3. 공지사항 (예정)

### `GET /notices`
공지사항 목록 조회

**쿼리 파라미터:**
- `page`: 페이지 번호 (기본값: 1)
- `limit`: 페이지당 개수 (기본값: 20)
- `category`: 카테고리 필터 (선택)

**응답:**
```json
{
  "status": "success",
  "data": {
    "notices": [
      {
        "id": "uuid",
        "title": "공지사항 제목",
        "content": "공지사항 내용",
        "category": "학사",
        "source_url": "https://...",
        "published_at": "2024-01-20T10:00:00Z",
        "ai_summary": "AI가 요약한 내용",
        "extracted_dates": ["2024-02-01", "2024-02-15"]
      }
    ],
    "total": 100,
    "page": 1,
    "total_pages": 5
  }
}
```

### `GET /notices/:id`
특정 공지사항 상세 조회

---

## 4. AI 분석 (예정)

### `POST /ai/analyze`
공지사항을 Gemini AI로 분석

**요청 Body:**
```json
{
  "notice_id": "uuid",
  "user_preferences": {
    "department": "컴퓨터정보공학과",
    "grade": 3
  }
}
```

**응답:**
```json
{
  "status": "success",
  "data": {
    "relevance_score": 0.95,
    "summary": "AI 요약",
    "extracted_events": [
      {
        "title": "이벤트명",
        "date": "2024-02-01",
        "time": "14:00",
        "location": "본관 101호"
      }
    ],
    "action_required": true,
    "deadline": "2024-01-31"
  }
}
```

---

## 5. 캘린더 (예정)

### `GET /calendar/events`
사용자의 캘린더 일정 조회

### `POST /calendar/events`
새로운 일정 추가

---

## 데이터 타입 정의

### Notice
```typescript
interface Notice {
  id: string;
  title: string;
  content: string;
  category: string;
  source_url: string;
  published_at: string;  // ISO 8601
  ai_summary?: string;
  extracted_dates?: string[];
  relevance_score?: number;
}
```

### CalendarEvent
```typescript
interface CalendarEvent {
  id: string;
  notice_id?: string;
  title: string;
  description?: string;
  start_date: string;  // ISO 8601
  end_date?: string;
  location?: string;
  created_at: string;
}
```

### User
```typescript
interface User {
  id: string;
  email: string;
  student_id: string;
  department: string;
  grade?: number;
  preferences?: UserPreferences;
}
```

### UserPreferences
```typescript
interface UserPreferences {
  categories: string[];  // 관심 카테고리
  keywords: string[];    // 관심 키워드
  notification_enabled: boolean;
}
```
