# -*- coding: utf-8 -*-
"""
Gemini AI 클라이언트 모듈

이 파일이 하는 일:
이 파일은 구글의 Gemini AI와 대화할 수 있게 해주는 "번역기" 같은 역할을 합니다.
우리가 공지사항 텍스트를 주면, Gemini에게 물어보고 답변을 받아오는 일을 합니다.

비유:
- 우리 = 한국어만 하는 학생
- Gemini AI = 영어만 하는 똑똑한 선생님
- 이 파일 = 한국어를 영어로, 영어를 한국어로 통역해주는 통역사
"""

import google.generativeai as genai
import os
from typing import Optional, Dict, Any
from dotenv import load_dotenv

# 환경 변수 로드 (.env 파일에서 API 키 가져오기)
load_dotenv()


class GeminiClient:
    """
    Gemini AI와 통신하는 클라이언트 클래스

    목적:
    구글 Gemini AI에게 질문을 보내고 답변을 받아오는 역할을 합니다.

    구조:
    1. __init__: Gemini AI와 연결 준비 (전화기 켜기)
    2. generate_text: 텍스트를 보내고 답변 받기 (문자 보내기)
    3. analyze_with_prompt: 특정 질문으로 분석하기 (특정 주제로 질문하기)
    """

    def __init__(self, api_key: Optional[str] = None):
        """
        Gemini 클라이언트를 초기화합니다.

        매개변수:
        - api_key: Gemini API 키 (없으면 .env 파일에서 자동으로 가져옴)

        예시:
        client = GeminiClient()  # .env에서 자동으로 키 가져옴
        또는
        client = GeminiClient(api_key="내_API_키")  # 직접 키 전달

        하는 일:
        1. API 키를 가져옵니다 (직접 주거나, .env에서 자동으로)
        2. Gemini에 연결합니다
        3. 사용할 AI 모델을 준비합니다 (gemini-1.5-pro 또는 gemini-1.5-flash)
        """
        # API 키 설정: 파라미터로 받았으면 그걸 쓰고, 아니면 .env에서 가져옴
        self.api_key = api_key or os.getenv('GEMINI_API_KEY')

        # API 키가 없으면 에러 발생
        if not self.api_key:
            raise ValueError(
                "[오류] Gemini API 키가 없습니다! "
                ".env 파일에 GEMINI_API_KEY를 설정하거나 "
                "GeminiClient(api_key='your-key')로 직접 전달하세요."
            )

        # Gemini AI 설정 (API 키로 인증)
        genai.configure(api_key=self.api_key)

        # 사용할 AI 모델 설정
        # gemini-2.5-pro: 최신 고성능 모델
        # gemini-2.0-flash: 빠르고 효율적, 간단한 작업용 (권장)
        self.model_name = "models/gemini-2.0-flash"  # 2024년 최신 모델
        self.model = genai.GenerativeModel(self.model_name)

        print(f"[완료] Gemini AI 클라이언트 초기화 완료 (모델: {self.model_name})")

    def generate_text(
        self,
        prompt: str,
        max_tokens: int = 2048,
        temperature: float = 0.7
    ) -> str:
        """
        Gemini AI에게 텍스트를 보내고 답변을 받습니다.

        매개변수:
        - prompt: Gemini에게 보낼 질문이나 요청 (예: "이 공지사항 요약해줘")
        - max_tokens: 최대 답변 길이 (숫자가 클수록 긴 답변, 기본값: 2048)
        - temperature: 창의성 수준 (0~1, 높을수록 창의적/랜덤, 기본값: 0.7)

        하는 일:
        1. 우리가 준 질문(prompt)을 Gemini에게 보냅니다
        2. Gemini가 생각해서 답변을 보냅니다
        3. 그 답변을 텍스트로 돌려줍니다

        예시:
        답변 = client.generate_text("안녕하세요! 오늘 날씨 어때?")
        print(답변)  # Gemini의 답변이 출력됨

        Temperature란?
        - 0.0: 항상 똑같은 답변 (로봇처럼)
        - 0.5: 적당히 일관적
        - 1.0: 매번 다른 창의적 답변
        """
        try:
            # Gemini에게 질문 보내기
            response = self.model.generate_content(
                prompt,
                generation_config={
                    "max_output_tokens": max_tokens,  # 최대 답변 길이
                    "temperature": temperature,  # 창의성 수준
                },
                request_options={"timeout": 30}  # 30초 타임아웃
            )

            # 답변 텍스트 추출
            return response.text

        except Exception as e:
            # 에러 발생 시 어떤 에러인지 알려줌
            raise Exception(f"[오류] Gemini AI 호출 실패: {str(e)}")

    def analyze_with_prompt(
        self,
        content: str,
        analysis_type: str = "summary"
    ) -> Dict[str, Any]:
        """
        특정 목적에 맞게 공지사항을 분석합니다.

        매개변수:
        - content: 분석할 공지사항 내용
        - analysis_type: 분석 종류
          * "summary": 요약 (긴 글을 짧게)
          * "schedule": 일정 추출 (날짜, 시간 찾기)
          * "category": 카테고리 분류 (학사/장학/취업 등)
          * "importance": 중요도 판단 (별 1개~5개)

        하는 일:
        1. 분석 종류에 맞는 질문을 만듭니다
        2. Gemini에게 그 질문과 함께 공지사항을 보냅니다
        3. Gemini의 답변을 정리해서 돌려줍니다

        예시:
        result = client.analyze_with_prompt(
            content="2024년 1학기 수강신청은 2월 1일부터입니다.",
            analysis_type="schedule"
        )
        print(result)
        # {"analysis_type": "schedule", "result": "수강신청: 2024-02-01"}
        """

        # 분석 종류별 프롬프트(질문) 템플릿
        prompts = {
            "summary": f"""
                다음 공지사항을 3줄 이내로 요약해주세요.
                중요한 내용만 간단명료하게 정리해주세요.

                공지사항:
                {content}

                요약:
            """,

            "schedule": f"""
                다음 공지사항에서 날짜와 일정 정보를 추출해주세요.
                형식: YYYY-MM-DD HH:MM 또는 YYYY-MM-DD
                날짜가 없으면 "일정 없음"이라고 답해주세요.

                공지사항:
                {content}

                일정:
            """,

            "category": f"""
                다음 공지사항을 카테고리로 분류해주세요.
                카테고리 종류: 학사, 장학, 취업, 행사, 교육, 공모전
                카테고리 이름만 답해주세요.

                공지사항:
                {content}

                카테고리:
            """,

            "importance": f"""
                다음 공지사항의 중요도를 1~5점으로 평가해주세요.
                1점: 별로 안 중요함
                5점: 매우 중요함 (필독)

                점수만 숫자로 답해주세요.

                공지사항:
                {content}

                중요도 점수:
            """
        }

        # 선택한 분석 종류의 프롬프트 가져오기
        if analysis_type not in prompts:
            raise ValueError(
                f"[오류] 지원하지 않는 분석 타입: {analysis_type}\n"
                f"사용 가능한 타입: {', '.join(prompts.keys())}"
            )

        prompt = prompts[analysis_type]

        # Gemini에게 분석 요청
        result = self.generate_text(prompt, temperature=0.3)  # 일관된 답변을 위해 낮은 temperature

        # 결과를 사전 형태로 정리
        return {
            "analysis_type": analysis_type,
            "result": result.strip(),  # 앞뒤 공백 제거
            "original_content": content
        }

    def switch_model(self, model_name: str):
        """
        사용할 Gemini 모델을 변경합니다.

        매개변수:
        - model_name: 변경할 모델 이름
          * "gemini-1.5-pro": 똑똑하지만 느림
          * "gemini-1.5-flash": 빠르지만 덜 똑똑함

        예시:
        client.switch_model("gemini-1.5-pro")  # 복잡한 분석할 때
        client.switch_model("gemini-1.5-flash")  # 빠른 처리 필요할 때
        """
        self.model_name = model_name
        self.model = genai.GenerativeModel(self.model_name)
        print(f"[완료] 모델 변경됨: {self.model_name}")


# 테스트 코드 (이 파일을 직접 실행했을 때만 작동)
if __name__ == "__main__":
    print("=" * 50)
    print("[테스트] Gemini 클라이언트 테스트 시작")
    print("=" * 50)

    try:
        # 1. 클라이언트 생성
        print("\n[1단계] Gemini 클라이언트 초기화 중...")
        client = GeminiClient()

        # 2. 간단한 텍스트 생성 테스트
        print("\n[2단계] 간단한 질문 테스트...")
        response = client.generate_text("안녕하세요! 간단히 인사해주세요.")
        print(f"[완료] Gemini 응답: {response}")

        # 3. 공지사항 분석 테스트
        print("\n[3단계] 공지사항 분석 테스트...")
        test_notice = """
        [학사공지] 2024학년도 1학기 수강신청 안내

        수강신청 일정:
        - 4학년: 2024년 2월 1일 10:00 ~ 2월 2일 18:00
        - 3학년: 2024년 2월 2일 10:00 ~ 2월 3일 18:00
        - 2학년: 2024년 2월 3일 10:00 ~ 2월 4일 18:00
        - 1학년: 2024년 2월 4일 10:00 ~ 2월 5일 18:00

        학생지원처 학사운영팀
        """

        # 요약 분석
        print("\n  [진행] 요약 분석 중...")
        summary_result = client.analyze_with_prompt(test_notice, "summary")
        print(f"  [완료] 요약: {summary_result['result']}")

        # 일정 추출
        print("\n  [진행] 일정 추출 중...")
        schedule_result = client.analyze_with_prompt(test_notice, "schedule")
        print(f"  [완료] 일정: {schedule_result['result']}")

        # 카테고리 분류
        print("\n  [진행] 카테고리 분류 중...")
        category_result = client.analyze_with_prompt(test_notice, "category")
        print(f"  [완료] 카테고리: {category_result['result']}")

        # 중요도 판단
        print("\n  [진행] 중요도 판단 중...")
        importance_result = client.analyze_with_prompt(test_notice, "importance")
        print(f"  [완료] 중요도: {importance_result['result']}")

        print("\n" + "=" * 50)
        print("[완료] 모든 테스트 완료!")
        print("=" * 50)

    except Exception as e:
        print(f"\n[오류] 테스트 실패: {str(e)}")
