# -*- coding: utf-8 -*-
"""
리랭킹 서비스 모듈

이 파일이 하는 일:
벡터 검색 결과의 상위 N개에 대해 AI로 최종 순위를 결정합니다.

왜 필요한가?
벡터 검색은 빠르지만 100% 정확하지 않습니다.
상위 결과들의 점수가 비슷할 때, AI가 최종 판단을 내립니다.

비유:
- 벡터 검색 = 서류 심사 (빠른 1차 스크리닝)
- 리랭킹 = 면접 (상위 후보만 꼼꼼히 평가)

비용 절감:
- 모든 후보에 AI 적용: 100명 × 1회 = 100회 API 호출
- 리랭킹: 상위 5명 × 1회 배치 = 1회 API 호출
"""

import os
import json
from typing import List, Dict, Any, Optional
from supabase import create_client, Client
from dotenv import load_dotenv

import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai.gemini_client import GeminiClient

load_dotenv()


class RerankingService:
    """
    AI 기반 리랭킹 서비스

    주요 기능:
    1. rerank_users_for_notice: 공지에 대해 사용자 순위 재조정
    2. rerank_notices_for_user: 사용자에 대해 공지 순위 재조정
    3. should_rerank: 리랭킹 필요 여부 판단
    """

    # 리랭킹 설정
    RERANK_THRESHOLD = 10   # 결과가 이 수 초과 시 리랭킹 고려
    RERANK_TOP_N = 3        # 상위 N개만 리랭킹 (5→3: Gemini 호출 비용/시간 절감)
    SCORE_VARIANCE_THRESHOLD = 0.02  # 점수 편차가 이보다 작으면 리랭킹 (0.05→0.02: 극히 변별력 없을 때만)

    def __init__(self):
        """리랭킹 서비스 초기화"""
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"),
            os.getenv("SUPABASE_KEY")
        )
        self.gemini = GeminiClient()

        print("RerankingService 초기화 완료")

    def should_rerank(
        self,
        candidates: List[Dict[str, Any]],
        threshold: int = None
    ) -> bool:
        """
        리랭킹이 필요한지 판단합니다.

        매개변수:
        - candidates: 후보 리스트 (점수 포함)
        - threshold: 최소 후보 수 (기본값: RERANK_THRESHOLD)

        반환값:
        - True: 리랭킹 필요
        - False: 리랭킹 불필요

        리랭킹이 필요한 경우:
        1. 후보 수가 threshold 초과
        2. 상위 결과들의 점수 차이가 작음 (변별력 부족)
        """
        threshold = threshold or self.RERANK_THRESHOLD

        # 후보가 적으면 리랭킹 불필요
        if len(candidates) <= threshold:
            return False

        # 상위 5개의 점수 분포 확인
        top_scores = [
            c.get("total_score", c.get("score", 0))
            for c in candidates[:5]
        ]

        if not top_scores:
            return False

        # 점수 편차 계산
        score_variance = max(top_scores) - min(top_scores)

        # 편차가 작으면 리랭킹 필요 (변별력 부족)
        return score_variance < self.SCORE_VARIANCE_THRESHOLD

    def rerank_users_for_notice(
        self,
        notice_id: str,
        candidate_users: List[Dict[str, Any]],
        top_n: int = None
    ) -> List[Dict[str, Any]]:
        """
        공지사항에 대해 사용자 순위를 재조정합니다.

        매개변수:
        - notice_id: 공지사항 ID
        - candidate_users: 후보 사용자 리스트
        - top_n: 리랭킹할 상위 후보 수

        반환값:
        - 리랭킹된 사용자 리스트

        과정:
        1. 공지사항 정보 조회
        2. 상위 N명의 프로필 조회
        3. AI에게 배치로 순위 요청
        4. 결과 반영
        """
        top_n = top_n or self.RERANK_TOP_N

        # 상위 N명만 리랭킹
        top_candidates = candidate_users[:top_n]
        remaining = candidate_users[top_n:]

        if not top_candidates:
            return candidate_users

        # 공지사항 정보 조회
        notice = self._get_notice_summary(notice_id)
        if not notice:
            return candidate_users

        # 사용자 프로필 조회
        user_profiles = self._get_user_profiles([c["user_id"] for c in top_candidates])

        # AI 리랭킹
        reranked = self._ai_rerank_users(notice, user_profiles)

        if not reranked:
            return candidate_users

        # 기존 점수 정보 병합
        reranked_with_scores = []
        for r in reranked:
            user_id = r["user_id"]
            original = next((c for c in top_candidates if c["user_id"] == user_id), {})
            reranked_with_scores.append({
                **original,
                "user_id": user_id,
                "ai_score": r.get("score", 0),
                "ai_reason": r.get("reason", ""),
                "total_score": r.get("score", original.get("total_score", 0))
            })

        # 나머지 후보와 합치기
        return reranked_with_scores + remaining

    def rerank_notices_for_user(
        self,
        user_id: str,
        candidate_notices: List[Dict[str, Any]],
        top_n: int = None
    ) -> List[Dict[str, Any]]:
        """
        사용자에 대해 공지사항 순위를 재조정합니다.

        매개변수:
        - user_id: 사용자 ID
        - candidate_notices: 후보 공지사항 리스트
        - top_n: 리랭킹할 상위 후보 수

        반환값:
        - 리랭킹된 공지사항 리스트
        """
        top_n = top_n or self.RERANK_TOP_N

        top_candidates = candidate_notices[:top_n]
        remaining = candidate_notices[top_n:]

        if not top_candidates:
            return candidate_notices

        # 사용자 프로필 조회
        user_profile = self._get_user_profile_detail(user_id)
        if not user_profile:
            return candidate_notices

        # AI 리랭킹
        reranked = self._ai_rerank_notices(user_profile, top_candidates)

        if not reranked:
            return candidate_notices

        # 기존 정보 병합 (id 또는 notice_id로 매칭)
        reranked_with_info = []
        for r in reranked:
            notice_id = r["notice_id"]
            original = next(
                (c for c in top_candidates if c.get("id") == notice_id or c.get("notice_id") == notice_id),
                {}
            )
            reranked_with_info.append({
                **original,
                "notice_id": notice_id,
                "ai_score": r.get("score", 0),
                "ai_reason": r.get("reason", ""),
                "total_score": r.get("score", original.get("total_score", 0))
            })

        return reranked_with_info + remaining

    # =========================================================================
    # 내부 메서드: 데이터 조회
    # =========================================================================

    def _get_notice_summary(self, notice_id: str) -> Optional[Dict[str, Any]]:
        """공지사항 요약 정보 조회"""
        try:
            result = self.supabase.table("notices")\
                .select("id, title, ai_summary, category, enriched_metadata")\
                .eq("id", notice_id)\
                .single()\
                .execute()

            return result.data

        except Exception as e:
            print(f"공지사항 조회 실패: {str(e)}")
            return None

    def _get_user_profiles(self, user_ids: List[str]) -> List[Dict[str, Any]]:
        """여러 사용자의 프로필 조회"""
        try:
            result = self.supabase.table("users")\
                .select("id, department, grade")\
                .in_("id", user_ids)\
                .execute()

            users = result.data or []

            # user_preferences 추가
            for user in users:
                pref_result = self.supabase.table("user_preferences")\
                    .select("categories, keywords")\
                    .eq("user_id", user["id"])\
                    .single()\
                    .execute()

                if pref_result.data:
                    user["interests"] = pref_result.data.get("keywords", [])
                    user["categories"] = pref_result.data.get("categories", [])

            return users

        except Exception as e:
            print(f"사용자 프로필 조회 실패: {str(e)}")
            return []

    def _get_user_profile_detail(self, user_id: str) -> Optional[Dict[str, Any]]:
        """단일 사용자 상세 프로필 조회"""
        try:
            result = self.supabase.table("users")\
                .select("id, department, grade")\
                .eq("id", user_id)\
                .single()\
                .execute()

            if not result.data:
                return None

            user = result.data

            pref_result = self.supabase.table("user_preferences")\
                .select("categories, keywords, enriched_profile")\
                .eq("user_id", user_id)\
                .single()\
                .execute()

            if pref_result.data:
                user["interests"] = pref_result.data.get("keywords", [])
                user["categories"] = pref_result.data.get("categories", [])
                user["enriched_profile"] = pref_result.data.get("enriched_profile", {})

            return user

        except Exception as e:
            print(f"사용자 프로필 조회 실패: {str(e)}")
            return None

    # =========================================================================
    # 내부 메서드: AI 리랭킹
    # =========================================================================

    def _ai_rerank_users(
        self,
        notice: Dict[str, Any],
        user_profiles: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        AI를 사용하여 사용자 순위를 결정합니다.

        하나의 API 호출로 여러 사용자를 동시에 평가합니다.
        """
        if not user_profiles:
            return []

        # 프롬프트 생성
        prompt = self._build_user_rerank_prompt(notice, user_profiles)

        try:
            # Gemini API 호출 (리랭킹 응답은 짧은 JSON이므로 max_tokens 제한)
            response = self.gemini.generate_text(prompt, max_tokens=512, temperature=0.2)

            # JSON 파싱
            result = self._parse_rerank_response(response)

            if result and "ranking" in result:
                return result["ranking"]

        except Exception as e:
            print(f"AI 리랭킹 실패: {str(e)}")

        return []

    def _ai_rerank_notices(
        self,
        user_profile: Dict[str, Any],
        notices: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        AI를 사용하여 공지사항 순위를 결정합니다.
        """
        if not notices:
            return []

        prompt = self._build_notice_rerank_prompt(user_profile, notices)

        try:
            response = self.gemini.generate_text(prompt, max_tokens=512, temperature=0.2)
            result = self._parse_rerank_response(response)

            if result and "ranking" in result:
                return result["ranking"]

        except Exception as e:
            print(f"AI 리랭킹 실패: {str(e)}")

        return []

    def _build_user_rerank_prompt(
        self,
        notice: Dict[str, Any],
        user_profiles: List[Dict[str, Any]]
    ) -> str:
        """사용자 리랭킹 프롬프트 생성 (간결한 버전)"""
        title = notice.get('title', '')
        cat = notice.get('category', '')
        summary = (notice.get('ai_summary', '') or '')[:80]

        enriched = notice.get('enriched_metadata', {}) or {}
        target_dept = ', '.join(enriched.get('target_departments', []))
        target_grade = ', '.join(map(str, enriched.get('target_grades', [])))

        users_lines = []
        for user in user_profiles:
            uid = user.get('id', '')
            dept = user.get('department', '미지정')
            grade = user.get('grade', '미지정')
            interests = ', '.join(user.get('interests', [])) or '없음'
            users_lines.append(f"- {uid} | {dept} {grade}학년 | 관심사: {interests}")

        users_text = '\n'.join(users_lines)

        return f"""공지: {title} ({cat}) - {summary}
대상: {target_dept or '전체'} {target_grade or '전학년'}

사용자:
{users_text}

위 사용자를 공지 관련도순으로 정렬. JSON만 출력:
{{"ranking":[{{"user_id":"ID","score":0.9,"reason":"사유"}}]}}"""

    def _build_notice_rerank_prompt(
        self,
        user_profile: Dict[str, Any],
        notices: List[Dict[str, Any]]
    ) -> str:
        """공지사항 리랭킹 프롬프트 생성 (간결한 버전)"""
        dept = user_profile.get('department', '미지정')
        grade = user_profile.get('grade', '미지정')
        interests = ', '.join(user_profile.get('interests', [])) or '없음'
        categories = ', '.join(user_profile.get('categories', [])) or '없음'

        notices_lines = []
        for notice in notices:
            nid = notice.get('notice_id', notice.get('id', ''))
            title = notice.get('title', '')
            cat = notice.get('category', '')
            notices_lines.append(f"- {nid} | {title} | {cat}")

        notices_text = '\n'.join(notices_lines)

        return f"""사용자: {dept} {grade}학년, 관심사: {interests}, 카테고리: {categories}

공지 목록:
{notices_text}

위 공지를 사용자 관련도순으로 정렬. JSON만 출력:
{{"ranking":[{{"notice_id":"ID","score":0.9,"reason":"사유"}}]}}"""

    def _parse_rerank_response(self, response: str) -> Optional[Dict[str, Any]]:
        """AI 응답에서 JSON을 파싱합니다."""
        try:
            # ```json ... ``` 블록 제거
            if "```json" in response:
                start = response.find("```json") + 7
                end = response.find("```", start)
                response = response[start:end].strip()
            elif "```" in response:
                start = response.find("```") + 3
                end = response.find("```", start)
                response = response[start:end].strip()

            return json.loads(response)

        except json.JSONDecodeError as e:
            print(f"JSON 파싱 실패: {str(e)}")
            return None


# 테스트 코드
if __name__ == "__main__":
    print("=" * 60)
    print("리랭킹 서비스 테스트 시작")
    print("=" * 60)

    try:
        service = RerankingService()

        # should_rerank 테스트
        print("\n[1단계] should_rerank 테스트...")

        # 점수가 비슷한 후보들
        similar_candidates = [
            {"user_id": "1", "total_score": 0.85},
            {"user_id": "2", "total_score": 0.84},
            {"user_id": "3", "total_score": 0.83},
            {"user_id": "4", "total_score": 0.82},
            {"user_id": "5", "total_score": 0.81},
        ] * 3  # 15명

        result = service.should_rerank(similar_candidates)
        print(f"  점수가 비슷한 15명 → 리랭킹 필요: {result}")

        # 점수 차이가 큰 후보들
        different_candidates = [
            {"user_id": "1", "total_score": 0.95},
            {"user_id": "2", "total_score": 0.75},
            {"user_id": "3", "total_score": 0.55},
            {"user_id": "4", "total_score": 0.35},
            {"user_id": "5", "total_score": 0.15},
        ] * 3

        result2 = service.should_rerank(different_candidates)
        print(f"  점수 차이가 큰 15명 → 리랭킹 필요: {result2}")

        print("\n" + "=" * 60)
        print("테스트 완료!")
        print("=" * 60)

    except Exception as e:
        print(f"\n테스트 실패: {str(e)}")
