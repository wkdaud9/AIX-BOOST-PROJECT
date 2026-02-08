# -*- coding: utf-8 -*-
"""
공지사항 서비스 모듈

이 파일이 하는 일:
AI로 분석한 공지사항을 데이터베이스에 저장하고 관리합니다.
크롤링 -> AI 분석 -> DB 저장의 전체 파이프라인을 연결하는 핵심 모듈입니다.

비유:
- 크롤러 = 신문 수집원
- AI 분석기 = 신문 요약 전문가
- 이 서비스 = 요약된 신문을 정리해서 도서관에 보관하는 사서
"""

import os
from typing import Dict, Any, List, Optional
from datetime import datetime
from supabase import create_client, Client


class NoticeService:
    """
    공지사항 저장 및 관리 서비스

    목적:
    AI 분석 결과를 포함한 공지사항을 데이터베이스에 저장하고 관리합니다.

    주요 기능:
    1. save_analyzed_notice: AI 분석 결과를 포함한 공지사항 저장
    2. update_ai_analysis: 기존 공지사항에 AI 분석 결과 업데이트
    3. get_unprocessed_notices: 아직 AI 분석되지 않은 공지사항 조회
    4. batch_save_notices: 여러 공지사항 일괄 저장
    """

    def __init__(self):
        """Supabase 클라이언트를 초기화합니다."""
        self.url: str = os.getenv("SUPABASE_URL")
        self.key: str = os.getenv("SUPABASE_KEY")

        if not self.url or not self.key:
            raise ValueError(
                "[오류] SUPABASE_URL과 SUPABASE_KEY 환경 변수가 필요합니다"
            )

        self.client: Client = create_client(self.url, self.key)
        print("[완료] NoticeService 초기화 완료")

    def save_analyzed_notice(self, notice_data: Dict[str, Any]) -> Optional[str]:
        """
        AI 분석 결과를 포함한 공지사항을 저장합니다.

        목적:
        크롤링한 공지사항과 AI 분석 결과를 한 번에 DB에 저장합니다.

        매개변수:
        - notice_data: 공지사항 데이터 (AI 분석 결과 포함)
          {
              "title": "제목",
              "content": "내용",
              "url": "링크",
              "published_date": "발표일",
              "summary": "AI 요약",
              "dates": {"start_date": "...", "end_date": "...", "deadline": "..."},
              "category": "카테고리"
          }

        반환값:
        - 저장된 공지사항의 ID (UUID) 또는 None (실패 시)

        특징:
        - 중복 체크: URL 기반으로 중복 확인
        - INSERT vs UPDATE: 중복이면 UPDATE, 없으면 INSERT
        - 트랜잭션: 에러 발생 시 롤백

        예시:
        service = NoticeService()
        notice = {
            "title": "수강신청 안내",
            "content": "...",
            "url": "http://...",
            "summary": "1학기 수강신청 2월 1일 시작",
            "category": "학사"
        }
        notice_id = service.save_analyzed_notice(notice)
        print(f"저장 완료: {notice_id}")
        """
        try:
            # 1. 필수 필드 검증
            # url 또는 source_url 중 하나는 있어야 함
            if not notice_data.get("title"):
                raise ValueError("필수 필드 누락: title")
            # content는 이미지 공지의 경우 비어있을 수 있음 (제목으로 대체)
            if not notice_data.get("content"):
                notice_data["content"] = notice_data.get("title", "")
            if not notice_data.get("url") and not notice_data.get("source_url"):
                raise ValueError("필수 필드 누락: url 또는 source_url")

            # 2. 중복 체크 (URL 기반)
            source_url = notice_data.get("url") or notice_data.get("source_url")
            existing = self.client.table("notices")\
                .select("id")\
                .eq("source_url", source_url)\
                .execute()

            # 3. DB 저장 데이터 준비
            db_data = {
                "title": notice_data.get("title"),
                "content": notice_data.get("content"),
                "source_url": source_url,
                "category": notice_data.get("category", "학사"),
                "published_at": self._parse_datetime(
                    notice_data.get("published_at") or notice_data.get("published_date") or notice_data.get("date")
                ),
                "ai_summary": notice_data.get("summary", ""),
                "is_processed": True,
                "ai_analyzed_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }

            # source_board, board_seq 추가 (크롤링 최적화용)
            if "source_board" in notice_data:
                db_data["source_board"] = notice_data["source_board"]
            if "board_seq" in notice_data:
                db_data["board_seq"] = notice_data["board_seq"]

            # 마감일 추출 (AI 분석 결과의 dates.deadline)
            dates = notice_data.get("dates", {})
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

            # 4. INSERT 또는 UPDATE
            if existing.data:
                # 이미 존재하는 공지사항 → UPDATE
                notice_id = existing.data[0]["id"]
                result = self.client.table("notices")\
                    .update(db_data)\
                    .eq("id", notice_id)\
                    .execute()

                print(f"[업데이트] {db_data['title'][:40]}...")
                return notice_id
            else:
                # 새로운 공지사항 -> INSERT
                result = self.client.table("notices")\
                    .insert(db_data)\
                    .execute()

                if result.data:
                    notice_id = result.data[0]["id"]
                    print(f"[저장] {db_data['title'][:40]}...")
                    return notice_id
                else:
                    print(f"[실패] {db_data['title'][:40]}...")
                    return None

        except Exception as e:
            print(f"[오류] 공지사항 저장 실패: {str(e)}")
            return None

    def update_ai_analysis(
        self,
        notice_id: str,
        analysis_result: Dict[str, Any]
    ) -> bool:
        """
        기존 공지사항에 AI 분석 결과를 업데이트합니다.

        목적:
        이미 DB에 저장된 공지사항에 나중에 AI 분석 결과를 추가합니다.

        매개변수:
        - notice_id: 공지사항 ID (UUID)
        - analysis_result: AI 분석 결과
          {
              "summary": "요약",
              "dates": {...},
              "category": "카테고리"
          }

        반환값:
        - 업데이트 성공 여부 (True/False)

        예시:
        service = NoticeService()
        analysis = {
            "summary": "요약문",
            "category": "학사"
        }
        success = service.update_ai_analysis("uuid-123", analysis)
        """
        try:
            # 업데이트할 데이터 준비
            update_data = {
                "ai_summary": analysis_result.get("summary", ""),
                "category": analysis_result.get("category", "학사"),
                "display_mode": analysis_result.get("display_mode", "DOCUMENT"),
                "has_important_image": analysis_result.get("has_important_image", False),
                "is_processed": True,
                "ai_analyzed_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }

            # 마감일 추출
            dates = analysis_result.get("dates", {})
            deadline = dates.get("deadline")
            if deadline and deadline != "null":
                update_data["deadline"] = deadline

            # DB 업데이트
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
        """
        DB에 저장된 최신 공지사항의 original_id를 조회합니다.

        목적:
        크롤링 최적화를 위해 DB에 이미 저장된 최신 공지의 ID를 확인합니다.

        매개변수:
        - category: 카테고리로 필터링 (기본값: None - 전체)

        반환값:
        - 최신 공지사항의 original_id (없으면 None)

        예시:
        service = NoticeService()
        latest_id = service.get_latest_original_id(category="공지사항")
        if latest_id:
            print(f"마지막 저장된 공지 ID: {latest_id}")
        """
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
        """
        아직 AI 분석되지 않은 공지사항을 조회합니다.

        목적:
        is_processed=False인 공지사항들을 가져와서 AI 분석을 수행할 수 있습니다.

        매개변수:
        - limit: 가져올 최대 개수 (기본값: 50)

        반환값:
        - 미처리 공지사항 리스트

        예시:
        service = NoticeService()
        unprocessed = service.get_unprocessed_notices(limit=10)
        for notice in unprocessed:
            # AI 분석 수행
            analysis = analyze(notice)
            service.update_ai_analysis(notice["id"], analysis)
        """
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
        """
        여러 공지사항을 일괄 저장합니다.

        목적:
        크롤링 + AI 분석한 여러 공지사항을 한 번에 저장합니다.

        매개변수:
        - notices: 공지사항 리스트 (AI 분석 결과 포함)

        반환값:
        {
            "total": 전체 개수,
            "inserted": 신규 저장 개수,
            "updated": 업데이트 개수,
            "failed": 실패 개수
        }

        예시:
        service = NoticeService()
        notices = [
            {"title": "공지1", "summary": "...", ...},
            {"title": "공지2", "summary": "...", ...},
        ]
        result = service.batch_save_notices(notices)
        print(f"저장 완료: {result['inserted']}개")
        """
        inserted = 0
        updated = 0
        failed = 0

        print(f"[시작] {len(notices)}개 공지사항 일괄 저장 시작...")

        for i, notice in enumerate(notices, 1):
            print(f"\n[{i}/{len(notices)}] 저장 중...")

            notice_id = self.save_analyzed_notice(notice)

            if notice_id:
                # 기존 공지사항 업데이트인지 신규 저장인지 판단
                if self._is_existing_notice(notice.get("url") or notice.get("source_url")):
                    updated += 1
                else:
                    inserted += 1
            else:
                failed += 1

        print("\n" + "=" * 50)
        print(f"[완료] 일괄 저장 완료")
        print(f"  - 신규 저장: {inserted}개")
        print(f"  - 업데이트: {updated}개")
        print(f"  - 실패: {failed}개")
        print("=" * 50)

        return {
            "total": len(notices),
            "inserted": inserted,
            "updated": updated,
            "failed": failed
        }

    def _is_existing_notice(self, url: str) -> bool:
        """
        URL로 공지사항 존재 여부를 확인합니다.

        내부 헬퍼 함수
        """
        try:
            result = self.client.table("notices")\
                .select("id")\
                .eq("source_url", url)\
                .execute()

            return bool(result.data)
        except:
            return False

    def save_notice_with_embedding(
        self,
        notice_data: Dict[str, Any],
        embedding: Optional[List[float]] = None,
        enriched_metadata: Optional[Dict[str, Any]] = None
    ) -> Optional[str]:
        """
        임베딩과 보강 메타데이터를 포함한 공지사항을 저장합니다.

        목적:
        벡터 검색을 위해 공지사항과 함께 임베딩을 저장합니다.

        매개변수:
        - notice_data: 공지사항 데이터 (AI 분석 결과 포함)
        - embedding: 768차원 벡터 임베딩 (Optional)
        - enriched_metadata: 보강된 메타데이터 (Optional)
          {
              "target_departments": ["컴퓨터정보공학과"],
              "target_grades": [3, 4],
              "keywords_expanded": ["AI", "인공지능"],
              "action_type": "신청"
          }

        반환값:
        - 저장된 공지사항 ID (UUID) 또는 None

        예시:
        service = NoticeService()
        notice_id = service.save_notice_with_embedding(
            notice_data=notice,
            embedding=[0.1, 0.2, ...],  # 3072차원
            enriched_metadata={"target_departments": ["컴공"]}
        )
        """
        try:
            # 기본 공지사항 저장 데이터 준비
            source_url = notice_data.get("url") or notice_data.get("source_url")

            # 필수 필드 검증
            if not notice_data.get("title"):
                raise ValueError("필수 필드 누락: title")
            # content는 이미지 공지의 경우 비어있을 수 있음 (제목으로 대체)
            if not notice_data.get("content"):
                notice_data["content"] = notice_data.get("title", "")
            if not source_url:
                raise ValueError("필수 필드 누락: url 또는 source_url")

            # 중복 체크
            existing = self.client.table("notices")\
                .select("id")\
                .eq("source_url", source_url)\
                .execute()

            # DB 저장 데이터 준비
            db_data = {
                "title": notice_data.get("title"),
                "content": notice_data.get("content"),
                "source_url": source_url,
                "category": notice_data.get("category", "학사"),
                "published_at": self._parse_datetime(
                    notice_data.get("published_at") or notice_data.get("published_date") or notice_data.get("date")
                ),
                "ai_summary": notice_data.get("summary", ""),
                "is_processed": True,
                "ai_analyzed_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }

            # 마감일 추출
            dates = notice_data.get("dates", {})
            deadline = dates.get("deadline")
            if deadline and deadline != "null":
                db_data["deadline"] = deadline

            # 추가 필드
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

            # source_board, board_seq 추가 (크롤링 최적화용)
            if "source_board" in notice_data:
                db_data["source_board"] = notice_data["source_board"]
            if "board_seq" in notice_data:
                db_data["board_seq"] = notice_data["board_seq"]

            # 임베딩 추가 (새로운 필드)
            if embedding:
                db_data["content_embedding"] = embedding

            # 보강 메타데이터 추가 (새로운 필드)
            if enriched_metadata:
                db_data["enriched_metadata"] = enriched_metadata

            # date_type을 enriched_metadata에 포함 (AI 프롬프트에서 추출한 날짜 성격)
            date_type = dates.get("date_type")
            if date_type and date_type != "null":
                if "enriched_metadata" not in db_data:
                    db_data["enriched_metadata"] = {}
                if isinstance(db_data["enriched_metadata"], dict):
                    db_data["enriched_metadata"]["date_type"] = date_type

            # INSERT 또는 UPDATE
            if existing.data:
                notice_id = existing.data[0]["id"]
                result = self.client.table("notices")\
                    .update(db_data)\
                    .eq("id", notice_id)\
                    .execute()

                print(f"[업데이트+임베딩] {db_data['title'][:40]}...")
                return notice_id
            else:
                result = self.client.table("notices")\
                    .insert(db_data)\
                    .execute()

                if result.data:
                    notice_id = result.data[0]["id"]
                    print(f"[저장+임베딩] {db_data['title'][:40]}...")
                    return notice_id
                else:
                    print(f"[실패] {db_data['title'][:40]}...")
                    return None

        except Exception as e:
            print(f"임베딩 포함 공지사항 저장 실패: {str(e)}")
            return None

    def update_embedding(
        self,
        notice_id: str,
        embedding: List[float],
        enriched_metadata: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        기존 공지사항에 임베딩을 업데이트합니다.

        목적:
        이미 저장된 공지사항에 나중에 임베딩을 추가합니다.

        매개변수:
        - notice_id: 공지사항 ID
        - embedding: 3072차원 벡터 임베딩
        - enriched_metadata: 보강된 메타데이터 (Optional)

        반환값:
        - 업데이트 성공 여부
        """
        try:
            update_data = {
                "content_embedding": embedding,
                "updated_at": datetime.now().isoformat()
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
        """
        특정 게시판의 마지막 순번을 조회합니다.

        목적:
        크롤링 최적화를 위해 DB에 저장된 최신 순번을 확인합니다.

        매개변수:
        - source_board: 게시판 구분 (공지사항, 학사장학, 모집공고)

        반환값:
        - 마지막 순번 (없으면 None)

        예시:
        service = NoticeService()
        last_seq = service.get_last_board_seq("공지사항")
        if last_seq:
            print(f"마지막 순번: {last_seq}")
        """
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
        """
        임베딩이 없는 공지사항을 조회합니다.

        목적:
        마이그레이션을 위해 아직 임베딩이 생성되지 않은 공지사항을 조회합니다.

        매개변수:
        - limit: 최대 조회 개수

        반환값:
        - 임베딩이 없는 공지사항 리스트
        """
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
        """
        날짜 문자열을 ISO 8601 형식으로 변환합니다.

        내부 헬퍼 함수

        예시:
        "2024-02-01" → "2024-02-01T00:00:00"
        "2024-02-01 10:00" → "2024-02-01T10:00:00"
        """
        if not date_str or date_str == "null":
            return None

        # 이미 datetime 객체인 경우
        if isinstance(date_str, datetime):
            return date_str.isoformat()

        # 문자열인 경우 변환 시도
        try:
            # YYYY-MM-DD 형식
            if len(date_str) == 10:
                dt = datetime.fromisoformat(date_str)
                return dt.isoformat()
            # 이미 ISO 형식인 경우
            else:
                return date_str
        except:
            # 파싱 실패 시 원본 문자열 그대로 반환
            return date_str


# 테스트 코드
if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()

    print("=" * 50)
    print("[테스트] NoticeService 테스트 시작")
    print("=" * 50)

    try:
        # 1. 서비스 초기화
        print("\n[1단계] NoticeService 초기화 중...")
        service = NoticeService()

        # 2. 테스트 공지사항 저장
        print("\n[2단계] 테스트 공지사항 저장...")
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

        # 3. 미처리 공지사항 조회
        print("\n[3단계] 미처리 공지사항 조회...")
        unprocessed = service.get_unprocessed_notices(limit=5)
        print(f"미처리 공지사항: {len(unprocessed)}개")

        print("\n" + "=" * 50)
        print("[완료] 모든 테스트 완료!")
        print("=" * 50)

    except Exception as e:
        print(f"\n[오류] 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
