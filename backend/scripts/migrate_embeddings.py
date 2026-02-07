# -*- coding: utf-8 -*-
"""
임베딩 마이그레이션 스크립트

이 스크립트가 하는 일:
기존 공지사항에 대해 임베딩을 생성하고 DB에 저장합니다.

실행 방법:
    python backend/scripts/migrate_embeddings.py

옵션:
    --dry-run: 실제 저장 없이 테스트만 수행
    --limit N: 최대 N개 공지만 처리
    --user-profiles: 사용자 프로필 임베딩도 생성

예시:
    python backend/scripts/migrate_embeddings.py --dry-run
    python backend/scripts/migrate_embeddings.py --limit 10
    python backend/scripts/migrate_embeddings.py --user-profiles
"""

import os
import sys
import argparse
from datetime import datetime
from typing import List, Dict, Any, Optional

# 프로젝트 루트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

from supabase import create_client, Client
from ai.embedding_service import EmbeddingService
from ai.enrichment_service import EnrichmentService


class EmbeddingMigration:
    """
    임베딩 마이그레이션 클래스

    기능:
    1. 기존 공지사항에 임베딩 생성
    2. 사용자 프로필에 임베딩 생성
    3. 진행 상황 추적 및 재시도 처리
    """

    BATCH_SIZE = 20  # 한 번에 처리할 개수

    def __init__(self):
        """마이그레이션 초기화"""
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"),
            os.getenv("SUPABASE_KEY")
        )
        self.embedding_service = EmbeddingService()
        self.enrichment_service = EnrichmentService()

        print("=" * 60)
        print("임베딩 마이그레이션 초기화 완료")
        print("=" * 60)

    def migrate_notices(
        self,
        dry_run: bool = False,
        limit: Optional[int] = None
    ) -> Dict[str, int]:
        """
        공지사항 임베딩 마이그레이션을 수행합니다.

        매개변수:
        - dry_run: True면 실제 저장 없이 테스트만 수행
        - limit: 최대 처리 개수 (None이면 전체)

        반환값:
        - 통계 딕셔너리 {"total", "success", "failed", "skipped"}
        """
        print("\n" + "=" * 60)
        print("공지사항 임베딩 마이그레이션 시작")
        print(f"모드: {'Dry Run (저장 안 함)' if dry_run else '실제 저장'}")
        if limit:
            print(f"제한: {limit}개")
        print("=" * 60)

        # 임베딩이 없는 공지사항 조회
        notices = self._get_notices_without_embedding(limit)
        total = len(notices)

        print(f"\n마이그레이션 대상: {total}개 공지사항\n")

        if total == 0:
            print("임베딩이 필요한 공지사항이 없습니다.")
            return {"total": 0, "success": 0, "failed": 0, "skipped": 0}

        success_count = 0
        failed_count = 0
        skipped_count = 0

        # 배치 처리
        for i in range(0, total, self.BATCH_SIZE):
            batch = notices[i:i + self.BATCH_SIZE]
            batch_num = i // self.BATCH_SIZE + 1
            total_batches = (total + self.BATCH_SIZE - 1) // self.BATCH_SIZE

            print(f"\n[배치 {batch_num}/{total_batches}] {len(batch)}개 처리 중...")

            for notice in batch:
                try:
                    notice_id = notice["id"]
                    title = notice.get("title", "")[:40]

                    # 1. 메타데이터 보강
                    enriched = self.enrichment_service.enrich_notice(notice)
                    enriched_metadata = enriched.get("enriched_metadata", {})

                    # 2. 임베딩 텍스트 생성
                    embedding_text = self._create_notice_embedding_text(enriched)

                    if not embedding_text:
                        print(f"  [스킵] {title}... (텍스트 없음)")
                        skipped_count += 1
                        continue

                    # 3. 임베딩 생성
                    embedding = self.embedding_service.create_embedding(embedding_text)

                    # 4. DB 업데이트 (dry_run이 아닐 때만)
                    if not dry_run:
                        self._update_notice_embedding(
                            notice_id=notice_id,
                            embedding=embedding,
                            enriched_metadata=enriched_metadata
                        )

                    success_count += 1
                    print(f"  [완료] {title}...")

                except Exception as e:
                    failed_count += 1
                    print(f"  [실패] {title}... ({str(e)})")

            # 진행률 출력
            processed = min(i + self.BATCH_SIZE, total)
            print(f"\n  진행률: {processed}/{total} ({processed * 100 // total}%)")

        # 최종 통계
        print("\n" + "=" * 60)
        print("공지사항 임베딩 마이그레이션 완료")
        print("=" * 60)
        print(f"  - 전체: {total}개")
        print(f"  - 성공: {success_count}개")
        print(f"  - 실패: {failed_count}개")
        print(f"  - 스킵: {skipped_count}개")

        return {
            "total": total,
            "success": success_count,
            "failed": failed_count,
            "skipped": skipped_count
        }

    def migrate_user_profiles(
        self,
        dry_run: bool = False,
        limit: Optional[int] = None
    ) -> Dict[str, int]:
        """
        사용자 프로필 임베딩 마이그레이션을 수행합니다.

        매개변수:
        - dry_run: True면 실제 저장 없이 테스트만 수행
        - limit: 최대 처리 개수 (None이면 전체)

        반환값:
        - 통계 딕셔너리
        """
        print("\n" + "=" * 60)
        print("사용자 프로필 임베딩 마이그레이션 시작")
        print(f"모드: {'Dry Run (저장 안 함)' if dry_run else '실제 저장'}")
        print("=" * 60)

        # 임베딩이 없는 사용자 조회
        users = self._get_users_without_embedding(limit)
        total = len(users)

        print(f"\n마이그레이션 대상: {total}명 사용자\n")

        if total == 0:
            print("임베딩이 필요한 사용자가 없습니다.")
            return {"total": 0, "success": 0, "failed": 0, "skipped": 0}

        success_count = 0
        failed_count = 0
        skipped_count = 0

        for i, user in enumerate(users, 1):
            try:
                user_id = user["id"]

                # 사용자 정보 + preferences 조회
                user_detail = self._get_user_detail(user_id)

                if not user_detail:
                    skipped_count += 1
                    continue

                # 1. 프로필 보강
                enriched = self.enrichment_service.enrich_user_profile(
                    department=user_detail.get("department"),
                    grade=user_detail.get("grade"),
                    interests=user_detail.get("keywords", []),
                    categories=user_detail.get("categories", []),
                    student_type=user_detail.get("student_type")
                )

                # 2. 임베딩 텍스트 생성
                embedding_text = self._create_user_embedding_text(
                    user_detail, enriched
                )

                if not embedding_text:
                    print(f"  [{i}/{total}] [스킵] (프로필 정보 없음)")
                    skipped_count += 1
                    continue

                # 3. 임베딩 생성
                embedding = self.embedding_service.create_embedding(embedding_text)

                # 4. DB 업데이트
                if not dry_run:
                    self._update_user_embedding(
                        user_id=user_id,
                        embedding=embedding,
                        enriched_profile=enriched
                    )

                success_count += 1
                dept = user_detail.get("department", "미지정")[:10]
                print(f"  [{i}/{total}] [완료] {dept}...")

            except Exception as e:
                failed_count += 1
                print(f"  [{i}/{total}] [실패] ({str(e)})")

        # 최종 통계
        print("\n" + "=" * 60)
        print("사용자 프로필 임베딩 마이그레이션 완료")
        print("=" * 60)
        print(f"  - 전체: {total}명")
        print(f"  - 성공: {success_count}명")
        print(f"  - 실패: {failed_count}명")
        print(f"  - 스킵: {skipped_count}명")

        return {
            "total": total,
            "success": success_count,
            "failed": failed_count,
            "skipped": skipped_count
        }

    # =========================================================================
    # 내부 메서드: 데이터 조회
    # =========================================================================

    def _get_notices_without_embedding(
        self,
        limit: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """임베딩이 없는 공지사항 조회"""
        try:
            query = self.supabase.table("notices")\
                .select("id, title, content, ai_summary, category")\
                .is_("content_embedding", "null")\
                .order("published_at", desc=True)

            if limit:
                query = query.limit(limit)

            result = query.execute()
            return result.data or []

        except Exception as e:
            print(f"공지사항 조회 실패: {str(e)}")
            return []

    def _get_users_without_embedding(
        self,
        limit: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """임베딩이 없는 사용자 조회"""
        try:
            # user_preferences에서 임베딩이 없는 사용자 조회
            query = self.supabase.table("user_preferences")\
                .select("user_id")\
                .is_("interests_embedding", "null")

            if limit:
                query = query.limit(limit)

            result = query.execute()

            # users 테이블과 매핑
            users = []
            for pref in (result.data or []):
                users.append({"id": pref["user_id"]})

            return users

        except Exception as e:
            print(f"사용자 조회 실패: {str(e)}")
            return []

    def _get_user_detail(self, user_id: str) -> Optional[Dict[str, Any]]:
        """사용자 상세 정보 조회"""
        try:
            # users 테이블
            user_result = self.supabase.table("users")\
                .select("id, department, grade")\
                .eq("id", user_id)\
                .single()\
                .execute()

            if not user_result.data:
                return None

            user = user_result.data

            # user_preferences 테이블
            pref_result = self.supabase.table("user_preferences")\
                .select("categories, keywords")\
                .eq("user_id", user_id)\
                .single()\
                .execute()

            if pref_result.data:
                user["categories"] = pref_result.data.get("categories", [])
                user["keywords"] = pref_result.data.get("keywords", [])

            return user

        except Exception as e:
            print(f"사용자 상세 조회 실패: {str(e)}")
            return None

    # =========================================================================
    # 내부 메서드: 임베딩 텍스트 생성
    # =========================================================================

    def _create_notice_embedding_text(self, notice: Dict[str, Any]) -> str:
        """공지사항 임베딩 텍스트 생성"""
        return self.embedding_service.create_notice_embedding_text(
            title=notice.get("title", ""),
            content=notice.get("content", ""),
            summary=notice.get("ai_summary"),
            category=notice.get("category"),
            keywords=notice.get("enriched_metadata", {}).get("keywords_expanded"),
            target_departments=notice.get("enriched_metadata", {}).get("target_departments")
        )

    def _create_user_embedding_text(
        self,
        user: Dict[str, Any],
        enriched: Dict[str, Any]
    ) -> str:
        """사용자 프로필 임베딩 텍스트 생성"""
        # 모든 관심사 결합
        all_interests = list(set(
            user.get("keywords", []) +
            enriched.get("interests_expanded", []) +
            enriched.get("department_context", []) +
            enriched.get("grade_context", [])
        ))

        return self.embedding_service.create_user_profile_embedding_text(
            department=user.get("department"),
            grade=user.get("grade"),
            interests=all_interests,
            categories=user.get("categories"),
            student_type=user.get("student_type")
        )

    # =========================================================================
    # 내부 메서드: DB 업데이트
    # =========================================================================

    def _update_notice_embedding(
        self,
        notice_id: str,
        embedding: List[float],
        enriched_metadata: Dict[str, Any]
    ):
        """공지사항 임베딩 업데이트"""
        self.supabase.table("notices")\
            .update({
                "content_embedding": embedding,
                "enriched_metadata": enriched_metadata,
                "updated_at": datetime.now().isoformat()
            })\
            .eq("id", notice_id)\
            .execute()

    def _update_user_embedding(
        self,
        user_id: str,
        embedding: List[float],
        enriched_profile: Dict[str, Any]
    ):
        """사용자 프로필 임베딩 업데이트"""
        self.supabase.table("user_preferences")\
            .update({
                "interests_embedding": embedding,
                "enriched_profile": enriched_profile
            })\
            .eq("user_id", user_id)\
            .execute()


def main():
    """메인 실행 함수"""
    # 명령줄 인자 파싱
    parser = argparse.ArgumentParser(
        description="기존 데이터에 임베딩을 생성합니다."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="실제 저장 없이 테스트만 수행"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="최대 처리 개수"
    )
    parser.add_argument(
        "--user-profiles",
        action="store_true",
        help="사용자 프로필 임베딩도 생성"
    )
    parser.add_argument(
        "--notices-only",
        action="store_true",
        help="공지사항 임베딩만 생성"
    )

    args = parser.parse_args()

    # 마이그레이션 실행
    migration = EmbeddingMigration()

    results = {}

    # 공지사항 마이그레이션
    if not args.user_profiles or not args.notices_only:
        results["notices"] = migration.migrate_notices(
            dry_run=args.dry_run,
            limit=args.limit
        )

    # 사용자 프로필 마이그레이션
    if args.user_profiles or (not args.notices_only):
        results["users"] = migration.migrate_user_profiles(
            dry_run=args.dry_run,
            limit=args.limit
        )

    # 최종 결과 출력
    print("\n" + "=" * 60)
    print("마이그레이션 전체 결과")
    print("=" * 60)

    for category, stats in results.items():
        print(f"\n{category}:")
        for key, value in stats.items():
            print(f"  - {key}: {value}")

    print("\n완료!")


if __name__ == "__main__":
    main()
