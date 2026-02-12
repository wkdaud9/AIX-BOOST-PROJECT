# -*- coding: utf-8 -*-
"""
북마크 API 라우트

이 파일이 하는 일:
사용자별 공지사항 북마크(즐겨찾기) API를 제공합니다.

주요 엔드포인트:
- POST /api/bookmarks/<notice_id>: 북마크 토글 (추가/제거)
- GET /api/bookmarks: 사용자의 북마크 목록 조회
"""

from flask import Blueprint, request, jsonify, g
from services.supabase_service import get_supabase_client
from utils.auth_middleware import login_required

# Blueprint 생성 (URL 접두사: /api/bookmarks)
bookmarks_bp = Blueprint('bookmarks', __name__, url_prefix='/api/bookmarks')


@bookmarks_bp.route('/<notice_id>', methods=['POST'])
@login_required
def toggle_bookmark(notice_id):
    """
    공지사항 북마크를 토글합니다 (추가/제거).

    UPSERT + ON CONFLICT로 race condition 방지.
    """
    try:
        user_id = g.user_id
        supabase = get_supabase_client()

        # 기존 북마크 확인
        existing = supabase.table("user_bookmarks")\
            .select("id")\
            .eq("user_id", user_id)\
            .eq("notice_id", notice_id)\
            .execute()

        if existing.data:
            # 이미 북마크 → 제거
            supabase.table("user_bookmarks")\
                .delete()\
                .eq("user_id", user_id)\
                .eq("notice_id", notice_id)\
                .execute()

            # notices 테이블의 bookmark_count 감소
            supabase.rpc("decrement_bookmark_count", {"nid": notice_id}).execute()

            # 변경된 bookmark_count 조회
            count_result = supabase.table("notices")\
                .select("bookmark_count")\
                .eq("id", notice_id)\
                .single()\
                .execute()
            new_count = count_result.data.get("bookmark_count", 0) if count_result.data else 0

            print(f"[북마크] 제거: user={user_id[:8]}..., notice={notice_id[:8]}... (count={new_count})")

            return jsonify({
                "status": "success",
                "data": {
                    "bookmarked": False,
                    "notice_id": notice_id,
                    "bookmark_count": new_count
                }
            }), 200
        else:
            # 북마크 추가 (UPSERT으로 중복 삽입 방지)
            supabase.table("user_bookmarks")\
                .upsert({
                    "user_id": user_id,
                    "notice_id": notice_id,
                }, on_conflict="user_id,notice_id")\
                .execute()

            # notices 테이블의 bookmark_count 증가
            supabase.rpc("increment_bookmark_count", {"nid": notice_id}).execute()

            # 변경된 bookmark_count 조회
            count_result = supabase.table("notices")\
                .select("bookmark_count")\
                .eq("id", notice_id)\
                .single()\
                .execute()
            new_count = count_result.data.get("bookmark_count", 0) if count_result.data else 0

            print(f"[북마크] 추가: user={user_id[:8]}..., notice={notice_id[:8]}... (count={new_count})")

            return jsonify({
                "status": "success",
                "data": {
                    "bookmarked": True,
                    "notice_id": notice_id,
                    "bookmark_count": new_count
                }
            }), 200

    except Exception as e:
        print(f"[에러] 북마크 토글 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "북마크 처리에 실패했습니다."
        }), 500


@bookmarks_bp.route('', methods=['GET'])
@login_required
def get_bookmarks():
    """
    사용자의 북마크 목록을 조회합니다.

    GET /api/bookmarks?limit=50&offset=0
    """
    try:
        user_id = g.user_id
        try:
            limit = max(1, min(100, int(request.args.get('limit', 50))))
            offset = max(0, int(request.args.get('offset', 0)))
        except (ValueError, TypeError):
            return jsonify({"status": "error", "message": "limit과 offset은 정수여야 합니다"}), 400

        supabase = get_supabase_client()

        # 사용자의 북마크 notice_id 목록 조회 (정렬 순서 보존)
        bookmark_result = supabase.table("user_bookmarks")\
            .select("notice_id")\
            .eq("user_id", user_id)\
            .order("created_at", desc=True)\
            .range(offset, offset + limit - 1)\
            .execute()

        if not bookmark_result.data:
            return jsonify({
                "status": "success",
                "data": {
                    "bookmarks": [],
                    "total": 0
                }
            }), 200

        # 북마크된 공지사항 상세 정보 조회
        notice_ids = [b["notice_id"] for b in bookmark_result.data]

        notices_result = supabase.table("notices")\
            .select("*")\
            .in_("id", notice_ids)\
            .execute()

        # 북마크 순서대로 정렬 (IN 쿼리는 순서를 보장하지 않으므로)
        notices_map = {n["id"]: n for n in (notices_result.data or [])}
        notices = []
        for nid in notice_ids:
            if nid in notices_map:
                notice = notices_map[nid]
                notice["is_bookmarked"] = True
                notices.append(notice)

        print(f"[북마크] 조회: user={user_id[:8]}..., {len(notices)}개")

        return jsonify({
            "status": "success",
            "data": {
                "bookmarks": notices,
                "total": len(notices)
            }
        }), 200

    except Exception as e:
        print(f"[에러] 북마크 목록 조회 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "북마크 목록 조회에 실패했습니다."
        }), 500
