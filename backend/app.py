# -*- coding: utf-8 -*-
"""
AIX-Boost Backend - 메인 서버 진입점
Flask 애플리케이션의 핵심 라우팅 및 서버 설정을 담당합니다.
"""

from flask import Flask, jsonify
from flask_cors import CORS
import os
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()

# Flask 앱 초기화
app = Flask(__name__)
CORS(app)  # CORS 설정 (Flutter 웹 클라이언트와 통신)

# 기본 설정
app.config['JSON_AS_ASCII'] = False  # 한글 JSON 응답 지원
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')


@app.route('/')
def index():
    """서버 상태 확인 엔드포인트"""
    return jsonify({
        "status": "success",
        "data": {
            "message": "AIX-Boost API Server is running",
            "version": "1.0.0"
        }
    })


@app.route('/health')
def health_check():
    """헬스 체크 엔드포인트"""
    return jsonify({
        "status": "success",
        "data": {
            "health": "ok"
        }
    })


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'

    print(f"🚀 AIX-Boost Backend starting on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)
