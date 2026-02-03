# -*- coding: utf-8 -*-
"""
공지사항 분석기 모듈

🤔 이 파일이 하는 일:
크롤링한 공지사항을 Gemini AI로 분석해서 유용한 정보를 추출합니다.
예를 들어, 긴 공지사항을 요약하거나, 어떤 카테고리인지 판단하거나,
얼마나 중요한지 점수를 매깁니다.

📚 비유:
- 공지사항 = 학교에서 받은 긴 가정통신문
- 이 분석기 = 가정통신문을 읽고 중요한 부분만 형광펜으로 표시해주는 친구
"""

from typing import Dict, Any, List, Optional
from .gemini_client import GeminiClient
from . import prompts
import json
import time
import re
from datetime import datetime


class NoticeAnalyzer:
    """
    공지사항을 AI로 분석하는 클래스

    🎯 목적:
    Gemini AI를 활용하여 공지사항의 다양한 정보를 자동으로 추출합니다.

    🏗️ 주요 기능:
    1. analyze_notice: 공지사항 종합 분석 (요약, 카테고리, 중요도 한번에)
    2. extract_summary: 요약만 추출
    3. categorize: 카테고리만 판단
    4. calculate_importance: 중요도만 계산
    5. extract_keywords: 핵심 키워드 추출
    """

    # 지원하는 카테고리 목록
    CATEGORIES = [
        "학사",      # 수강신청, 학적, 성적 등
        "장학",      # 장학금, 학자금 대출 등
        "취업",      # 채용, 인턴십, 취업특강 등
        "행사",      # 축제, 세미나, 공모전 등
        "시설",      # 도서관, 기숙사 등
        "기타"       # 위 카테고리에 해당 안 되는 것
    ]

    def __init__(self, gemini_client: Optional[GeminiClient] = None):
        """
        분석기를 초기화합니다.

        🔧 매개변수:
        - gemini_client: Gemini 클라이언트 (없으면 자동 생성)

        💡 예시:
        analyzer = NoticeAnalyzer()  # Gemini 클라이언트 자동 생성
        또는
        client = GeminiClient()
        analyzer = NoticeAnalyzer(gemini_client=client)  # 기존 클라이언트 재사용
        """
        # Gemini 클라이언트 설정 (없으면 새로 만들기)
        self.client = gemini_client or GeminiClient()
        print("✅ 공지사항 분석기 초기화 완료")

    def analyze_notice(self, notice_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        공지사항을 종합적으로 분석합니다.

        🔧 매개변수:
        - notice_data: 공지사항 데이터 (딕셔너리 형태)
          {
              "title": "공지사항 제목",
              "content": "공지사항 내용",
              "url": "공지사항 링크",
              "date": "2024-01-22"
          }

        🎯 하는 일:
        1. 제목과 내용을 합쳐서 전체 텍스트 만들기
        2. Gemini AI로 요약, 카테고리, 중요도, 키워드 분석
        3. 결과를 하나의 딕셔너리로 정리

        💡 예시:
        notice = {
            "title": "수강신청 안내",
            "content": "2024년 1학기 수강신청은 2월 1일부터...",
            "url": "http://example.com",
            "date": "2024-01-20"
        }
        result = analyzer.analyze_notice(notice)
        print(result)
        # {
        #     "summary": "1학기 수강신청 2월 1일 시작",
        #     "category": "학사",
        #     "importance": 5,
        #     "keywords": ["수강신청", "1학기", "2월 1일"],
        #     ...
        # }
        """
        # 제목과 내용 추출
        title = notice_data.get("title", "")
        content = notice_data.get("content", "")

        # 전체 텍스트 만들기
        full_text = f"제목: {title}\n\n내용: {content}"

        print(f"📄 공지사항 분석 시작: {title[:30]}...")

        # 각종 분석 수행
        summary = self.extract_summary(full_text)
        category = self.categorize(full_text)
        importance = self.calculate_importance(full_text)
        keywords = self.extract_keywords(full_text)

        # 결과를 하나로 합치기
        analysis_result = {
            # 원본 데이터
            "original_title": title,
            "original_content": content,
            "url": notice_data.get("url", ""),
            "published_date": notice_data.get("date", ""),

            # 분석 결과
            "summary": summary,
            "category": category,
            "importance": importance,
            "keywords": keywords,

            # 메타 정보
            "analyzed": True,
            "analysis_model": self.client.model_name
        }

        print(f"✅ 분석 완료: {category} / 중요도 {importance}점")
        return analysis_result

    def extract_summary(self, text: str, max_length: int = 100) -> str:
        """
        공지사항을 요약합니다.

        🔧 매개변수:
        - text: 요약할 텍스트
        - max_length: 최대 요약 길이 (글자 수)

        🎯 하는 일:
        긴 공지사항을 짧게 요약해서 핵심만 전달합니다.

        💡 예시:
        긴_공지 = "2024학년도 1학기 수강신청은 2월 1일부터 시작됩니다. 학년별로..."
        요약 = analyzer.extract_summary(긴_공지)
        print(요약)  # "1학기 수강신청 2월 1일 시작, 학년별 일정 확인 필요"
        """
        prompt = f"""
        다음 공지사항을 {max_length}자 이내로 요약해주세요.
        핵심 내용만 간결하게 정리해주세요.

        공지사항:
        {text}

        요약 ({max_length}자 이내):
        """

        summary = self.client.generate_text(prompt, temperature=0.3)
        return summary.strip()

    def categorize(self, text: str) -> str:
        """
        공지사항의 카테고리를 판단합니다.

        🔧 매개변수:
        - text: 분류할 공지사항 텍스트

        🎯 하는 일:
        공지사항이 학사/장학/취업/행사/시설/기타 중 어디에 속하는지 판단합니다.

        💡 예시:
        공지 = "2024년 1학기 수강신청 안내..."
        카테고리 = analyzer.categorize(공지)
        print(카테고리)  # "학사"
        """
        categories_str = ", ".join(self.CATEGORIES)

        prompt = f"""
        다음 공지사항을 아래 카테고리 중 하나로 분류해주세요.
        카테고리: {categories_str}

        카테고리 이름만 정확히 답해주세요. (예: 학사)

        공지사항:
        {text}

        카테고리:
        """

        category = self.client.generate_text(prompt, temperature=0.1)  # 일관성을 위해 낮은 temperature
        category = category.strip()

        # 카테고리 목록에 없으면 "기타"로 처리
        if category not in self.CATEGORIES:
            print(f"⚠️ 알 수 없는 카테고리 '{category}' -> '기타'로 변경")
            category = "기타"

        return category

    def calculate_importance(self, text: str) -> int:
        """
        공지사항의 중요도를 1~5점으로 평가합니다.

        🔧 매개변수:
        - text: 평가할 공지사항 텍스트

        🎯 하는 일:
        공지사항이 얼마나 중요한지 1점(별로 안 중요)부터 5점(매우 중요)까지 점수를 매깁니다.

        📊 점수 기준:
        - 1점: 선택 사항, 관심 있는 사람만 보면 됨
        - 2점: 알아두면 좋음
        - 3점: 해당되면 확인 필요
        - 4점: 대부분 학생이 확인해야 함
        - 5점: 모든 학생 필독 (수강신청, 등록금 납부 등)

        💡 예시:
        공지 = "수강신청 안내"
        점수 = analyzer.calculate_importance(공지)
        print(점수)  # 5
        """
        prompt = f"""
        다음 공지사항의 중요도를 1~5점으로 평가해주세요.

        평가 기준:
        1점: 선택 사항, 관심 있는 사람만
        2점: 알아두면 좋음
        3점: 해당되면 확인 필요
        4점: 대부분 학생 확인 필요
        5점: 전체 학생 필독 (마감일 있음, 의무사항 등)

        숫자만 답해주세요. (예: 4)

        공지사항:
        {text}

        중요도 점수:
        """

        importance_str = self.client.generate_text(prompt, temperature=0.2)

        # 숫자로 변환 시도
        try:
            importance = int(importance_str.strip())
            # 1~5 범위 확인
            if importance < 1 or importance > 5:
                print(f"⚠️ 중요도 범위 초과 ({importance}) -> 3점으로 조정")
                importance = 3
        except ValueError:
            print(f"⚠️ 중요도 파싱 실패 ('{importance_str}') -> 3점으로 설정")
            importance = 3

        return importance

    def extract_keywords(self, text: str, max_keywords: int = 5) -> List[str]:
        """
        공지사항에서 핵심 키워드를 추출합니다.

        🔧 매개변수:
        - text: 키워드를 추출할 텍스트
        - max_keywords: 최대 키워드 개수

        🎯 하는 일:
        공지사항에서 가장 중요한 단어들을 찾아냅니다.

        💡 예시:
        공지 = "2024년 1학기 수강신청은 2월 1일부터 시작됩니다."
        키워드 = analyzer.extract_keywords(공지)
        print(키워드)  # ["수강신청", "1학기", "2월 1일", "2024년"]
        """
        prompt = f"""
        다음 공지사항에서 핵심 키워드를 최대 {max_keywords}개 추출해주세요.
        가장 중요한 단어만 뽑아주세요.

        키워드는 쉼표(,)로 구분해서 나열해주세요.
        예: 수강신청, 1학기, 2월 1일

        공지사항:
        {text}

        핵심 키워드:
        """

        keywords_str = self.client.generate_text(prompt, temperature=0.3)

        # 쉼표로 분리하고 앞뒤 공백 제거
        keywords = [kw.strip() for kw in keywords_str.split(",")]

        # 빈 키워드 제거 및 개수 제한
        keywords = [kw for kw in keywords if kw][:max_keywords]

        return keywords

    def batch_analyze(self, notices: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        여러 공지사항을 한번에 분석합니다.

        🔧 매개변수:
        - notices: 공지사항 리스트 (각각 딕셔너리 형태)

        🎯 하는 일:
        여러 개의 공지사항을 순서대로 분석해서 결과를 리스트로 돌려줍니다.

        💡 예시:
        공지들 = [
            {"title": "수강신청", "content": "..."},
            {"title": "장학금", "content": "..."},
        ]
        결과들 = analyzer.batch_analyze(공지들)
        for 결과 in 결과들:
            print(결과["summary"])
        """
        print(f"📚 {len(notices)}개 공지사항 일괄 분석 시작...")

        results = []
        for i, notice in enumerate(notices, 1):
            print(f"\n[{i}/{len(notices)}] 분석 중...")
            try:
                result = self.analyze_notice(notice)
                results.append(result)
            except Exception as e:
                print(f"❌ 분석 실패: {str(e)}")
                # 실패해도 계속 진행
                results.append({
                    **notice,
                    "analyzed": False,
                    "error": str(e)
                })

        print(f"\n✅ 일괄 분석 완료: {len(results)}개 결과")
        return results

    def analyze_notice_comprehensive(self, notice_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        공지사항을 한 번의 AI 호출로 종합 분석합니다. (TODO 요구사항 준수)

        🎯 목적:
        prompts.py의 구조화된 프롬프트를 사용하여 JSON 형식으로 분석 결과를 받습니다.

        🔧 매개변수:
        - notice_data: 공지사항 데이터
          {
              "title": "제목",
              "content": "내용",
              "url": "링크",
              "date": "발표일"
          }

        📊 반환값:
        {
            "summary": "요약",
            "dates": {
                "start_date": "YYYY-MM-DD",
                "end_date": "YYYY-MM-DD",
                "deadline": "YYYY-MM-DD"
            },
            "category": "카테고리",
            "priority": "중요도",
            "analyzed": True,
            "analysis_model": "gemini-1.5-flash"
        }

        💡 특징:
        - 재시도 로직 포함 (최대 3회, exponential backoff)
        - 날짜 형식 정규화 (한글 날짜 → ISO 8601)
        - JSON 응답 파싱 및 검증
        """
        title = notice_data.get("title", "")
        content = notice_data.get("content", "")
        full_text = f"제목: {title}\n\n내용: {content}"

        print(f"📄 [종합 분석] 시작: {title[:30]}...")

        # 프롬프트 생성
        prompt = prompts.get_comprehensive_analysis_prompt(full_text)
        config = prompts.get_prompt_config("comprehensive")

        # 재시도 로직으로 AI 호출
        try:
            response = self._retry_with_backoff(
                lambda: self.client.generate_text(
                    prompt,
                    temperature=config["temperature"],
                    max_tokens=config["max_tokens"]
                ),
                max_retries=3
            )

            # JSON 파싱
            parsed_result = self._parse_json_response(response)

            # 날짜 정규화
            if "dates" in parsed_result and isinstance(parsed_result["dates"], dict):
                parsed_result["dates"] = self._normalize_dates(parsed_result["dates"])

            # 결과 구조화
            analysis_result = {
                # 원본 데이터
                "original_title": title,
                "original_content": content,
                "url": notice_data.get("url", ""),
                "published_date": notice_data.get("date", ""),

                # 분석 결과
                "summary": parsed_result.get("summary", ""),
                "dates": parsed_result.get("dates", {}),
                "category": parsed_result.get("category", "기타"),
                "priority": parsed_result.get("priority", "일반"),

                # 메타 정보
                "analyzed": True,
                "analysis_model": self.client.model_name,
                "analysis_timestamp": datetime.now().isoformat()
            }

            print(f"✅ 분석 완료: {analysis_result['category']} / {analysis_result['priority']}")
            return analysis_result

        except Exception as e:
            print(f"❌ 종합 분석 실패: {str(e)}")
            # 실패 시 기본 구조 반환
            return {
                "original_title": title,
                "original_content": content,
                "url": notice_data.get("url", ""),
                "published_date": notice_data.get("date", ""),
                "summary": "",
                "dates": {},
                "category": "기타",
                "priority": "일반",
                "analyzed": False,
                "error": str(e)
            }

    def _retry_with_backoff(self, func, max_retries: int = 3, initial_delay: float = 1.0):
        """
        재시도 로직을 적용하여 함수를 실행합니다. (Exponential Backoff)

        🎯 목적:
        API 호출 실패 시 자동으로 재시도하여 안정성을 높입니다.

        🔧 매개변수:
        - func: 실행할 함수
        - max_retries: 최대 재시도 횟수 (기본값: 3)
        - initial_delay: 초기 대기 시간 (기본값: 1.0초)

        📊 Exponential Backoff:
        - 1회 실패: 1초 대기 후 재시도
        - 2회 실패: 2초 대기 후 재시도
        - 3회 실패: 4초 대기 후 재시도
        - 3회 모두 실패: 에러 발생

        💡 예시:
        result = self._retry_with_backoff(
            lambda: self.client.generate_text("질문"),
            max_retries=3
        )
        """
        delay = initial_delay
        last_exception = None

        for attempt in range(max_retries):
            try:
                return func()
            except Exception as e:
                last_exception = e
                if attempt < max_retries - 1:
                    print(f"⚠️ 시도 {attempt + 1}/{max_retries} 실패, {delay}초 후 재시도...")
                    time.sleep(delay)
                    delay *= 2  # Exponential backoff
                else:
                    print(f"❌ {max_retries}회 모두 실패")

        # 모든 재시도 실패
        raise last_exception

    def _parse_json_response(self, response: str) -> Dict[str, Any]:
        """
        AI 응답에서 JSON을 추출하고 파싱합니다.

        🎯 목적:
        AI가 반환한 텍스트에서 JSON 부분만 추출하여 파싱합니다.

        🔧 처리 과정:
        1. ```json ... ``` 코드 블록 제거
        2. 앞뒤 공백 제거
        3. JSON 파싱
        4. 유효성 검증

        💡 예시:
        response = "```json\n{\"summary\": \"요약\"}\n```"
        parsed = self._parse_json_response(response)
        print(parsed)  # {"summary": "요약"}
        """
        # JSON 코드 블록 제거
        response = response.strip()
        if response.startswith("```json"):
            response = response[7:]
        if response.startswith("```"):
            response = response[3:]
        if response.endswith("```"):
            response = response[:-3]
        response = response.strip()

        try:
            parsed = json.loads(response)
            return parsed
        except json.JSONDecodeError as e:
            print(f"❌ JSON 파싱 실패: {str(e)}")
            print(f"응답 내용: {response[:200]}...")
            raise ValueError(f"JSON 파싱 실패: {str(e)}")

    def _normalize_dates(self, dates: Dict[str, Any]) -> Dict[str, Optional[str]]:
        """
        날짜 정보를 ISO 8601 형식(YYYY-MM-DD)으로 정규화합니다.

        🎯 목적:
        다양한 형식의 날짜를 표준 형식으로 변환합니다.

        🔧 처리 가능한 형식:
        - YYYY-MM-DD (이미 표준 형식)
        - YYYY/MM/DD
        - YYYY.MM.DD
        - null, None, "null" → None
        - 빈 문자열 → None

        💡 예시:
        dates = {
            "start_date": "2024/02/01",
            "end_date": "2024.02.05",
            "deadline": null
        }
        normalized = self._normalize_dates(dates)
        print(normalized)
        # {
        #     "start_date": "2024-02-01",
        #     "end_date": "2024-02-05",
        #     "deadline": None
        # }
        """
        normalized = {}

        for key, value in dates.items():
            # null 값 처리
            if value is None or value == "null" or value == "":
                normalized[key] = None
                continue

            # 문자열인 경우 정규화
            if isinstance(value, str):
                # 이미 YYYY-MM-DD 형식인지 확인
                if re.match(r'^\d{4}-\d{2}-\d{2}$', value):
                    normalized[key] = value
                # YYYY/MM/DD 형식
                elif re.match(r'^\d{4}/\d{2}/\d{2}$', value):
                    normalized[key] = value.replace("/", "-")
                # YYYY.MM.DD 형식
                elif re.match(r'^\d{4}\.\d{2}\.\d{2}$', value):
                    normalized[key] = value.replace(".", "-")
                else:
                    # 형식이 맞지 않으면 원본 유지
                    print(f"⚠️ 날짜 형식 불일치: {key}={value}")
                    normalized[key] = value
            else:
                normalized[key] = value

        return normalized


# 🧪 테스트 코드
if __name__ == "__main__":
    print("=" * 50)
    print("🧪 공지사항 분석기 테스트 시작")
    print("=" * 50)

    try:
        # 1. 분석기 생성
        print("\n[1단계] 분석기 초기화 중...")
        analyzer = NoticeAnalyzer()

        # 2. 테스트 공지사항
        test_notice = {
            "title": "[학사공지] 2024학년도 1학기 수강신청 안내",
            "content": """
            수강신청 일정을 다음과 같이 안내합니다.

            1. 수강신청 기간
               - 4학년: 2024년 2월 1일 10:00 ~ 2월 2일 18:00
               - 3학년: 2024년 2월 2일 10:00 ~ 2월 3일 18:00
               - 2학년: 2024년 2월 3일 10:00 ~ 2월 4일 18:00
               - 1학년: 2024년 2월 4일 10:00 ~ 2월 5일 18:00

            2. 수강신청 방법
               - 학교 포털 접속 후 '수강신청' 메뉴 이용
               - 최대 21학점까지 신청 가능

            3. 주의사항
               - 선수과목 이수 여부 확인 필수
               - 시간표 중복 확인

            학생지원처 학사운영팀
            """,
            "url": "https://kunsan.ac.kr/notice/123",
            "date": "2024-01-20"
        }

        # 3. 종합 분석
        print("\n[2단계] 공지사항 종합 분석 중...")
        result = analyzer.analyze_notice(test_notice)

        print("\n📊 분석 결과:")
        print(f"  📝 요약: {result['summary']}")
        print(f"  🏷️ 카테고리: {result['category']}")
        print(f"  ⭐ 중요도: {result['importance']}점")
        print(f"  🔑 키워드: {', '.join(result['keywords'])}")

        # 4. 개별 기능 테스트
        print("\n[3단계] 개별 기능 테스트...")

        print("\n  📝 요약만 추출:")
        summary = analyzer.extract_summary(test_notice["content"])
        print(f"  {summary}")

        print("\n  🏷️ 카테고리만 분류:")
        category = analyzer.categorize(test_notice["content"])
        print(f"  {category}")

        print("\n  ⭐ 중요도만 평가:")
        importance = analyzer.calculate_importance(test_notice["content"])
        print(f"  {importance}점")

        print("\n  🔑 키워드만 추출:")
        keywords = analyzer.extract_keywords(test_notice["content"])
        print(f"  {', '.join(keywords)}")

        print("\n" + "=" * 50)
        print("✅ 모든 테스트 완료!")
        print("=" * 50)

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
