# Frontend 개발자 - Claude 설정 가이드

> **Frontend 개발자를 위한 완전 자동화 가이드**
> 아래 내용을 그대로 Claude Code에 복사-붙여넣기만 하세요!

---

## 1단계: 최초 설정 (딱 1번만)

Claude Code를 열고 아래 전체를 복사해서 붙여넣으세요:

```
안녕 Claude! AIX-Boost 프로젝트 시작할게.

=== 프로젝트 정보 ===
저장소: https://github.com/wkdaud9/AIX-BOOST-PROJECT.git
내 역할: Frontend 개발자 (Flutter)
작업 위치: C:\Users\[본인계정]\Desktop\aix-boost-project

=== 나의 작업 영역 ===
✅ 작업 가능: frontend/ 폴더 전체
❌ 절대 수정 금지: backend/ 폴더

=== Git 설정 ===
- 내 브랜치 접두사: feature/frontend-
- 예시: feature/frontend-login, feature/frontend-calendar
- 커밋 메시지 형식: [Frontend] 작업 내용

=== 요청사항 ===
1. 위 저장소를 C:\Users\[본인계정]\Desktop\aix-boost-project 경로에 클론해줘
2. develop 브랜치로 이동해줘
3. backend/.env.example을 backend/.env로 복사해줘 (파일만 복사, 내용은 나중에 수정)
4. frontend/.env.example을 frontend/.env로 복사해줘 (파일만 복사, 내용은 나중에 수정)
5. Git 설정 확인해줘

앞으로 내가 "작업 시작", "작업 종료", "PR 생성" 같은 키워드를 말하면
자동으로 Git 작업을 처리해줘.

docs/CLAUDE_WORKFLOW.md 파일을 읽고 워크플로우를 숙지해줘.
```

**주의**: `[본인계정]` 부분을 본인의 Windows 사용자 이름으로 바꾸세요!
- 예: `C:\Users\kimcoding\Desktop\aix-boost-project`

---

## 2단계: 환경 변수 설정

Claude가 .env 파일을 만들어주면, 파일을 열어서 실제 값을 입력하세요:

### frontend/.env 파일
```env
# Backend API URL (로컬 개발 시)
BACKEND_URL=http://localhost:5000

# Supabase 설정 (팀 리더에게 받기)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Firebase 설정 (나중에 추가)
FIREBASE_API_KEY=
FIREBASE_PROJECT_ID=
```

**어디서 받나요?**
- Supabase 정보: 팀 리더 또는 Slack #general 채널
- Firebase 정보: 나중에 푸시 알림 구현 시 추가

---

## 3단계: 매일 사용하는 명령어

### 🌅 아침 - 작업 시작
Claude에게 이렇게 말하세요:

```
🌅 오늘 작업 시작!

오늘 할 일: [로그인 화면 만들기]

1. develop 최신 코드 pull
2. feature/frontend-login 브랜치 생성 (또는 이동)
3. develop 변경사항 merge
```

### 💻 작업 중 - 개발 요청
```
로그인 화면 UI 만들어줘.
- 이메일, 비밀번호 입력 폼
- 로그인 버튼
- Material Design 3 스타일로
```

### 💾 중간 저장 (선택)
```
지금까지 중간 저장해줘.
```

### 🌙 저녁 - 작업 완료
```
🌙 오늘 작업 끝!

1. 변경 파일 확인
2. .env 파일 제외됐는지 확인
3. 커밋 메시지: [Frontend] 로그인 화면 UI 구현
4. Push
```

### 🚀 기능 완성 - PR 생성
```
🚀 로그인 기능 완성!

PR 생성해줘:
- 제목: [Frontend] 로그인 화면 구현
- Base: develop
- 템플릿 사용
```

---

## 4단계: 팀원 코드 가져오기

백엔드 팀원이 API 추가했다고 Slack 공지 오면:

```
백엔드 팀원이 API 추가했대.
develop 최신 코드 받아서 내 브랜치에 merge 해줘.
```

---

## 자주 쓰는 명령어 모음

```
# 상태 확인
지금 상태 보여줘

# 최근 커밋 확인
최근 커밋 3개 보여줘

# 브랜치 목록
브랜치 목록 보여줘

# 특정 파일 되돌리기
[파일명] 변경사항 취소해줘

# 커밋 취소 (push 전)
마지막 커밋 취소해줘
```

---

## 🆘 문제 해결

### Merge Conflict 났을 때
```
Merge conflict 났어.
어떻게 해결하면 돼?
```

### 실수로 backend/ 파일 수정했을 때
```
실수로 backend 파일 수정했어.
내 작업만 남기고 backend 변경사항은 취소해줘.
```

### .env 파일이 커밋에 포함될 뻔 했을 때
```
.env 파일 커밋에서 제외해줘.
```

---

## ✅ 완료!

이제 매일:
1. 아침에 "작업 시작" 복사-붙여넣기
2. 개발 요청
3. 저녁에 "작업 끝" 복사-붙여넣기

이것만 하면 됩니다! Claude가 알아서 Git 관리를 해줍니다. 🎉
