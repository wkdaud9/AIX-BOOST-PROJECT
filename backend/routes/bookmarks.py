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
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from supabase import create_client, Client
from utils.auth_middleware import login_required

# Blueprint 생성 (URL 접두사: /api/bookmarks)
bookmarks_bp = Blueprint('bookmarks', __name__, url_prefix='/api/bookmarks')

# Supabase 클라이언트 초기화
def _get_supabase() -> Client:
    return create_client(
        os.getenv("SUPABASE_URL"),
        os.getenv("SUPABASE_KEY")
    )


@bookmarks_bp.route('/<notice_id>', methods=['POST'])
@login_required
def toggle_bookmark(notice_id):
    """
    공지사항 북마크를 토글합니다 (추가/제거).

    POST /api/bookmarks/<notice_id>

    응답 (추가 시):
    {
        "status": "success",
        "data": {
            "bookmarked": true,
            "notice_id": "uuid"
        }
    }

    응답 (제거 시):
    {
        "status": "success",
        "data": {
            "bookmarked": false,
            "notice_id": "uuid"
        }
    }
    """
    try:
        user_id = g.user_id
        supabase = _get_supabase()

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

            print(f"[북마크] 제거: user={user_id[:8]}..., notice={notice_id[:8]}...")

            return jsonify({
                "status": "success",
                "data": {
                    "bookmarked": False,
                    "notice_id": notice_id
                }
            }), 200
        else:
            # 북마크 추가
            supabase.table("user_bookmarks")\
                .insert({
                    "user_id": user_id,
                    "notice_id": notice_id,
                })\
                .execute()

            print(f"[북마크] 추가: user={user_id[:8]}..., notice={notice_id[:8]}...")

            return jsonify({
                "status": "success",
                "data": {
                    "bookmarked": True,
                    "notice_id": notice_id
                }
            }), 200

    except Exception as e:
        print(f"[에러] 북마크 토글 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@bookmarks_bp.route('', methods=['GET'])
@login_required
def get_bookmarks():
    """
    사용자의 북마크 목록을 조회합니다.

    GET /api/bookmarks?limit=50&offset=0

    쿼리 파라미터:
    - limit: 최대 개수 (기본 50)
    - offset: 건너뛸 개수 (기본 0)

    응답:
    {
        "status": "success",
        "data": {
            "bookmarks": [
                {
                    "id": "uuid",
                    "title": "공지사항 제목",
                    "content": "내용",
                    "category": "학사",
                    ...
                }
            ],
            "total": 10
        }
    }
    """
    try:
        user_id = g.user_id
        limit = int(request.args.get('limit', 50))
        offset = int(request.args.get('offset', 0))

        supabase = _get_supabase()

        # 사용자의 북마크 notice_id 목록 조회
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

        # 북마크 표시 추가
        notices = notices_result.data or []
        for notice in notices:
            notice["is_bookmarked"] = True

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
            "message": str(e)
        }), 500
