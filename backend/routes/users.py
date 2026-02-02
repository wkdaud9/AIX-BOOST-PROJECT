# -*- coding: utf-8 -*-
"""
사용자 API 라우트

이 파일이 하는 일:
사용자 프로필 및 선호도 관련 API 엔드포인트를 제공합니다.
"""

from flask import Blueprint, request, jsonify
from typing import Dict, Any
from services.supabase_service import SupabaseService

# Blueprint 생성 (URL 접두사: /api/users)
users_bp = Blueprint('users', __name__, url_prefix='/api/users')


@users_bp.route('/profile', methods=['POST'])
def create_user_profile():
    """
    회원가입 후 사용자 프로필 및 선호도를 생성합니다.

    POST /api/users/profile
    Body (JSON):
    {
        "user_id": "uuid",
        "email": "student@kunsan.ac.kr",
        "name": "홍길동",
        "student_id": "20241234",
        "department": "컴퓨터정보공학과",
        "grade": 3,
        "categories": ["학사공지", "장학"]
    }

    응답:
    {
        "status": "success",
        "data": {
            "user_id": "uuid",
            "message": "프로필이 생성되었습니다."
        }
    }
    """
    try:
        # 요청 데이터 가져오기
        data = request.get_json()

        # 필수 필드 검증
        required_fields = ['user_id', 'email', 'name', 'student_id', 'department', 'grade', 'categories']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    "status": "error",
                    "message": f"필수 필드가 누락되었습니다: {field}"
                }), 400

        user_id = data['user_id']
        email = data['email']
        name = data['name']
        student_id = data['student_id']
        department = data['department']
        grade = data['grade']
        categories = data['categories']

        # Supabase 서비스 초기화
        supabase = SupabaseService()

        # 1. users 테이블에 사용자 정보 삽입 또는 업데이트
        user_data = {
            "id": user_id,
            "email": email,
            "name": name,
            "student_id": student_id,
            "department": department,
            "grade": grade
        }

        # upsert: 이미 존재하면 업데이트, 없으면 삽입
        user_result = supabase.client.table("users")\
            .upsert(user_data, on_conflict="id")\
            .execute()

        if not user_result.data:
            raise Exception("사용자 프로필 생성 실패")

        print(f"[사용자 프로필] 생성 완료: {email} ({student_id})")

        # 2. user_preferences 테이블에 선호도 정보 삽입 또는 업데이트
        preferences_data = {
            "user_id": user_id,
            "categories": categories,
            "keywords": [],  # 초기값: 빈 배열
            "notification_enabled": True
        }

        # upsert: 이미 존재하면 업데이트, 없으면 삽입
        preferences_result = supabase.client.table("user_preferences")\
            .upsert(preferences_data, on_conflict="user_id")\
            .execute()

        if not preferences_result.data:
            raise Exception("사용자 선호도 생성 실패")

        print(f"[사용자 선호도] 생성 완료: {len(categories)}개 카테고리")

        return jsonify({
            "status": "success",
            "data": {
                "user_id": user_id,
                "message": "프로필이 생성되었습니다."
            }
        }), 200

    except Exception as e:
        error_msg = str(e)
        print(f"[ERROR] 프로필 생성 에러: {error_msg}")

        # 학번 중복 에러 체크
        if "duplicate key value violates unique constraint" in error_msg.lower() and "student_id" in error_msg.lower():
            return jsonify({
                "status": "error",
                "message": "이미 사용 중인 학번입니다."
            }), 400

        # 이메일 중복 에러 체크
        if "duplicate key value violates unique constraint" in error_msg.lower() and "email" in error_msg.lower():
            return jsonify({
                "status": "error",
                "message": "이미 사용 중인 이메일입니다."
            }), 400

        return jsonify({
            "status": "error",
            "message": error_msg
        }), 500


@users_bp.route('/profile/<user_id>', methods=['GET'])
def get_user_profile(user_id):
    """
    사용자 프로필 및 선호도를 조회합니다.

    GET /api/users/profile/<user_id>

    응답:
    {
        "status": "success",
        "data": {
            "user": {...},
            "preferences": {...}
        }
    }
    """
    try:
        supabase = SupabaseService()

        # 1. users 테이블에서 사용자 정보 조회
        user_result = supabase.client.table("users")\
            .select("*")\
            .eq("id", user_id)\
            .single()\
            .execute()

        if not user_result.data:
            return jsonify({
                "status": "error",
                "message": "사용자를 찾을 수 없습니다."
            }), 404

        # 2. user_preferences 테이블에서 선호도 정보 조회
        preferences_result = supabase.client.table("user_preferences")\
            .select("*")\
            .eq("user_id", user_id)\
            .single()\
            .execute()

        return jsonify({
            "status": "success",
            "data": {
                "user": user_result.data,
                "preferences": preferences_result.data if preferences_result.data else None
            }
        }), 200

    except Exception as e:
        print(f"[ERROR] 프로필 조회 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@users_bp.route('/preferences/<user_id>', methods=['PUT'])
def update_user_preferences(user_id):
    """
    사용자 선호도(카테고리) 업데이트

    PUT /api/users/preferences/<user_id>
    Body (JSON):
    {
        "categories": ["학사공지", "장학", "취업"]
    }

    응답:
    {
        "status": "success",
        "data": {
            "message": "선호도가 업데이트되었습니다.",
            "preferences": {...}
        }
    }
    """
    try:
        data = request.get_json()

        # 필수 필드 검증
        if 'categories' not in data:
            return jsonify({
                "status": "error",
                "message": "categories 필드가 필요합니다."
            }), 400

        categories = data['categories']

        # 카테고리가 리스트인지 확인
        if not isinstance(categories, list):
            return jsonify({
                "status": "error",
                "message": "categories는 배열이어야 합니다."
            }), 400

        # 최소 1개 이상의 카테고리 선택 확인
        if len(categories) == 0:
            return jsonify({
                "status": "error",
                "message": "최소 1개 이상의 카테고리를 선택해야 합니다."
            }), 400

        supabase = SupabaseService()

        # user_preferences 테이블 업데이트
        preferences_data = {
            "user_id": user_id,
            "categories": categories
        }

        result = supabase.client.table("user_preferences")\
            .update({"categories": categories})\
            .eq("user_id", user_id)\
            .execute()

        if not result.data:
            return jsonify({
                "status": "error",
                "message": "선호도 업데이트에 실패했습니다."
            }), 500

        print(f"[선호도 업데이트] 완료: {user_id} - {len(categories)}개 카테고리")

        return jsonify({
            "status": "success",
            "data": {
                "message": "선호도가 업데이트되었습니다.",
                "preferences": result.data[0]
            }
        }), 200

    except Exception as e:
        print(f"[ERROR] 선호도 업데이트 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@users_bp.route('/profile/<user_id>', methods=['DELETE'])
def delete_user(user_id):
    """
    사용자 삭제 (회원가입 롤백용)

    DELETE /api/users/profile/<user_id>

    응답:
    {
        "status": "success",
        "data": {
            "message": "사용자가 삭제되었습니다."
        }
    }
    """
    try:
        supabase = SupabaseService()

        # auth.users에서 사용자 삭제 (service_role 권한 필요)
        supabase.client.auth.admin.delete_user(user_id)

        print(f"[사용자 삭제] 완료: {user_id}")

        return jsonify({
            "status": "success",
            "data": {
                "message": "사용자가 삭제되었습니다."
            }
        }), 200

    except Exception as e:
        print(f"[ERROR] 사용자 삭제 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500
