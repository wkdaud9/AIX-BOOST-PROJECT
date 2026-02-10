# -*- coding: utf-8 -*-
"""
검색 API 라우트

이 파일이 하는 일:
하이브리드 검색 기반의 공지사항 검색 API를 제공합니다.

주요 엔드포인트:
- GET /api/search/notices: 사용자 맞춤 공지사항 검색
- GET /api/search/notices/keyword: 키워드 기반 벡터 검색
"""

from flask import Blueprint, request, jsonify, g
from typing import Dict, Any
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.hybrid_search_service import HybridSearchService
from services.reranking_service import RerankingService
from services.supabase_service import SupabaseService
from utils.auth_middleware import login_required

# Blueprint 생성 (URL 접두사: /api/search)
search_bp = Blueprint('search', __name__, url_prefix='/api/search')


@search_bp.route('/notices', methods=['GET'])
@login_required
def search_personalized_notices():
    """
    사용자 맞춤 공지사항을 검색합니다.

    GET /api/search/notices?limit=20&min_score=0.3&rerank=true

    쿼리 파라미터:
    - limit: 최대 결과 수 (기본값: 20)
    - min_score: 최소 관련도 점수 (기본값: 0.3)
    - rerank: AI 리랭킹 적용 여부 (기본값: false)

    응답:
    {
        "status": "success",
        "data": {
            "notices": [
                {
                    "notice_id": "uuid",
                    "title": "공지사항 제목",
                    "ai_summary": "AI 요약",
                    "category": "학사",
                    "total_score": 0.85,
                    "hard_filter_score": 0.3,
                    "vector_score": 0.55,
                    "ai_score": 0.9,
                    "ai_reason": "학과 일치"
                }
            ],
            "total": 15,
            "user_id": "user_uuid"
        }
    }
    """
    try:
        # 인증된 사용자 ID
        user_id = g.user_id

        # 쿼리 파라미터
        limit = int(request.args.get('limit', 20))
        min_score = float(request.args.get('min_score', 0.3))
        rerank = request.args.get('rerank', 'false').lower() == 'true'

        print(f"\n[검색] 사용자 맞춤 공지 검색")
        print(f"   - 사용자: {user_id[:8]}...")
        print(f"   - 제한: {limit}개, 최소점수: {min_score}")
        print(f"   - 리랭킹: {rerank}")

        # 하이브리드 검색
        search_service = HybridSearchService()
        results = search_service.find_relevant_notices_for_user(
            user_id=user_id,
            limit=limit,
            min_score=min_score
        )

        # 리랭킹 적용 (옵션)
        if rerank and len(results) > 5:
            reranking_service = RerankingService()
            if reranking_service.should_rerank(results):
                results = reranking_service.rerank_notices_for_user(
                    user_id=user_id,
                    candidate_notices=results
                )

        print(f"   - 결과: {len(results)}개")

        return jsonify({
            "status": "success",
            "data": {
                "notices": results,
                "total": len(results),
                "user_id": user_id
            }
        }), 200

    except Exception as e:
        print(f"[에러] 검색 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@search_bp.route('/notices/keyword', methods=['GET'])
def search_by_keyword():
    """
    키워드로 공지사항을 검색합니다 (벡터 검색).

    GET /api/search/notices/keyword?q=장학금&limit=10&min_score=0.3

    쿼리 파라미터:
    - q: 검색 키워드 (필수)
    - limit: 최대 결과 수 (기본값: 10)
    - min_score: 최소 유사도 점수 (기본값: 0.3)

    응답:
    {
        "status": "success",
        "data": {
            "notices": [
                {
                    "id": "uuid",
                    "title": "2024학년도 국가장학금 신청 안내",
                    "ai_summary": "국가장학금 1월 2일부터 신청 시작",
                    "category": "장학",
                    "similarity": 0.85
                }
            ],
            "total": 5,
            "query": "장학금"
        }
    }
    """
    try:
        # 쿼리 파라미터
        query = request.args.get('q', '').strip()
        limit = int(request.args.get('limit', 10))
        min_score = float(request.args.get('min_score', 0.3))

        # 검색어 검증
        if not query or len(query) < 2:
            return jsonify({
                "status": "error",
                "message": "검색어(q)는 2자 이상이어야 합니다"
            }), 400

        print(f"\n[검색] 키워드 검색: '{query}'")
        print(f"   - 제한: {limit}개, 최소점수: {min_score}")

        # 벡터 검색
        search_service = HybridSearchService()
        results = search_service.search_by_keyword(
            query=query,
            limit=limit,
            min_score=min_score
        )

        print(f"   - 결과: {len(results)}개")

        return jsonify({
            "status": "success",
            "data": {
                "notices": results,
                "total": len(results),
                "query": query
            }
        }), 200

    except Exception as e:
        print(f"[에러] 키워드 검색 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@search_bp.route('/notices/relevant-users', methods=['GET'])
@login_required
def find_relevant_users():
    """
    공지사항에 관련된 사용자를 검색합니다 (관리자용).

    GET /api/search/notices/relevant-users?notice_id=uuid&min_score=0.5&max_users=50

    쿼리 파라미터:
    - notice_id: 공지사항 ID (필수)
    - min_score: 최소 관련도 점수 (기본값: 0.5)
    - max_users: 최대 사용자 수 (기본값: 50)
    - rerank: AI 리랭킹 적용 여부 (기본값: false)

    응답:
    {
        "status": "success",
        "data": {
            "users": [
                {
                    "user_id": "uuid",
                    "department": "컴퓨터정보공학과",
                    "grade": 3,
                    "total_score": 0.85,
                    "hard_filter_score": 0.3,
                    "vector_score": 0.55
                }
            ],
            "total": 25,
            "notice_id": "uuid"
        }
    }
    """
    try:
        # 쿼리 파라미터
        notice_id = request.args.get('notice_id', '').strip()
        min_score = float(request.args.get('min_score', 0.5))
        max_users = int(request.args.get('max_users', 50))
        rerank = request.args.get('rerank', 'false').lower() == 'true'

        # notice_id 검증
        if not notice_id:
            return jsonify({
                "status": "error",
                "message": "notice_id는 필수입니다"
            }), 400

        print(f"\n[검색] 관련 사용자 검색")
        print(f"   - 공지: {notice_id[:8]}...")
        print(f"   - 최대: {max_users}명, 최소점수: {min_score}")

        # 하이브리드 검색
        search_service = HybridSearchService()
        results = search_service.find_relevant_users(
            notice_id=notice_id,
            min_score=min_score,
            max_users=max_users
        )

        # 리랭킹 적용 (옵션)
        if rerank and len(results) > 5:
            reranking_service = RerankingService()
            if reranking_service.should_rerank(results):
                results = reranking_service.rerank_users_for_notice(
                    notice_id=notice_id,
                    candidate_users=results
                )

        print(f"   - 결과: {len(results)}명")

        return jsonify({
            "status": "success",
            "data": {
                "users": results,
                "total": len(results),
                "notice_id": notice_id
            }
        }), 200

    except Exception as e:
        print(f"[에러] 관련 사용자 검색 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@search_bp.route('/notices/all', methods=['GET'])
def search_all_notices():
    """
    전체 공지사항 검색 (공개 API)

    GET /api/search/notices/all?q=장학금&category=학사&date_from=2026-01-01&date_to=2026-02-28&sort=latest&page=1&limit=20

    쿼리 파라미터:
    - q: 검색어 (제목, 내용 ILIKE 검색) - 선택
    - category: 카테고리 필터 - 선택
    - date_from: 시작일 필터 (YYYY-MM-DD) - 선택
    - date_to: 종료일 필터 (YYYY-MM-DD) - 선택
    - sort: 정렬 기준 (latest|views) - 기본값: latest
    - page: 페이지 번호 (기본값: 1)
    - limit: 페이지당 결과 수 (기본값: 20, 최대 100)

    응답:
    {
        "status": "success",
        "data": {
            "notices": [...],
            "total": 150,
            "page": 1,
            "total_pages": 8
        }
    }
    """
    try:
        # 쿼리 파라미터 파싱
        q = request.args.get('q', '').strip()
        category = request.args.get('category', '').strip()
        date_from = request.args.get('date_from', '').strip()
        date_to = request.args.get('date_to', '').strip()
        sort = request.args.get('sort', 'latest').strip()
        page = max(1, int(request.args.get('page', 1)))
        limit = min(100, max(1, int(request.args.get('limit', 20))))

        # 오프셋 계산
        offset = (page - 1) * limit

        print(f"\n[검색] 전체 검색 API")
        print(f"   - 검색어: '{q}', 카테고리: '{category}'")
        print(f"   - 기간: {date_from} ~ {date_to}")
        print(f"   - 정렬: {sort}, 페이지: {page}, 제한: {limit}")

        supabase_service = SupabaseService()

        # 총 개수 조회용 쿼리
        count_query = supabase_service.client.table("notices")\
            .select("id", count="exact")

        # 데이터 조회용 쿼리
        data_query = supabase_service.client.table("notices")\
            .select("id, title, content, ai_summary, category, source_url, "
                    "published_at, author, view_count, deadline, display_mode, "
                    "has_important_image, content_images, bookmark_count")

        # 검색어 필터 (제목 또는 내용 ILIKE)
        if q:
            escaped_q = q.replace("%", "\\%").replace("_", "\\_")
            filter_str = f"title.ilike.%{escaped_q}%,content.ilike.%{escaped_q}%"
            count_query = count_query.or_(filter_str)
            data_query = data_query.or_(filter_str)

        # 카테고리 필터
        if category:
            count_query = count_query.eq("category", category)
            data_query = data_query.eq("category", category)

        # 날짜 범위 필터
        if date_from:
            count_query = count_query.gte("published_at", date_from)
            data_query = data_query.gte("published_at", date_from)
        if date_to:
            count_query = count_query.lte("published_at", date_to + "T23:59:59")
            data_query = data_query.lte("published_at", date_to + "T23:59:59")

        # 총 개수 조회
        count_result = count_query.execute()
        total = count_result.count if count_result.count is not None else 0

        # 정렬 적용
        if sort == 'views':
            data_query = data_query.order("view_count", desc=True)
        else:
            data_query = data_query.order("published_at", desc=True)

        # 페이지네이션 적용
        data_query = data_query.range(offset, offset + limit - 1)

        # 데이터 조회
        result = data_query.execute()
        notices = result.data or []

        # 총 페이지 수 계산
        total_pages = (total + limit - 1) // limit if total > 0 else 0

        print(f"   - 결과: {len(notices)}개 / 총 {total}개")

        return jsonify({
            "status": "success",
            "data": {
                "notices": notices,
                "total": total,
                "page": page,
                "total_pages": total_pages
            }
        }), 200

    except ValueError as ve:
        return jsonify({
            "status": "error",
            "message": f"잘못된 파라미터: {str(ve)}"
        }), 400
    except Exception as e:
        print(f"[에러] 전체 검색 실패: {str(e)}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@search_bp.route('/health', methods=['GET'])
def health_check():
    """
    검색 서비스 헬스 체크

    GET /api/search/health

    응답:
    {
        "status": "success",
        "data": {
            "service": "search",
            "embedding": true,
            "database": true
        }
    }
    """
    try:
        # 서비스 초기화 테스트
        search_service = HybridSearchService()

        return jsonify({
            "status": "success",
            "data": {
                "service": "search",
                "embedding": True,
                "database": True
            }
        }), 200

    except Exception as e:
        return jsonify({
            "status": "error",
            "data": {
                "service": "search",
                "error": str(e)
            }
        }), 500
