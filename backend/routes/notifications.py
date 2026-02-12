# -*- coding: utf-8 -*-
"""
알림 API 라우트

이 파일이 하는 일:
FCM 디바이스 토큰 등록/해제 및 알림 내역 조회 API를 제공합니다.

주요 엔드포인트:
- POST /api/notifications/token: FCM 디바이스 토큰 등록
- DELETE /api/notifications/token: FCM 디바이스 토큰 해제
- GET /api/notifications: 알림 내역 조회
- PUT /api/notifications/read-all: 전체 알림 읽음 처리
- PUT /api/notifications/<id>/read: 개별 알림 읽음 처리
"""

from flask import Blueprint, request, jsonify, g
from services.supabase_service import get_supabase_client
from utils.auth_middleware import login_required

# Blueprint 생성 (URL 접두사: /api/notifications)
notifications_bp = Blueprint('notifications', __name__, url_prefix='/api/notifications')


@notifications_bp.route('/token', methods=['POST'])
@login_required
def register_token():
    """
    FCM 디바이스 토큰을 등록합니다.
    이미 등록된 토큰이면 user_id를 업데이트합니다 (디바이스 소유자 변경 대응).
    """
    try:
        user_id = g.user_id
        data = request.get_json()

        # 필수 필드 검증
        if not data or not data.get("token"):
            return jsonify({
                "status": "error",
                "message": "token 필드가 필요합니다."
            }), 400

        token = data["token"]
        device_type = data.get("device_type", "android")

        # device_type 유효성 검증
        if device_type not in ("android", "web", "ios"):
            return jsonify({
                "status": "error",
                "message": "device_type은 'android', 'web', 'ios' 중 하나여야 합니다."
            }), 400

        supabase = get_supabase_client()

        # 같은 사용자+디바이스 타입의 이전 토큰 삭제 (FCM 토큰 갱신 시 누적 방지)
        supabase.table("device_tokens")\
            .delete()\
            .eq("user_id", user_id)\
            .eq("device_type", device_type)\
            .neq("token", token)\
            .execute()

        # upsert: 토큰이 이미 존재하면 user_id와 device_type 업데이트
        supabase.table("device_tokens").upsert(
            {
                "user_id": user_id,
                "token": token,
                "device_type": device_type
            },
            on_conflict="token"
        ).execute()

        print(f"[알림] 토큰 등록: user={user_id[:8]}..., type={device_type}")

        return jsonify({
            "status": "success",
            "data": {
                "message": "토큰이 등록되었습니다."
            }
        }), 200

    except Exception as e:
        print(f"[에러] 토큰 등록 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "토큰 등록에 실패했습니다."
        }), 500


@notifications_bp.route('/token', methods=['DELETE'])
@login_required
def unregister_token():
    """
    FCM 디바이스 토큰을 해제합니다.
    로그아웃 시 또는 알림 비활성화 시 호출합니다.
    """
    try:
        user_id = g.user_id
        data = request.get_json()

        if not data or not data.get("token"):
            return jsonify({
                "status": "error",
                "message": "token 필드가 필요합니다."
            }), 400

        token = data["token"]
        supabase = get_supabase_client()

        # 현재 사용자의 해당 토큰만 삭제 (보안: 다른 사용자 토큰 삭제 방지)
        supabase.table("device_tokens")\
            .delete()\
            .eq("user_id", user_id)\
            .eq("token", token)\
            .execute()

        print(f"[알림] 토큰 해제: user={user_id[:8]}...")

        return jsonify({
            "status": "success",
            "data": {
                "message": "토큰이 해제되었습니다."
            }
        }), 200

    except Exception as e:
        print(f"[에러] 토큰 해제 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "토큰 해제에 실패했습니다."
        }), 500


@notifications_bp.route('', methods=['GET'])
@login_required
def get_notifications():
    """
    사용자의 알림 내역을 조회합니다.

    GET /api/notifications?limit=20&offset=0&unread_only=false
    """
    try:
        user_id = g.user_id
        try:
            limit = max(1, min(100, int(request.args.get('limit', 20))))
            offset = max(0, int(request.args.get('offset', 0)))
        except (ValueError, TypeError):
            return jsonify({"status": "error", "message": "limit과 offset은 정수여야 합니다"}), 400
        unread_only = request.args.get('unread_only', 'false').lower() == 'true'

        supabase = get_supabase_client()

        # 알림 내역 조회 쿼리
        query = supabase.table("notification_logs")\
            .select("*")\
            .eq("user_id", user_id)\
            .order("sent_at", desc=True)\
            .range(offset, offset + limit - 1)

        if unread_only:
            query = query.eq("is_read", False)

        result = query.execute()
        notifications = result.data or []

        # 읽지 않은 알림 수 조회
        unread_result = supabase.table("notification_logs")\
            .select("id", count="exact")\
            .eq("user_id", user_id)\
            .eq("is_read", False)\
            .execute()
        unread_count = unread_result.count if unread_result.count else 0

        return jsonify({
            "status": "success",
            "data": {
                "notifications": notifications,
                "total": len(notifications),
                "unread_count": unread_count
            }
        }), 200

    except Exception as e:
        print(f"[에러] 알림 내역 조회 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "알림 내역 조회에 실패했습니다."
        }), 500


@notifications_bp.route('/read-all', methods=['PUT'])
@login_required
def mark_all_as_read():
    """
    사용자의 모든 알림을 읽음 처리합니다.
    """
    try:
        user_id = g.user_id
        supabase = get_supabase_client()

        result = supabase.table("notification_logs")\
            .update({"is_read": True})\
            .eq("user_id", user_id)\
            .eq("is_read", False)\
            .execute()

        updated_count = len(result.data) if result.data else 0
        print(f"[알림] 전체 읽음: user={user_id[:8]}..., {updated_count}건")

        return jsonify({
            "status": "success",
            "data": {
                "message": "모든 알림이 읽음 처리되었습니다.",
                "updated_count": updated_count
            }
        }), 200

    except Exception as e:
        print(f"[에러] 전체 읽음 처리 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "전체 읽음 처리에 실패했습니다."
        }), 500


@notifications_bp.route('/<notification_id>/read', methods=['PUT'])
@login_required
def mark_as_read(notification_id):
    """
    특정 알림을 읽음 처리합니다.
    """
    try:
        user_id = g.user_id
        supabase = get_supabase_client()

        # 자신의 알림만 읽음 처리 가능 (보안)
        result = supabase.table("notification_logs")\
            .update({"is_read": True})\
            .eq("id", notification_id)\
            .eq("user_id", user_id)\
            .execute()

        if not result.data:
            return jsonify({
                "status": "error",
                "message": "알림을 찾을 수 없습니다."
            }), 404

        return jsonify({
            "status": "success",
            "data": {
                "message": "알림이 읽음 처리되었습니다."
            }
        }), 200

    except Exception as e:
        print(f"[에러] 알림 읽음 처리 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "알림 읽음 처리에 실패했습니다."
        }), 500
