# 🎉 AIX-Boost 팀원 온보딩 - 최종 가이드

> **팀원들에게 이 파일 하나만 공유하세요!**
> GitHub가 처음이어도, Git을 몰라도 Claude Code가 모든 걸 해줍니다.

---

## 📍 저장소 주소
https://github.com/wkdaud9/AIX-BOOST-PROJECT

---

## 🚀 5분 만에 시작하기

### 1단계: 본인 역할 확인
- 🎨 **Frontend (Flutter)** - 앱 화면 개발
- 🔧 **Backend API (Flask)** - REST API 개발
- 🤖 **Backend AI/크롤링** - Gemini AI + 크롤링

### 2단계: 역할별 가이드 열기

**본인 역할에 맞는 파일을 하나만 열어서 따라하세요**:

| 역할 | 가이드 파일 | Claude에게 할 일 |
|------|------------|-----------------|
| 🎨 Frontend | [docs/SETUP_FRONTEND.md](docs/SETUP_FRONTEND.md) | 복사-붙여넣기 1번 |
| 🔧 Backend API | [docs/SETUP_BACKEND_API.md](docs/SETUP_BACKEND_API.md) | 복사-붙여넣기 1번 |
| 🤖 Backend AI | [docs/SETUP_BACKEND_AI.md](docs/SETUP_BACKEND_AI.md) | 복사-붙여넣기 1번 |

### 3단계: 끝!

가이드 파일의 "1단계"를 복사해서 Claude Code에 붙여넣기하면:
- ✅ 저장소 자동 클론
- ✅ 환경 설정 자동 완료
- ✅ Git 브랜치 자동 생성
- ✅ 앞으로 모든 Git 작업 자동화

---

## 📅 매일 사용하는 3가지 명령어

### 🌅 아침 - 작업 시작
```
🌅 오늘 작업 시작!
오늘 할 일: [로그인 화면 만들기]
```
Claude가 자동으로:
- develop 최신 코드 pull
- 브랜치 생성/이동
- Merge

### 💻 작업 중 - 개발
```
로그인 화면 만들어줘
```
평소처럼 Claude에게 개발 요청

### 🌙 저녁 - 작업 종료
```
🌙 오늘 작업 끝!
커밋 메시지: [Frontend] 로그인 화면 구현
```
Claude가 자동으로:
- 변경사항 확인
- .env 파일 제외
- 커밋 + Push

---

## 🔒 중요: 환경 변수 설정

Claude가 `.env` 파일을 만들어주면, **반드시** 실제 값을 입력하세요:

### Supabase 정보 (팀 리더에게 받기)
```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=eyJhbGci...
```

### Gemini API (AI 담당자만, 직접 발급)
```env
GEMINI_API_KEY=AIzaSy...
```
발급: https://ai.google.dev/

**⚠️ 주의**: `.env` 파일은 절대 Git에 올라가지 않습니다 (자동 제외됨)

---

## 📞 소통 채널

### Slack/Discord 채널
- `#general`: 일반 공지
- `#frontend`: 프론트엔드
- `#backend`: 백엔드
- `#daily-standup`: 진행상황

### 매일 오전 스탠드업
```
[이름]
- 어제: 로그인 UI 완성
- 오늘: 회원가입 기능
- 블로커: 없음
```

---

## 🆘 문제 생기면?

### Claude에게 물어보기
```
이 에러 어떻게 해결해?
[에러 메시지]
```

### 팀원에게 물어보기
Slack #general 채널에:
```
@channel Git 충돌 났는데 도와주세요!
```

---

## 📚 추가 문서 (필요시)

| 문서 | 언제 읽나요? |
|------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | 프로젝트 전체 이해하고 싶을 때 |
| [docs/CLAUDE_WORKFLOW.md](docs/CLAUDE_WORKFLOW.md) | Claude 자동화 원리 궁금할 때 |
| [docs/COLLABORATION_GUIDE.md](docs/COLLABORATION_GUIDE.md) | Git 협업 자세히 알고 싶을 때 |
| [docs/api_spec.md](docs/api_spec.md) | API 명세 확인할 때 |
| [CLAUDE.md](CLAUDE.md) | 코딩 컨벤션 확인할 때 |

---

## ✅ 체크리스트

### 오늘 처음 시작하는 팀원
- [ ] 본인 역할 확인 (Frontend/Backend API/Backend AI)
- [ ] 역할별 가이드 파일 열기
- [ ] Claude Code에 1단계 복사-붙여넣기
- [ ] .env 파일에 실제 값 입력
- [ ] Slack에 "시작했습니다!" 공지

### 매일 아침
- [ ] Claude에게 "작업 시작" 요청
- [ ] Slack 스탠드업 작성

### 매일 저녁
- [ ] Claude에게 "작업 끝" 요청
- [ ] Slack 진행상황 공유

### 기능 완성 시
- [ ] Claude에게 "PR 생성" 요청
- [ ] 팀원 2명 리뷰어 지정
- [ ] 리뷰 피드백 반영

---

## 🎯 핵심 규칙 (3가지만 기억!)

1. **본인 작업 영역만 수정**
   - Frontend: `frontend/`
   - Backend API: `backend/routes/`, `backend/services/`
   - Backend AI: `backend/ai/`, `backend/crawler/`

2. **공유 파일 수정 시 Slack 공지**
   - `api_spec.md`
   - `requirements.txt`
   - `pubspec.yaml`

3. **Claude에게 명확히 지시**
   - "frontend/ 폴더에서만 작업해줘"
   - ".env 파일 제외하고 커밋해줘"

---

## 🎉 시작하기

1. **지금 바로 본인 역할 가이드 열기**:
   - 🎨 [Frontend 가이드](docs/SETUP_FRONTEND.md)
   - 🔧 [Backend API 가이드](docs/SETUP_BACKEND_API.md)
   - 🤖 [Backend AI 가이드](docs/SETUP_BACKEND_AI.md)

2. **1단계 복사 → Claude에 붙여넣기**

3. **5분 후 개발 시작!**

---

**질문이나 문제가 있으면 주저하지 말고 Slack에 공유하세요!**

**We're a team! 함께 만들어가요! 🚀**

---

*이 프로젝트는 Claude Code를 활용한 AI 페어 프로그래밍으로 개발됩니다.*
