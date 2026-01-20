# Claude Code 자동 워크플로우 가이드

> **이 문서는 Git이 처음이거나 익숙하지 않은 팀원을 위한 가이드입니다.**
> Claude Code에게 복사-붙여넣기만 하면 모든 Git 작업을 자동으로 처리합니다.

---

## 📌 시작 전 준비 (최초 1회만)

### 1. 저장소 클론
Claude에게 다음과 같이 요청하세요:

```
저장소 클론해줘:
https://github.com/wkdaud9/AIX-BOOST-PROJECT.git

클론 위치: C:\Users\Admin\Desktop\aix-boost-project
(또는 본인이 원하는 경로)
```

### 2. 본인 역할 설정
**중요**: 본인의 역할에 맞는 메시지를 Claude에게 보내세요.

#### Frontend 개발자라면:
```
안녕 Claude! 나는 AIX-Boost 프로젝트의 Frontend 개발자야.

프로젝트 경로: C:\Users\Admin\Desktop\aix-boost-project

나의 역할:
- Flutter 앱 개발 담당
- 작업 영역: frontend/ 폴더 전체
- 작업하지 말아야 할 곳: backend/ 폴더

Git 설정:
- 브랜치 네이밍: feature/frontend-[기능명]
- 예시: feature/frontend-login, feature/frontend-calendar

앞으로 나의 Git 작업을 자동으로 처리해줘.
```

#### Backend 개발자 (API 담당)라면:
```
안녕 Claude! 나는 AIX-Boost 프로젝트의 Backend API 개발자야.

프로젝트 경로: C:\Users\Admin\Desktop\aix-boost-project

나의 역할:
- Flask API 개발 담당
- 작업 영역: backend/routes/, backend/services/
- 작업하지 말아야 할 곳: backend/crawler/, backend/ai/, frontend/

Git 설정:
- 브랜치 네이밍: feature/backend-api-[기능명]
- 예시: feature/backend-api-auth, feature/backend-api-notices

앞으로 나의 Git 작업을 자동으로 처리해줘.
```

#### Backend 개발자 (AI/크롤링 담당)라면:
```
안녕 Claude! 나는 AIX-Boost 프로젝트의 Backend AI/크롤링 개발자야.

프로젝트 경로: C:\Users\Admin\Desktop\aix-boost-project

나의 역할:
- Gemini AI 통합 및 크롤링 담당
- 작업 영역: backend/ai/, backend/crawler/
- 작업하지 말아야 할 곳: backend/routes/, backend/services/, frontend/

Git 설정:
- 브랜치 네이밍: feature/backend-ai-[기능명]
- 예시: feature/backend-ai-gemini, feature/backend-ai-crawler

앞으로 나의 Git 작업을 자동으로 처리해줘.
```

---

## 🌅 매일 아침 - 작업 시작

Claude에게 이 메시지를 복사해서 보내세요:

```
🌅 오늘 작업 시작할게!

1. develop 브랜치에서 최신 코드 pull 해줘
2. 오늘 작업할 브랜치 만들어줘 (또는 기존 브랜치로 이동)
   브랜치명: feature/[내역할]-[오늘작업명]
3. develop의 최신 변경사항을 내 브랜치에 merge 해줘
4. 충돌이 있으면 알려줘
```

**예시**:
- Frontend: `feature/frontend-login-ui`
- Backend API: `feature/backend-api-user-auth`
- Backend AI: `feature/backend-ai-gemini-integration`

Claude가 자동으로 다음을 처리합니다:
```bash
git checkout develop
git pull origin develop
git checkout -b feature/frontend-login-ui  # 또는 기존 브랜치로 checkout
git merge develop
```

---

## 💻 작업 중 - 중간 저장 (선택 사항)

작업 중간에 임시 저장하고 싶을 때:

```
지금까지 작업 중간 저장해줘.
커밋 메시지: "WIP: 로그인 UI 작업 중"
```

Claude가 자동으로:
```bash
git add .
git commit -m "WIP: 로그인 UI 작업 중"
```

---

## 🌙 저녁 - 작업 완료 후 Push

하루 작업이 끝나면 Claude에게 이 메시지를 보내세요:

```
🌙 오늘 작업 끝났어! Push까지 해줘.

1. 변경된 파일 목록 보여줘
2. .env 파일이나 팀원 작업 영역 파일이 포함됐는지 확인해줘
3. 문제 없으면 커밋해줘
   커밋 메시지: [Frontend] 로그인 화면 UI 구현 완료
   (본인 영역에 맞게: [Frontend], [Backend-API], [Backend-AI])
4. GitHub에 push 해줘
```

Claude가 자동으로:
```bash
git status                          # 변경 파일 확인
git add .                           # 스테이징
git commit -m "[Frontend] ..."      # 커밋
git push origin feature/본인브랜치   # Push
```

---

## 🚀 PR 생성 - 기능 완성 후

기능 개발이 완전히 끝나면:

```
🚀 기능 개발 완료했어! PR 만들어줘.

PR 정보:
- 제목: [Frontend] 로그인 화면 구현
- Base 브랜치: develop
- 내용: .github/PULL_REQUEST_TEMPLATE.md 템플릿 사용
```

Claude가 자동으로:
```bash
gh pr create --base develop --title "[Frontend] 로그인 화면 구현" --body "템플릿 내용"
```

또는 수동으로:
1. GitHub 웹사이트 접속
2. Pull Requests → New Pull Request
3. Base: `develop`, Compare: `feature/본인브랜치`
4. 템플릿 작성 후 Create

---

## 🔄 팀원 코드 업데이트 받기

팀원이 develop에 merge 했다는 공지가 오면:

```
팀원이 develop에 merge 했다고 해.
최신 코드 받아서 내 브랜치에 merge 해줘.
```

Claude가 자동으로:
```bash
git checkout develop
git pull origin develop
git checkout feature/본인브랜치
git merge develop
```

---

## 🆘 문제 해결

### 1. Merge Conflict 발생 시

```
Merge conflict가 났어.
충돌 파일 보여주고 해결 방법 알려줘.
```

Claude가:
1. 충돌 파일 목록 보여줌
2. 충돌 내용 설명
3. 해결 방법 제시 (자동 해결 또는 수동 선택)

### 2. 실수로 잘못 커밋한 경우

```
방금 커밋 취소해줘. (아직 push 안 했어)
```

Claude가:
```bash
git reset --soft HEAD~1  # 커밋만 취소, 변경사항은 유지
```

### 3. 브랜치 이름 바꾸고 싶을 때

```
현재 브랜치 이름을 feature/frontend-new-name으로 바꿔줘.
```

Claude가:
```bash
git branch -m feature/frontend-new-name
```

---

## 📋 자주 쓰는 명령어 모음

### 현재 상태 확인
```
지금 Git 상태 보여줘.
```

### 최근 커밋 이력 확인
```
최근 커밋 5개 보여줘.
```

### 특정 파일 변경사항 확인
```
[파일명]에서 뭐가 바뀌었는지 보여줘.
```

### 브랜치 목록 확인
```
모든 브랜치 목록 보여줘.
```

---

## 📝 커밋 메시지 규칙

Claude에게 커밋할 때 자동으로 이 형식을 사용하도록 지시되어 있습니다:

```
[영역] 간단한 설명

- 상세 내용 1
- 상세 내용 2

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**영역 태그**:
- `[Frontend]`: Flutter UI/로직
- `[Backend-API]`: Flask API
- `[Backend-AI]`: Gemini AI/크롤링
- `[Docs]`: 문서 수정
- `[Fix]`: 버그 수정

---

## 🎯 완전 자동화 - 하루 워크플로우

### 아침에 Claude에게:
```
🌅 오늘 작업: 로그인 화면 UI 만들기

1. develop 최신화
2. feature/frontend-login-ui 브랜치 생성 (또는 이동)
3. develop merge
```

### 작업 중에는:
```
(Claude에게 개발 요청)
"로그인 화면 만들어줘"
"API 연동해줘"
등등...
```

### 저녁에 Claude에게:
```
🌙 오늘 작업 끝! Push 해줘.
커밋 메시지: [Frontend] 로그인 화면 UI 구현
```

### 기능 완성 시:
```
🚀 로그인 기능 완성! PR 만들어줘.
```

---

## 💡 Pro Tips

### Tip 1: 매일 같은 브랜치에서 작업
```
오늘도 feature/frontend-login-ui 브랜치에서 작업할게.
최신화부터 해줘.
```

### Tip 2: 빠른 저장
```
빠르게 저장: "임시 저장"
```

### Tip 3: 팀원 변경사항 확인
```
develop 브랜치에 뭐가 바뀌었는지 보여줘.
```

### Tip 4: Claude가 자동으로 .env 파일 제외
Claude는 자동으로 `.env` 파일을 커밋에서 제외합니다.
하지만 확인하려면:
```
.env 파일이 커밋에 포함됐는지 확인해줘.
```

---

## 📞 도움 요청

막히면 Claude에게:
```
Git 작업이 막혔어. 도와줘.
현재 상황: [설명]
```

또는 팀 Slack에:
```
#general 채널에 "Git 문제 생겼어요!" 메시지
```

---

## ✅ 체크리스트

### 매일 아침
- [ ] Claude에게 "오늘 작업 시작" 요청
- [ ] develop 최신화 확인
- [ ] 브랜치 생성/이동 확인

### 매일 저녁
- [ ] Claude에게 "작업 끝" 요청
- [ ] 변경 파일 확인
- [ ] Push 완료 확인
- [ ] Slack에 진행상황 공유

### 기능 완성 시
- [ ] PR 생성
- [ ] 팀원 리뷰 요청
- [ ] 리뷰 피드백 반영

---

**이 가이드만 따라하면 Git을 몰라도 Claude가 모든 걸 알아서 합니다!** 🎉
