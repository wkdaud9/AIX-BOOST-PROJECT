# -*- coding: utf-8 -*-
"""
인증 미들웨어
API 요청 시 Authorization 헤더의 JWT 토큰을 검증합니다.
"""

from functools import wraps
from flask import request, jsonify, g
from services.supabase_service import SupabaseService

def login_required(f):
    """
    로그인이 필요한 엔드포인트에 적용하는 데코레이터
    
    사용법:
    @app.route('/protected-api')
    @login_required
    def protected_route():
        current_user = g.user
        ...
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # 헤더에서 토큰 추출
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({
                "status": "error",
                "message": "인증 토큰이 필요합니다 (Authorization Header missing)"
            }), 401
        
        try:
            # Bearer <token> 형식 파싱
            parts = auth_header.split()
            if parts[0].lower() != "bearer" or len(parts) != 2:
                return jsonify({
                    "status": "error",
                    "message": "잘못된 인증 헤더 형식입니다 (Bearer Token 필요)"
                }), 401
            
            token = parts[1]
            
            # Supabase를 통해 토큰 검증 및 사용자 정보 조회
            # get_user 함수는 토큰이 유효하지 않으면 에러를 발생시킴
            supabase = SupabaseService()
            user_response = supabase.client.auth.get_user(token)
            
            if not user_response or not user_response.user:
                raise Exception("User info validation failed")
                
            # Flask 전역 객체 g에 사용자 정보 저장
            g.user = user_response.user
            
        except Exception as e:
            # 토큰 만료, 서명 불일치 등
            print(f"[Auth Error] {str(e)}")
            return jsonify({
                "status": "error",
                "message": "유효하지 않거나 만료된 토큰입니다"
            }), 401
            
        return f(*args, **kwargs)
        
    return decorated_function
