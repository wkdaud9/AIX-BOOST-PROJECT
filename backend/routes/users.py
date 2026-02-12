# -*- coding: utf-8 -*-
"""
사용자 API 라우트

이 파일이 하는 일:
사용자 프로필 및 선호도 관련 API 엔드포인트를 제공합니다.
"""

from flask import Blueprint, request, jsonify, g
from typing import Dict, Any, List, Optional, Tuple
from services.supabase_service import SupabaseService
from utils.auth_middleware import login_required
from ai.embedding_service import EmbeddingService
from ai.enrichment_service import EnrichmentService

# Blueprint 생성 (URL 접두사: /api/users)
users_bp = Blueprint('users', __name__, url_prefix='/api/users')


def _generate_user_embedding_and_profile(
    department: str,
    categories: List[str],
    grade: Optional[int] = None
) -> Tuple[Optional[List[float]], Optional[Dict[str, Any]]]:
    """사용자 프로필 보강(enriched_profile) 및 관심사 임베딩을 생성합니다."""
    try:
        # 1. enriched_profile 생성 (학과/학년 기반 관심사 확장)
        enrichment_service = EnrichmentService()
        enriched_profile = enrichment_service.enrich_user_profile(
            department=department,
            grade=grade,
            categories=categories
        )
        print(f"[프로필 보강] 완료: {enriched_profile}")

        # 2. 보강된 정보를 포함한 임베딩 텍스트 생성
        parts = []
        if department:
            parts.append(f"학과: {department}")
        if grade:
            parts.append(f"학년: {grade}학년")
        if categories:
            parts.append(f"관심 카테고리: {', '.join(categories)}")
        # enriched_profile의 확장 정보를 임베딩에 포함
        if enriched_profile.get("department_context"):
            parts.append(f"학과 관련: {', '.join(enriched_profile['department_context'])}")
        if enriched_profile.get("grade_context"):
            parts.append(f"학년 관련: {', '.join(enriched_profile['grade_context'])}")
        if enriched_profile.get("category_context"):
            parts.append(f"카테고리 관련: {', '.join(enriched_profile['category_context'])}")

        if not parts:
            return None, enriched_profile

        profile_text = " ".join(parts)
        embedding_service = EmbeddingService()
        embedding = embedding_service.create_embedding(profile_text)
        print(f"[임베딩] 사용자 관심사 임베딩 생성 완료 ({len(embedding)}차원)")
        return embedding, enriched_profile
    except Exception as e:
        print(f"[임베딩] 사용자 임베딩/프로필 생성 실패: {str(e)}")
        return None, None


@users_bp.route('/departments', methods=['GET'])
def get_departments():
    """
    학과 목록 조회 (회원가입 드롭다운용)

    GET /api/users/departments

    응답:
    {
        "status": "success",
        "data": { "대학명": ["학과1", "학과2", ...], ... }
    }
    """
    return jsonify({
        "status": "success",
        "data": EnrichmentService.UNIVERSITY_DEPARTMENTS
    })


@users_bp.route('/profile', methods=['POST'])
@login_required
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

        # 토큰의 사용자 ID와 요청 body의 user_id 일치 확인 (위변조 방지)
        if g.user_id != user_id:
            return jsonify({
                "status": "error",
                "message": "인증된 사용자와 요청 user_id가 일치하지 않습니다."
            }), 403

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

        # 2. 사용자 관심사 임베딩 + enriched_profile 생성
        interests_embedding, enriched_profile = _generate_user_embedding_and_profile(
            department=department,
            categories=categories,
            grade=grade
        )

        # 3. user_preferences 테이블에 선호도 정보 삽입 또는 업데이트
        preferences_data = {
            "user_id": user_id,
            "categories": categories,
            "keywords": [],  # 초기값: 빈 배열
            "notification_enabled": True
        }

        if interests_embedding:
            preferences_data["interests_embedding"] = interests_embedding
        if enriched_profile:
            preferences_data["enriched_profile"] = enriched_profile

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
            "message": "프로필 생성에 실패했습니다."
        }), 500


@users_bp.route('/profile/<user_id>', methods=['GET'])
@login_required
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
        # 현재 로그인한 사용자와 요청하는 user_id가 일치하는지 확인
        if g.user_id != user_id:
            return jsonify({
                "status": "error",
                "message": "자신의 프로필만 조회할 수 있습니다."
            }), 403

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
            "message": "프로필 조회에 실패했습니다."
        }), 500


@users_bp.route('/profile/<user_id>', methods=['PUT'])
@login_required
def update_user_profile(user_id):
    """
    사용자 프로필(이름, 학과, 학년) 업데이트

    PUT /api/users/profile/<user_id>
    Body (JSON):
    {
        "name": "홍길동",
        "department": "컴퓨터정보공학과",
        "grade": 3
    }

    응답:
    {
        "status": "success",
        "data": {
            "message": "프로필이 업데이트되었습니다.",
            "user": {...}
        }
    }
    """
    try:
        # 현재 로그인한 사용자와 요청하는 user_id가 일치하는지 확인
        if g.user_id != user_id:
            return jsonify({
                "status": "error",
                "message": "자신의 프로필만 변경할 수 있습니다."
            }), 403

        data = request.get_json()

        # 업데이트할 필드 수집
        update_data = {}
        if 'name' in data and data['name']:
            update_data['name'] = data['name'].strip()
        if 'department' in data and data['department']:
            update_data['department'] = data['department']
        if 'grade' in data and data['grade'] is not None:
            update_data['grade'] = int(data['grade'])

        if not update_data:
            return jsonify({
                "status": "error",
                "message": "변경할 필드가 없습니다."
            }), 400

        supabase = SupabaseService()

        # users 테이블 업데이트
        result = supabase.client.table("users")\
            .update(update_data)\
            .eq("id", user_id)\
            .execute()

        if not result.data:
            return jsonify({
                "status": "error",
                "message": "프로필 업데이트에 실패했습니다."
            }), 500

        # 학과/학년이 변경된 경우 임베딩 재생성
        if 'department' in update_data or 'grade' in update_data:
            try:
                # 현재 카테고리 조회
                pref_result = supabase.client.table("user_preferences")\
                    .select("categories")\
                    .eq("user_id", user_id)\
                    .single()\
                    .execute()

                if pref_result.data and pref_result.data.get("categories"):
                    updated_user = result.data[0]
                    interests_embedding, enriched_profile = _generate_user_embedding_and_profile(
                        department=updated_user.get("department", ""),
                        categories=pref_result.data["categories"],
                        grade=updated_user.get("grade")
                    )

                    pref_update = {}
                    if interests_embedding:
                        pref_update["interests_embedding"] = interests_embedding
                    if enriched_profile:
                        pref_update["enriched_profile"] = enriched_profile

                    if pref_update:
                        supabase.client.table("user_preferences")\
                            .update(pref_update)\
                            .eq("user_id", user_id)\
                            .execute()
            except Exception as embed_err:
                print(f"[임베딩] 프로필 변경 후 임베딩 재생성 실패 (무시): {embed_err}")

        print(f"[프로필 업데이트] 완료: {user_id} - {update_data}")

        return jsonify({
            "status": "success",
            "data": {
                "message": "프로필이 업데이트되었습니다.",
                "user": result.data[0]
            }
        }), 200

    except Exception as e:
        print(f"[ERROR] 프로필 업데이트 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "프로필 업데이트에 실패했습니다."
        }), 500


@users_bp.route('/preferences/<user_id>', methods=['PUT'])
@login_required
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
        # 현재 로그인한 사용자와 요청하는 user_id가 일치하는지 확인
        if g.user_id != user_id:
            return jsonify({
                "status": "error",
                "message": "자신의 선호도만 변경할 수 있습니다."
            }), 403

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

        # 사용자 정보 조회 (임베딩 생성에 필요)
        user_result = supabase.client.table("users")\
            .select("department, grade")\
            .eq("id", user_id)\
            .execute()

        department = ""
        grade = None
        if user_result.data:
            department = user_result.data[0].get("department", "")
            grade = user_result.data[0].get("grade")

        # 관심사 임베딩 + enriched_profile 재생성
        interests_embedding, enriched_profile = _generate_user_embedding_and_profile(
            department=department,
            categories=categories,
            grade=grade
        )

        # user_preferences 테이블 업데이트
        update_data = {"categories": categories}
        if interests_embedding:
            update_data["interests_embedding"] = interests_embedding
        if enriched_profile:
            update_data["enriched_profile"] = enriched_profile

        result = supabase.client.table("user_preferences")\
            .update(update_data)\
            .eq("user_id", user_id)\
            .execute()

        if not result.data:
            return jsonify({
                "status": "error",
                "message": "선호도 업데이트에 실패했습니다."
            }), 500

        print(f"[선호도 업데이트] 완료: {user_id} - {len(categories)}개 카테고리, 임베딩 갱신: {'성공' if interests_embedding else '실패'}")

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
            "message": "선호도 업데이트에 실패했습니다."
        }), 500


@users_bp.route('/preferences/<user_id>/notification-settings', methods=['PUT'])
@login_required
def update_notification_settings(user_id):
    """
    알림 설정을 업데이트합니다

    PUT /api/users/preferences/<user_id>/notification-settings
    Body (JSON):
    {
        "notification_mode": "all_on",
        "deadline_reminder_days": 3
    }

    notification_mode 옵션:
    - "all_off": 모든 알림 끄기
    - "schedule_only": 일정 알림만
    - "notice_only": 공지 알림만
    - "all_on": 모든 알림 켜기

    deadline_reminder_days: 1~7 (마감 며칠 전 알림)

    응답:
    {
        "status": "success",
        "data": {
            "message": "알림 설정이 업데이트되었습니다.",
            "settings": {
                "notification_mode": "all_on",
                "deadline_reminder_days": 3
            }
        }
    }
    """
    try:
        if g.user_id != user_id:
            return jsonify({
                "status": "error",
                "message": "자신의 설정만 변경할 수 있습니다."
            }), 403

        data = request.get_json()

        # 유효한 알림 모드 검증
        valid_modes = ['all_off', 'schedule_only', 'notice_only', 'all_on']
        update_data = {}

        if 'notification_mode' in data:
            mode = data['notification_mode']
            if mode not in valid_modes:
                return jsonify({
                    "status": "error",
                    "message": f"유효하지 않은 알림 모드입니다. 가능한 값: {valid_modes}"
                }), 400
            update_data['notification_mode'] = mode

        if 'deadline_reminder_days' in data:
            try:
                days = int(data['deadline_reminder_days'])
            except (ValueError, TypeError):
                return jsonify({
                    "status": "error",
                    "message": "deadline_reminder_days는 정수여야 합니다."
                }), 400
            if days < 1 or days > 7:
                return jsonify({
                    "status": "error",
                    "message": "deadline_reminder_days는 1~7 사이여야 합니다."
                }), 400
            update_data['deadline_reminder_days'] = days

        if not update_data:
            return jsonify({
                "status": "error",
                "message": "변경할 설정이 없습니다."
            }), 400

        supabase = SupabaseService()

        result = supabase.client.table("user_preferences")\
            .update(update_data)\
            .eq("user_id", user_id)\
            .execute()

        if not result.data:
            return jsonify({
                "status": "error",
                "message": "알림 설정 업데이트에 실패했습니다."
            }), 500

        print(f"[알림 설정] 업데이트 완료: {user_id} - {update_data}")

        return jsonify({
            "status": "success",
            "data": {
                "message": "알림 설정이 업데이트되었습니다.",
                "settings": update_data
            }
        }), 200

    except Exception as e:
        print(f"[ERROR] 알림 설정 업데이트 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "알림 설정 업데이트에 실패했습니다."
        }), 500


@users_bp.route('/preferences/<user_id>/notification-settings', methods=['GET'])
@login_required
def get_notification_settings(user_id):
    """
    알림 설정을 조회합니다

    GET /api/users/preferences/<user_id>/notification-settings

    응답:
    {
        "status": "success",
        "data": {
            "notification_mode": "all_on",
            "deadline_reminder_days": 3
        }
    }
    """
    try:
        if g.user_id != user_id:
            return jsonify({
                "status": "error",
                "message": "자신의 설정만 조회할 수 있습니다."
            }), 403

        supabase = SupabaseService()

        result = supabase.client.table("user_preferences")\
            .select("notification_mode, deadline_reminder_days")\
            .eq("user_id", user_id)\
            .single()\
            .execute()

        if not result.data:
            return jsonify({
                "status": "success",
                "data": {
                    "notification_mode": "all_on",
                    "deadline_reminder_days": 3
                }
            }), 200

        return jsonify({
            "status": "success",
            "data": result.data
        }), 200

    except Exception as e:
        print(f"[ERROR] 알림 설정 조회 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "알림 설정 조회에 실패했습니다."
        }), 500


@users_bp.route('/profile/<user_id>', methods=['DELETE'])
@login_required
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
        # 현재 로그인한 사용자와 요청하는 user_id가 일치하는지 확인
        if g.user_id != user_id:
            return jsonify({
                "status": "error",
                "message": "자신의 계정만 삭제할 수 있습니다."
            }), 403

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
            "message": "사용자 삭제에 실패했습니다."
        }), 500


@users_bp.route('/find-email', methods=['POST'])
def find_email():
    """
    아이디(이메일) 찾기

    학번과 이름으로 사용자의 마스킹된 이메일을 조회합니다.
    인증 불필요 (비로그인 상태에서 사용)
    """
    try:
        data = request.get_json()

        # 필수 필드 검증
        if not data or 'student_id' not in data or 'name' not in data:
            return jsonify({
                "status": "error",
                "message": "학번과 이름을 입력해주세요."
            }), 400

        student_id = data['student_id'].strip()
        name = data['name'].strip()

        if not student_id or not name:
            return jsonify({
                "status": "error",
                "message": "학번과 이름을 입력해주세요."
            }), 400

        # Supabase에서 학번 + 이름으로 사용자 조회
        supabase = SupabaseService()
        result = supabase.client.table("users") \
            .select("email") \
            .eq("student_id", student_id) \
            .eq("name", name) \
            .execute()

        if not result.data:
            return jsonify({
                "status": "error",
                "message": "일치하는 사용자를 찾을 수 없습니다."
            }), 404

        # 이메일 마스킹 처리
        email = result.data[0]['email']
        masked_email = _mask_email(email)

        print(f"[아이디 찾기] 조회 완료: {student_id} / {name} -> {masked_email}")

        return jsonify({
            "status": "success",
            "data": {
                "masked_email": masked_email
            }
        }), 200

    except Exception as e:
        print(f"[ERROR] 아이디 찾기 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": "아이디 찾기에 실패했습니다."
        }), 500


def _mask_email(email: str) -> str:
    """
    이메일 주소를 마스킹합니다. 실제 길이에 맞게 *를 표시합니다.
    예시: "hong@..." -> "h***@...", "honggildong@..." -> "hon********@..."
    """
    try:
        local_part, domain = email.split('@')
        if len(local_part) <= 2:
            masked_local = local_part[0] + '*' * (len(local_part) - 1)
        else:
            show = max(1, len(local_part) // 3)
            masked_local = local_part[:show] + '*' * (len(local_part) - show)
        return f"{masked_local}@{domain}"
    except Exception:
        return '***@***'
