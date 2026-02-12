# -*- coding: utf-8 -*-
"""
공지사항 서비스 모듈

이 파일이 하는 일:
AI로 분석한 공지사항을 데이터베이스에 저장하고 관리합니다.
크롤링 -> AI 분석 -> DB 저장의 전체 파이프라인을 연결하는 핵심 모듈입니다.
"""

from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

from services.supabase_service import get_supabase_client


class NoticeService:
    """
    공지사항 저장 및 관리 서비스

    목적:
    AI 분석 결과를 포함한 공지사항을 데이터베이스에 저장하고 관리합니다.
    """

    def __init__(self):
        """싱글턴 Supabase 클라이언트를 사용합니다."""
        self.client = get_supabase_client()

    def _prepare_db_data(
        self,
        notice_data: Dict[str, Any],
        embedding: Optional[List[float]] = None,
        enriched_metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        공지사항 저장용 DB 데이터를 준비합니다. (공통 로직)

        save_analyzed_notice와 save_notice_with_embedding에서 공유합니다.
        """
        source_url = notice_data.get("url") or notice_data.get("source_url")
        now_iso = datetime.now(timezone.utc).isoformat()

        db_data = {
            "title": notice_data.get("title"),
            "content": notice_data.get("content") or notice_data.get("title", ""),
            "source_url": source_url,
            "category": notice_data.get("category", "학사"),
            "published_at": self._parse_datetime(
                notice_data.get("published_at") or notice_data.get("published_date") or notice_data.get("date")
            ),
            "ai_summary": notice_data.get("summary", ""),
            "is_processed": True,
            "ai_analyzed_at": now_iso,
            "updated_at": now_iso
        }

        # source_board, board_seq 추가 (크롤링 최적화용)
        if "source_board" in notice_data:
            db_data["source_board"] = notice_data["source_board"]
        if "board_seq" in notice_data:
            db_data["board_seq"] = notice_data["board_seq"]

        # 마감일 추출 (복수 마감일 포함)
        dates = notice_data.get("dates", {})
        deadlines_list = dates.get("deadlines", [])
        if deadlines_list and isinstance(deadlines_list, list):
            db_data["deadlines"] = deadlines_list
            upcoming = [d["date"] for d in deadlines_list if d.get("date")]
            if upcoming:
                db_data["deadline"] = min(upcoming)
        else:
            deadline = dates.get("deadline")
            if deadline and deadline != "null":
                db_data["deadline"] = deadline

        # 추가 필드 (있으면 포함)
        if "author" in notice_data:
            db_data["author"] = notice_data["author"]
        if "view_count" in notice_data or "views" in notice_data:
            db_data["view_count"] = notice_data.get("view_count") or notice_data.get("views")
        if "original_id" in notice_data:
            db_data["original_id"] = notice_data["original_id"]
        if "attachments" in notice_data:
            db_data["attachments"] = notice_data["attachments"]
        if "content_images" in notice_data and notice_data["content_images"]:
            db_data["content_images"] = notice_data["content_images"]

        # display_mode, has_important_image 추가 (AI 분석 결과)
        if "display_mode" in notice_data:
            db_data["display_mode"] = notice_data["display_mode"]
        if "has_important_image" in notice_data:
            db_data["has_important_image"] = notice_data["has_important_image"]

        # 임베딩 추가
        if embedding:
            db_data["content_embedding"] = embedding

        # 보강 메타데이터 추가
        if enriched_metadata:
            db_data["enriched_metadata"] = enriched_metadata

        # date_type을 enriched_metadata에 포함
        date_type = dates.get("date_type")
        if date_type and date_type != "null":
            if "enriched_metadata" not in db_data:
                db_data["enriched_metadata"] = {}
            if isinstance(db_data["enriched_metadata"], dict):
                db_data["enriched_metadata"]["date_type"] = date_type

        return db_data

    def _upsert_notice(self, source_url: str, db_data: Dict[str, Any], label: str = "") -> Optional[str]:
        """공통 INSERT/UPDATE 로직"""
        # 중복 체크 (URL 기반)
        existing = self.client.table("notices")\
            .select("id")\
            .eq("source_url", source_url)\
            .execute()

        if existing.data:
            # 이미 존재하는 공지사항 → UPDATE
            notice_id = existing.data[0]["id"]
            self.client.table("notices")\
                .update(db_data)\
                .eq("id", notice_id)\
                .execute()

            print(f"[업데이트{label}] {db_data['title'][:40]}...")
            return notice_id
        else:
            # 새로운 공지사항 → INSERT
            result = self.client.table("notices")\
                .insert(db_data)\
                .execute()

            if result.data:
                notice_id = result.data[0]["id"]
                print(f"[저장{label}] {db_data['title'][:40]}...")
                return notice_id
            else:
                print(f"[실패] {db_data['title'][:40]}...")
                return None

    def save_analyzed_notice(self, notice_data: Dict[str, Any]) -> Optional[str]:
        """
        AI 분석 결과를 포함한 공지사항을 저장합니다.

        매개변수:
        - notice_data: 공지사항 데이터 (AI 분석 결과 포함)

        반환값:
        - 저장된 공지사항의 ID (UUID) 또는 None (실패 시)
        """
        try:
            # 필수 필드 검증
            if not notice_data.get("title"):
                raise ValueError("필수 필드 누락: title")
            if not notice_data.get("content"):
                notice_data["content"] = notice_data.get("title", "")

            source_url = notice_data.get("url") or notice_data.get("source_url")
            if not source_url:
                raise ValueError("필수 필드 누락: url 또는 source_url")

            db_data = self._prepare_db_data(notice_data)
            return self._upsert_notice(source_url, db_data)

        except Exception as e:
            print(f"[오류] 공지사항 저장 실패: {str(e)}")
            return None

    def save_notice_with_embedding(
        self,
        notice_data: Dict[str, Any],
        embedding: Optional[List[float]] = None,
        enriched_metadata: Optional[Dict[str, Any]] = None
    ) -> Optional[str]:
        """
        임베딩과 보강 메타데이터를 포함한 공지사항을 저장합니다.

        매개변수:
        - notice_data: 공지사항 데이터 (AI 분석 결과 포함)
        - embedding: 벡터 임베딩 (Optional)
        - enriched_metadata: 보강된 메타데이터 (Optional)

        반환값:
        - 저장된 공지사항 ID (UUID) 또는 None
        """
        try:
            # 필수 필드 검증
            if not notice_data.get("title"):
                raise ValueError("필수 필드 누락: title")
            if not notice_data.get("content"):
                notice_data["content"] = notice_data.get("title", "")

            source_url = notice_data.get("url") or notice_data.get("source_url")
            if not source_url:
                raise ValueError("필수 필드 누락: url 또는 source_url")

            db_data = self._prepare_db_data(notice_data, embedding, enriched_metadata)
            return self._upsert_notice(source_url, db_data, label="+임베딩")

        except Exception as e:
            print(f"[오류] 임베딩 포함 공지사항 저장 실패: {str(e)}")
            return None

    def update_ai_analysis(
        self,
        notice_id: str,
        analysis_result: Dict[str, Any]
    ) -> bool:
        """
        기존 공지사항에 AI 분석 결과를 업데이트합니다.

        매개변수:
        - notice_id: 공지사항 ID (UUID)
        - analysis_result: AI 분석 결과

        반환값:
        - 업데이트 성공 여부 (True/False)
        """
        try:
            now_iso = datetime.now(timezone.utc).isoformat()

            update_data = {
                "ai_summary": analysis_result.get("summary", ""),
                "category": analysis_result.get("category", "학사"),
                "display_mode": analysis_result.get("display_mode", "DOCUMENT"),
                "has_important_image": analysis_result.get("has_important_image", False),
                "is_processed": True,
                "ai_analyzed_at": now_iso,
                "updated_at": now_iso
            }

            # 마감일 추출 (복수 마감일 포함)
            dates = analysis_result.get("dates", {})
            deadlines_list = dates.get("deadlines", [])
            if deadlines_list and isinstance(deadlines_list, list):
                update_data["deadlines"] = deadlines_list
                upcoming = [d["date"] for d in deadlines_list if d.get("date")]
                if upcoming:
                    update_data["deadline"] = min(upcoming)
            else:
                deadline = dates.get("deadline")
                if deadline and deadline != "null":
                    update_data["deadline"] = deadline

            result = self.client.table("notices")\
                .update(update_data)\
                .eq("id", notice_id)\
                .execute()

            if result.data:
                print(f"[완료] AI 분석 결과 업데이트 완료: {notice_id}")
                return True
            else:
                print(f"[실패] AI 분석 결과 업데이트 실패: {notice_id}")
                return False

        except Exception as e:
            print(f"[오류] AI 분석 업데이트 실패: {str(e)}")
            return False

    def get_latest_original_id(self, category: str = None) -> Optional[str]:
        """DB에 저장된 최신 공지사항의 original_id를 조회합니다."""
        try:
            query = self.client.table("notices")\
                .select("original_id")\
                .order("created_at", desc=True)\
                .limit(1)

            if category:
                query = query.eq("category", category)

            result = query.execute()

            if result.data and result.data[0].get("original_id"):
                latest_id = result.data[0]["original_id"]
                print(f"[정보] 최신 공지 ID: {latest_id}")
                return latest_id
            else:
                print("[정보] DB에 저장된 공지사항 없음")
                return None

        except Exception as e:
            print(f"[오류] 최신 공지 ID 조회 실패: {str(e)}")
            return None

    def get_unprocessed_notices(self, limit: int = 50) -> List[Dict[str, Any]]:
        """아직 AI 분석되지 않은 공지사항을 조회합니다."""
        try:
            result = self.client.table("notices")\
                .select("*")\
                .eq("is_processed", False)\
                .order("published_at", desc=True)\
                .limit(limit)\
                .execute()

            if result.data:
                print(f"[조회] 미처리 공지사항 {len(result.data)}개 조회")
                return result.data
            else:
                print("[정보] 미처리 공지사항 없음")
                return []

        except Exception as e:
            print(f"[오류] 미처리 공지사항 조회 실패: {str(e)}")
            return []

    def batch_save_notices(
        self,
        notices: List[Dict[str, Any]]
    ) -> Dict[str, int]:
        """여러 공지사항을 일괄 저장합니다."""
        saved = 0
        failed = 0

        print(f"[시작] {len(notices)}개 공지사항 일괄 저장 시작...")

        for i, notice in enumerate(notices, 1):
            print(f"\n[{i}/{len(notices)}] 저장 중...")
            notice_id = self.save_analyzed_notice(notice)
            if notice_id:
                saved += 1
            else:
                failed += 1

        print(f"\n[완료] 일괄 저장 완료 - 성공: {saved}개, 실패: {failed}개")

        return {
            "total": len(notices),
            "saved": saved,
            "failed": failed
        }

    def update_embedding(
        self,
        notice_id: str,
        embedding: List[float],
        enriched_metadata: Optional[Dict[str, Any]] = None
    ) -> bool:
        """기존 공지사항에 임베딩을 업데이트합니다."""
        try:
            update_data = {
                "content_embedding": embedding,
                "updated_at": datetime.now(timezone.utc).isoformat()
            }

            if enriched_metadata:
                update_data["enriched_metadata"] = enriched_metadata

            result = self.client.table("notices")\
                .update(update_data)\
                .eq("id", notice_id)\
                .execute()

            if result.data:
                print(f"임베딩 업데이트 완료: {notice_id[:8]}...")
                return True
            else:
                print(f"임베딩 업데이트 실패: {notice_id[:8]}...")
                return False

        except Exception as e:
            print(f"임베딩 업데이트 실패: {str(e)}")
            return False

    def get_last_board_seq(self, source_board: str) -> Optional[int]:
        """특정 게시판의 마지막 순번을 조회합니다."""
        try:
            result = self.client.table("notices")\
                .select("board_seq")\
                .eq("source_board", source_board)\
                .not_.is_("board_seq", "null")\
                .order("board_seq", desc=True)\
                .limit(1)\
                .execute()

            if result.data and result.data[0].get("board_seq"):
                last_seq = result.data[0]["board_seq"]
                print(f"[정보] {source_board} 마지막 순번: {last_seq}")
                return last_seq
            else:
                print(f"[정보] {source_board} 저장된 순번 없음")
                return None

        except Exception as e:
            print(f"[오류] 마지막 순번 조회 실패: {str(e)}")
            return None

    def get_notices_without_embedding(self, limit: int = 100) -> List[Dict[str, Any]]:
        """임베딩이 없는 공지사항을 조회합니다."""
        try:
            result = self.client.table("notices")\
                .select("id, title, content, ai_summary, category")\
                .is_("content_embedding", "null")\
                .order("published_at", desc=True)\
                .limit(limit)\
                .execute()

            if result.data:
                print(f"임베딩 필요한 공지사항 {len(result.data)}개 조회")
                return result.data
            else:
                print("임베딩 필요한 공지사항 없음")
                return []

        except Exception as e:
            print(f"임베딩 없는 공지사항 조회 실패: {str(e)}")
            return []

    def _parse_datetime(self, date_str: Optional[str]) -> Optional[str]:
        """날짜 문자열을 ISO 8601 형식으로 변환합니다."""
        if not date_str or date_str == "null":
            return None

        # 이미 datetime 객체인 경우
        if isinstance(date_str, datetime):
            return date_str.isoformat()

        # 문자열인 경우 변환 시도
        try:
            if len(date_str) == 10:
                dt = datetime.fromisoformat(date_str)
                return dt.isoformat()
            else:
                return date_str
        except Exception:
            return date_str


# 테스트 코드
if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()

    print("=" * 50)
    print("[테스트] NoticeService 테스트 시작")
    print("=" * 50)

    try:
        service = NoticeService()

        test_notice = {
            "title": "[테스트] 2024학년도 1학기 수강신청 안내",
            "content": "수강신청 일정을 안내드립니다...",
            "url": f"https://kunsan.ac.kr/test/{datetime.now().timestamp()}",
            "published_date": "2024-02-01",
            "summary": "1학기 수강신청 2월 1일 시작",
            "dates": {
                "start_date": "2024-02-01",
                "end_date": "2024-02-05",
                "deadline": None
            },
            "category": "학사",
            "source_board": "공지사항",
            "board_seq": 9999
        }

        notice_id = service.save_analyzed_notice(test_notice)
        if notice_id:
            print(f"[완료] 저장 성공: {notice_id}")
        else:
            print("[실패] 저장 실패")

        unprocessed = service.get_unprocessed_notices(limit=5)
        print(f"미처리 공지사항: {len(unprocessed)}개")

        print("\n[완료] 모든 테스트 완료!")

    except Exception as e:
        print(f"\n[오류] 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
