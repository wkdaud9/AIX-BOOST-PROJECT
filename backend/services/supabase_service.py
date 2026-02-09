# -*- coding: utf-8 -*-
"""
Supabase 데이터베이스 연동 서비스

이 파일이 하는 일:
Supabase PostgreSQL 데이터베이스와 연결하여 CRUD 작업을 수행합니다.
"""

import os
from typing import List, Dict, Any, Optional
from datetime import datetime
from supabase import create_client, Client


class SupabaseService:
    """
    Supabase 데이터베이스 서비스

    목적:
    - Supabase DB 연결 관리
    - 공지사항 CRUD 작업
    - 데이터 변환 및 검증
    """

    def __init__(self):
        """Supabase 클라이언트 초기화"""
        self.url: str = os.getenv("SUPABASE_URL")
        self.key: str = os.getenv("SUPABASE_KEY")

        if not self.url or not self.key:
            raise ValueError("SUPABASE_URL과 SUPABASE_KEY 환경 변수가 필요합니다")

        self.client: Client = create_client(self.url, self.key)
        print(f"[DB] Supabase 연결 성공: {self.url}")

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
        user_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        공지사항 목록을 조회합니다

        매개변수:
        - category: 카테고리 필터 (선택)
        - limit: 가져올 개수 (기본 20)
        - offset: 건너뛸 개수 (페이지네이션)
        - user_id: 사용자 ID (있으면 is_bookmarked 포함)

        반환값:
        - 공지사항 리스트 (bookmark_count, is_bookmarked 포함)
        """
        try:
            query = self.client.table("notices")\
                .select("*")\
                .order("published_at", desc=True)\
                .range(offset, offset + limit - 1)

            if category:
                query = query.eq("category", category)

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
                "last_updated": datetime.now().isoformat()
            }

        except Exception as e:
            print(f"[ERROR] 통계 조회 에러: {str(e)}")
            return {"total": 0, "by_category": {}, "error": str(e)}
