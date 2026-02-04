# Frontend 작업 목록 (2026-02-04 예정)

## 🎯 작업 영역: Frontend (Flutter)

---

## ✅ 백엔드 현황 (연동 가능)

| 기능 | 상태 | API 엔드포인트 |
|------|------|----------------|
| 서버 상태 | ✅ | `GET /health` |
| 공지사항 목록 | ✅ | `GET /api/notices` |
| 공지사항 상세 | ✅ | `GET /api/notices/:id` |
| AI 분석 결과 | ✅ | notices 테이블에 포함 |
| 캘린더 일정 | ✅ | `GET /api/calendar/events` |
| 북마크 | 🚧 내일 | `POST/GET/DELETE /api/bookmarks` |

**백엔드 서버**: `https://aix-boost-backend.onrender.com`

---

## 🚀 오늘 할 일 (2026-02-04)

### 1. API 서비스 연동 설정

#### 목표: 백엔드 API와 통신 기반 구축

- [ ] `lib/services/api_service.dart` 백엔드 URL 설정
  ```dart
  static const String baseUrl = 'https://aix-boost-backend.onrender.com';
  ```
- [ ] API 응답 공통 처리 (status, data, message 파싱)
- [ ] 에러 핸들링 (네트워크 오류, 서버 오류)
- [ ] 인증 토큰 헤더 추가 로직

---

### 2. 공지사항 화면 구현

#### 목표: 공지 목록 + AI 분석 결과 표시

- [ ] `home_screen.dart` - 공지사항 목록 API 연동
  - `GET /api/notices?page=1&limit=20`
  - 무한 스크롤 또는 페이지네이션
- [ ] `notice_detail_screen.dart` - 상세 화면 구현
  - AI 요약 (`ai_summary`) 표시
  - 카테고리 뱃지 (`category`)
  - 중요도 표시 (`priority`: 긴급/중요/일반)
  - 추출된 일정 표시 (`extracted_dates`)
- [ ] `notice_provider.dart` - 상태 관리 로직
- [ ] 카테고리 필터 UI (학사, 장학, 취업, 행사, 시설, 기타)

---

### 3. 캘린더 화면 구현

#### 목표: AI가 추출한 일정 캘린더에 표시

- [ ] `calendar_screen.dart` - 캘린더 UI 구현
  - 패키지: `table_calendar` 또는 `syncfusion_flutter_calendar`
- [ ] 캘린더 일정 API 연동
  - `GET /api/calendar/events?month=2026-02`
- [ ] 일정 클릭 시 원본 공지로 이동
- [ ] 월별/주별 뷰 전환

---

### 4. 북마크 화면 구현

#### 목표: 사용자가 저장한 공지 관리

- [ ] `bookmark_screen.dart` - 북마크 목록 UI
- [ ] 북마크 추가/삭제 기능
  - `POST /api/bookmarks` (추가)
  - `DELETE /api/bookmarks/:id` (삭제)
- [ ] 공지 카드에 북마크 아이콘 추가
- [ ] 로컬 상태 관리 (낙관적 업데이트)

---

### 5. 사용자 프로필/설정 (시간 되면)

- [ ] `profile_screen.dart` - 사용자 정보 표시
- [ ] 관심 카테고리 설정
- [ ] 알림 설정 (ON/OFF)

---

## 📋 API 응답 예시

### 공지사항 목록 (`GET /api/notices`)
```json
{
  "status": "success",
  "data": {
    "notices": [
      {
        "id": "uuid",
        "title": "2026학년도 1학기 수강신청 안내",
        "category": "학사",
        "priority": "긴급",
        "ai_summary": "2월 1일부터 학년별 수강신청 시작",
        "published_at": "2026-02-03T10:00:00Z",
        "extracted_dates": ["2026-02-01", "2026-02-05"]
      }
    ],
    "total": 50,
    "page": 1
  }
}
```

### 캘린더 일정 (`GET /api/calendar/events`)
```json
{
  "status": "success",
  "data": {
    "events": [
      {
        "id": "uuid",
        "notice_id": "uuid",
        "title": "수강신청 시작",
        "start_date": "2026-02-01",
        "end_date": "2026-02-05",
        "event_type": "deadline"
      }
    ]
  }
}
```

---

## 📁 현재 프론트엔드 구조

```
frontend/lib/
├── main.dart
├── models/
│   └── notice.dart
├── providers/
│   └── notice_provider.dart
├── screens/
│   ├── auth_wrapper.dart
│   ├── bookmark_screen.dart
│   ├── calendar_screen.dart
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── notice_detail_screen.dart
│   ├── profile_screen.dart
│   └── signup_screen.dart
├── services/
│   ├── api_service.dart
│   └── auth_service.dart
├── theme/
│   └── app_theme.dart
└── widgets/
    ├── custom_text_field.dart
    ├── form_section.dart
    └── loading_button.dart
```

---

## ⚠️ 주의사항

1. `pubspec.yaml` 수정 시 팀원에게 즉시 공지
2. 백엔드 API 변경 시 Backend 담당자와 소통
3. `.env` 파일은 절대 커밋하지 않기
4. 상태 관리는 Provider 패턴 유지

---

## 🔗 참고 자료

- 백엔드 서버: `https://aix-boost-backend.onrender.com`
- API 명세서: `docs/api_spec.md`
- Flutter 공식 문서: https://docs.flutter.dev
- Provider 패키지: https://pub.dev/packages/provider
