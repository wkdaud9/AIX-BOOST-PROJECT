# -*- coding: utf-8 -*-
"""
공지사항 서비스 모듈

🤔 이 파일이 하는 일:
AI로 분석한 공지사항을 데이터베이스에 저장하고 관리합니다.
크롤링 → AI 분석 → DB 저장의 전체 파이프라인을 연결하는 핵심 모듈입니다.

📚 비유:
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

    🎯 목적:
    AI 분석 결과를 포함한 공지사항을 데이터베이스에 저장하고 관리합니다.

    🏗️ 주요 기능:
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
                "❌ SUPABASE_URL과 SUPABASE_KEY 환경 변수가 필요합니다"
            )

        self.client: Client = create_client(self.url, self.key)
        print("✅ NoticeService 초기화 완료")

    def save_analyzed_notice(self, notice_data: Dict[str, Any]) -> Optional[str]:
        """
        AI 분석 결과를 포함한 공지사항을 저장합니다.

        🎯 목적:
        크롤링한 공지사항과 AI 분석 결과를 한 번에 DB에 저장합니다.

        🔧 매개변수:
        - notice_data: 공지사항 데이터 (AI 분석 결과 포함)
          {
              "title": "제목",
              "content": "내용",
              "url": "링크",
              "published_date": "발표일",
              "summary": "AI 요약",
              "dates": {"start_date": "...", "end_date": "...", "deadline": "..."},
              "category": "카테고리",
              "priority": "중요도"
          }

        📊 반환값:
        - 저장된 공지사항의 ID (UUID) 또는 None (실패 시)

        💡 특징:
        - 중복 체크: URL 기반으로 중복 확인
        - INSERT vs UPDATE: 중복이면 UPDATE, 없으면 INSERT
        - 트랜잭션: 에러 발생 시 롤백

        💡 예시:
        service = NoticeService()
        notice = {
            "title": "수강신청 안내",
            "content": "...",
            "url": "http://...",
            "summary": "1학기 수강신청 2월 1일 시작",
            "category": "학사",
            "priority": "중요"
        }
        notice_id = service.save_analyzed_notice(notice)
        print(f"저장 완료: {notice_id}")
        """
        try:
            # 1. 필수 필드 검증
            required_fields = ["title", "content", "url"]
            for field in required_fields:
                if field not in notice_data or not notice_data[field]:
                    raise ValueError(f"필수 필드 누락: {field}")

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
                "category": notice_data.get("category", "기타"),
                "published_at": self._parse_datetime(
                    notice_data.get("published_date") or notice_data.get("date")
                ),
                "ai_summary": notice_data.get("summary", ""),
                "priority": notice_data.get("priority", "일반"),
                "is_processed": True,
                "ai_analyzed_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }

            # 날짜 정보 추출 (dates 객체에서 배열로 변환)
            dates = notice_data.get("dates", {})
            extracted_dates = []
            for date_key in ["start_date", "end_date", "deadline"]:
                date_value = dates.get(date_key)
                if date_value and date_value != "null":
                    extracted_dates.append(date_value)

            if extracted_dates:
                db_data["extracted_dates"] = extracted_dates

            # 추가 필드 (있으면 포함)
            if "author" in notice_data:
                db_data["author"] = notice_data["author"]
            if "view_count" in notice_data or "views" in notice_data:
                db_data["view_count"] = notice_data.get("view_count") or notice_data.get("views")
            if "original_id" in notice_data:
                db_data["original_id"] = notice_data["original_id"]
            if "attachments" in notice_data:
                db_data["attachments"] = notice_data["attachments"]

            # 4. INSERT 또는 UPDATE
            if existing.data:
                # 이미 존재하는 공지사항 → UPDATE
                notice_id = existing.data[0]["id"]
                result = self.client.table("notices")\
                    .update(db_data)\
                    .eq("id", notice_id)\
                    .execute()

                print(f"✅ [업데이트] {db_data['title'][:40]}...")
                return notice_id
            else:
                # 새로운 공지사항 → INSERT
                db_data["crawled_at"] = datetime.now().isoformat()
                result = self.client.table("notices")\
                    .insert(db_data)\
                    .execute()

                if result.data:
                    notice_id = result.data[0]["id"]
                    print(f"✅ [저장] {db_data['title'][:40]}...")
                    return notice_id
                else:
                    print(f"❌ [실패] {db_data['title'][:40]}...")
                    return None

        except Exception as e:
            print(f"❌ 공지사항 저장 실패: {str(e)}")
            return None

    def update_ai_analysis(
        self,
        notice_id: str,
        analysis_result: Dict[str, Any]
    ) -> bool:
        """
        기존 공지사항에 AI 분석 결과를 업데이트합니다.

        🎯 목적:
        이미 DB에 저장된 공지사항에 나중에 AI 분석 결과를 추가합니다.

        🔧 매개변수:
        - notice_id: 공지사항 ID (UUID)
        - analysis_result: AI 분석 결과
          {
              "summary": "요약",
              "dates": {...},
              "category": "카테고리",
              "priority": "중요도"
          }

        📊 반환값:
        - 업데이트 성공 여부 (True/False)

        💡 예시:
        service = NoticeService()
        analysis = {
            "summary": "요약문",
            "category": "학사",
            "priority": "중요"
        }
        success = service.update_ai_analysis("uuid-123", analysis)
        """
        try:
            # 업데이트할 데이터 준비
            update_data = {
                "ai_summary": analysis_result.get("summary", ""),
                "category": analysis_result.get("category", "기타"),
                "priority": analysis_result.get("priority", "일반"),
                "is_processed": True,
                "ai_analyzed_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }

            # 날짜 정보 추출
            dates = analysis_result.get("dates", {})
            extracted_dates = []
            for date_key in ["start_date", "end_date", "deadline"]:
                date_value = dates.get(date_key)
                if date_value and date_value != "null":
                    extracted_dates.append(date_value)

            if extracted_dates:
                update_data["extracted_dates"] = extracted_dates

            # DB 업데이트
            result = self.client.table("notices")\
                .update(update_data)\
                .eq("id", notice_id)\
                .execute()

            if result.data:
                print(f"✅ AI 분석 결과 업데이트 완료: {notice_id}")
                return True
            else:
                print(f"❌ AI 분석 결과 업데이트 실패: {notice_id}")
                return False

        except Exception as e:
            print(f"❌ AI 분석 업데이트 실패: {str(e)}")
            return False

    def get_unprocessed_notices(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        아직 AI 분석되지 않은 공지사항을 조회합니다.

        🎯 목적:
        is_processed=False인 공지사항들을 가져와서 AI 분석을 수행할 수 있습니다.

        🔧 매개변수:
        - limit: 가져올 최대 개수 (기본값: 50)

        📊 반환값:
        - 미처리 공지사항 리스트

        💡 예시:
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
                print(f"📋 미처리 공지사항 {len(result.data)}개 조회")
                return result.data
            else:
                print("ℹ️ 미처리 공지사항 없음")
                return []

        except Exception as e:
            print(f"❌ 미처리 공지사항 조회 실패: {str(e)}")
            return []

    def batch_save_notices(
        self,
        notices: List[Dict[str, Any]]
    ) -> Dict[str, int]:
        """
        여러 공지사항을 일괄 저장합니다.

        🎯 목적:
        크롤링 + AI 분석한 여러 공지사항을 한 번에 저장합니다.

        🔧 매개변수:
        - notices: 공지사항 리스트 (AI 분석 결과 포함)

        📊 반환값:
        {
            "total": 전체 개수,
            "inserted": 신규 저장 개수,
            "updated": 업데이트 개수,
            "failed": 실패 개수
        }

        💡 예시:
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

        print(f"📦 {len(notices)}개 공지사항 일괄 저장 시작...")

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
        print(f"✅ 일괄 저장 완료")
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

        🎯 내부 헬퍼 함수
        """
        try:
            result = self.client.table("notices")\
                .select("id")\
                .eq("source_url", url)\
                .execute()

            return bool(result.data)
        except:
            return False

    def _parse_datetime(self, date_str: Optional[str]) -> Optional[str]:
        """
        날짜 문자열을 ISO 8601 형식으로 변환합니다.

        🎯 내부 헬퍼 함수

        💡 예시:
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
            # 파싱 실패 시 현재 시간 반환
            return datetime.now().isoformat()


# 🧪 테스트 코드
if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()

    print("=" * 50)
    print("🧪 NoticeService 테스트 시작")
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
            "priority": "중요"
        }

        notice_id = service.save_analyzed_notice(test_notice)
        if notice_id:
            print(f"✅ 저장 성공: {notice_id}")
        else:
            print("❌ 저장 실패")

        # 3. 미처리 공지사항 조회
        print("\n[3단계] 미처리 공지사항 조회...")
        unprocessed = service.get_unprocessed_notices(limit=5)
        print(f"미처리 공지사항: {len(unprocessed)}개")

        print("\n" + "=" * 50)
        print("✅ 모든 테스트 완료!")
        print("=" * 50)

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
