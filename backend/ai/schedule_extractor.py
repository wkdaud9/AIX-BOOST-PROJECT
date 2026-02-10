# -*- coding: utf-8 -*-
"""
일정 추출기 모듈

🤔 이 파일이 하는 일:
공지사항에서 날짜와 시간 정보를 찾아내서 캘린더에 추가할 수 있는 형태로 만듭니다.
예를 들어, "수강신청은 2월 1일 10시부터"라는 문장에서
"2024-02-01 10:00"이라는 정확한 일정을 뽑아냅니다.

📚 비유:
- 공지사항 = 선생님이 말한 긴 설명
- 이 추출기 = 달력에 동그라미 쳐야 할 날짜만 쏙쏙 골라내는 학생
"""

from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from .gemini_client import GeminiClient
import json
import re


class ScheduleExtractor:
    """
    공지사항에서 일정 정보를 추출하는 클래스

    🎯 목적:
    Gemini AI를 활용하여 공지사항에서 날짜, 시간, 이벤트 정보를 자동으로 추출합니다.

    🏗️ 주요 기능:
    1. extract_schedules: 공지사항에서 모든 일정 추출
    2. parse_schedule: AI가 추출한 일정을 구조화된 데이터로 변환
    3. create_calendar_event: 캘린더에 추가할 수 있는 형태로 변환
    """

    def __init__(self, gemini_client: Optional[GeminiClient] = None):
        """
        일정 추출기를 초기화합니다.

        🔧 매개변수:
        - gemini_client: Gemini 클라이언트 (없으면 자동 생성)

        💡 예시:
        extractor = ScheduleExtractor()  # 자동 생성
        또는
        client = GeminiClient()
        extractor = ScheduleExtractor(gemini_client=client)  # 재사용
        """
        self.client = gemini_client or GeminiClient()
        print("✅ 일정 추출기 초기화 완료")

    def extract_schedules(self, notice_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        공지사항에서 모든 일정을 추출합니다.

        🔧 매개변수:
        - notice_data: 공지사항 데이터
          {
              "title": "제목",
              "content": "내용",
              "date": "발표일"
          }

        🎯 하는 일:
        1. Gemini AI에게 공지사항을 주고 일정을 찾아달라고 요청
        2. AI가 찾은 일정들을 JSON 형태로 받음
        3. 각 일정을 캘린더 이벤트 형태로 변환

        💡 예시:
        공지 = {
            "title": "수강신청 안내",
            "content": "4학년은 2월 1일 10시부터, 3학년은 2월 2일 10시부터"
        }
        일정들 = extractor.extract_schedules(공지)
        print(일정들)
        # [
        #     {
        #         "event_name": "4학년 수강신청",
        #         "start_date": "2024-02-01",
        #         "start_time": "10:00",
        #         ...
        #     },
        #     {
        #         "event_name": "3학년 수강신청",
        #         "start_date": "2024-02-02",
        #         "start_time": "10:00",
        #         ...
        #     }
        # ]
        """
        title = notice_data.get("title", "")
        content = notice_data.get("content", "")
        full_text = f"제목: {title}\n\n내용: {content}"

        print(f"📅 일정 추출 시작: {title[:30]}...")

        # Gemini에게 일정 추출 요청
        prompt = f"""
        다음 공지사항에서 날짜와 일정 정보를 모두 추출해주세요.

        **중요**: 반드시 아래 JSON 형식으로만 답변해주세요. 다른 설명은 추가하지 마세요.

        형식:
        {{
            "schedules": [
                {{
                    "event_name": "이벤트 이름 (예: 4학년 수강신청)",
                    "start_date": "YYYY-MM-DD 형식 (예: 2024-02-01)",
                    "start_time": "HH:MM 형식 (예: 10:00, 시간 없으면 null)",
                    "end_date": "YYYY-MM-DD 형식 (종료일 없으면 start_date와 동일)",
                    "end_time": "HH:MM 형식 (예: 18:00, 시간 없으면 null)",
                    "description": "간단한 설명"
                }}
            ]
        }}

        공지사항:
        {full_text}

        JSON 응답:
        """

        try:
            # AI로부터 JSON 형태로 일정 정보 받기
            response = self.client.generate_text(prompt, temperature=0.2)

            # JSON 파싱
            # AI가 ```json ... ``` 형태로 감쌀 수 있으므로 제거
            response = response.strip()
            if response.startswith("```json"):
                response = response[7:]
            if response.startswith("```"):
                response = response[3:]
            if response.endswith("```"):
                response = response[:-3]
            response = response.strip()

            # JSON 파싱
            parsed_data = json.loads(response)
            schedules = parsed_data.get("schedules", [])

            if not schedules:
                print("⚠️ 추출된 일정이 없습니다.")
                return []

            # 각 일정을 캘린더 이벤트 형태로 변환
            calendar_events = []
            for schedule in schedules:
                event = self.create_calendar_event(schedule, notice_data)
                calendar_events.append(event)

            print(f"✅ {len(calendar_events)}개 일정 추출 완료")
            return calendar_events

        except json.JSONDecodeError as e:
            print(f"❌ JSON 파싱 실패: {str(e)}")
            print(f"AI 응답: {response[:200]}...")
            return []
        except Exception as e:
            print(f"❌ 일정 추출 실패: {str(e)}")
            return []

    def create_calendar_event(
        self,
        schedule: Dict[str, Any],
        notice_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        추출한 일정을 캘린더 이벤트 형태로 변환합니다.

        🔧 매개변수:
        - schedule: AI가 추출한 일정 정보
        - notice_data: 원본 공지사항 데이터

        🎯 하는 일:
        Google Calendar, Apple Calendar 등에서 사용할 수 있는
        표준 형식으로 일정을 변환합니다.

        💡 예시:
        schedule = {
            "event_name": "수강신청",
            "start_date": "2024-02-01",
            "start_time": "10:00",
            ...
        }
        event = extractor.create_calendar_event(schedule, 공지데이터)
        print(event)
        # {
        #     "title": "수강신청",
        #     "start": "2024-02-01T10:00:00",
        #     "end": "2024-02-01T18:00:00",
        #     "all_day": False,
        #     ...
        # }
        """
        # 기본 정보 추출
        event_name = schedule.get("event_name", "알림")
        start_date = schedule.get("start_date", "")
        start_time = schedule.get("start_time")
        end_date = schedule.get("end_date", start_date)
        end_time = schedule.get("end_time")
        description = schedule.get("description", "")

        # 종일 이벤트 여부 판단 (시간 정보가 없으면 종일)
        all_day = (start_time is None or start_time == "null")

        # 날짜/시간 합치기
        if all_day:
            # 종일 이벤트
            start_datetime = start_date
            end_datetime = end_date or start_date
        else:
            # 시간이 있는 이벤트
            start_datetime = f"{start_date}T{start_time}:00"

            # 종료 시간이 없으면 시작 시간 + 1시간으로 설정
            if not end_time or end_time == "null":
                # 시작 시간에서 1시간 뒤
                try:
                    start_dt = datetime.fromisoformat(start_datetime)
                    end_dt = start_dt + timedelta(hours=1)
                    end_datetime = end_dt.isoformat()
                except:
                    end_datetime = start_datetime
            else:
                end_datetime = f"{end_date}T{end_time}:00"

        # 캘린더 이벤트 객체 생성
        calendar_event = {
            # 기본 정보
            "title": event_name,
            "description": description or notice_data.get("title", ""),
            "location": "군산대학교",

            # 일정 정보
            "start": start_datetime,
            "end": end_datetime,
            "all_day": all_day,

            # 메타 정보
            "source_url": notice_data.get("url", ""),
            "source_title": notice_data.get("title", ""),
            "category": self._guess_category(event_name),

            # 알림 설정 (기본값)
            "reminders": self._create_default_reminders(all_day)
        }

        return calendar_event

    def _guess_category(self, event_name: str) -> str:
        """
        이벤트 이름으로부터 카테고리를 추측합니다.

        🎯 하는 일:
        이벤트 이름에 특정 키워드가 있으면 그에 맞는 카테고리를 반환합니다.
        """
        event_lower = event_name.lower()

        # 카테고리별 키워드
        category_keywords = {
            "학사": ["수강", "학기", "성적", "학점", "졸업", "휴학", "복학", "학적"],
            "장학": ["장학", "학자금", "등록금"],
            "취업": ["채용", "인턴", "취업", "구직", "면접", "취업박람회"],
            "행사": ["축제", "입학식", "졸업식", "오리엔테이션", "OT", "행사"],
            "교육": ["특강", "교육", "진로", "워크숍", "세미나", "강좌", "프로그램"],
            "공모전": ["공모전", "대회", "경진대회", "콘테스트", "챌린지"],
        }

        for category, keywords in category_keywords.items():
            for keyword in keywords:
                if keyword in event_name:
                    return category

        return "학사"

    def _create_default_reminders(self, all_day: bool) -> List[Dict[str, Any]]:
        """
        기본 알림 설정을 생성합니다.

        🎯 하는 일:
        종일 이벤트와 시간 이벤트에 맞는 기본 알림을 설정합니다.
        """
        if all_day:
            # 종일 이벤트: 당일 오전 9시
            return [
                {"method": "notification", "minutes": 0}  # 당일 알림
            ]
        else:
            # 시간 이벤트: 1일 전, 1시간 전
            return [
                {"method": "notification", "minutes": 1440},  # 1일 전
                {"method": "notification", "minutes": 60}     # 1시간 전
            ]

    def extract_deadlines(self, notice_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        공지사항에서 마감일 정보만 추출합니다.

        🔧 매개변수:
        - notice_data: 공지사항 데이터

        🎯 하는 일:
        전체 일정 중에서 "마감일", "신청 마감", "접수 마감" 등
        중요한 데드라인만 골라냅니다.

        💡 예시:
        공지 = {"title": "장학금 신청", "content": "신청 마감: 2월 15일"}
        마감일들 = extractor.extract_deadlines(공지)
        print(마감일들)
        # [{"title": "장학금 신청 마감", "date": "2024-02-15", ...}]
        """
        # 전체 일정 추출
        all_schedules = self.extract_schedules(notice_data)

        # 마감일 관련 키워드
        deadline_keywords = ["마감", "종료", "끝", "접수", "신청"]

        # 마감일만 필터링
        deadlines = []
        for schedule in all_schedules:
            title = schedule.get("title", "").lower()
            if any(keyword in title for keyword in deadline_keywords):
                deadlines.append(schedule)

        return deadlines


# 🧪 테스트 코드
if __name__ == "__main__":
    print("=" * 50)
    print("🧪 일정 추출기 테스트 시작")
    print("=" * 50)

    try:
        # 1. 추출기 생성
        print("\n[1단계] 일정 추출기 초기화 중...")
        extractor = ScheduleExtractor()

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

            2. 수강신청 정정 기간
               - 전체 학년: 2024년 2월 20일 ~ 2월 22일

            학생지원처 학사운영팀
            """,
            "url": "https://kunsan.ac.kr/notice/123",
            "date": "2024-01-20"
        }

        # 3. 일정 추출
        print("\n[2단계] 일정 추출 중...")
        schedules = extractor.extract_schedules(test_notice)

        print(f"\n📊 추출된 일정: {len(schedules)}개")
        for i, schedule in enumerate(schedules, 1):
            print(f"\n[일정 {i}]")
            print(f"  📌 제목: {schedule['title']}")
            print(f"  📅 시작: {schedule['start']}")
            print(f"  ⏰ 종료: {schedule['end']}")
            print(f"  🏷️ 카테고리: {schedule['category']}")
            print(f"  🔔 종일 이벤트: {schedule['all_day']}")

        # 4. 마감일만 추출 테스트
        print("\n[3단계] 마감일 정보만 추출...")
        deadlines = extractor.extract_deadlines(test_notice)
        print(f"\n⏰ 마감일: {len(deadlines)}개")
        for deadline in deadlines:
            print(f"  - {deadline['title']}: {deadline['start']}")

        print("\n" + "=" * 50)
        print("✅ 모든 테스트 완료!")
        print("=" * 50)

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
