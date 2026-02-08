# -*- coding: utf-8 -*-
"""
기본 크롤러 클래스

🤔 이 파일이 하는 일:
모든 크롤러가 공통으로 사용하는 기본 기능을 제공합니다.
공지사항, 학사장학, 모집공고 크롤러가 이 클래스를 상속받아 사용합니다.

📚 비유:
- 이 클래스 = 모든 차(자동차)의 기본 설계도
- 자식 크롤러들 = 이 설계도를 바탕으로 만든 승용차, 트럭, 버스
"""

import requests
from bs4 import BeautifulSoup
from typing import List, Dict, Any, Optional
from datetime import datetime
import time
import re
import random


class BaseCrawler:
    """
    모든 크롤러의 부모 클래스

    🎯 목적:
    웹 페이지에서 데이터를 가져오는 기본 기능을 제공합니다.

    🏗️ 주요 기능:
    1. fetch_page: 웹 페이지 HTML 가져오기
    2. parse_date: 날짜 문자열을 표준 형식으로 변환
    3. clean_text: 텍스트 정리 (공백, 특수문자 제거)
    4. crawl: 크롤링 실행 (자식 클래스에서 구현)
    """

    def __init__(self, base_url: str, category: str):
        """
        크롤러를 초기화합니다.

        🔧 매개변수:
        - base_url: 크롤링할 웹사이트 주소
        - category: 카테고리 이름 (예: "공지사항", "학사장학")

        💡 예시:
        crawler = BaseCrawler(
            base_url="https://www.kunsan.ac.kr/board/list.kunsan",
            category="공지사항"
        )
        """
        self.base_url = base_url
        self.category = category
        self.session = requests.Session()

        # HTTP 요청 헤더 (사람처럼 보이게 하기)
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
        })

        print(f"[OK] {category} 크롤러 초기화 완료")

    def fetch_page(
        self,
        url: str,
        params: Optional[Dict] = None,
        max_retries: int = 3,
        delay_range: tuple = (1.0, 2.0)
    ) -> Optional[BeautifulSoup]:
        """
        웹 페이지의 HTML을 가져옵니다. (재시도 및 백오프 로직 포함)

        🔧 매개변수:
        - url: 가져올 페이지 주소
        - params: URL 파라미터 (딕셔너리)
        - max_retries: 최대 재시도 횟수 (기본값: 3)
        - delay_range: 요청 간 딜레이 범위 (초 단위, 기본값: 1~2초)

        🎯 하는 일:
        1. requests로 웹 페이지 요청
        2. HTML을 BeautifulSoup으로 파싱
        3. 실패 시 exponential backoff로 재시도
        4. 파싱된 객체 반환

        💡 예시:
        soup = crawler.fetch_page("https://example.com")
        제목 = soup.find("h1").text
        """
        for attempt in range(1, max_retries + 1):
            try:
                if attempt == 1:
                    print(f"[페이지] 페이지 요청 중: {url}")
                else:
                    print(f"[재시도 {attempt}/{max_retries}] {url}")

                # 웹 페이지 요청
                response = self.session.get(url, params=params, timeout=10)
                response.raise_for_status()  # 에러 확인

                # 인코딩 설정 (한글 깨짐 방지)
                response.encoding = 'utf-8'

                # HTML 파싱
                soup = BeautifulSoup(response.text, 'html.parser')

                # 서버 부담 최소화: 1~2초 랜덤 대기
                delay = random.uniform(*delay_range)
                time.sleep(delay)

                return soup

            except requests.exceptions.Timeout:
                print(f"[타임아웃] {url}")
                if attempt < max_retries:
                    # Exponential backoff (2^attempt 초)
                    backoff_time = 2 ** attempt
                    print(f"  → {backoff_time}초 후 재시도...")
                    time.sleep(backoff_time)
                else:
                    return None

            except requests.exceptions.RequestException as e:
                print(f"[ERROR] 페이지 요청 실패: {str(e)}")
                if attempt < max_retries:
                    # Exponential backoff
                    backoff_time = 2 ** attempt
                    print(f"  → {backoff_time}초 후 재시도...")
                    time.sleep(backoff_time)
                else:
                    return None

        return None

    def parse_date(self, date_str: str) -> Optional[datetime]:
        """
        날짜 문자열을 datetime 객체로 변환합니다.

        🔧 매개변수:
        - date_str: 날짜 문자열 (예: "2024-01-22", "2024.01.22")

        🎯 하는 일:
        다양한 형식의 날짜를 표준 datetime으로 변환합니다.

        💡 예시:
        날짜1 = crawler.parse_date("2024-01-22")
        날짜2 = crawler.parse_date("2024.01.22")
        날짜3 = crawler.parse_date("24-01-22")
        # 모두 같은 datetime 객체로 변환됨
        """
        if not date_str:
            return None

        # 공백 제거
        date_str = date_str.strip()

        # 시도할 날짜 형식들
        date_formats = [
            "%Y-%m-%d",           # 2024-01-22
            "%Y.%m.%d",           # 2024.01.22
            "%Y/%m/%d",           # 2024/01/22
            "%y-%m-%d",           # 24-01-22
            "%y.%m.%d",           # 24.01.22
            "%Y-%m-%d %H:%M:%S",  # 2024-01-22 14:30:00
            "%Y.%m.%d %H:%M",     # 2024.01.22 14:30
        ]

        for fmt in date_formats:
            try:
                return datetime.strptime(date_str, fmt)
            except ValueError:
                continue

        print(f"[WARNING] 날짜 파싱 실패: {date_str}")
        return None

    def clean_text(self, text: str) -> str:
        """
        텍스트를 정리합니다 (공백, 특수문자 제거).

        🔧 매개변수:
        - text: 정리할 텍스트

        🎯 하는 일:
        1. 앞뒤 공백 제거
        2. 여러 줄바꿈을 하나로
        3. 여러 공백을 하나로

        💡 예시:
        지저분한_텍스트 = "  안녕하세요\n\n\n    반갑습니다  "
        깔끔한_텍스트 = crawler.clean_text(지저분한_텍스트)
        print(깔끔한_텍스트)
        # "안녕하세요\n반갑습니다"
        """
        if not text:
            return ""

        # 앞뒤 공백 제거
        text = text.strip()

        # 여러 줄바꿈을 하나로
        text = re.sub(r'\n\s*\n', '\n', text)

        # 여러 공백을 하나로
        text = re.sub(r' +', ' ', text)

        return text

    def extract_attachment_urls(self, soup: BeautifulSoup) -> List[str]:
        """
        첨부파일 URL을 추출합니다.

        🔧 매개변수:
        - soup: BeautifulSoup 객체

        🎯 하는 일:
        페이지에서 첨부파일 다운로드 링크를 찾아 리스트로 반환합니다.

        💡 예시:
        첨부파일들 = crawler.extract_attachment_urls(soup)
        print(첨부파일들)
        # ["https://example.com/file1.pdf", "https://example.com/file2.hwp"]
        """
        attachments = []

        # 일반적인 첨부파일 링크 찾기
        for link in soup.find_all('a', href=True):
            href = link['href']

            # 파일 확장자 확인
            file_extensions = ['.pdf', '.hwp', '.doc', '.docx', '.xls', '.xlsx', '.zip']
            if any(href.lower().endswith(ext) for ext in file_extensions):
                # 상대 경로면 절대 경로로 변환
                if not href.startswith('http'):
                    href = requests.compat.urljoin(self.base_url, href)
                attachments.append(href)

        return attachments

    def crawl(self, max_pages: int = 1) -> List[Dict[str, Any]]:
        """
        크롤링을 실행합니다.

        ⚠️ 주의: 이 메서드는 자식 클래스에서 반드시 구현해야 합니다!

        🔧 매개변수:
        - max_pages: 크롤링할 최대 페이지 수

        🎯 반환값:
        크롤링한 데이터 리스트
        [
            {
                "title": "제목",
                "content": "내용",
                "published_at": datetime 객체,
                "source_url": "링크",
                "category": "카테고리"
            },
            ...
        ]
        """
        raise NotImplementedError("자식 클래스에서 crawl() 메서드를 구현해야 합니다!")

    def save_to_dict(
        self,
        title: str,
        content: str,
        published_at: datetime,
        source_url: str,
        **kwargs
    ) -> Dict[str, Any]:
        """
        크롤링한 데이터를 딕셔너리 형태로 저장합니다.

        🔧 매개변수:
        - title: 제목
        - content: 내용
        - published_at: 작성일
        - source_url: 원본 링크
        - **kwargs: 추가 정보 (작성자, 조회수 등)

        🎯 반환값:
        데이터베이스에 저장할 수 있는 형태의 딕셔너리

        💡 예시:
        데이터 = crawler.save_to_dict(
            title="수강신청 안내",
            content="2024년 1학기...",
            published_at=datetime.now(),
            source_url="https://...",
            author="학생지원처"
        )
        """
        return {
            "title": self.clean_text(title),
            "content": self.clean_text(content),
            "source_board": self.category,  # 게시판명 (category는 AI가 판별)
            "published_at": published_at,
            "source_url": source_url,
            **kwargs  # 추가 정보
        }


# 🧪 테스트 코드
if __name__ == "__main__":
    print("=" * 50)
    print("🧪 기본 크롤러 테스트 시작")
    print("=" * 50)

    # 1. 크롤러 생성
    print("\n[1단계] 크롤러 초기화...")
    crawler = BaseCrawler(
        base_url="https://www.kunsan.ac.kr",
        category="테스트"
    )

    # 2. 날짜 파싱 테스트
    print("\n[2단계] 날짜 파싱 테스트...")
    test_dates = [
        "2024-01-22",
        "2024.01.22",
        "24-01-22",
        "2024-01-22 14:30:00"
    ]

    for date_str in test_dates:
        parsed = crawler.parse_date(date_str)
        print(f"  '{date_str}' → {parsed}")

    # 3. 텍스트 정리 테스트
    print("\n[3단계] 텍스트 정리 테스트...")
    dirty_text = "  안녕하세요\n\n\n    반갑습니다  "
    clean = crawler.clean_text(dirty_text)
    print(f"  정리 전: {repr(dirty_text)}")
    print(f"  정리 후: {repr(clean)}")

    # 4. 데이터 저장 테스트
    print("\n[4단계] 데이터 저장 형식 테스트...")
    data = crawler.save_to_dict(
        title="테스트 제목",
        content="테스트 내용입니다.",
        published_at=datetime.now(),
        source_url="https://example.com",
        author="테스터"
    )
    print(f"  저장 데이터:")
    for key, value in data.items():
        print(f"    {key}: {value}")

    print("\n" + "=" * 50)
    print("✅ 기본 크롤러 테스트 완료!")
    print("=" * 50)
