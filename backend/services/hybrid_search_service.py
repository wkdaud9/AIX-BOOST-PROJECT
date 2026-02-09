# -*- coding: utf-8 -*-
"""
하이브리드 검색 서비스 모듈

이 파일이 하는 일:
3단계 검색 파이프라인으로 공지사항과 사용자를 매칭합니다.

1단계: 하드 필터링
   - 학과, 학년이 맞지 않는 공지 제외
   - SQL WHERE 절로 빠르게 처리

2단계: 벡터 검색
   - 남은 공지 중 의미적으로 유사한 것 추출
   - 코사인 유사도 계산

3단계: 점수 결합
   - 하드 필터 보너스 + 벡터 유사도 점수 결합
   - 최종 순위 결정

왜 하이브리드인가?
- 벡터만: "경영학과" 공지가 "컴공과" 학생에게도 높은 점수
- 하드 필터만: 의미적 유사도 무시
- 하이브리드: 두 장점을 결합
"""

import os
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from supabase import create_client, Client
from dotenv import load_dotenv

import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai.embedding_service import EmbeddingService

load_dotenv()


class HybridSearchService:
    """
    하이브리드 검색 서비스

    주요 기능:
    1. find_relevant_notices_for_user: 사용자에게 맞는 공지 검색
    2. find_relevant_users: 공지에 맞는 사용자 검색 (알림용)
    3. search_by_keyword: 키워드 기반 벡터 검색
    """

    # 점수 가중치 기본값 (사용자-공지 매칭용)
    DEFAULT_WEIGHTS = {
        "hard_filter": 0.3,   # 하드 필터 매칭 보너스
        "vector": 0.7         # 벡터 유사도 비중
    }

    # 키워드 검색용 가중치 (제목 + 벡터 결합용)
    KEYWORD_SEARCH_WEIGHTS = {
        "title": 0.5,         # 제목 매칭 보너스
        "vector": 0.5         # 벡터 유사도 비중
    }

    def __init__(self):
        """하이브리드 검색 서비스 초기화"""
        # Supabase 클라이언트
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"),
            os.getenv("SUPABASE_KEY")
        )

        # 임베딩 서비스
        self.embedding_service = EmbeddingService()

        print("HybridSearchService 초기화 완료")

    def find_relevant_notices_for_user(
        self,
        user_id: str,
        limit: int = 20,
        min_score: float = 0.3,
        weights: Optional[Dict[str, float]] = None
    ) -> List[Dict[str, Any]]:
        """
        사용자에게 관련 있는 공지사항을 검색합니다.

        매개변수:
        - user_id: 사용자 ID
        - limit: 최대 결과 수
        - min_score: 최소 점수 (0~1)
        - weights: 점수 가중치 (hard_filter, vector)

        반환값:
        - 관련 공지사항 리스트 (점수 포함)

        검색 과정:
        1. 사용자 프로필 조회
        2. 하드 필터링 (학과, 학년)
        3. 벡터 검색 (관심사 매칭)
        4. 점수 결합 및 정렬
        """
        weights = weights or self.DEFAULT_WEIGHTS

        # 1. 사용자 프로필 조회
        user_profile = self._get_user_profile(user_id)
        if not user_profile:
            print(f"사용자를 찾을 수 없습니다: {user_id}")
            return []

        # 2. 하드 필터링
        hard_filtered = self._hard_filter_notices(
            department=user_profile.get("department"),
            grade=user_profile.get("grade")
        )

        # 3. 벡터 검색 (사용자 임베딩으로)
        user_embedding = user_profile.get("interests_embedding")
        if user_embedding:
            vector_results = self._vector_search_notices(
                query_embedding=user_embedding,
                notice_ids=[n["id"] for n in hard_filtered] if hard_filtered else None,
                limit=limit * 2
            )
        else:
            # 임베딩이 없으면 벡터 검색 스킵
            vector_results = []

        # 4. 점수 결합
        combined = self._combine_notice_scores(
            hard_filtered=hard_filtered,
            vector_results=vector_results,
            weights=weights
        )

        # 5. 필터링 및 정렬
        results = [
            r for r in combined
            if r["total_score"] >= min_score
        ]

        # 사용자 선택 카테고리에 해당하는 공지를 최상위에 배치
        user_categories = user_profile.get("categories", [])
        results.sort(key=lambda x: (
            1 if x.get("category") in user_categories else 0,
            x["total_score"]
        ), reverse=True)

        return results[:limit]

    def find_relevant_users(
        self,
        notice_id: str,
        min_score: float = 0.5,
        max_users: int = 50,
        weights: Optional[Dict[str, float]] = None
    ) -> List[Dict[str, Any]]:
        """
        공지사항에 관련 있는 사용자를 검색합니다 (알림 발송용).

        매개변수:
        - notice_id: 공지사항 ID
        - min_score: 최소 점수 (0~1)
        - max_users: 최대 사용자 수
        - weights: 점수 가중치

        반환값:
        - 관련 사용자 리스트 (점수 포함)

        검색 과정:
        1. 공지사항 정보 조회
        2. 하드 필터링 (대상 학과/학년에 해당하는 사용자)
        3. 벡터 검색 (관심사 매칭)
        4. 점수 결합 및 정렬
        """
        weights = weights or self.DEFAULT_WEIGHTS

        # 1. 공지사항 정보 조회
        notice = self._get_notice(notice_id)
        if not notice:
            print(f"공지사항을 찾을 수 없습니다: {notice_id}")
            return []

        enriched = notice.get("enriched_metadata") or {}

        # 2. 하드 필터링 (대상 학과/학년 매칭)
        candidate_users = self._hard_filter_users(
            target_departments=enriched.get("target_departments", []),
            target_grades=enriched.get("target_grades", []),
            is_for_all=enriched.get("is_for_all", False)
        )

        # 3. 벡터 검색 (공지 임베딩으로)
        notice_embedding = notice.get("content_embedding")
        if notice_embedding:
            vector_results = self._vector_search_users(
                notice_embedding=notice_embedding,
                user_ids=[u["id"] for u in candidate_users] if candidate_users else None,
                limit=max_users * 2
            )
        else:
            vector_results = []

        # 4. 점수 결합
        combined = self._combine_user_scores(
            hard_filtered=candidate_users,
            vector_results=vector_results,
            weights=weights,
            enriched=enriched
        )

        # 5. 필터링 및 정렬
        results = [
            r for r in combined
            if r["total_score"] >= min_score
        ]
        results.sort(key=lambda x: x["total_score"], reverse=True)

        return results[:max_users]

    def search_by_keyword(
        self,
        query: str,
        limit: int = 10,
        min_score: float = 0.3
    ) -> List[Dict[str, Any]]:
        """
        키워드로 공지사항을 검색합니다 (제목 + 벡터 하이브리드 검색).

        매개변수:
        - query: 검색 키워드
        - limit: 최대 결과 수
        - min_score: 최소 유사도 점수

        반환값:
        - 검색 결과 리스트 (공지사항 + 점수)

        검색 과정:
        1. 제목에서 키워드 포함 여부 확인 (ILIKE)
        2. 벡터 유사도 검색
        3. 두 결과 결합 (제목 매칭 보너스 + 벡터 점수)
        """
        if not query or len(query.strip()) < 2:
            return []

        query = query.strip()
        print(f"\n[검색] 하이브리드 키워드 검색: '{query}'")

        # 1. 제목 검색 (ILIKE)
        title_results = self._search_by_title(query, limit=limit * 2)
        print(f"   - 제목 매칭: {len(title_results)}개")

        # 2. 벡터 검색
        query_embedding = self.embedding_service.create_query_embedding(query)
        vector_results = self._vector_search_notices(
            query_embedding=query_embedding,
            limit=limit * 2
        )
        print(f"   - 벡터 매칭: {len(vector_results)}개")

        # 3. 결과 결합
        combined = self._combine_keyword_search_results(
            title_results=title_results,
            vector_results=vector_results,
            min_score=min_score
        )

        # 점수순 정렬 및 제한
        combined.sort(key=lambda x: x.get("total_score", 0), reverse=True)
        results = combined[:limit]

        print(f"   - 최종 결과: {len(results)}개")

        return results

    def _search_by_title(
        self,
        query: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        제목에서 키워드를 검색합니다 (ILIKE).

        매개변수:
        - query: 검색 키워드
        - limit: 최대 결과 수

        반환값:
        - 제목 매칭 결과 리스트
        """
        try:
            # ILIKE 와일드카드 문자 이스케이프 (%, _ 는 ILIKE 특수 패턴 문자)
            escaped_query = query.replace("%", "\\%").replace("_", "\\_")

            # ILIKE 검색 (대소문자 무시)
            result = self.supabase.table("notices")\
                .select("id, title, content, ai_summary, category, source_url, published_at, view_count")\
                .ilike("title", f"%{escaped_query}%")\
                .order("published_at", desc=True)\
                .limit(limit)\
                .execute()

            notices = result.data or []

            # 제목 매칭 점수 추가
            results = []
            for notice in notices:
                results.append({
                    "id": notice["id"],
                    "title": notice["title"],
                    "content": notice.get("content", ""),
                    "ai_summary": notice.get("ai_summary"),
                    "category": notice.get("category"),
                    "source_url": notice.get("source_url"),
                    "published_at": notice.get("published_at"),
                    "view_count": notice.get("view_count", 0),
                    "title_match": True,
                    "title_score": self.KEYWORD_SEARCH_WEIGHTS["title"]
                })

            return results

        except Exception as e:
            print(f"제목 검색 실패: {str(e)}")
            return []

    def _combine_keyword_search_results(
        self,
        title_results: List[Dict[str, Any]],
        vector_results: List[Dict[str, Any]],
        min_score: float = 0.3
    ) -> List[Dict[str, Any]]:
        """
        제목 검색과 벡터 검색 결과를 결합합니다.

        점수 계산:
        - 제목 매칭: +0.5점
        - 벡터 유사도: 0~1점 (0.5 가중치 적용)
        - 최종 점수: 제목 점수 + 벡터 점수

        매개변수:
        - title_results: 제목 검색 결과
        - vector_results: 벡터 검색 결과
        - min_score: 최소 점수 (필터링용)

        반환값:
        - 결합된 검색 결과
        """
        combined = {}

        # 제목 검색 결과 추가
        for result in title_results:
            notice_id = result["id"]
            combined[notice_id] = {
                "id": notice_id,
                "title": result["title"],
                "content": result.get("content", ""),
                "ai_summary": result.get("ai_summary"),
                "category": result.get("category"),
                "source_url": result.get("source_url"),
                "published_at": result.get("published_at"),
                "view_count": result.get("view_count", 0),
                "title_match": True,
                "title_score": self.KEYWORD_SEARCH_WEIGHTS["title"],
                "vector_score": 0.0,
                "total_score": self.KEYWORD_SEARCH_WEIGHTS["title"]
            }

        # 벡터 검색 결과 추가/결합
        vector_only_ids = []  # 벡터만 매칭된 공지 ID (추후 상세 정보 조회용)
        for result in vector_results:
            notice_id = result["id"]
            vector_score = result.get("similarity", 0) * self.KEYWORD_SEARCH_WEIGHTS["vector"]

            if notice_id in combined:
                # 이미 제목 매칭된 결과에 벡터 점수 추가
                combined[notice_id]["vector_score"] = vector_score
                combined[notice_id]["total_score"] += vector_score
            else:
                # 벡터만 매칭된 새 결과
                combined[notice_id] = {
                    "id": notice_id,
                    "title": result.get("title"),
                    "content": "",
                    "ai_summary": result.get("ai_summary"),
                    "category": result.get("category"),
                    "source_url": None,
                    "published_at": None,
                    "view_count": 0,
                    "title_match": False,
                    "title_score": 0.0,
                    "vector_score": vector_score,
                    "total_score": vector_score
                }
                vector_only_ids.append(notice_id)

        # 벡터 전용 결과의 누락 필드를 DB에서 보완
        if vector_only_ids:
            try:
                detail_result = self.supabase.table("notices")\
                    .select("id, content, source_url, published_at, view_count")\
                    .in_("id", vector_only_ids)\
                    .execute()

                for detail in (detail_result.data or []):
                    nid = detail["id"]
                    if nid in combined:
                        combined[nid]["content"] = detail.get("content", "")
                        combined[nid]["source_url"] = detail.get("source_url")
                        combined[nid]["published_at"] = detail.get("published_at")
                        combined[nid]["view_count"] = detail.get("view_count", 0)
            except Exception as e:
                print(f"벡터 전용 결과 상세 정보 조회 실패: {str(e)}")

        # 최소 점수 필터링
        results = [
            r for r in combined.values()
            if r["total_score"] >= min_score
        ]

        return results

    # =========================================================================
    # 내부 메서드: 데이터 조회
    # =========================================================================

    def _get_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """사용자 프로필 조회"""
        try:
            # users 테이블 조회
            user_result = self.supabase.table("users")\
                .select("id, department, grade")\
                .eq("id", user_id)\
                .single()\
                .execute()

            if not user_result.data:
                return None

            user = user_result.data

            # user_preferences 테이블 조회
            pref_result = self.supabase.table("user_preferences")\
                .select("categories, keywords, interests_embedding, enriched_profile")\
                .eq("user_id", user_id)\
                .single()\
                .execute()

            if pref_result.data:
                user.update(pref_result.data)

            return user

        except Exception as e:
            print(f"사용자 프로필 조회 실패: {str(e)}")
            return None

    def _get_notice(self, notice_id: str) -> Optional[Dict[str, Any]]:
        """공지사항 조회"""
        try:
            result = self.supabase.table("notices")\
                .select("id, title, content, ai_summary, category, content_embedding, enriched_metadata")\
                .eq("id", notice_id)\
                .single()\
                .execute()

            return result.data

        except Exception as e:
            print(f"공지사항 조회 실패: {str(e)}")
            return None

    # =========================================================================
    # 내부 메서드: 하드 필터링
    # =========================================================================

    def _hard_filter_notices(
        self,
        department: Optional[str] = None,
        grade: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        하드 필터링으로 공지사항을 필터링합니다.

        조건:
        - enriched_metadata.target_departments가 없거나 빈 배열이면 패스 (전체 대상)
        - 사용자 학과가 target_departments에 포함되면 패스
        - 학년도 동일하게 처리
        """
        try:
            # 최근 공지사항 조회 (30일 이내)
            thirty_days_ago = (datetime.utcnow() - timedelta(days=30)).isoformat()
            result = self.supabase.table("notices")\
                .select("id, title, ai_summary, category, enriched_metadata, content_embedding")\
                .gte("published_at", thirty_days_ago)\
                .order("published_at", desc=True)\
                .limit(200)\
                .execute()

            notices = result.data or []

            # Python에서 필터링 (JSONB 쿼리가 복잡해서)
            filtered = []
            for notice in notices:
                enriched = notice.get("enriched_metadata") or {}

                # 전체 대상이면 패스
                if enriched.get("is_for_all", False):
                    notice["hard_filter_match"] = True
                    filtered.append(notice)
                    continue

                # 학과 매칭
                target_depts = enriched.get("target_departments", [])
                dept_match = not target_depts or department in target_depts

                # 학년 매칭
                target_grades = enriched.get("target_grades", [])
                grade_match = not target_grades or grade in target_grades

                if dept_match and grade_match:
                    notice["hard_filter_match"] = True
                    filtered.append(notice)
                else:
                    # 의도적으로 매칭 안 된 공지도 포함 (벡터 검색 후보군 유지)
                    # 하드 필터는 "제외"가 아닌 "보너스 점수 부여" 역할
                    # _combine_notice_scores()에서 hard_filter_match=False이면 보너스 0점
                    notice["hard_filter_match"] = False
                    filtered.append(notice)

            return filtered

        except Exception as e:
            print(f"하드 필터링 실패: {str(e)}")
            return []

    def _hard_filter_users(
        self,
        target_departments: List[str],
        target_grades: List[int],
        is_for_all: bool = False
    ) -> List[Dict[str, Any]]:
        """
        하드 필터링으로 사용자를 필터링합니다.
        """
        try:
            # 알림 활성화된 사용자만 조회
            query = self.supabase.table("users")\
                .select("id, department, grade, user_preferences(notification_enabled, interests_embedding)")\

            result = query.execute()
            users = result.data or []

            filtered = []
            for user in users:
                prefs = user.get("user_preferences", [])
                if prefs and isinstance(prefs, list) and len(prefs) > 0:
                    pref = prefs[0]
                    if not pref.get("notification_enabled", True):
                        continue
                    user["interests_embedding"] = pref.get("interests_embedding")

                # 전체 대상이면 모두 포함
                if is_for_all:
                    user["hard_filter_match"] = True
                    filtered.append(user)
                    continue

                # 학과 매칭
                dept_match = not target_departments or user.get("department") in target_departments

                # 학년 매칭
                grade_match = not target_grades or user.get("grade") in target_grades

                if dept_match and grade_match:
                    user["hard_filter_match"] = True
                else:
                    user["hard_filter_match"] = False

                filtered.append(user)

            return filtered

        except Exception as e:
            print(f"사용자 하드 필터링 실패: {str(e)}")
            return []

    # =========================================================================
    # 내부 메서드: 벡터 검색
    # =========================================================================

    def _vector_search_notices(
        self,
        query_embedding: List[float],
        notice_ids: Optional[List[str]] = None,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        벡터 유사도로 공지사항을 검색합니다.

        Supabase의 pgvector RPC 함수를 사용하거나,
        Python에서 직접 코사인 유사도를 계산합니다.
        """
        try:
            # RPC 함수 호출 시도
            result = self.supabase.rpc(
                "search_notices_by_vector",
                {
                    "query_embedding": query_embedding,
                    "match_threshold": 0.2,
                    "match_count": limit
                }
            ).execute()

            if result.data:
                # notice_ids 필터 적용 (set 변환으로 O(1) 조회)
                if notice_ids:
                    notice_ids_set = set(notice_ids)
                    return [r for r in result.data if r["id"] in notice_ids_set]
                return result.data

        except Exception as e:
            print(f"RPC 벡터 검색 실패, Python 폴백: {str(e)}")

        # 폴백: Python에서 직접 계산
        return self._vector_search_fallback(query_embedding, notice_ids, limit)

    def _vector_search_fallback(
        self,
        query_embedding: List[float],
        notice_ids: Optional[List[str]] = None,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """벡터 검색 폴백 (Python에서 직접 계산)"""
        try:
            # 공지사항 조회
            query = self.supabase.table("notices")\
                .select("id, title, ai_summary, category, content_embedding")

            if notice_ids:
                query = query.in_("id", notice_ids)

            result = query.execute()
            notices = result.data or []

            # 코사인 유사도 계산
            results = []
            for notice in notices:
                embedding = notice.get("content_embedding")
                if not embedding:
                    continue

                similarity = self.embedding_service.calculate_similarity(
                    query_embedding,
                    embedding
                )

                results.append({
                    "id": notice["id"],
                    "title": notice["title"],
                    "ai_summary": notice.get("ai_summary"),
                    "category": notice.get("category"),
                    "similarity": similarity
                })

            # 유사도순 정렬
            results.sort(key=lambda x: x["similarity"], reverse=True)

            return results[:limit]

        except Exception as e:
            print(f"폴백 벡터 검색 실패: {str(e)}")
            return []

    def _vector_search_users(
        self,
        notice_embedding: List[float],
        user_ids: Optional[List[str]] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        벡터 유사도로 사용자를 검색합니다.
        """
        try:
            # RPC 함수 호출 시도
            result = self.supabase.rpc(
                "search_users_by_notice_vector",
                {
                    "notice_embedding": notice_embedding,
                    "match_threshold": 0.2,
                    "match_count": limit
                }
            ).execute()

            if result.data:
                if user_ids:
                    return [r for r in result.data if r["user_id"] in user_ids]
                return result.data

        except Exception as e:
            print(f"RPC 사용자 검색 실패, Python 폴백: {str(e)}")

        # 폴백: Python에서 직접 계산
        return self._vector_search_users_fallback(notice_embedding, user_ids, limit)

    def _vector_search_users_fallback(
        self,
        notice_embedding: List[float],
        user_ids: Optional[List[str]] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """사용자 벡터 검색 폴백"""
        try:
            query = self.supabase.table("user_preferences")\
                .select("user_id, interests_embedding")

            if user_ids:
                query = query.in_("user_id", user_ids)

            result = query.execute()
            prefs = result.data or []

            results = []
            for pref in prefs:
                embedding = pref.get("interests_embedding")
                if not embedding:
                    continue

                similarity = self.embedding_service.calculate_similarity(
                    notice_embedding,
                    embedding
                )

                results.append({
                    "user_id": pref["user_id"],
                    "similarity": similarity
                })

            results.sort(key=lambda x: x["similarity"], reverse=True)

            return results[:limit]

        except Exception as e:
            print(f"폴백 사용자 검색 실패: {str(e)}")
            return []

    # =========================================================================
    # 내부 메서드: 점수 결합
    # =========================================================================

    def _combine_notice_scores(
        self,
        hard_filtered: List[Dict[str, Any]],
        vector_results: List[Dict[str, Any]],
        weights: Dict[str, float]
    ) -> List[Dict[str, Any]]:
        """
        하드 필터링과 벡터 검색 결과를 결합합니다.
        """
        combined = {}

        # 하드 필터 결과
        for notice in hard_filtered:
            notice_id = notice["id"]
            hard_score = weights["hard_filter"] if notice.get("hard_filter_match") else 0

            combined[notice_id] = {
                "id": notice_id,
                "title": notice.get("title"),
                "ai_summary": notice.get("ai_summary"),
                "category": notice.get("category"),
                "hard_filter_score": hard_score,
                "vector_score": 0.0,
                "total_score": hard_score
            }

        # 벡터 검색 결과 추가
        for result in vector_results:
            notice_id = result["id"]
            vector_score = result.get("similarity", 0) * weights["vector"]

            if notice_id in combined:
                combined[notice_id]["vector_score"] = vector_score
                combined[notice_id]["total_score"] += vector_score
            else:
                combined[notice_id] = {
                    "id": notice_id,
                    "title": result.get("title"),
                    "ai_summary": result.get("ai_summary"),
                    "category": result.get("category"),
                    "hard_filter_score": 0.0,
                    "vector_score": vector_score,
                    "total_score": vector_score
                }

        return list(combined.values())

    def _combine_user_scores(
        self,
        hard_filtered: List[Dict[str, Any]],
        vector_results: List[Dict[str, Any]],
        weights: Dict[str, float],
        enriched: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        사용자 점수를 결합합니다.
        """
        combined = {}

        # 전체 대상 공지면 모든 사용자에게 하드 필터 보너스
        is_for_all = enriched.get("is_for_all", False)

        # 하드 필터 결과
        for user in hard_filtered:
            user_id = user["id"]
            hard_match = user.get("hard_filter_match", False) or is_for_all
            hard_score = weights["hard_filter"] if hard_match else 0

            combined[user_id] = {
                "user_id": user_id,
                "department": user.get("department"),
                "grade": user.get("grade"),
                "hard_filter_score": hard_score,
                "vector_score": 0.0,
                "total_score": hard_score
            }

        # 벡터 검색 결과 추가
        for result in vector_results:
            user_id = result["user_id"]
            vector_score = result.get("similarity", 0) * weights["vector"]

            if user_id in combined:
                combined[user_id]["vector_score"] = vector_score
                combined[user_id]["total_score"] += vector_score
            else:
                combined[user_id] = {
                    "user_id": user_id,
                    "department": None,
                    "grade": None,
                    "hard_filter_score": 0.0,
                    "vector_score": vector_score,
                    "total_score": vector_score
                }

        return list(combined.values())


# 테스트 코드
if __name__ == "__main__":
    print("=" * 60)
    print("하이브리드 검색 서비스 테스트 시작")
    print("=" * 60)

    try:
        service = HybridSearchService()

        # 키워드 검색 테스트
        print("\n[1단계] 키워드 검색 테스트...")
        results = service.search_by_keyword("장학금", limit=5)
        print(f"\n  '장학금' 검색 결과: {len(results)}개")
        for r in results[:3]:
            print(f"    - {r.get('title', 'N/A')[:40]}... (유사도: {r.get('similarity', 0):.3f})")

        print("\n" + "=" * 60)
        print("테스트 완료!")
        print("=" * 60)

    except Exception as e:
        print(f"\n테스트 실패: {str(e)}")
