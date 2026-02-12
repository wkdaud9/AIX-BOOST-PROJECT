# -*- coding: utf-8 -*-
"""
크롤링 API 라우트

이 파일이 하는 일:
크롤링 파이프라인을 실행하고 상태를 조회하는 API를 제공합니다.
"""

from flask import Blueprint, jsonify, request
from datetime import datetime, timezone
import threading

from utils.auth_middleware import login_required

# Blueprint 생성
crawl_bp = Blueprint('crawl', __name__, url_prefix='/api/crawl')

# 크롤링 상태 추적 (Lock으로 스레드 안전 보장)
_crawl_lock = threading.Lock()
crawl_status = {
    "is_running": False,
    "last_run": None,
    "last_result": None
}


@crawl_bp.route('', methods=['POST'])
@login_required
def trigger_crawl():
    """
    크롤링 파이프라인을 수동으로 실행합니다.

    백그라운드 스레드에서 실행되므로 즉시 응답을 반환합니다.
    인증 필수 (Authorization: Bearer <token>)
    """
    with _crawl_lock:
        if crawl_status["is_running"]:
            return jsonify({
                "status": "error",
                "message": "크롤링이 이미 실행 중입니다"
            }), 409
        crawl_status["is_running"] = True

    # 백그라운드에서 크롤링 실행
    thread = threading.Thread(target=run_crawl_pipeline)
    thread.daemon = True
    thread.start()

    return jsonify({
        "status": "success",
        "message": "크롤링 파이프라인이 백그라운드에서 시작되었습니다"
    })


@crawl_bp.route('/status', methods=['GET'])
def get_crawl_status():
    """크롤링 상태 조회"""
    return jsonify({
        "status": "success",
        "data": crawl_status
    })


def run_crawl_pipeline():
    """크롤링 파이프라인 실행 (백그라운드 스레드)"""
    import sys
    import os

    # 프로젝트 루트를 Python 경로에 추가
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sys.path.insert(0, project_root)

    crawl_status["last_run"] = datetime.now(timezone.utc).isoformat()

    try:
        print("\n크롤링 파이프라인 시작...")

        from scripts.crawl_and_notify import CrawlAndNotifyPipeline
        pipeline = CrawlAndNotifyPipeline()
        pipeline.run()

        crawl_status["last_result"] = {
            "status": "success",
            "message": "크롤링 완료",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        print("크롤링 파이프라인 완료!")

    except Exception as e:
        print(f"크롤링 실패: {str(e)}")
        import traceback
        traceback.print_exc()

        crawl_status["last_result"] = {
            "status": "error",
            "message": "크롤링에 실패했습니다.",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

    finally:
        with _crawl_lock:
            crawl_status["is_running"] = False
