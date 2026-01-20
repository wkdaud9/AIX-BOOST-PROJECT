# AIX-Boost 빠른 시작 가이드

## 신규 팀원 온보딩 (5분 완료)

### 1단계: 저장소 클론
```bash
git clone <repository-url>
cd aix-boost-project
```

### 2단계: 본인 역할 확인
- **Frontend 개발자**: Flutter 담당
- **Backend 개발자 1**: API 개발
- **Backend 개발자 2**: AI/크롤링

### 3단계: 환경 설정

#### 공통
```bash
# develop 브랜치로 이동
git checkout develop

# 본인의 feature 브랜치 생성
git checkout -b feature/[본인영역]-[작업명]

# 예시:
# git checkout -b feature/frontend-login
# git checkout -b feature/backend-gemini
```

#### Frontend 개발자
```bash
cd frontend

# .env 파일 생성
cp .env.example .env
# .env 파일을 열어 BACKEND_URL 등 설정

# Flutter 의존성 설치
flutter pub get

# 앱 실행 테스트
flutter run
```

#### Backend 개발자
```bash
cd backend

# .env 파일 생성
cp .env.example .env
# .env 파일을 열어 API 키 등 설정

# Python 가상환경 생성 (권장)
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 의존성 설치
pip install -r requirements.txt

# 서버 실행 테스트
python app.py
```

### 4단계: 협업 가이드 읽기
```bash
# 필독 문서
cat docs/COLLABORATION_GUIDE.md
```

**핵심 규칙 요약**:
- 작업 전 항상 `git pull origin develop`
- 본인 작업 영역에서만 작업
- 공유 파일 수정 시 Slack 공지
- PR 전 로컬 테스트 필수

---

## Claude Code 사용 팀원을 위한 팁

### Claude에게 첫 지시 예시

#### Frontend 개발자
```
안녕 Claude! 나는 AIX-Boost 프로젝트의 Frontend 개발자야.
Flutter로 군산대학교 공지 큐레이션 앱을 만들고 있어.

- 내 작업 영역: frontend/ 폴더 전체
- 백엔드 팀원 2명과 협업 중이야
- docs/api_spec.md에 API 명세가 있어

앞으로 frontend/ 폴더에서만 작업해줘.
backend/ 폴더는 건드리지 마.
```

#### Backend 개발자 (API)
```
안녕 Claude! 나는 AIX-Boost 프로젝트의 Backend API 개발자야.
Flask로 RESTful API를 만들고 있어.

- 내 작업 영역: backend/routes/, backend/services/
- 프론트 개발자 1명, 백엔드 동료 1명과 협업 중이야
- docs/api_spec.md의 명세에 따라 API를 구현해야 해

backend/crawler/, backend/ai/ 폴더는 동료가 작업 중이니 건드리지 마.
```

#### Backend 개발자 (AI/크롤링)
```
안녕 Claude! 나는 AIX-Boost 프로젝트의 Backend AI/크롤링 개발자야.
Gemini AI와 크롤링을 담당하고 있어.

- 내 작업 영역: backend/crawler/, backend/ai/
- 동료가 backend/routes/에서 API를 작업 중이야

내 작업 영역에서만 작업해줘.
```

### Claude로 일일 작업 시작하기
```
Claude, 오늘 작업 시작할게.

1. develop 브랜치의 최신 변경사항 확인해줘
2. 내 feature 브랜치에 merge해줘
3. 충돌이 있으면 알려줘
```

### Claude로 작업 마무리하기
```
Claude, 오늘 작업 마무리할게.

1. 변경된 파일 목록 보여줘
2. .env 파일이나 팀원 영역 파일이 포함됐는지 확인해줘
3. 문제 없으면 커밋해줘. 커밋 메시지는 "[Frontend] 로그인 UI 구현"로 해줘
```

---

## 자주 묻는 질문 (FAQ)

### Q1: "git pull 하니까 충돌이 났어요"
```bash
# Claude에게 요청
"git pull origin develop 했더니 충돌이 났어.
[파일명] 파일에서 충돌 해결해줘."
```

### Q2: "팀원이 수정한 API 명세를 확인하고 싶어요"
```bash
git checkout develop
git pull origin develop

# Claude에게 요청
"docs/api_spec.md 파일에서 최근 추가된 API가 뭐야?"
```

### Q3: "실수로 팀원 파일을 수정했어요"
```bash
# 커밋 전이라면
git checkout -- [팀원파일명]

# 이미 커밋했다면
git revert [커밋해시]
```

### Q4: "Claude가 .env 파일을 커밋하려고 해요"
```bash
# .gitignore가 제대로 설정되어 있는지 확인
cat .gitignore | grep .env

# Claude에게 재지시
".env 파일은 제외하고 커밋해줘"
```

### Q5: "PR을 만들고 싶어요"
```bash
# Claude에게 요청
"현재 작업으로 PR 만들어줘.
- 제목: [Frontend] 로그인 화면 구현
- Base: develop
- PR 템플릿 사용해줘"
```

---

## 일일 체크리스트

### 아침 (작업 시작)
- [ ] `git checkout develop && git pull origin develop`
- [ ] `git checkout feature/본인브랜치`
- [ ] `git merge develop` (충돌 확인)
- [ ] Slack에 오늘 작업 내용 공유

### 저녁 (작업 종료)
- [ ] Claude에게 변경 파일 확인 요청
- [ ] 로컬 테스트 실행 (pytest / flutter test)
- [ ] 커밋 + push
- [ ] PR 생성 (작업 완료 시)
- [ ] Slack에 진행 상황 공유

---

## 긴급 상황 대응

### 서버가 안 돌아가요
```bash
# Backend
cd backend
python app.py
# 에러 메시지를 Claude에게 공유

# Frontend
cd frontend
flutter doctor  # 환경 확인
flutter clean && flutter pub get
```

### 팀원과 동시에 같은 파일을 수정했어요
1. Slack에 즉시 공지
2. 먼저 PR 올린 사람이 우선 merge
3. 나중 사람이 충돌 해결

### main 브랜치에 실수로 push했어요
1. **절대 force push 하지 말 것**
2. 즉시 팀 리더에게 연락
3. `git revert`로 복구

---

## 추가 리소스

- **협업 가이드**: [docs/COLLABORATION_GUIDE.md](docs/COLLABORATION_GUIDE.md)
- **API 명세**: [docs/api_spec.md](docs/api_spec.md)
- **DB 스키마**: [docs/database_schema.sql](docs/database_schema.sql)
- **Claude 가이드**: [CLAUDE.md](CLAUDE.md)

---

**문제가 생기면 주저하지 말고 Slack #general 채널에 공유하세요!**
**We're a team! 🚀**
