# 🕷️ 크롤러 모듈 설명서 (초등학생도 이해하는 버전!)

## 📚 목차
1. [크롤러가 뭔가요?](#크롤러가-뭔가요)
2. [전체 구조 한눈에 보기](#전체-구조-한눈에-보기)
3. [파일별 상세 설명](#파일별-상세-설명)
4. [실제 사용 예시](#실제-사용-예시)
5. [테스트 방법](#테스트-방법)

---

## 🤔 크롤러가 뭔가요?

### 쉽게 설명하면?

**크롤러**는 인터넷 웹사이트를 자동으로 방문해서 필요한 정보를 가져오는 프로그램입니다.

**비유:**
- 학교 게시판 = 군산대학교 홈페이지 공지사항
- 우리 = 공지를 확인하고 싶은 학생
- 크롤러 = 매일 게시판을 확인하고 중요한 공지를 사진 찍어서 가져다주는 로봇

### 이 프로젝트의 크롤러는?

우리의 크롤러는 **군산대학교 홈페이지**의 3개 게시판을 자동으로 확인합니다:

1. **공지사항** - 학교 전체 공지
2. **학사/장학** - 수강신청, 장학금 등
3. **모집공고** - 채용, 인턴십, 공모전 등

```
군산대 홈페이지
    ↓
[크롤러가 방문]
    ↓
최신 공지사항 수집
    ↓
데이터베이스에 저장
    ↓
학생들에게 알림 전송
```

---

## 🎯 전체 구조 한눈에 보기

### 폴더 구조

```
backend/crawler/
├── __init__.py              # 🚪 모듈 입구 (다른 곳에서 쓸 수 있게)
├── base_crawler.py          # 🏗️ 기본 크롤러 (모든 크롤러의 부모)
├── notice_crawler.py        # 📢 공지사항 크롤러
├── scholarship_crawler.py   # 🎓 학사/장학 크롤러
├── recruitment_crawler.py   # 💼 모집공고 크롤러
├── crawler_manager.py       # 👔 크롤러 통합 관리자
└── README.md               # 📖 이 설명서!
```

### 각 파일의 역할

| 파일 | 역할 | 비유 |
|------|------|------|
| `__init__.py` | 모듈 입구 | 가게 간판 |
| `base_crawler.py` | 기본 기능 제공 | 자동차의 기본 설계도 |
| `notice_crawler.py` | 공지사항 수집 | 공지사항 게시판 담당 직원 |
| `scholarship_crawler.py` | 학사/장학 수집 | 학사 게시판 담당 직원 |
| `recruitment_crawler.py` | 모집공고 수집 | 취업 게시판 담당 직원 |
| `crawler_manager.py` | 전체 관리 | 3명의 직원을 관리하는 팀장 |

---

## 📁 파일별 상세 설명

### 1️⃣ `base_crawler.py` - 기본 크롤러

#### 🤔 이 파일은 뭐 하는 파일인가요?

모든 크롤러가 공통으로 사용하는 **기본 기능**을 제공합니다.

**비유:**
- 이 클래스 = 모든 차(자동차)의 기본 설계도
- 자식 크롤러들 = 이 설계도로 만든 승용차, 트럭, 버스

#### 🏗️ 주요 기능

```python
class BaseCrawler:
    def fetch_page(url):
        # 🌐 웹 페이지 HTML 가져오기
        # "이 주소로 가서 페이지 내용 가져와!"

    def parse_date(date_str):
        # 📅 날짜 문자열을 표준 형식으로 변환
        # "2024-01-22" → datetime 객체

    def clean_text(text):
        # 🧹 텍스트 정리 (공백, 줄바꿈 제거)
        # "  안녕하세요\n\n  " → "안녕하세요"

    def extract_attachment_urls(soup):
        # 📎 첨부파일 링크 찾기
        # PDF, HWP 파일 등의 링크 추출
```

#### 💡 주요 함수 설명

##### `fetch_page(url)` - 웹 페이지 가져오기

**하는 일:**
1. 지정한 URL로 방문
2. HTML 코드를 다운로드
3. BeautifulSoup으로 파싱 (분석하기 쉽게 만들기)

**예시:**
```python
crawler = BaseCrawler("https://kunsan.ac.kr", "테스트")
soup = crawler.fetch_page("https://kunsan.ac.kr/notice")
제목 = soup.find("h1").text  # 페이지의 제목 찾기
```

##### `parse_date(date_str)` - 날짜 변환

**하는 일:**
다양한 형식의 날짜를 표준 datetime 객체로 변환합니다.

**지원하는 형식:**
- `2024-01-22` (대시)
- `2024.01.22` (점)
- `2024/01/22` (슬래시)
- `24-01-22` (짧은 년도)

**예시:**
```python
날짜1 = crawler.parse_date("2024-01-22")
날짜2 = crawler.parse_date("2024.01.22")
# 둘 다 같은 datetime 객체로 변환됨!
```

##### `clean_text(text)` - 텍스트 정리

**하는 일:**
지저분한 텍스트를 깔끔하게 정리합니다.

**예시:**
```python
지저분함 = "  안녕하세요\n\n\n    반갑습니다  "
깔끔함 = crawler.clean_text(지저분함)
print(깔끔함)
# "안녕하세요\n반갑습니다"
```

---

### 2️⃣ `notice_crawler.py` - 공지사항 크롤러

#### 🤔 이 파일은 뭐 하는 파일인가요?

**군산대학교 공지사항 게시판**을 자동으로 크롤링합니다.

**비유:**
- 게시판 = 공지가 붙어있는 큰 게시판
- 이 크롤러 = 게시판을 보고 공지를 사진 찍어서 저장하는 학생

#### 🏗️ 작동 방식

```
1. 공지사항 목록 페이지 접속
   ↓
2. 각 공지의 제목, 날짜, 링크 추출
   ↓
3. 각 공지의 상세 페이지 방문
   ↓
4. 본문 내용 가져오기
   ↓
5. 데이터 정리해서 반환
```

#### 💡 주요 함수

##### `crawl(max_pages)` - 크롤링 실행

**하는 일:**
1. 목록 페이지에서 공지 목록 가져오기
2. 각 공지의 상세 페이지 방문
3. 제목, 내용, 작성일 등 추출

**예시:**
```python
crawler = NoticeCrawler()
공지들 = crawler.crawl(max_pages=3)  # 3페이지 크롤링

for 공지 in 공지들:
    print(f"제목: {공지['title']}")
    print(f"작성일: {공지['published_at']}")
```

#### 📊 수집하는 정보

| 항목 | 설명 | 예시 |
|------|------|------|
| `title` | 공지사항 제목 | "2024학년도 1학기 수강신청 안내" |
| `content` | 본문 내용 | "수강신청 일정을 다음과 같이..." |
| `published_at` | 작성일 | 2024-01-22 |
| `source_url` | 원본 링크 | https://kunsan.ac.kr/... |
| `category` | 카테고리 | "공지사항" |
| `author` | 작성자 (선택) | "학생지원처" |
| `views` | 조회수 (선택) | 123 |
| `attachments` | 첨부파일 (선택) | [링크1, 링크2, ...] |

---

### 3️⃣ `scholarship_crawler.py` - 학사/장학 크롤러

#### 🤔 이 파일은 뭐 하는 파일인가요?

**군산대학교 학사/장학 게시판**을 크롤링합니다.

**수집하는 정보:**
- 수강신청 안내
- 장학금 공지
- 학사 일정
- 등록금 납부 안내

#### 🔧 차이점

`NoticeCrawler`를 상속받아 같은 방식으로 작동하지만, **게시판 ID와 카테고리**만 다릅니다.

**예시:**
```python
crawler = ScholarshipCrawler()
학사공지들 = crawler.crawl(max_pages=2)

for 공지 in 학사공지들:
    if "장학금" in 공지['title']:
        print(f"💰 {공지['title']}")
```

---

### 4️⃣ `recruitment_crawler.py` - 모집공고 크롤러

#### 🤔 이 파일은 뭐 하는 파일인가요?

**군산대학교 모집공고 게시판**을 크롤링합니다.

**수집하는 정보:**
- 채용 공고
- 인턴십 모집
- 공모전 안내
- 대외활동 모집

**예시:**
```python
crawler = RecruitmentCrawler()
채용공고들 = crawler.crawl(max_pages=2)

for 공고 in 채용공고들:
    if "채용" in 공고['title']:
        print(f"💼 {공고['title']}")
```

---

### 5️⃣ `crawler_manager.py` - 크롤러 통합 관리자

#### 🤔 이 파일은 뭐 하는 파일인가요?

**3개의 크롤러를 한번에 관리**하는 매니저입니다.

**비유:**
- 3개 크롤러 = 3명의 일꾼 (각자 다른 게시판 담당)
- 이 매니저 = 3명을 지휘하는 팀장

#### 🏗️ 주요 기능

```python
class CrawlerManager:
    def crawl_all(max_pages):
        # 🌍 모든 게시판 한번에 크롤링
        # 공지사항 + 학사/장학 + 모집공고

    def crawl_category(category, max_pages):
        # 🎯 특정 카테고리만 크롤링
        # 예: "공지사항"만 크롤링

    def get_statistics(results):
        # 📊 통계 계산
        # 카테고리별 개수, 최신 업데이트 날짜 등

    def filter_by_date(results, start_date, end_date):
        # 📅 날짜 범위로 필터링
        # 최근 7일 공지만 보기

    def search_by_keyword(results, keyword):
        # 🔍 키워드 검색
        # "수강신청" 키워드가 있는 공지만 찾기
```

---

## 🎮 실제 사용 예시

### 시나리오 1: 공지사항만 크롤링

```python
from backend.crawler import NoticeCrawler

# 1. 크롤러 생성
crawler = NoticeCrawler()

# 2. 3페이지 크롤링
notices = crawler.crawl(max_pages=3)

# 3. 결과 확인
print(f"총 {len(notices)}개 공지 수집")

for notice in notices[:5]:  # 처음 5개만
    print(f"\n제목: {notice['title']}")
    print(f"날짜: {notice['published_at']}")
    print(f"링크: {notice['source_url']}")
```

### 시나리오 2: 모든 게시판 한번에 크롤링

```python
from backend.crawler import CrawlerManager

# 1. 매니저 생성
manager = CrawlerManager()

# 2. 모든 게시판 크롤링 (각 2페이지씩)
all_results = manager.crawl_all(max_pages=2)

# 3. 카테고리별 결과
print(f"공지사항: {len(all_results['공지사항'])}개")
print(f"학사/장학: {len(all_results['학사/장학'])}개")
print(f"모집공고: {len(all_results['모집공고'])}개")
```

### 시나리오 3: 특정 키워드로 검색

```python
from backend.crawler import CrawlerManager

manager = CrawlerManager()

# 1. 전체 크롤링
all_results = manager.crawl_all(max_pages=2)

# 2. "수강신청" 키워드 검색
수강신청_공지 = manager.search_by_keyword(all_results, "수강신청")

# 3. 결과 출력
for category, notices in 수강신청_공지.items():
    print(f"\n[{category}]")
    for notice in notices:
        print(f"  - {notice['title']}")
```

### 시나리오 4: 최근 7일 공지만 보기

```python
from backend.crawler import CrawlerManager
from datetime import datetime, timedelta

manager = CrawlerManager()

# 1. 전체 크롤링
all_results = manager.crawl_all(max_pages=3)

# 2. 7일 전 날짜 계산
일주일전 = datetime.now() - timedelta(days=7)

# 3. 최근 7일 공지만 필터링
최신공지 = manager.filter_by_date(all_results, start_date=일주일전)

# 4. 통계
stats = manager.get_statistics(최신공지)
print(f"최근 7일 공지: {stats['total_count']}개")
```

### 시나리오 5: AI와 연동해서 분석

```python
from backend.crawler import CrawlerManager
from backend.ai import NoticeAnalyzer

# 1. 크롤링
manager = CrawlerManager()
results = manager.crawl_all(max_pages=1)

# 2. AI 분석기 준비
analyzer = NoticeAnalyzer()

# 3. 공지사항 분석
for notice in results['공지사항'][:3]:
    분석결과 = analyzer.analyze_notice(notice)

    print(f"\n{'='*60}")
    print(f"📌 원본 제목: {notice['title']}")
    print(f"📝 AI 요약: {분석결과['summary']}")
    print(f"⭐ 중요도: {분석결과['importance']}점")
    print(f"🏷️ 카테고리: {분석결과['category']}")
    print(f"🔑 키워드: {', '.join(분석결과['keywords'])}")
```

---

## 🧪 테스트 방법

### 방법 1: 개별 크롤러 테스트

각 크롤러 파일을 직접 실행하면 테스트가 됩니다!

```bash
cd backend

# 공지사항 크롤러 테스트
python -m crawler.notice_crawler

# 학사/장학 크롤러 테스트
python -m crawler.scholarship_crawler

# 모집공고 크롤러 테스트
python -m crawler.recruitment_crawler
```

### 방법 2: 크롤러 매니저 테스트

```bash
# 통합 매니저 테스트
python -m crawler.crawler_manager
```

### 방법 3: Python 스크립트로 테스트

```python
# test_crawler.py 파일 만들기
from backend.crawler import CrawlerManager

def test_crawling():
    print("🧪 크롤링 테스트 시작\n")

    # 1. 매니저 생성
    manager = CrawlerManager()

    # 2. 공지사항만 테스트
    print("[테스트 1] 공지사항 크롤링")
    notices = manager.crawl_category("공지사항", max_pages=1)
    print(f"✅ {len(notices)}개 수집\n")

    # 3. 전체 크롤링
    print("[테스트 2] 전체 크롤링")
    all_results = manager.crawl_all(max_pages=1)

    # 4. 통계
    stats = manager.get_statistics(all_results)
    print(f"\n📊 통계:")
    print(f"총 {stats['total_count']}개")
    for cat, count in stats['by_category'].items():
        print(f"  - {cat}: {count}개")

    print("\n✅ 테스트 완료!")

if __name__ == "__main__":
    test_crawling()
```

**실행:**
```bash
python test_crawler.py
```

---

## 🔧 트러블슈팅

### Q1: "페이지 요청 실패" 에러가 나요

**원인:** 인터넷 연결 문제 또는 군산대 서버 접속 불가

**해결:**
1. 인터넷 연결 확인
2. 군산대 홈페이지가 정상인지 브라우저로 확인
3. 방화벽이 Python을 차단하고 있는지 확인

### Q2: "공지사항을 찾지 못했습니다"

**원인:** 군산대 홈페이지의 HTML 구조가 변경됨

**해결:**
1. 브라우저로 해당 페이지 접속
2. F12 눌러서 개발자 도구 열기
3. HTML 구조 확인
4. `notice_crawler.py`의 CSS 선택자 수정

### Q3: 크롤링이 너무 느려요

**해결:**
1. `max_pages` 줄이기 (1~2 페이지만)
2. `base_crawler.py`의 `time.sleep(0.5)` 값 줄이기
3. 하지만 너무 빠르면 서버에 부담 → 차단될 수 있음!

### Q4: 날짜 파싱이 실패해요

**원인:** 예상하지 못한 날짜 형식

**해결:**
`base_crawler.py`의 `parse_date()` 함수에 새로운 형식 추가:
```python
date_formats = [
    "%Y-%m-%d",
    "%Y.%m.%d",
    # 여기에 새로운 형식 추가!
    "%Y년 %m월 %d일",  # 예: 2024년 01월 22일
]
```

---

## 📊 데이터 흐름

### 전체 흐름도

```
[군산대 홈페이지]
    ↓
[크롤러가 방문]
    ↓
[HTML 다운로드]
    ↓
[BeautifulSoup 파싱]
    ↓
[필요한 정보 추출]
  • 제목
  • 내용
  • 작성일
  • 링크
    ↓
[데이터 정리]
    ↓
[딕셔너리로 변환]
    ↓
[AI 모듈로 전달] → 분석 & 요약
    ↓
[데이터베이스 저장]
    ↓
[사용자에게 알림]
```

---

## 🎓 핵심 요약

### 파일별 역할 (한 줄 요약)

| 파일 | 역할 | 비유 |
|------|------|------|
| `base_crawler.py` | 기본 기능 제공 | 자동차 설계도 |
| `notice_crawler.py` | 공지사항 수집 | 공지 게시판 직원 |
| `scholarship_crawler.py` | 학사/장학 수집 | 학사 게시판 직원 |
| `recruitment_crawler.py` | 모집공고 수집 | 취업 게시판 직원 |
| `crawler_manager.py` | 전체 관리 | 3명을 관리하는 팀장 |

### 사용 흐름

```python
# 1단계: 크롤러 준비
from backend.crawler import CrawlerManager
manager = CrawlerManager()

# 2단계: 크롤링 실행
results = manager.crawl_all(max_pages=2)

# 3단계: 결과 활용
# - AI 분석
# - 데이터베이스 저장
# - 사용자 알림
```

---

## 📚 추가 리소스

- [기본 크롤러 코드](base_crawler.py) - 공통 기능
- [공지사항 크롤러 코드](notice_crawler.py) - 공지사항 전용
- [크롤러 매니저 코드](crawler_manager.py) - 통합 관리
- [AI 모듈 연동](../ai/README.md) - AI 분석과 연동

---

## 🚀 다음 단계

크롤링한 데이터를 활용하는 방법:

1. **AI 분석** - `backend/ai/` 모듈 사용
2. **데이터베이스 저장** - Supabase에 저장
3. **API 제공** - Flask 라우트 생성
4. **푸시 알림** - 사용자에게 맞춤 알림

---

**만든 사람:** Backend 개발자 2 (AI/크롤링 담당)
**마지막 수정:** 2024-01-22
**버전:** 1.0.0
