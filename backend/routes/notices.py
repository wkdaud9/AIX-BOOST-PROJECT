# -*- coding: utf-8 -*-
"""
공지사항 API 라우트

이 파일이 하는 일:
공지사항 관련 API 엔드포인트를 제공합니다.
"""

from flask import Blueprint, request, jsonify, Response, g
from typing import Dict, Any
import requests as http_requests
from services.supabase_service import SupabaseService
from crawler.crawler_manager import CrawlerManager
from utils.auth_middleware import login_required, optional_login

# Blueprint 생성 (URL 접두사: /api/notices)
notices_bp = Blueprint('notices', __name__, url_prefix='/api/notices')


@notices_bp.route('/crawl', methods=['POST'])
@login_required
def crawl_and_save():
    """
    공지사항을 크롤링하고 DB에 저장합니다

    POST /api/notices/crawl
    Body (JSON):
    {
        "max_pages": 2,  # 선택, 기본값 1
        "categories": ["공지사항", "학사/장학"]  # 선택, 기본값 전체
    }

    응답:
    {
        "status": "success",
        "data": {
            "crawled": 30,
            "inserted": 25,
            "duplicates": 5,
            "errors": 0
        }
    }
    """
    try:
        # 요청 데이터 가져오기
        data = request.get_json() or {}
        max_pages = data.get('max_pages', 1)
        categories = data.get('categories', None)

        print(f"\n{'='*60}")
        print(f"[크롤링] 공지사항 크롤링 시작")
        print(f"   - 최대 페이지: {max_pages}")
        print(f"   - 카테고리: {categories or '전체'}")
        print(f"{'='*60}\n")

        # 크롤러 실행
        manager = CrawlerManager()

        if categories:
            # 특정 카테고리만 크롤링
            all_notices = []
            for category in categories:
                notices = manager.crawl_category(category, max_pages=max_pages)
                all_notices.extend(notices)
        else:
            # 전체 크롤링
            results = manager.crawl_all(max_pages=max_pages)
            all_notices = []
            for category_notices in results.values():
                all_notices.extend(category_notices)

        print(f"\n[완료] 크롤링 완료: {len(all_notices)}개 수집")

        # DB에 저장
        if all_notices:
            print(f"\n{'='*60}")
            print(f"[저장] DB 저장 시작")
            print(f"{'='*60}\n")

            supabase = SupabaseService()
            save_result = supabase.insert_notices(all_notices)

            print(f"\n{'='*60}")
            print(f"[완료] DB 저장 완료")
            print(f"   - 삽입: {save_result['inserted']}개")
            print(f"   - 중복: {save_result['duplicates']}개")
            print(f"   - 에러: {save_result['errors']}개")
            print(f"{'='*60}\n")

            return jsonify({
                "status": "success",
                "data": {
                    "crawled": len(all_notices),
                    "inserted": save_result['inserted'],
                    "duplicates": save_result['duplicates'],
                    "errors": save_result['errors']
                }
            }), 200
        else:
            return jsonify({
                "status": "error",
                "message": "크롤링된 데이터가 없습니다"
            }), 400

    except Exception as e:
        print(f"[ERROR] 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@notices_bp.route('/', methods=['GET'])
@optional_login
def get_notices():
    """
    공지사항 목록을 조회합니다

    GET /api/notices?category=공지사항&limit=20&offset=0

    쿼리 파라미터:
    - category: 카테고리 필터 (선택)
    - limit: 가져올 개수 (기본 20)
    - offset: 건너뛸 개수 (기본 0)

    응답:
    {
        "status": "success",
        "data": [
            {
                "id": "uuid",
                "title": "제목",
                "content": "내용",
                "category": "공지사항",
                "published_at": "2024-01-01T00:00:00",
                "bookmark_count": 5,
                "is_bookmarked": true,
                ...
            }
        ],
        "pagination": {
            "limit": 20,
            "offset": 0,
            "total": 100
        }
    }
    """
    try:
        # 쿼리 파라미터 가져오기
        category = request.args.get('category', None)
        limit = int(request.args.get('limit', 20))
        offset = int(request.args.get('offset', 0))
        user_id = g.user_id  # optional_login으로 설정됨 (없으면 None)

        # Supabase에서 조회
        supabase = SupabaseService()
        notices = supabase.get_notices(
            category=category,
            limit=limit,
            offset=offset,
            user_id=user_id
        )

        return jsonify({
            "status": "success",
            "data": notices,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "count": len(notices)
            }
        }), 200

    except Exception as e:
        print(f"[ERROR] 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@notices_bp.route('/<notice_id>', methods=['GET'])
def get_notice(notice_id):
    """
    특정 공지사항을 조회합니다

    GET /api/notices/{notice_id}

    응답:
    {
        "status": "success",
        "data": {
            "id": "uuid",
            "title": "제목",
            "content": "내용",
            ...
        }
    }
    """
    try:
        supabase = SupabaseService()
        notice = supabase.get_notice_by_id(notice_id)

        if notice:
            return jsonify({
                "status": "success",
                "data": notice
            }), 200
        else:
            return jsonify({
                "status": "error",
                "message": "공지사항을 찾을 수 없습니다"
            }), 404

    except Exception as e:
        print(f"[ERROR] 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@notices_bp.route('/<notice_id>', methods=['DELETE'])
@login_required
def delete_notice(notice_id):
    """
    공지사항을 삭제합니다

    DELETE /api/notices/{notice_id}

    응답:
    {
        "status": "success",
        "message": "삭제되었습니다"
    }
    """
    try:
        supabase = SupabaseService()
        success = supabase.delete_notice(notice_id)

        if success:
            return jsonify({
                "status": "success",
                "message": "삭제되었습니다"
            }), 200
        else:
            return jsonify({
                "status": "error",
                "message": "삭제 실패"
            }), 400

    except Exception as e:
        print(f"[ERROR] 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@notices_bp.route('/stats', methods=['GET'])
def get_statistics():
    """
    공지사항 통계를 조회합니다

    GET /api/notices/stats

    응답:
    {
        "status": "success",
        "data": {
            "total": 150,
            "by_category": {
                "공지사항": 100,
                "학사/장학": 30,
                "모집공고": 20
            }
        }
    }
    """
    try:
        supabase = SupabaseService()
        stats = supabase.get_statistics()

        return jsonify({
            "status": "success",
            "data": stats
        }), 200

    except Exception as e:
        print(f"[ERROR] 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@notices_bp.route('/image-proxy', methods=['GET'])
def proxy_image():
    """
    학교 서버 이미지 프록시 (CORS/핫링크 차단 우회)

    GET /api/notices/image-proxy?url=https://www.kunsan.ac.kr/upload_data/...

    학교 서버가 외부 직접 접근을 차단하므로,
    백엔드에서 이미지를 가져와 클라이언트에 전달합니다.
    """
    image_url = request.args.get('url', '')

    # 보안: 군산대 도메인만 허용
    if not image_url.startswith('https://www.kunsan.ac.kr/'):
        return jsonify({
            "status": "error",
            "message": "허용되지 않는 URL입니다"
        }), 403

    try:
        # 학교 서버에 Referer 포함하여 요청
        resp = http_requests.get(
            image_url,
            headers={
                'Referer': 'https://www.kunsan.ac.kr/',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
            timeout=10,
        )

        if resp.status_code != 200:
            return jsonify({
                "status": "error",
                "message": f"이미지 로드 실패: {resp.status_code}"
            }), 502

        # 이미지 바이너리 응답 (1일 캐시)
        content_type = resp.headers.get('Content-Type', 'image/png')
        return Response(
            resp.content,
            content_type=content_type,
            headers={
                'Cache-Control': 'public, max-age=86400',
            },
        )

    except Exception as e:
        print(f"[ERROR] 이미지 프록시 에러: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500
