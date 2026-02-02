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
        required_fields = ['user_id', 'email', 'student_id', 'department', 'grade', 'categories']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    "status": "error",
                    "message": f"필수 필드가 누락되었습니다: {field}"
                }), 400

        user_id = data['user_id']
        email = data['email']
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
        print(f"[ERROR] 프로필 생성 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
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
