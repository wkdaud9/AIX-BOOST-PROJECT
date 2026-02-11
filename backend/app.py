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
app.url_map.strict_slashes = False  # trailing slash 리다이렉트 비활성화 (CORS 호환)
CORS(app)  # CORS 설정 (Flutter 웹 클라이언트와 통신)

# 기본 설정
app.config['JSON_AS_ASCII'] = False  # 한글 JSON 응답 지원
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')

# Blueprint 등록 (API 라우트)
from routes.notices import notices_bp
from routes.users import users_bp
from routes.crawl import crawl_bp
from routes.search import search_bp
from routes.calendar import calendar_bp
from routes.bookmarks import bookmarks_bp
from routes.notifications import notifications_bp
app.register_blueprint(notices_bp)
app.register_blueprint(users_bp)
app.register_blueprint(crawl_bp)
app.register_blueprint(search_bp)
app.register_blueprint(calendar_bp)
app.register_blueprint(bookmarks_bp)
app.register_blueprint(notifications_bp)

# 스케줄러 초기화 (15분마다 자동 크롤링)
# Flask debug 모드에서 reloader가 프로세스를 2개 생성하므로,
# 실제 워커 프로세스에서만 스케줄러를 시작합니다 (중복 실행 방지).
from services.scheduler_service import SchedulerService
scheduler = SchedulerService()

if not app.debug or os.environ.get('WERKZEUG_RUN_MAIN') == 'true':
    scheduler.start()


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


@app.route('/scheduler/status')
def scheduler_status():
    """스케줄러 상태 확인 엔드포인트"""
    jobs = scheduler.get_jobs()
    return jsonify({
        "status": "success",
        "data": {
            "is_running": scheduler.is_running,
            "jobs": jobs
        }
    })


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'

    print(f"[AIX-Boost] Backend starting on port {port}")
    print(f"[AIX-Boost] Server running at http://localhost:{port}")
    app.run(host='0.0.0.0', port=port, debug=debug)
