# 🤖 AI 모듈 설명서 (초등학생도 이해하는 버전!)

## 📚 목차
1. [전체 구조 한눈에 보기](#전체-구조-한눈에-보기)
2. [파일별 상세 설명](#파일별-상세-설명)
3. [실제 사용 예시](#실제-사용-예시)
4. [테스트 방법](#테스트-방법)

---

## 🎯 전체 구조 한눈에 보기

### 이 폴더는 뭐 하는 곳인가요?

이 `backend/ai/` 폴더는 **"똑똑한 AI가 공지사항을 읽고 정리해주는 곳"**입니다!

```
학교 공지사항 (긴 글)
    ↓
[AI 모듈이 분석]
    ↓
요약 + 중요도 + 일정 + 키워드 (정리된 정보)
```

### 폴더 구조

```
backend/ai/
├── __init__.py              # 🚪 입구 (다른 곳에서 이 폴더를 쓸 수 있게 해줌)
├── gemini_client.py         # 🤖 Gemini AI와 대화하는 번역기
├── analyzer.py              # 📊 공지사항을 분석하는 분석가
├── schedule_extractor.py    # 📅 날짜와 일정을 찾는 탐정
└── README.md               # 📖 이 설명서!
```

### 각 파일이 하는 일 (한 줄 요약)

| 파일 | 한 줄 설명 | 비유 |
|------|-----------|------|
| `__init__.py` | 다른 곳에서 이 모듈을 쉽게 쓸 수 있게 해줌 | 가게 입구 간판 |
| `gemini_client.py` | Gemini AI와 대화하는 번역기 | 한국어↔영어 통역사 |
| `analyzer.py` | 공지사항을 요약하고 분석하는 분석가 | 책 읽고 독후감 쓰는 친구 |
| `schedule_extractor.py` | 날짜와 일정을 찾아내는 탐정 | 달력에 동그라미 치는 학생 |

---

## 📁 파일별 상세 설명

### 1️⃣ `__init__.py` - 모듈 입구

#### 🤔 이 파일은 뭐 하는 파일인가요?

다른 파일에서 이 `ai` 폴더를 쉽게 쓸 수 있게 해주는 **"간판"** 같은 역할입니다.

#### 📖 예시로 이해하기

**간판이 없을 때:**
```python
# 매번 길고 복잡하게 써야 함
from backend.ai.gemini_client import GeminiClient
from backend.ai.analyzer import NoticeAnalyzer
from backend.ai.schedule_extractor import ScheduleExtractor
```

**간판이 있을 때 (우리 방식):**
```python
# 간단하게 쓸 수 있음!
from backend.ai import GeminiClient, NoticeAnalyzer, ScheduleExtractor
```

#### 💡 코드 설명

```python
# 이 모듈에서 중요한 것들을 여기 모아둠
from .gemini_client import GeminiClient
from .analyzer import NoticeAnalyzer
from .schedule_extractor import ScheduleExtractor

# 외부에서 쓸 수 있는 것들 목록
__all__ = [
    'GeminiClient',          # AI 클라이언트
    'NoticeAnalyzer',        # 분석기
    'ScheduleExtractor'      # 일정 추출기
]
```

---

### 2️⃣ `gemini_client.py` - Gemini AI 번역기

#### 🤔 이 파일은 뭐 하는 파일인가요?

구글의 **Gemini AI**와 대화할 수 있게 해주는 **통역사** 같은 역할입니다.

**비유:**
- 우리 = 한국어만 하는 학생
- Gemini AI = 영어만 하는 똑똑한 선생님
- 이 파일 = 한↔영 통역해주는 통역사

#### 🏗️ 주요 기능

```python
class GeminiClient:
    def __init__(self):
        # 🔑 API 키로 Gemini에 연결
        # "안녕하세요, 저 통역사입니다" 하고 인사

    def generate_text(self, prompt):
        # 💬 Gemini에게 질문하고 답변 받기
        # 우리: "이거 요약해줘"
        # Gemini: "네, 요약하면..."

    def analyze_with_prompt(self, content, analysis_type):
        # 🎯 특정 목적으로 분석하기
        # "요약해줘" / "일정 찾아줘" / "중요도 매겨줘"
```

#### 💡 실제 사용 예시

**예시 1: 간단한 질문**
```python
# 1. 클라이언트 만들기
client = GeminiClient()

# 2. 질문하기
답변 = client.generate_text("안녕하세요! 간단히 인사해주세요.")
print(답변)
# 출력: "안녕하세요! 무엇을 도와드릴까요?"
```

**예시 2: 공지사항 요약**
```python
공지 = "2024년 1학기 수강신청은 2월 1일부터 시작됩니다. 학년별로..."

결과 = client.analyze_with_prompt(공지, "summary")
print(결과["result"])
# 출력: "1학기 수강신청 2월 1일 시작, 학년별 일정 확인 필요"
```

#### 📊 주요 함수 설명

##### `__init__(api_key)` - 초기화

```python
client = GeminiClient()  # .env에서 자동으로 API 키 가져옴
```

**하는 일:**
1. `.env` 파일에서 API 키 읽기
2. Gemini에 연결
3. 사용할 모델 준비 (gemini-1.5-flash)

**결과:**
```
✅ Gemini AI 클라이언트 초기화 완료 (모델: gemini-1.5-flash)
```

##### `generate_text(prompt, max_tokens, temperature)` - 텍스트 생성

```python
답변 = client.generate_text(
    prompt="이 글 요약해줘: ...",
    max_tokens=2048,      # 최대 답변 길이
    temperature=0.7       # 창의성 (0~1)
)
```

**매개변수 설명:**
- `prompt`: AI에게 할 질문
- `max_tokens`: 최대 답변 길이 (숫자가 클수록 긴 답변)
- `temperature`: 창의성 수준
  - `0.0` → 항상 똑같은 답변 (로봇)
  - `0.5` → 적당히 일관적
  - `1.0` → 매번 다른 창의적 답변

##### `analyze_with_prompt(content, analysis_type)` - 목적별 분석

```python
결과 = client.analyze_with_prompt(
    content="공지사항 내용...",
    analysis_type="summary"  # 또는 "schedule", "category", "importance"
)
```

**분석 종류:**
- `"summary"`: 요약 (긴 글 → 짧게)
- `"schedule"`: 일정 추출 (날짜 찾기)
- `"category"`: 카테고리 분류 (학사/장학/취업 등)
- `"importance"`: 중요도 판단 (1~5점)

---

### 3️⃣ `analyzer.py` - 공지사항 분석가

#### 🤔 이 파일은 뭐 하는 파일인가요?

크롤링한 공지사항을 AI로 분석해서 **유용한 정보를 추출**하는 분석가입니다.

**비유:**
- 공지사항 = 학교 가정통신문 (길고 복잡함)
- 이 분석기 = 통신문 읽고 중요한 부분만 형광펜 칠해주는 똑똑한 친구

#### 🏗️ 주요 기능

```python
class NoticeAnalyzer:
    def analyze_notice(self, notice_data):
        # 📊 공지사항 종합 분석 (요약+카테고리+중요도+키워드)

    def extract_summary(self, text):
        # 📝 요약만 추출

    def categorize(self, text):
        # 🏷️ 카테고리만 분류

    def calculate_importance(self, text):
        # ⭐ 중요도만 계산

    def extract_keywords(self, text):
        # 🔑 핵심 키워드만 추출
```

#### 💡 실제 사용 예시

**예시 1: 공지사항 종합 분석**

```python
# 1. 분석기 만들기
analyzer = NoticeAnalyzer()

# 2. 공지사항 데이터 준비
공지 = {
    "title": "수강신청 안내",
    "content": "2024년 1학기 수강신청은 2월 1일부터...",
    "url": "https://kunsan.ac.kr/notice/123",
    "date": "2024-01-20"
}

# 3. 분석 실행
결과 = analyzer.analyze_notice(공지)

# 4. 결과 확인
print(f"요약: {결과['summary']}")
print(f"카테고리: {결과['category']}")
print(f"중요도: {결과['importance']}점")
print(f"키워드: {', '.join(결과['keywords'])}")
```

**출력 예시:**
```
요약: 1학기 수강신청 2월 1일 시작, 학년별 일정 확인 필요
카테고리: 학사
중요도: 5점
키워드: 수강신청, 1학기, 2월 1일, 학년별, 일정
```

**예시 2: 여러 공지사항 한번에 분석**

```python
공지들 = [
    {"title": "수강신청", "content": "..."},
    {"title": "장학금 안내", "content": "..."},
    {"title": "취업박람회", "content": "..."}
]

결과들 = analyzer.batch_analyze(공지들)

for 결과 in 결과들:
    print(f"{결과['original_title']}: {결과['summary']}")
```

#### 📊 주요 함수 설명

##### `analyze_notice(notice_data)` - 종합 분석

**입력:**
```python
{
    "title": "공지사항 제목",
    "content": "공지사항 내용",
    "url": "링크",
    "date": "2024-01-22"
}
```

**출력:**
```python
{
    "original_title": "공지사항 제목",
    "summary": "3줄 요약",
    "category": "학사",
    "importance": 5,
    "keywords": ["키워드1", "키워드2", ...],
    "analyzed": True
}
```

##### `categorize(text)` - 카테고리 분류

**지원 카테고리:**
1. **학사** - 수강신청, 학적, 성적 등
2. **장학** - 장학금, 학자금 대출 등
3. **취업** - 채용, 인턴십, 취업특강 등
4. **행사** - 축제, 세미나, 공모전 등
5. **시설** - 도서관, 기숙사 등
6. **기타** - 위에 해당 안 되는 것

##### `calculate_importance(text)` - 중요도 평가

**점수 기준:**
- **1점** - 별로 안 중요함 (선택 사항)
- **2점** - 알아두면 좋음
- **3점** - 해당되면 확인 필요
- **4점** - 대부분 학생이 확인해야 함
- **5점** - 전체 학생 필독! (수강신청, 등록금 등)

---

### 4️⃣ `schedule_extractor.py` - 일정 탐정

#### 🤔 이 파일은 뭐 하는 파일인가요?

공지사항에서 **날짜와 시간 정보를 찾아내서** 캘린더에 추가할 수 있게 만드는 탐정입니다.

**비유:**
- 공지사항 = 선생님이 말한 긴 설명
- 이 추출기 = 달력에 동그라미 쳐야 할 날짜만 쏙쏙 골라내는 학생

#### 🏗️ 주요 기능

```python
class ScheduleExtractor:
    def extract_schedules(self, notice_data):
        # 📅 공지사항에서 모든 일정 추출

    def create_calendar_event(self, schedule, notice_data):
        # 📆 캘린더 이벤트 형태로 변환

    def extract_deadlines(self, notice_data):
        # ⏰ 마감일 정보만 추출
```

#### 💡 실제 사용 예시

**예시 1: 일정 추출**

```python
# 1. 추출기 만들기
extractor = ScheduleExtractor()

# 2. 공지사항 준비
공지 = {
    "title": "수강신청 안내",
    "content": """
    수강신청 일정:
    - 4학년: 2024년 2월 1일 10:00 ~ 2월 2일 18:00
    - 3학년: 2024년 2월 2일 10:00 ~ 2월 3일 18:00
    """,
    "url": "https://kunsan.ac.kr/notice/123"
}

# 3. 일정 추출
일정들 = extractor.extract_schedules(공지)

# 4. 결과 확인
for 일정 in 일정들:
    print(f"제목: {일정['title']}")
    print(f"시작: {일정['start']}")
    print(f"종료: {일정['end']}")
    print()
```

**출력 예시:**
```
제목: 4학년 수강신청
시작: 2024-02-01T10:00:00
종료: 2024-02-02T18:00:00

제목: 3학년 수강신청
시작: 2024-02-02T10:00:00
종료: 2024-02-03T18:00:00
```

**예시 2: 마감일만 추출**

```python
공지 = {
    "title": "장학금 신청 안내",
    "content": "신청 마감: 2024년 2월 15일까지"
}

마감일들 = extractor.extract_deadlines(공지)

for 마감 in 마감일들:
    print(f"⏰ {마감['title']}: {마감['start']}")
```

**출력:**
```
⏰ 장학금 신청 마감: 2024-02-15
```

#### 📊 추출되는 일정 형식

```python
{
    # 기본 정보
    "title": "4학년 수강신청",
    "description": "수강신청 안내",
    "location": "군산대학교",

    # 일정 정보
    "start": "2024-02-01T10:00:00",
    "end": "2024-02-02T18:00:00",
    "all_day": False,  # 종일 이벤트 여부

    # 추가 정보
    "category": "학사",
    "source_url": "https://kunsan.ac.kr/notice/123",

    # 알림 설정
    "reminders": [
        {"method": "notification", "minutes": 1440},  # 1일 전
        {"method": "notification", "minutes": 60}      # 1시간 전
    ]
}
```

---

## 🎮 실제 사용 예시

### 시나리오: 공지사항 완전 분석

**상황:** 학교에서 수강신청 공지사항이 올라왔습니다. 이걸 AI로 분석해봅시다!

```python
# 1. 모든 모듈 가져오기
from backend.ai import GeminiClient, NoticeAnalyzer, ScheduleExtractor

# 2. 각 도구 준비
client = GeminiClient()
analyzer = NoticeAnalyzer(gemini_client=client)
extractor = ScheduleExtractor(gemini_client=client)

# 3. 공지사항 데이터
공지 = {
    "title": "[학사공지] 2024학년도 1학기 수강신청 안내",
    "content": """
    수강신청 일정을 다음과 같이 안내합니다.

    1. 수강신청 기간
       - 4학년: 2024년 2월 1일 10:00 ~ 2월 2일 18:00
       - 3학년: 2024년 2월 2일 10:00 ~ 2월 3일 18:00

    2. 주의사항
       - 선수과목 이수 여부 확인 필수
       - 최대 21학점까지 신청 가능

    학생지원처 학사운영팀
    """,
    "url": "https://kunsan.ac.kr/notice/123",
    "date": "2024-01-20"
}

# 4. 분석 실행
print("=" * 50)
print("📊 공지사항 분석 결과")
print("=" * 50)

# (1) 종합 분석
분석결과 = analyzer.analyze_notice(공지)
print(f"\n📝 요약: {분석결과['summary']}")
print(f"🏷️ 카테고리: {분석결과['category']}")
print(f"⭐ 중요도: {분석결과['importance']}점")
print(f"🔑 키워드: {', '.join(분석결과['keywords'])}")

# (2) 일정 추출
일정들 = extractor.extract_schedules(공지)
print(f"\n📅 추출된 일정: {len(일정들)}개")
for i, 일정 in enumerate(일정들, 1):
    print(f"\n[일정 {i}]")
    print(f"  제목: {일정['title']}")
    print(f"  시작: {일정['start']}")
    print(f"  종료: {일정['end']}")

print("\n" + "=" * 50)
```

**출력 결과:**
```
==================================================
📊 공지사항 분석 결과
==================================================

📝 요약: 2024년 1학기 수강신청 학년별 일정 안내. 4학년 2월 1일부터 시작.
🏷️ 카테고리: 학사
⭐ 중요도: 5점
🔑 키워드: 수강신청, 1학기, 학년별, 일정, 선수과목

📅 추출된 일정: 2개

[일정 1]
  제목: 4학년 수강신청
  시작: 2024-02-01T10:00:00
  종료: 2024-02-02T18:00:00

[일정 2]
  제목: 3학년 수강신청
  시작: 2024-02-02T10:00:00
  종료: 2024-02-03T18:00:00

==================================================
```

---

## 🧪 테스트 방법

### 방법 1: 개별 파일 테스트

각 파일에는 테스트 코드가 내장되어 있습니다!

#### Gemini 클라이언트 테스트

```bash
cd backend
python -m ai.gemini_client
```

**결과:**
```
==================================================
🧪 Gemini 클라이언트 테스트 시작
==================================================

[1단계] Gemini 클라이언트 초기화 중...
✅ Gemini AI 클라이언트 초기화 완료

[2단계] 간단한 질문 테스트...
✅ Gemini 응답: 안녕하세요! ...

...
```

#### 분석기 테스트

```bash
python -m ai.analyzer
```

#### 일정 추출기 테스트

```bash
python -m ai.schedule_extractor
```

### 방법 2: 전체 통합 테스트

```python
# test_ai_module.py 파일 만들기
from backend.ai import GeminiClient, NoticeAnalyzer, ScheduleExtractor

def test_all():
    print("🧪 전체 AI 모듈 테스트 시작\n")

    # 테스트 공지사항
    notice = {
        "title": "테스트 공지",
        "content": "2024년 2월 1일 10시부터 수강신청 시작",
        "url": "https://test.com",
        "date": "2024-01-20"
    }

    # 1. Gemini 클라이언트
    print("[1] Gemini 클라이언트 테스트")
    client = GeminiClient()
    response = client.generate_text("안녕하세요!")
    print(f"✅ 응답: {response}\n")

    # 2. 분석기
    print("[2] 분석기 테스트")
    analyzer = NoticeAnalyzer()
    result = analyzer.analyze_notice(notice)
    print(f"✅ 카테고리: {result['category']}")
    print(f"✅ 중요도: {result['importance']}점\n")

    # 3. 일정 추출기
    print("[3] 일정 추출기 테스트")
    extractor = ScheduleExtractor()
    schedules = extractor.extract_schedules(notice)
    print(f"✅ 일정 {len(schedules)}개 추출\n")

    print("🎉 모든 테스트 통과!")

if __name__ == "__main__":
    test_all()
```

**실행:**
```bash
python test_ai_module.py
```

---

## ⚙️ 환경 설정

### 필수: Gemini API 키 설정

**1단계: API 키 발급**
1. [Google AI Studio](https://makersuite.google.com/app/apikey) 접속
2. "Create API Key" 클릭
3. API 키 복사

**2단계: .env 파일에 추가**
```bash
# backend/.env 파일 열기
cd backend
nano .env  # 또는 메모장으로 열기
```

**추가할 내용:**
```
GEMINI_API_KEY=여기에_복사한_API_키_붙여넣기
```

**3단계: 테스트**
```bash
python -m ai.gemini_client
```

---

## 🎓 요약 정리

### 각 파일의 역할 정리

| 파일 | 역할 | 언제 사용? |
|------|------|-----------|
| `gemini_client.py` | AI와 대화 | 모든 AI 기능의 기본 |
| `analyzer.py` | 공지 분석 | 공지를 요약/분류하고 싶을 때 |
| `schedule_extractor.py` | 일정 추출 | 캘린더에 추가할 일정 찾을 때 |

### 사용 흐름

```
1. 공지사항 크롤링 (crawler 모듈)
        ↓
2. AI 분석 (analyzer.py)
   - 요약
   - 카테고리 분류
   - 중요도 평가
   - 키워드 추출
        ↓
3. 일정 추출 (schedule_extractor.py)
   - 날짜/시간 찾기
   - 캘린더 이벤트 생성
        ↓
4. 데이터베이스 저장
        ↓
5. 사용자에게 맞춤 알림 전송
```

---

## 🆘 자주 묻는 질문 (FAQ)

### Q1: "API 키가 없어요"라는 에러가 나요

**답변:**
`backend/.env` 파일에 `GEMINI_API_KEY`를 추가했는지 확인하세요.

```bash
# .env 파일 확인
cat backend/.env | grep GEMINI_API_KEY
```

### Q2: "JSON 파싱 실패" 에러가 나요

**답변:**
Gemini AI가 JSON 형식이 아닌 답변을 보냈을 수 있습니다.
`temperature`를 낮춰보세요 (0.1~0.3 권장).

### Q3: 분석이 너무 느려요

**답변:**
모델을 `gemini-1.5-flash`로 변경하세요 (기본값).
더 빠른 처리가 필요하면:
```python
client = GeminiClient()
client.switch_model("gemini-1.5-flash")
```

### Q4: 여러 공지를 한번에 분석하고 싶어요

**답변:**
`batch_analyze` 사용:
```python
analyzer = NoticeAnalyzer()
결과들 = analyzer.batch_analyze([공지1, 공지2, 공지3])
```

---

## 📞 도움이 필요하면?

- **팀 협업**: Slack #backend 채널에 질문
- **버그 발견**: GitHub Issues에 등록
- **코드 개선**: PR 올려주세요!

---

**만든 사람:** Backend 개발자 2 (AI/크롤링 담당)
**마지막 수정:** 2024-01-22
**버전:** 1.0.0
