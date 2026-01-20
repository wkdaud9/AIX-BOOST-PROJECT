# AIX-Boost 협업 가이드

## 팀 구성
- **Frontend 개발자 1명**: Flutter 담당
- **Backend 개발자 2명**: Flask + AI/크롤링 담당
- **각자 Claude Code 사용**: AI 페어 프로그래밍

---

## 1. Git 브랜치 전략 (GitHub Flow 기반)

### 브랜치 구조
```
main (production)
  └── develop (개발 통합)
       ├── feature/frontend-auth (프론트 개발자)
       ├── feature/backend-api (백엔드 개발자 1)
       └── feature/backend-crawler (백엔드 개발자 2)
```

### 브랜치 규칙

1. **main**: 배포 가능한 안정 버전만 merge
2. **develop**: 개발 중인 기능들을 통합하는 브랜치
3. **feature/**: 개인별 작업 브랜치
   - 네이밍: `feature/{영역}-{기능명}`
   - 예시: `feature/frontend-login`, `feature/backend-gemini`

### 브랜치 생성 예시
```bash
# develop 브랜치에서 시작
git checkout develop
git pull origin develop

# 본인의 feature 브랜치 생성
git checkout -b feature/frontend-auth
```

---

## 2. 작업 영역 분리 (충돌 최소화)

### Frontend 개발자
**작업 폴더**: `frontend/` 전체
```
frontend/
├── lib/
│   ├── screens/      # 화면 UI (본인 담당)
│   ├── widgets/      # 재사용 위젯
│   ├── services/     # API 통신 (공유 주의)
│   └── models/       # 데이터 모델 (공유 주의)
└── pubspec.yaml      # ⚠️ 수정 시 팀원에게 공지
```

**주의사항**:
- `pubspec.yaml` 수정 시 Slack/Discord로 공지
- `api_service.dart` 수정 시 백엔드 팀과 협의

### Backend 개발자 1 (API 담당)
**작업 폴더**: `backend/routes/`, `backend/services/`
```
backend/
├── routes/           # API 라우팅 (본인 담당)
│   ├── auth.py
│   ├── notices.py
│   └── calendar.py
├── services/         # 비즈니스 로직
│   └── supabase_service.py
└── app.py            # ⚠️ 라우트 등록만 수정
```

### Backend 개발자 2 (AI/크롤링 담당)
**작업 폴더**: `backend/crawler/`, `backend/ai/`
```
backend/
├── crawler/          # 크롤링 스크립트 (본인 담당)
│   ├── kunsan_crawler.py
│   └── scheduler.py
├── ai/               # Gemini AI 로직 (본인 담당)
│   ├── gemini_service.py
│   └── prompt_templates.py
└── requirements.txt  # ⚠️ 수정 시 팀원에게 공지
```

---

## 3. Claude Code 협업 워크플로우

### 🔄 일일 작업 루틴

#### 아침: 작업 시작 전
```bash
# 1. develop 브랜치 최신화
git checkout develop
git pull origin develop

# 2. 본인 feature 브랜치로 이동
git checkout feature/본인브랜치

# 3. develop 변경사항 merge (충돌 방지)
git merge develop

# 4. Claude Code 시작
# Claude에게: "develop 최신 변경사항 확인해줘"
```

#### 오후: 작업 완료 후
```bash
# 1. Claude에게: "현재 작업 커밋해줘"
# Claude가 자동으로 git commit 수행

# 2. 본인 브랜치에 push
git push origin feature/본인브랜치

# 3. GitHub에서 Pull Request 생성
# - Base: develop
# - Compare: feature/본인브랜치
# - 리뷰어: 팀원 2명 지정
```

### 📝 커밋 메시지 규칙

Claude Code에게 커밋 요청 시 아래 형식을 따르도록 안내:

```
[영역] 작업 내용

- 상세 설명 1
- 상세 설명 2

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**예시**:
```
[Frontend] 로그인 화면 UI 구현

- MaterialButton 커스텀 위젯 추가
- 이메일/비밀번호 입력 폼 구현
- 폼 유효성 검사 로직 추가

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**영역 태그**:
- `[Frontend]`: Flutter UI/로직
- `[Backend-API]`: Flask API 엔드포인트
- `[Backend-AI]`: Gemini AI 관련
- `[Backend-Crawler]`: 크롤링 관련
- `[Docs]`: 문서 수정
- `[Fix]`: 버그 수정
- `[Refactor]`: 리팩토링

---

## 4. Pull Request (PR) 프로세스

### PR 생성 체크리스트
- [ ] 본인 feature 브랜치에서 develop으로 PR
- [ ] 제목: `[영역] 간단한 설명`
- [ ] 설명: Claude가 생성한 변경사항 요약 포함
- [ ] 리뷰어 2명 지정
- [ ] 충돌(Conflict) 해결 완료

### PR 리뷰 규칙
- **리뷰 기한**: PR 생성 후 24시간 이내
- **승인 조건**: 최소 1명의 Approve 필요
- **머지 담당**: PR 작성자가 직접 merge

### PR 템플릿
```markdown
## 작업 내용
- [ ] 기능 1
- [ ] 기능 2

## 변경된 파일
- `file1.dart`
- `file2.py`

## 테스트 완료
- [ ] 로컬 테스트 완료
- [ ] Backend 서버 정상 작동 확인
- [ ] Frontend 빌드 성공

## 스크린샷 (UI 작업 시)
(이미지 첨부)

## 리뷰 요청 사항
특별히 확인해주셨으면 하는 부분을 적어주세요.
```

---

## 5. 공유 파일 수정 규칙 (충돌 방지)

### ⚠️ 절대 수정 금지 파일
- `.env`: 각자 로컬에서만 관리
- `backend/app.py`: 구조 변경 시 **반드시 팀 회의 후**
- `frontend/pubspec.yaml`: 패키지 추가 시 **Slack 공지 필수**

### 🔄 공유 파일 수정 절차

#### `docs/api_spec.md` (API 명세서)
1. **백엔드 개발자가 수정**하면 즉시 커밋 + PR
2. **프론트엔드 개발자가 확인** 후 Approve
3. 변경사항을 Slack에 공지

#### `backend/requirements.txt`
```bash
# 백엔드 개발자 2명이 동시에 패키지 추가할 경우
# 1. 백엔드 개발자 1
pip install new-package
pip freeze > requirements.txt
git add requirements.txt
git commit -m "[Backend] new-package 의존성 추가"
git push

# 2. 백엔드 개발자 2 (충돌 방지)
git pull origin develop
pip install -r requirements.txt  # 새 패키지 설치
# 그 다음 본인 패키지 추가
```

#### `frontend/lib/services/api_service.dart`
- **프론트엔드 개발자가 주 관리자**
- 백엔드 팀이 API 추가 시 → 프론트 개발자에게 Slack DM
- 프론트 개발자가 직접 수정 후 커밋

---

## 6. Claude Code 활용 팁

### Claude에게 명확히 지시하기

#### ✅ 좋은 예시
```
"develop 브랜치의 최신 변경사항을 내 브랜치에 merge해줘.
충돌이 있으면 알려줘."
```

```
"backend/routes/auth.py에 회원가입 API를 추가해줘.
docs/api_spec.md의 명세를 참고해서 만들어줘."
```

#### ❌ 나쁜 예시
```
"코드 좀 고쳐줘"  # 너무 추상적
"API 만들어줘"    # 어떤 API인지 불명확
```

### Claude에게 협업 컨텍스트 제공
```
"나는 백엔드 개발자고, 지금 Gemini AI 통합 작업 중이야.
backend/ai/ 폴더 안에서만 작업해줘.
팀원이 작업 중인 backend/routes/는 건드리지 마."
```

### Claude로 PR 생성하기
```
"현재 작업 내용으로 PR 만들어줘.
제목은 '[Backend-AI] Gemini API 통합'으로 하고,
변경된 파일 목록이랑 테스트 완료 체크리스트 포함해줘."
```

---

## 7. 충돌 해결 가이드

### 상황 1: Merge Conflict 발생
```bash
# Claude에게 요청
"git merge develop 했더니 충돌이 났어.
backend/app.py 파일에서 충돌 해결해줘."
```

Claude가 충돌을 자동으로 해결하거나, 수동 해결이 필요한 부분을 알려줍니다.

### 상황 2: 같은 파일을 동시에 수정
- **예방**: 작업 시작 전 Slack에 "XX 파일 수정 시작합니다" 공지
- **해결**: 나중에 작업한 사람이 충돌 해결 책임

---

## 8. 커뮤니케이션 규칙

### Slack/Discord 채널 구성
- `#general`: 일반 공지
- `#frontend`: 프론트엔드 논의
- `#backend`: 백엔드 논의
- `#pr-reviews`: PR 리뷰 요청 알림
- `#daily-standup`: 데일리 스탠드업

### 데일리 스탠드업 (오전 10시)
각자 Slack에 작성:
```
[이름]
- 어제 한 일: 로그인 UI 완성
- 오늘 할 일: 회원가입 API 연동
- 블로커: API 명세 확인 필요 (@백엔드개발자1)
```

### 즉시 공지가 필요한 경우
- `pubspec.yaml` 또는 `requirements.txt` 수정
- `app.py` 구조 변경
- API 명세(`api_spec.md`) 변경
- `.env.example` 새 환경 변수 추가

---

## 9. 주간 통합 일정

### 월요일 오전
- **주간 계획 회의** (30분)
- 각자 이번 주 작업 목표 공유
- develop 브랜치 최신화

### 수요일 오후
- **중간 점검** (15분)
- 진행 상황 공유
- 블로커 해결

### 금요일 오후
- **코드 리뷰 + 통합 테스트** (1시간)
- 모든 feature 브랜치를 develop에 merge
- 통합 테스트 실행
- 다음 주 계획 논의

---

## 10. Claude Code 협업 시나리오 예시

### 시나리오: 백엔드 개발자 1이 새 API 추가

1. **API 명세 업데이트**
```
Claude에게: "docs/api_spec.md에 POST /notices API 명세 추가해줘"
```

2. **Slack 공지**
```
@channel
POST /notices API 명세 추가했습니다.
PR: https://github.com/xxx/pull/123
프론트 개발자님 확인 부탁드려요!
```

3. **프론트엔드 개발자 확인**
```
git pull origin develop
Claude에게: "docs/api_spec.md 확인해줘. POST /notices API가 뭐야?"
```

4. **프론트엔드 API 통신 구현**
```
Claude에게: "api_spec.md의 POST /notices 명세 보고
lib/services/api_service.dart에 createNotice() 함수 추가해줘"
```

---

## 11. 트러블슈팅

### 문제: "git push가 안돼요"
```bash
# 해결
git pull origin feature/본인브랜치 --rebase
git push origin feature/본인브랜치
```

### 문제: "Claude가 다른 팀원 파일을 수정했어요"
```bash
# 해결
git checkout -- 팀원파일.py  # 변경 취소
# Claude에게: "backend/crawler/ 폴더에서만 작업해줘"
```

### 문제: "develop merge 후 테스트가 실패해요"
```bash
# 해결
1. Slack에 공지
2. git revert로 마지막 커밋 취소
3. 로컬에서 수정 후 다시 PR
```

---

## 12. 베스트 프랙티스 요약

### ✅ DO
- 작업 시작 전 항상 `git pull origin develop`
- 커밋 전 Claude에게 "변경된 파일 목록 보여줘" 확인
- 공유 파일 수정 시 Slack 공지
- PR은 작은 단위로 자주 올리기
- Claude에게 구체적이고 명확한 지시

### ❌ DON'T
- main 브랜치에 직접 push 금지
- 팀원 작업 폴더 무단 수정 금지
- 거대한 PR (파일 10개 이상) 지양
- .env 파일 커밋 절대 금지
- Claude에게 "알아서 해줘" 같은 모호한 지시

---

## 13. 체크리스트

### 작업 시작 전
- [ ] develop 브랜치 최신화
- [ ] 본인 feature 브랜치 생성/체크아웃
- [ ] Slack에 오늘 작업 내용 공지

### 커밋 전
- [ ] Claude에게 변경 파일 목록 확인 요청
- [ ] .env 파일이 포함되지 않았는지 확인
- [ ] 팀원 작업 영역을 침범하지 않았는지 확인

### PR 생성 전
- [ ] 로컬 테스트 완료
- [ ] develop 최신 변경사항 merge 완료
- [ ] 충돌 해결 완료
- [ ] 커밋 메시지 규칙 준수

### PR 리뷰 후
- [ ] 리뷰어 피드백 반영
- [ ] Approve 받음
- [ ] develop에 merge
- [ ] feature 브랜치 삭제 (선택)

---

**이 가이드는 팀의 협업 상황에 따라 계속 업데이트됩니다.**
**질문이나 개선 사항은 Slack #general 채널에 공유해주세요!**
