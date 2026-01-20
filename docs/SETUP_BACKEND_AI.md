# Backend AI/크롤링 개발자 - Claude 설정 가이드

> **Backend AI/크롤링 개발자를 위한 완전 자동화 가이드**
> 아래 내용을 그대로 Claude Code에 복사-붙여넣기만 하세요!

---

## 1단계: 최초 설정 (딱 1번만)

Claude Code를 열고 아래 전체를 복사해서 붙여넣으세요:

```
안녕 Claude! AIX-Boost 프로젝트 시작할게.

=== 프로젝트 정보 ===
저장소: https://github.com/wkdaud9/AIX-BOOST-PROJECT.git
내 역할: Backend AI/크롤링 개발자 (Gemini + Crawler)
작업 위치: C:\Users\[본인계정]\Desktop\aix-boost-project

=== 나의 작업 영역 ===
✅ 작업 가능:
  - backend/ai/ (Gemini AI 통합)
  - backend/crawler/ (공지사항 크롤링)
  - backend/requirements.txt (패키지 추가 시)

❌ 절대 수정 금지:
  - backend/routes/ (API 담당 동료 작업 중)
  - backend/services/ (API 담당 동료 작업 중)
  - frontend/ (프론트 개발자 작업 중)

=== Git 설정 ===
- 내 브랜치 접두사: feature/backend-ai-
- 예시: feature/backend-ai-gemini, feature/backend-ai-crawler
- 커밋 메시지 형식: [Backend-AI] 작업 내용

=== 요청사항 ===
1. 위 저장소를 C:\Users\[본인계정]\Desktop\aix-boost-project 경로에 클론해줘
2. develop 브랜치로 이동해줘
3. backend/.env.example을 backend/.env로 복사해줘
4. Python 가상환경 생성해줘 (backend/venv)
5. requirements.txt로 패키지 설치해줘
6. backend/ai/, backend/crawler/ 폴더 구조 확인해줘
7. Git 설정 확인해줘

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
SECRET_KEY=dev-secret-key
PORT=5000

# Supabase 설정 (팀 리더에게 받기)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# ⭐ Gemini AI 설정 (직접 발급)
GEMINI_API_KEY=AIzaSy...
# 발급: https://ai.google.dev/

# 크롤링 설정
CRAWLER_INTERVAL=3600  # 1시간마다 크롤링
```

**Gemini API 키 발급 방법**:
1. https://ai.google.dev/ 접속
2. Google 계정으로 로그인
3. "Get API Key" 클릭
4. 복사해서 .env에 붙여넣기

---

## 3단계: 매일 사용하는 명령어

### 🌅 아침 - 작업 시작
```
🌅 오늘 작업 시작!

오늘 할 일: [Gemini AI로 공지사항 분석 기능 만들기]

1. develop 최신 코드 pull
2. feature/backend-ai-gemini 브랜치 생성 (또는 이동)
3. develop 변경사항 merge
```

### 💻 작업 중 - AI 기능 개발
```
Gemini AI로 공지사항 요약 기능 만들어줘.

파일: backend/ai/gemini_service.py

함수명: analyze_notice(notice_text: str) -> dict
기능:
- 공지사항 텍스트를 Gemini로 분석
- 중요도 점수 (0-1)
- 3줄 요약
- 중요 날짜 추출
- 행동 필요 여부

Gemini 1.5 Flash 모델 사용하고,
.env의 GEMINI_API_KEY 사용해줘.
```

### 🕷️ 크롤링 개발
```
군산대 공지사항 크롤러 만들어줘.

파일: backend/crawler/kunsan_crawler.py

기능:
- 군산대 공지사항 페이지 크롤링
- 제목, 내용, 날짜, URL 추출
- Supabase notices 테이블에 저장
- 중복 체크

BeautifulSoup4 사용하고,
docs/database_schema.sql 참고해줘.
```

### 🧪 테스트
```
방금 만든 AI 분석 함수 테스트해줘.

샘플 공지사항으로 테스트하고
결과가 제대로 나오는지 확인해줘.
```

### 📦 패키지 추가
```
google-generativeai 패키지 설치하고
requirements.txt에 추가해줘.

추가했으면 Slack에 공지 메시지 작성해줘:
"requirements.txt 업데이트 했습니다. pip install -r requirements.txt 해주세요."
```

### 🌙 저녁 - 작업 완료
```
🌙 오늘 작업 끝!

1. 변경 파일 확인
2. requirements.txt 변경됐으면 Slack 공지 필요
3. 커밋 메시지: [Backend-AI] Gemini 공지사항 분석 기능 구현
4. Push
```

### 🚀 기능 완성 - PR 생성
```
🚀 Gemini 분석 기능 완성!

PR 생성해줘:
- 제목: [Backend-AI] Gemini 공지사항 분석 기능
- Base: develop
- 테스트 완료 체크
```

---

## 4단계: 협업 시나리오

### API 동료에게 함수 제공
```
backend/ai/gemini_service.py에 만든
analyze_notice() 함수를 API 동료가 사용할 수 있게
주석과 타입 힌트 추가해줘.

완료되면 Slack에 공지:
"Gemini 분석 함수 완성했습니다.
backend/ai/gemini_service.py의 analyze_notice() 사용하시면 됩니다."
```

### 스케줄러 설정
```
크롤러를 1시간마다 자동 실행하는
스케줄러 만들어줘.

파일: backend/crawler/scheduler.py
APScheduler 사용해서 구현해줘.
```

---

## 자주 쓰는 명령어

```
# Gemini API 테스트
Gemini API 연결 테스트해줘

# 크롤러 실행
크롤러 실행해서 공지사항 1개만 가져와봐

# 로그 확인
크롤링 로그 보여줘

# 데이터베이스 확인
Supabase notices 테이블 최근 10개 보여줘

# 패키지 설치
selenium 설치하고 requirements.txt 업데이트
```

---

## 🆘 문제 해결

### Gemini API 오류
```
Gemini API 호출이 실패했어.
에러 메시지: [에러 내용]

원인 확인하고 해결 방법 알려줘.
```

### 크롤링 실패
```
크롤링이 안 돼.
웹사이트 구조가 바뀐 것 같아.

현재 크롤링 코드 확인하고 수정해줘.
```

### Rate Limit 초과
```
Gemini API rate limit 걸렸어.
요청 속도 제한 로직 추가해줘.
```

---

## 📋 Gemini 프롬프트 템플릿

AI 분석용 프롬프트 예시:

```python
prompt = """
다음 공지사항을 분석해주세요:

{notice_text}

다음 정보를 JSON으로 반환해주세요:
1. summary: 3줄 요약
2. relevance_score: 중요도 (0-1)
3. dates: 추출된 날짜 리스트
4. action_required: 행동 필요 여부 (true/false)
5. keywords: 주요 키워드 리스트
"""
```

---

## 🎯 개발 팁

### Gemini 모델 선택
- **Gemini 1.5 Flash**: 빠르고 저렴 (일반 분석)
- **Gemini 1.5 Pro**: 정확하고 강력 (복잡한 분석)

### 크롤링 주의사항
- `time.sleep()` 추가해서 서버 부하 방지
- User-Agent 헤더 설정
- 에러 발생 시 재시도 로직

### 비용 절감
- Gemini Flash 우선 사용
- 캐싱 활용 (같은 공지 재분석 방지)
- 배치 처리로 API 호출 최소화

---

## ✅ 완료!

매일:
1. "작업 시작" → AI/크롤링 개발 → "작업 끝"
2. requirements.txt 변경 시 Slack 공지
3. 완성된 함수는 주석 달아서 동료가 사용하기 쉽게

Claude가 모든 Git 작업을 자동으로 처리합니다! 🎉
