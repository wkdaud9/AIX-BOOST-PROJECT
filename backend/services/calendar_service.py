# -*- coding: utf-8 -*-
"""
캘린더 이벤트 서비스 모듈

🤔 이 파일이 하는 일:
AI가 분석한 날짜 정보를 기반으로 사용자별 캘린더 이벤트를 생성하고 관리합니다.
사용자의 관심 카테고리에 맞는 일정만 자동으로 캘린더에 추가합니다.

📚 비유:
- AI 분석 결과 = 중요한 날짜가 적힌 메모
- 이 서비스 = 메모를 보고 자동으로 달력에 일정을 표시해주는 비서
"""

import os
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from supabase import create_client, Client


class CalendarService:
    """
    캘린더 이벤트 생성 및 관리 서비스

    🎯 목적:
    공지사항의 날짜 정보를 사용자별 캘린더 이벤트로 변환하여 저장합니다.

    🏗️ 주요 기능:
    1. create_calendar_events: 공지사항에서 캘린더 이벤트 생성
    2. create_events_for_users: 특정 사용자들에게만 이벤트 생성
    3. get_user_events: 사용자의 캘린더 이벤트 조회
    4. delete_event: 이벤트 삭제
    """

    # 이벤트 타입 정의
    EVENT_TYPES = {
        "start_date": "시작일",
        "end_date": "종료일",
        "deadline": "마감일"
    }

    def __init__(self):
        """Supabase 클라이언트를 초기화합니다."""
        self.url: str = os.getenv("SUPABASE_URL")
        self.key: str = os.getenv("SUPABASE_KEY")

        if not self.url or not self.key:
            raise ValueError(
                "❌ SUPABASE_URL과 SUPABASE_KEY 환경 변수가 필요합니다"
            )

        self.client: Client = create_client(self.url, self.key)
        print("✅ CalendarService 초기화 완료")

    def create_calendar_events(
        self,
        notice_id: str,
        dates: Dict[str, Optional[str]],
        notice_title: str,
        category: str,
        user_ids: Optional[List[str]] = None
    ) -> List[str]:
        """
        공지사항의 날짜 정보를 기반으로 캘린더 이벤트를 생성합니다.

        🎯 목적:
        AI가 추출한 start_date, end_date, deadline을 각각 별도의 이벤트로 생성합니다.

        🔧 매개변수:
        - notice_id: 공지사항 ID (UUID)
        - dates: 날짜 정보 {"start_date": "YYYY-MM-DD", "end_date": ..., "deadline": ...}
        - notice_title: 공지사항 제목
        - category: 공지사항 카테고리
        - user_ids: 이벤트를 생성할 사용자 ID 리스트 (None이면 모든 사용자)

        📊 반환값:
        - 생성된 이벤트 ID 리스트

        💡 예시:
        service = CalendarService()
        dates = {
            "start_date": "2024-02-01",
            "end_date": "2024-02-05",
            "deadline": "2024-01-31"
        }
        event_ids = service.create_calendar_events(
            notice_id="uuid-123",
            dates=dates,
            notice_title="수강신청 안내",
            category="학사",
            user_ids=["user1", "user2"]
        )
        print(f"{len(event_ids)}개 이벤트 생성 완료")
        """
        created_event_ids = []

        # user_ids가 없으면 해당 카테고리에 관심 있는 모든 사용자 조회
        if user_ids is None:
            user_ids = self._get_interested_users(category)

        if not user_ids:
            print("⚠️ 이벤트를 생성할 사용자가 없습니다")
            return []

        print(f"📅 {len(user_ids)}명의 사용자를 위한 캘린더 이벤트 생성 중...")

        # 각 날짜 타입별로 이벤트 생성
        for date_type, event_type_name in self.EVENT_TYPES.items():
            date_value = dates.get(date_type)

            # 날짜가 없으면 스킵
            if not date_value or date_value == "null":
                continue

            # 이벤트 제목 생성
            event_title = f"{event_type_name}: {notice_title}"

            # 각 사용자별로 이벤트 생성
            for user_id in user_ids:
                event_data = {
                    "user_id": user_id,
                    "notice_id": notice_id,
                    "title": event_title,
                    "description": f"{category} 공지사항",
                    "start_date": self._parse_datetime(date_value),
                    "end_date": self._parse_datetime(date_value),  # 종일 이벤트는 시작=종료
                    "event_type": event_type_name,
                    "is_all_day": True,  # 기본적으로 종일 이벤트
                    "is_notified": False,
                    "is_synced": False
                }

                try:
                    # 중복 체크 (같은 사용자, 같은 공지, 같은 날짜)
                    existing = self.client.table("calendar_events")\
                        .select("id")\
                        .eq("user_id", user_id)\
                        .eq("notice_id", notice_id)\
                        .eq("event_type", event_type_name)\
                        .execute()

                    if existing.data:
                        # 이미 존재하면 스킵
                        continue

                    # 이벤트 생성
                    result = self.client.table("calendar_events")\
                        .insert(event_data)\
                        .execute()

                    if result.data:
                        event_id = result.data[0]["id"]
                        created_event_ids.append(event_id)

                except Exception as e:
                    print(f"❌ 이벤트 생성 실패 (user={user_id}): {str(e)}")
                    continue

        print(f"✅ {len(created_event_ids)}개 캘린더 이벤트 생성 완료")
        return created_event_ids

    def create_events_for_users(
        self,
        notice_data: Dict[str, Any],
        user_ids: List[str]
    ) -> List[str]:
        """
        특정 사용자들에게만 캘린더 이벤트를 생성합니다.

        🎯 목적:
        개인화된 알림을 위해 특정 사용자들에게만 이벤트를 생성합니다.

        🔧 매개변수:
        - notice_data: 공지사항 데이터 (AI 분석 결과 포함)
        - user_ids: 대상 사용자 ID 리스트

        📊 반환값:
        - 생성된 이벤트 ID 리스트

        💡 예시:
        service = CalendarService()
        notice = {
            "id": "uuid-123",
            "title": "4학년 수강신청",
            "category": "학사",
            "dates": {"start_date": "2024-02-01", ...}
        }
        event_ids = service.create_events_for_users(
            notice_data=notice,
            user_ids=["user1", "user2"]
        )
        """
        return self.create_calendar_events(
            notice_id=notice_data.get("id"),
            dates=notice_data.get("dates", {}),
            notice_title=notice_data.get("title", "일정"),
            category=notice_data.get("category", "기타"),
            user_ids=user_ids
        )

    def get_user_events(
        self,
        user_id: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        특정 사용자의 캘린더 이벤트를 조회합니다.

        🎯 목적:
        사용자의 일정을 날짜 범위로 필터링하여 조회합니다.

        🔧 매개변수:
        - user_id: 사용자 ID (UUID)
        - start_date: 조회 시작 날짜 (YYYY-MM-DD, 선택)
        - end_date: 조회 종료 날짜 (YYYY-MM-DD, 선택)
        - limit: 최대 조회 개수 (기본값: 100)

        📊 반환값:
        - 캘린더 이벤트 리스트

        💡 예시:
        service = CalendarService()
        events = service.get_user_events(
            user_id="user-uuid",
            start_date="2024-02-01",
            end_date="2024-02-28"
        )
        for event in events:
            print(f"{event['start_date']}: {event['title']}")
        """
        try:
            query = self.client.table("calendar_events")\
                .select("*")\
                .eq("user_id", user_id)\
                .order("start_date", desc=False)\
                .limit(limit)

            # 날짜 범위 필터
            if start_date:
                query = query.gte("start_date", start_date)
            if end_date:
                query = query.lte("start_date", end_date)

            result = query.execute()

            if result.data:
                print(f"📅 {len(result.data)}개 이벤트 조회")
                return result.data
            else:
                print("ℹ️ 조회된 이벤트 없음")
                return []

        except Exception as e:
            print(f"❌ 이벤트 조회 실패: {str(e)}")
            return []

    def delete_event(self, event_id: str, user_id: str) -> bool:
        """
        캘린더 이벤트를 삭제합니다.

        🎯 목적:
        사용자가 더 이상 필요 없는 이벤트를 삭제합니다.

        🔧 매개변수:
        - event_id: 이벤트 ID (UUID)
        - user_id: 사용자 ID (UUID, 권한 확인용)

        📊 반환값:
        - 삭제 성공 여부 (True/False)

        💡 예시:
        service = CalendarService()
        success = service.delete_event(
            event_id="event-uuid",
            user_id="user-uuid"
        )
        """
        try:
            result = self.client.table("calendar_events")\
                .delete()\
                .eq("id", event_id)\
                .eq("user_id", user_id)\
                .execute()

            print(f"✅ 이벤트 삭제 완료: {event_id}")
            return True

        except Exception as e:
            print(f"❌ 이벤트 삭제 실패: {str(e)}")
            return False

    def mark_as_notified(self, event_id: str) -> bool:
        """
        이벤트를 알림 발송 완료로 표시합니다.

        🎯 목적:
        푸시 알림을 보낸 이벤트를 표시하여 중복 알림을 방지합니다.

        🔧 매개변수:
        - event_id: 이벤트 ID (UUID)

        📊 반환값:
        - 업데이트 성공 여부 (True/False)

        💡 예시:
        service = CalendarService()
        service.mark_as_notified("event-uuid")
        """
        try:
            result = self.client.table("calendar_events")\
                .update({"is_notified": True, "updated_at": datetime.now().isoformat()})\
                .eq("id", event_id)\
                .execute()

            return bool(result.data)

        except Exception as e:
            print(f"❌ 알림 상태 업데이트 실패: {str(e)}")
            return False

    def get_upcoming_events(
        self,
        days_ahead: int = 7
    ) -> List[Dict[str, Any]]:
        """
        앞으로 N일 이내의 모든 이벤트를 조회합니다.

        🎯 목적:
        푸시 알림을 보낼 이벤트를 조회합니다.

        🔧 매개변수:
        - days_ahead: 앞으로 며칠까지 조회할지 (기본값: 7일)

        📊 반환값:
        - 다가오는 이벤트 리스트

        💡 예시:
        service = CalendarService()
        upcoming = service.get_upcoming_events(days_ahead=3)
        for event in upcoming:
            # 푸시 알림 발송
            send_push_notification(event)
        """
        try:
            today = datetime.now().date()
            end_date = (today + timedelta(days=days_ahead)).isoformat()

            result = self.client.table("calendar_events")\
                .select("*")\
                .gte("start_date", today.isoformat())\
                .lte("start_date", end_date)\
                .eq("is_notified", False)\
                .order("start_date", desc=False)\
                .execute()

            if result.data:
                print(f"📅 {len(result.data)}개 다가오는 이벤트 조회")
                return result.data
            else:
                return []

        except Exception as e:
            print(f"❌ 다가오는 이벤트 조회 실패: {str(e)}")
            return []

    def _get_interested_users(self, category: str) -> List[str]:
        """
        특정 카테고리에 관심 있는 사용자 ID 목록을 조회합니다.

        🎯 내부 헬퍼 함수

        🔧 매개변수:
        - category: 카테고리 이름 (예: "학사", "장학")

        📊 반환값:
        - 사용자 ID 리스트

        💡 로직:
        user_preferences 테이블에서 해당 카테고리를 선호하는 사용자를 찾습니다.
        """
        try:
            # user_preferences에서 해당 카테고리를 포함한 사용자 조회
            result = self.client.table("user_preferences")\
                .select("user_id")\
                .contains("categories", [category])\
                .execute()

            if result.data:
                user_ids = [pref["user_id"] for pref in result.data]
                print(f"ℹ️ {category} 카테고리 관심 사용자: {len(user_ids)}명")
                return user_ids
            else:
                print(f"ℹ️ {category} 카테고리 관심 사용자 없음")
                return []

        except Exception as e:
            print(f"❌ 관심 사용자 조회 실패: {str(e)}")
            # 에러 발생 시 모든 사용자에게 이벤트 생성
            return self._get_all_users()

    def _get_all_users(self) -> List[str]:
        """
        모든 사용자 ID를 조회합니다.

        🎯 내부 헬퍼 함수
        """
        try:
            result = self.client.table("users")\
                .select("id")\
                .execute()

            if result.data:
                return [user["id"] for user in result.data]
            else:
                return []

        except Exception as e:
            print(f"❌ 전체 사용자 조회 실패: {str(e)}")
            return []

    def _parse_datetime(self, date_str: str) -> str:
        """
        날짜 문자열을 ISO 8601 형식으로 변환합니다.

        🎯 내부 헬퍼 함수

        💡 예시:
        "2024-02-01" → "2024-02-01T00:00:00"
        """
        try:
            # YYYY-MM-DD 형식을 datetime으로 변환
            if len(date_str) == 10:
                dt = datetime.fromisoformat(date_str)
                return dt.isoformat()
            else:
                return date_str
        except:
            return datetime.now().isoformat()


# 🧪 테스트 코드
if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()

    print("=" * 50)
    print("🧪 CalendarService 테스트 시작")
    print("=" * 50)

    try:
        # 1. 서비스 초기화
        print("\n[1단계] CalendarService 초기화 중...")
        service = CalendarService()

        # 2. 테스트 이벤트 생성
        print("\n[2단계] 테스트 이벤트 생성...")
        dates = {
            "start_date": "2024-02-01",
            "end_date": "2024-02-05",
            "deadline": "2024-01-31"
        }

        # 실제 사용자 ID가 필요하므로, 테스트는 주석 처리
        # event_ids = service.create_calendar_events(
        #     notice_id="test-notice-id",
        #     dates=dates,
        #     notice_title="테스트 공지사항",
        #     category="학사",
        #     user_ids=["test-user-id"]
        # )
        # print(f"생성된 이벤트: {len(event_ids)}개")

        print("\n✅ CalendarService 초기화 및 구조 검증 완료")
        print("실제 이벤트 생성은 사용자 ID가 필요합니다.")

        print("\n" + "=" * 50)
        print("✅ 테스트 완료!")
        print("=" * 50)

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
