# -*- coding: utf-8 -*-
"""
Supabase 데이터베이스 연동 서비스

이 파일이 하는 일:
Supabase PostgreSQL 데이터베이스와 연결하여 CRUD 작업을 수행합니다.
"""

import os
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from supabase import create_client, Client


# 모듈 레벨 싱글턴 클라이언트 (모든 곳에서 공유)
_shared_client: Optional[Client] = None


def get_supabase_client() -> Client:
    """싱글턴 Supabase 클라이언트를 반환합니다. 모든 모듈에서 공유합니다."""
    global _shared_client
    if _shared_client is None:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_KEY")
        if not url or not key:
            raise ValueError("SUPABASE_URL과 SUPABASE_KEY 환경 변수가 필요합니다")
        _shared_client = create_client(url, key)
        print(f"[DB] Supabase 클라이언트 초기화 완료")
    return _shared_client


class SupabaseService:
    """
    Supabase 데이터베이스 서비스 (싱글턴)

    목적:
    - Supabase DB 연결 관리
    - 공지사항 CRUD 작업
    - 데이터 변환 및 검증
    """

    _instance = None
    _initialized = False

    def __new__(cls):
        """싱글턴 패턴: 항상 같은 인스턴스를 반환합니다."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        """Supabase 클라이언트 초기화 (최초 1회만 실행)"""
        if SupabaseService._initialized:
            return

        self.client: Client = get_supabase_client()
        SupabaseService._initialized = True

    def insert_notices(self, notices: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        공지사항을 DB에 저장합니다

        매개변수:
        - notices: 크롤링한 공지사항 리스트

        반환값:
        - success: 성공 여부
        - inserted: 삽입된 개수
        - duplicates: 중복된 개수
        - errors: 에러 개수

        예시:
        service = SupabaseService()
        result = service.insert_notices(notices_data)
        print(f"삽입 완료: {result['inserted']}개")
        """
        inserted_count = 0
        duplicate_count = 0
        error_count = 0

        for notice in notices:
            try:
                # 데이터 변환 (크롤러 형식 → DB 형식)
                published_at = notice.get("published_at")
                if isinstance(published_at, datetime):
                    published_at = published_at.isoformat()

                # original_id 추출 (URL에서 dataSid 추출)
                original_id = notice.get("notice_id") or notice.get("original_id")
                if not original_id and notice.get("source_url"):
                    # URL에서 dataSid 추출
                    import re
                    match = re.search(r'dataSid=(\d+)', notice.get("source_url"))
                    if match:
                        original_id = match.group(1)

                notice_data = {
                    "title": notice.get("title"),
                    "content": notice.get("content"),
                    "category": notice.get("category", "공지사항"),
                    "source_url": notice.get("source_url"),
                    "published_at": published_at,
                    "is_processed": False,
                    "author": notice.get("author"),
                    "view_count": notice.get("view_count") or notice.get("views"),
                    "original_id": original_id,
                    "attachments": notice.get("attachments", []),
                    "ai_summary": notice.get("ai_summary") or notice.get("summary", ""),
                }

                # 중복 체크 (original_id 우선, 없으면 source_url 사용)
                if original_id:
                    existing = self.client.table("notices")\
                        .select("id")\
                        .eq("original_id", original_id)\
                        .execute()
                else:
                    existing = self.client.table("notices")\
                        .select("id")\
                        .eq("source_url", notice_data["source_url"])\
                        .execute()

                if existing.data:
                    duplicate_count += 1
                    print(f"[중복] {notice_data['title'][:30]}...")
                    continue

                # 데이터 삽입
                result = self.client.table("notices").insert(notice_data).execute()

                if result.data:
                    inserted_count += 1
                    print(f"[저장] {notice_data['title'][:40]}...")
                else:
                    error_count += 1
                    print(f"[실패] {notice_data['title'][:30]}...")

            except Exception as e:
                error_count += 1
                print(f"[ERROR] {str(e)}")
                continue

        return {
            "success": True,
            "inserted": inserted_count,
            "duplicates": duplicate_count,
            "errors": error_count,
            "total": len(notices)
        }

    def get_notices(
        self,
        category: Optional[str] = None,
        limit: int = 20,
        offset: int = 0,
        user_id: Optional[str] = None,
        deadline_from: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        공지사항 목록을 조회합니다

        매개변수:
        - category: 카테고리 필터 (선택)
        - limit: 가져올 개수 (기본 20, 0이면 무제한)
        - offset: 건너뛸 개수 (페이지네이션)
        - user_id: 사용자 ID (있으면 is_bookmarked 포함)
        - deadline_from: 마감일 필터 (이 날짜 이후 마감인 공지만, ISO 형식)

        반환값:
        - 공지사항 리스트 (bookmark_count, is_bookmarked 포함)
        """
        try:
            # content_embedding 제외 (프론트엔드에서 불필요, 건당 ~12KB 절약)
            query = self.client.table("notices")\
                .select(
                    "id, title, content, category, published_at, source_url, "
                    "view_count, ai_summary, author, deadline, deadlines, "
                    "bookmark_count, source_board, board_seq, attachments, "
                    "content_images, display_mode, has_important_image"
                )

            if category:
                query = query.eq("category", category)

            # 마감일 필터: deadline_from 이후 마감인 공지만
            if deadline_from:
                query = query.gte("deadline", deadline_from)
                query = query.order("deadline", desc=False)
            else:
                query = query.order("published_at", desc=True)

            # limit=0이면 무제한, 아니면 페이지네이션 적용
            if limit > 0:
                query = query.range(offset, offset + limit - 1)

            result = query.execute()
            notices = result.data if result.data else []

            # 로그인한 사용자면 is_bookmarked 표시
            if notices and user_id:
                notice_ids = [n["id"] for n in notices]
                bookmark_result = self.client.table("user_bookmarks")\
                    .select("notice_id")\
                    .eq("user_id", user_id)\
                    .in_("notice_id", notice_ids)\
                    .execute()
                bookmarked_ids = {b["notice_id"] for b in (bookmark_result.data or [])}
                for notice in notices:
                    notice["is_bookmarked"] = notice["id"] in bookmarked_ids

            return notices

        except Exception as e:
            print(f"[ERROR] 조회 에러: {str(e)}")
            return []

    def get_notice_by_id(self, notice_id: str) -> Optional[Dict[str, Any]]:
        """
        특정 공지사항을 조회합니다

        매개변수:
        - notice_id: 공지사항 ID (UUID)

        반환값:
        - 공지사항 데이터 또는 None

        예시:
        service = SupabaseService()
        notice = service.get_notice_by_id("123e4567-e89b-12d3-a456-426614174000")
        """
        try:
            result = self.client.table("notices")\
                .select("*")\
                .eq("id", notice_id)\
                .single()\
                .execute()

            return result.data if result.data else None

        except Exception as e:
            print(f"[ERROR] 조회 에러: {str(e)}")
            return None

    def delete_notice(self, notice_id: str) -> bool:
        """
        공지사항을 삭제합니다

        매개변수:
        - notice_id: 공지사항 ID

        반환값:
        - 성공 여부

        예시:
        service = SupabaseService()
        success = service.delete_notice("123e4567...")
        """
        try:
            result = self.client.table("notices")\
                .delete()\
                .eq("id", notice_id)\
                .execute()

            return True

        except Exception as e:
            print(f"[ERROR] 삭제 에러: {str(e)}")
            return False

    def get_deadline_notices(self, week_start: str, week_end: str, limit: int = 10) -> List[Dict[str, Any]]:
        """
        이번 주 마감 공지사항만 조회합니다 (홈 화면 카드4용 경량 API)

        매개변수:
        - week_start: 주 시작일 (ISO 형식, 예: 2026-02-09)
        - week_end: 주 종료일 (ISO 형식, 예: 2026-02-15)
        - limit: 가져올 개수 (기본 10)

        반환값:
        - 마감일 기준 정렬된 공지사항 리스트
        """
        try:
            result = self.client.table("notices")\
                .select(
                    "id, title, category, published_at, source_url, "
                    "view_count, ai_summary, deadline, deadlines, "
                    "bookmark_count, display_mode"
                )\
                .not_.is_("deadline", "null")\
                .gte("deadline", week_start)\
                .lte("deadline", week_end + "T23:59:59")\
                .order("deadline", desc=False)\
                .limit(limit)\
                .execute()

            return result.data if result.data else []

        except Exception as e:
            print(f"[ERROR] 이번 주 마감 공지 조회 에러: {str(e)}")
            return []

    def get_bookmarked_notices(self, user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """
        사용자가 북마크한 공지사항만 조회합니다 (홈 화면 카드2용 경량 API)

        매개변수:
        - user_id: 사용자 UUID
        - limit: 가져올 개수 (기본 10)

        반환값:
        - 북마크된 공지사항 리스트 (마감일 임박 순)
        """
        try:
            # 1. 사용자의 북마크 notice_id 목록 조회
            bookmark_result = self.client.table("user_bookmarks")\
                .select("notice_id")\
                .eq("user_id", user_id)\
                .order("created_at", desc=True)\
                .limit(limit)\
                .execute()

            bookmarked_ids = [b["notice_id"] for b in (bookmark_result.data or [])]
            if not bookmarked_ids:
                return []

            # 2. 해당 공지사항 상세 조회
            result = self.client.table("notices")\
                .select(
                    "id, title, category, published_at, source_url, "
                    "view_count, ai_summary, deadline, deadlines, "
                    "bookmark_count, display_mode"
                )\
                .in_("id", bookmarked_ids)\
                .execute()

            notices = result.data if result.data else []
            # is_bookmarked 필드 추가 (전부 true)
            for notice in notices:
                notice["is_bookmarked"] = True

            return notices

        except Exception as e:
            print(f"[ERROR] 북마크 공지 조회 에러: {str(e)}")
            return []

    def get_popular_notices(self, limit: int = 5) -> List[Dict[str, Any]]:
        """
        조회수 기준 인기 공지사항을 조회합니다 (DB 전체 대상)

        매개변수:
        - limit: 가져올 개수 (기본 5)

        반환값:
        - 조회수 기준 상위 공지사항 리스트
        """
        try:
            result = self.client.table("notices")\
                .select(
                    "id, title, content, category, published_at, source_url, "
                    "view_count, ai_summary, author, deadline, deadlines, "
                    "bookmark_count, source_board, board_seq, attachments, "
                    "content_images, display_mode, has_important_image"
                )\
                .order("view_count", desc=True)\
                .limit(limit)\
                .execute()

            return result.data if result.data else []

        except Exception as e:
            print(f"[ERROR] 인기 공지 조회 에러: {str(e)}")
            return []

    def get_essential_notices(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        오늘 필수 공지사항을 조회합니다 (점수 기반 정렬)

        최근 7일 공지를 조회한 뒤 중요도 점수를 계산합니다:
        - 마감 3일 이내: +8점
        - 신규 3일 이내: +5점
        - 조회수 상위 20%: +3점
        - 북마크 3개 이상: +2점

        매개변수:
        - limit: 반환할 최대 개수 (기본 10)

        반환값:
        - 점수 기준 내림차순 정렬된 공지사항 리스트
        """
        try:
            from datetime import timedelta
            now = datetime.now(timezone.utc)
            seven_days_ago = (now - timedelta(days=7)).strftime('%Y-%m-%dT00:00:00')

            result = self.client.table("notices")\
                .select(
                    "id, title, content, category, published_at, source_url, "
                    "view_count, ai_summary, author, deadline, deadlines, "
                    "bookmark_count, display_mode"
                )\
                .gte("published_at", seven_days_ago)\
                .order("published_at", desc=True)\
                .execute()

            notices = result.data if result.data else []
            if not notices:
                return []

            # 조회수 상위 20% 기준값 계산
            view_counts = sorted(
                [(n.get('view_count') or 0) for n in notices],
                reverse=True
            )
            top20_idx = max(1, int(len(view_counts) * 0.2))
            views_threshold = view_counts[min(top20_idx - 1, len(view_counts) - 1)]

            scored = []
            for notice in notices:
                score = 0

                # 마감 3일 이내: +8점
                deadline = notice.get('deadline')
                if deadline:
                    try:
                        dl = datetime.fromisoformat(
                            deadline.split('+')[0].replace('Z', '')
                        )
                        days_until = (dl - now).days
                        if 0 <= days_until <= 3:
                            score += 8
                    except Exception:
                        pass

                # 신규 3일 이내: +5점
                published_at = notice.get('published_at')
                if published_at:
                    try:
                        pub = datetime.fromisoformat(
                            published_at.split('+')[0].replace('Z', '')
                        )
                        days_since = (now - pub).days
                        if days_since <= 3:
                            score += 5
                    except Exception:
                        pass

                # 조회수 상위 20%: +3점
                view_count = notice.get('view_count') or 0
                if view_count >= views_threshold and views_threshold > 0:
                    score += 3

                # 북마크 3개 이상: +2점
                bookmark_count = notice.get('bookmark_count') or 0
                if bookmark_count >= 3:
                    score += 2

                if score > 0:
                    notice['_score'] = score
                    scored.append(notice)

            # 점수 순 정렬 → 상위 limit개 반환
            scored.sort(key=lambda n: n['_score'], reverse=True)
            result_notices = scored[:limit]

            # 내부 점수 필드 제거
            for n in result_notices:
                n.pop('_score', None)

            return result_notices

        except Exception as e:
            print(f"[ERROR] 오늘 필수 공지 조회 에러: {str(e)}")
            return []

    def get_deadline_soon_notices(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        마감 임박 공지사항을 조회합니다 (오늘~D+7)

        매개변수:
        - limit: 가져올 개수 (기본 10)

        반환값:
        - 마감일 오름차순 정렬된 공지사항 리스트
        """
        try:
            from datetime import timedelta
            now = datetime.now(timezone.utc)
            today = now.strftime('%Y-%m-%d')
            week_later = (now + timedelta(days=7)).strftime('%Y-%m-%d') + "T23:59:59"

            result = self.client.table("notices")\
                .select(
                    "id, title, content, category, published_at, source_url, "
                    "view_count, ai_summary, author, deadline, deadlines, "
                    "bookmark_count, display_mode"
                )\
                .not_.is_("deadline", "null")\
                .gte("deadline", today)\
                .lte("deadline", week_later)\
                .order("deadline", desc=False)\
                .limit(limit)\
                .execute()

            return result.data if result.data else []

        except Exception as e:
            print(f"[ERROR] 마감 임박 공지 조회 에러: {str(e)}")
            return []

    def get_statistics(self) -> Dict[str, Any]:
        """
        공지사항 통계를 조회합니다

        반환값:
        - total: 전체 공지사항 개수
        - by_category: 카테고리별 개수
        - recent: 최근 7일 공지사항 개수

        예시:
        service = SupabaseService()
        stats = service.get_statistics()
        print(f"전체: {stats['total']}개")
        """
        try:
            # 전체 개수
            total_result = self.client.table("notices")\
                .select("id", count="exact")\
                .execute()

            total = total_result.count if total_result else 0

            # 카테고리별 개수
            categories = ["공지사항", "학사/장학", "모집공고"]
            by_category = {}

            for cat in categories:
                cat_result = self.client.table("notices")\
                    .select("id", count="exact")\
                    .eq("category", cat)\
                    .execute()

                by_category[cat] = cat_result.count if cat_result else 0

            return {
                "total": total,
                "by_category": by_category,
                "last_updated": datetime.now(timezone.utc).isoformat()
            }

        except Exception as e:
            print(f"[ERROR] 통계 조회 에러: {str(e)}")
            return {"total": 0, "by_category": {}, "error": str(e)}
