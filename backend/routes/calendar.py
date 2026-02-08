# -*- coding: utf-8 -*-
"""
캘린더 API 라우트

이 파일이 하는 일:
사용자가 북마크한 공지사항의 마감일 이벤트를 제공합니다.
user_bookmarks + notices 테이블을 조인하여 마감일 기반 이벤트를 반환합니다.

주요 엔드포인트:
- GET /api/calendar/events: 사용자의 북마크 기반 마감일 이벤트 조회
"""

from flask import Blueprint, request, jsonify, g
import os

from supabase import create_client, Client
from utils.auth_middleware import login_required

# Blueprint 생성 (URL 접두사: /api/calendar)
calendar_bp = Blueprint('calendar', __name__, url_prefix='/api/calendar')


def _get_supabase() -> Client:
    """Supabase 클라이언트 초기화"""
    return create_client(
        os.getenv("SUPABASE_URL"),
        os.getenv("SUPABASE_KEY")
    )


@calendar_bp.route('/events', methods=['GET'])
@login_required
def get_calendar_events():
    """
    사용자의 북마크된 공지사항에서 마감일 이벤트를 조회합니다.

    user_bookmarks + notices 테이블을 조인하여
    사용자가 북마크한 공지사항의 deadline(마감일)을 반환합니다.

    GET /api/calendar/events?month=2026-02

    쿼리 파라미터:
    - month: 조회할 월 (YYYY-MM 형식, 선택)

    응답:
    {
        "status": "success",
        "data": {
            "events": [
                {
                    "notice_id": "uuid",
                    "title": "수강신청 안내",
                    "category": "학사",
                    "deadline": "2026-02-15",
                    "event_type": "마감일"
                }
            ],
            "total": 5
        }
    }
    """
    try:
        user_id = g.user_id
        month = request.args.get('month', '').strip()

        print(f"\n[캘린더] 마감일 이벤트 조회")
        print(f"   - 사용자: {user_id[:8]}...")
        if month:
            print(f"   - 월: {month}")

        supabase = _get_supabase()

        # 1. 사용자의 북마크된 공지사항 ID 목록 조회
        bookmark_result = supabase.table("user_bookmarks")\
            .select("notice_id")\
            .eq("user_id", user_id)\
            .execute()

        if not bookmark_result.data:
            print("   - 결과: 북마크 없음")
            return jsonify({
                "status": "success",
                "data": {"events": [], "total": 0}
            }), 200

        notice_ids = [b["notice_id"] for b in bookmark_result.data]

        # 2. 북마크된 공지사항 중 마감일이 있는 것만 조회
        notices_result = supabase.table("notices")\
            .select("id, title, category, deadline")\
            .in_("id", notice_ids)\
            .not_.is_("deadline", "null")\
            .execute()

        # 3. 마감일 이벤트 목록 생성
        events = []
        for notice in (notices_result.data or []):
            deadline = str(notice.get("deadline", ""))
            if not deadline:
                continue

            # month 필터 적용
            if month and not deadline.startswith(month):
                continue

            events.append({
                "notice_id": notice["id"],
                "title": notice["title"],
                "category": notice.get("category", ""),
                "deadline": deadline,
                "event_type": "마감일"
            })

        print(f"   - 결과: {len(events)}개 마감일 이벤트")

        return jsonify({
            "status": "success",
            "data": {
                "events": events,
                "total": len(events)
            }
        }), 200

    except Exception as e:
        print(f"[에러] 캘린더 이벤트 조회 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500
