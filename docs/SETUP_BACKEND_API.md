# Backend API 개발자 - Claude 설정 가이드

> **Backend API 개발자를 위한 완전 자동화 가이드**
> 아래 내용을 그대로 Claude Code에 복사-붙여넣기만 하세요!

---

## 1단계: 최초 설정 (딱 1번만)

Claude Code를 열고 아래 전체를 복사해서 붙여넣으세요:

```
안녕 Claude! AIX-Boost 프로젝트 시작할게.

=== 프로젝트 정보 ===
저장소: https://github.com/wkdaud9/AIX-BOOST-PROJECT.git
내 역할: Backend API 개발자 (Flask)
작업 위치: C:\Users\[본인계정]\Desktop\aix-boost-project

=== 나의 작업 영역 ===
✅ 작업 가능:
  - backend/routes/ (API 라우팅)
  - backend/services/ (비즈니스 로직)
  - backend/app.py (라우트 등록만)

❌ 절대 수정 금지:
  - backend/ai/ (AI 담당 동료 작업 중)
  - backend/crawler/ (크롤링 담당 동료 작업 중)
  - frontend/ (프론트 개발자 작업 중)

=== Git 설정 ===
- 내 브랜치 접두사: feature/backend-api-
- 예시: feature/backend-api-auth, feature/backend-api-notices
- 커밋 메시지 형식: [Backend-API] 작업 내용

=== 요청사항 ===
1. 위 저장소를 C:\Users\[본인계정]\Desktop\aix-boost-project 경로에 클론해줘
2. develop 브랜치로 이동해줘
3. backend/.env.example을 backend/.env로 복사해줘
4. Python 가상환경 생성해줘 (backend/venv)
5. requirements.txt로 패키지 설치해줘
6. Git 설정 확인해줘

앞으로 내가 "작업 시작", "작업 종료", "PR 생성" 같은 키워드를 말하면
자동으로 Git 작업을 처리해줘.

docs/CLAUDE_WORKFLOW.md 파일을 읽고 워크플로우를 숙지해줘.
```

**주의**: `[본인계정]` 부분을 본인의 Windows 사용자 이름으로 바꾸세요!

---

## 2단계: 환경 변수 설정

### backend/.env 파일
```env
# Flask 설정
FLASK_ENV=development
SECRET_KEY=dev-secret-key-change-later
PORT=5000

# Supabase 설정 (팀 리더에게 받기)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Gemini AI (나중에 AI 담당 동료가 설정)
GEMINI_API_KEY=

# 크롤링 설정
CRAWLER_INTERVAL=3600
```

---

## 3단계: 매일 사용하는 명령어

### 🌅 아침 - 작업 시작
```
🌅 오늘 작업 시작!

오늘 할 일: [사용자 인증 API 만들기]

1. develop 최신 코드 pull
2. feature/backend-api-auth 브랜치 생성 (또는 이동)
3. develop 변경사항 merge
4. Flask 서버 실행 확인
```

### 💻 작업 중 - API 개발
```
회원가입 API 만들어줘.

docs/api_spec.md의 POST /auth/signup 명세 참고해서
backend/routes/auth.py 파일에 구현해줘.

Supabase Auth 연동하고,
응답 포맷은 {"status": "success", "data": {...}} 로 해줘.
```

### 🧪 테스트
```
방금 만든 API 테스트해줘.
pytest로 유닛 테스트 돌려봐.
```

### 📝 API 명세 업데이트
```
docs/api_spec.md에 방금 만든 API 명세 추가해줘.
그리고 Slack에 공지할 메시지 작성해줘.
```

### 🌙 저녁 - 작업 완료
```
🌙 오늘 작업 끝!

1. 변경 파일 확인
2. requirements.txt 업데이트 필요한지 확인
3. 커밋 메시지: [Backend-API] 사용자 인증 API 구현
4. Push
```

### 🚀 기능 완성 - PR 생성
```
🚀 인증 API 완성!

PR 생성해줘:
- 제목: [Backend-API] 사용자 인증 API 구현
- Base: develop
- 테스트 완료 체크
```

---

## 4단계: 협업 시나리오

### API 명세 먼저 작성 (프론트와 협의)
```
로그인 API 명세를 docs/api_spec.md에 작성해줘.

엔드포인트: POST /auth/login
요청: email, password
응답: 토큰, 사용자 정보

작성 후 커밋하고 Slack에 공지 메시지 만들어줘.
```

### AI 동료가 만든 함수 사용
```
backend/ai/gemini_service.py에 있는
analyze_notice() 함수를 사용해서
공지사항 분석 API 만들어줘.

AI 동료 파일은 수정하지 말고 import만 해서 사용해.
```

---

## 자주 쓰는 명령어

```
# Flask 서버 실행
서버 실행해줘

# 서버 중지
서버 중지해줘

# 테스트 실행
pytest 돌려줘

# API 테스트 (curl)
curl로 로그인 API 테스트해줘

# 패키지 추가
requests 패키지 설치하고 requirements.txt 업데이트해줘

# 로그 확인
최근 Flask 로그 보여줘
```

---

## 🆘 문제 해결

### Import Error 날 때
```
[패키지명] import error 났어.
패키지 설치되어 있는지 확인하고 필요하면 설치해줘.
```

### DB 연결 오류
```
Supabase 연결 안 돼.
.env 파일 설정 확인해줘.
```

### 포트 충돌
```
5000번 포트가 이미 사용 중이래.
다른 포트로 실행해줘.
```

---

## 📋 체크리스트

### API 개발 완료 기준
- [ ] API 명세 작성 (docs/api_spec.md)
- [ ] API 구현 (backend/routes/)
- [ ] 유닛 테스트 작성
- [ ] curl 또는 Postman으로 수동 테스트
- [ ] 에러 처리 추가
- [ ] Slack에 프론트 개발자에게 공지

### 커밋 전 확인
- [ ] .env 파일 제외됐는지 확인
- [ ] backend/ai/, backend/crawler/ 수정 안 했는지 확인
- [ ] requirements.txt 업데이트 필요 시 팀원 공지

---

## ✅ 완료!

매일:
1. "작업 시작" → API 개발 → "작업 끝"
2. API 명세 업데이트 시 Slack 공지
3. 동료 작업 영역은 절대 수정 금지

Claude가 모든 Git 작업을 자동으로 처리합니다! 🎉
