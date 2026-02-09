#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
크롤링 + AI 분석 + 알림 파이프라인

이 파일이 하는 일:
15분마다 Render Cron Job에서 자동 실행되는 메인 스크립트입니다.
크롤링 -> AI 분석 -> 임베딩 비교 -> 푸시 알림까지 전체 파이프라인을 실행합니다.

실행 순서:
1. 크롤러 실행 (새 공지 감지)
2. AI 전체 분석 (요약, 카테고리, 중요도) + 임베딩 생성
3. DB 저장 (notices 테이블 + content_embedding)
4. 하이브리드 검색으로 관련 사용자 찾기 (임베딩 비교)
5. 캘린더 이벤트 생성
6. 푸시 알림 발송 + notification_logs 저장

실행 방법:
python backend/scripts/crawl_and_notify.py
"""

import os
import sys
from datetime import datetime
from typing import List, Dict, Any

# 프로젝트 루트를 Python 경로에 추가
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

from crawler.notice_crawler import NoticeCrawler
from crawler.scholarship_crawler import ScholarshipCrawler
from crawler.recruitment_crawler import RecruitmentCrawler
from ai.analyzer import NoticeAnalyzer
from ai.embedding_service import EmbeddingService
from ai.enrichment_service import EnrichmentService
from services.notice_service import NoticeService
from services.hybrid_search_service import HybridSearchService
from services.reranking_service import RerankingService
from services.fcm_service import FCMService
from supabase import create_client


class CrawlAndNotifyPipeline:
    """
    크롤링 + 분석 + 알림 파이프라인

    목적:
    전체 자동화 프로세스를 한 번에 실행합니다.
    """

    def __init__(self):
        """파이프라인을 초기화합니다."""
        print("\n" + "="*60)
        print("[시작] 크롤링 + 분석 + 알림 파이프라인 시작")
        print("="*60)

        # 서비스 초기화
        self.notice_service = NoticeService()
        self.ai_analyzer = NoticeAnalyzer()
        # 새로운 벡터 검색 서비스
        self.embedding_service = EmbeddingService()
        self.enrichment_service = EnrichmentService()
        self.hybrid_search_service = HybridSearchService()
        self.reranking_service = RerankingService()

        # Supabase 클라이언트 (알림 로그용)
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_KEY")
        self.supabase = create_client(self.supabase_url, self.supabase_key)

        # 새 아키텍처 사용 여부 (환경변수로 제어)
        self.use_vector_search = os.getenv("USE_VECTOR_SEARCH", "true").lower() == "true"
        if self.use_vector_search:
            print("벡터 검색 모드 활성화 (하이브리드 검색 기반 알림)")

        # 크롤러 초기화
        self.crawlers = {
            "공지사항": NoticeCrawler(),
            "학사/장학": ScholarshipCrawler(),
            "모집공고": RecruitmentCrawler()
        }

        # FCM 서비스 초기화 (설정되지 않으면 None)
        try:
            self.fcm_service = FCMService()
            print("[완료] FCM 서비스 초기화 완료")
        except Exception as e:
            self.fcm_service = None
            print(f"[경고] FCM 서비스 초기화 실패 (푸시 알림 미발송): {str(e)}")

        print("[완료] 파이프라인 초기화 완료\n")

    def run(self):
        """전체 파이프라인을 실행합니다."""
        start_time = datetime.now()

        try:
            # 1단계: 크롤링
            new_notices = self._step1_crawl()

            if not new_notices:
                print("\n[완료] 새로운 공지사항이 없습니다. 종료합니다.")
                return

            # 2단계: AI 분석
            analyzed_notices = self._step2_analyze(new_notices)

            # 3단계: DB 저장
            saved_ids = self._step3_save_to_db(analyzed_notices)

            # 4단계: 사용자별 관련도 계산
            relevance_results = self._step4_calculate_relevance(saved_ids)

            # 5단계: 푸시 알림 발송
            notification_count = self._step5_send_notifications(relevance_results)

            # 최종 통계
            self._print_final_stats(
                start_time=start_time,
                new_count=len(new_notices),
                analyzed_count=len(analyzed_notices),
                saved_count=len(saved_ids),
                relevance_count=sum(len(users) for users in relevance_results.values()),
                notification_count=notification_count
            )

        except Exception as e:
            print(f"\n[오류] 파이프라인 실행 실패: {str(e)}")
            import traceback
            traceback.print_exc()

    def _step1_crawl(self) -> List[Dict[str, Any]]:
        """
        1단계: 새 공지사항 크롤링 (순번 기반 중복 체크)

        - 첫 크롤링 (DB 비어있음): 게시판당 최대 10개씩 (총 30개)
        - 정기 크롤링 (DB에 데이터 있음): 새 공지 전부 수집 (제한 없음)
        """
        print("\n" + "-"*60)
        print("[1단계] 새 공지사항 크롤링 (순번 기반)")
        print("-"*60)

        all_new_notices = []

        for category, crawler in self.crawlers.items():
            print(f"\n[검색] [{category}] 크롤링 중...")

            # 최적화된 크롤링 (순번 기반 중복 체크)
            if hasattr(crawler, 'crawl_optimized'):
                # DB에 해당 게시판 데이터가 있는지 확인
                last_seq = crawler._get_last_board_seq()
                if last_seq is None:
                    # 첫 크롤링: 게시판당 10개만
                    print(f"  [정보] 첫 크롤링 - 최대 10개만 수집")
                    new_notices = crawler.crawl_optimized(
                        last_board_seq=None, max_pages=1, max_notices=10
                    )
                else:
                    # 정기 크롤링: 새 공지 전부 수집
                    new_notices = crawler.crawl_optimized(
                        last_board_seq=last_seq, max_pages=1, max_notices=100
                    )
            else:
                new_notices = crawler.crawl(max_pages=1, max_notices=10)

            if new_notices:
                print(f"  [완료] {len(new_notices)}개 새 공지 발견")
                all_new_notices.extend(new_notices)
            else:
                print(f"  [정보] 새 공지 없음")

        print(f"\n[통계] 크롤링 완료: 총 {len(all_new_notices)}개 새 공지")
        return all_new_notices

    def _step2_analyze(self, notices: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """2단계: AI 전체 분석 + 임베딩 생성 + 메타데이터 보강"""
        print("\n" + "-"*60)
        print("[2단계] AI 전체 분석" + (" + 임베딩" if self.use_vector_search else ""))
        print("-"*60)

        analyzed_notices = []

        for i, notice in enumerate(notices, 1):
            title = notice.get('title', '')[:40]
            print(f"\n[{i}/{len(notices)}] {title}...")

            try:
                # 이미지 공지 처리: OCR 텍스트는 AI 분석용으로만 사용 (content에 추가하지 않음)
                content = notice.get('content', '')
                content_images = notice.get('content_images', [])

                if content_images:
                    print(f"  [이미지 분석] {len(content_images)}개 이미지 분석 중...")
                    extracted_content = self.ai_analyzer.analyze_images(
                        image_urls=content_images,
                        title=notice.get('title', '')
                    )
                    if extracted_content:
                        # OCR 텍스트를 별도 필드에 저장 (AI 분석 시 참고용)
                        notice['_ocr_text'] = extracted_content
                        print(f"  [완료] 이미지에서 {len(extracted_content)}자 추출 (AI 분석용)")
                    else:
                        notice['_ocr_text'] = ''
                        print(f"  [경고] 이미지 분석 실패")

                    # 본문이 거의 없는 경우 제목으로 대체 (content는 순수 크롤링 텍스트 유지)
                    if len(content) < 50 and not extracted_content:
                        notice['content'] = notice.get('title', '')

                # AI 종합 분석 (요약, 카테고리, 중요도, 날짜)
                analysis = self.ai_analyzer.analyze_notice_comprehensive(notice)

                # 벡터 검색 모드: 임베딩 + 메타데이터 보강
                if self.use_vector_search:
                    try:
                        # 메타데이터 보강
                        enriched = self.enrichment_service.enrich_notice(analysis)
                        analysis["enriched_metadata"] = enriched.get("enriched_metadata", {})

                        # 임베딩 생성
                        embedding_text = self.embedding_service.create_notice_embedding_text(
                            title=analysis.get("title", ""),
                            content=analysis.get("content", ""),
                            summary=analysis.get("summary"),
                            category=analysis.get("category"),
                            keywords=analysis.get("enriched_metadata", {}).get("keywords_expanded"),
                            target_departments=analysis.get("enriched_metadata", {}).get("target_departments")
                        )
                        embedding = self.embedding_service.create_embedding(embedding_text)
                        analysis["content_embedding"] = embedding

                        print(f"  [완료] 분석+임베딩 완료 - {analysis.get('category', '학사')}")
                    except Exception as embed_err:
                        # 임베딩 실패해도 AI 분석 결과(category 등)는 유지
                        print(f"  [경고] 임베딩 생성 실패 (분석 결과는 유지): {str(embed_err)}")
                        print(f"  [완료] 분석 완료 (임베딩 없음) - {analysis.get('category', '학사')}")
                else:
                    print(f"  [완료] 분석 완료 - {analysis.get('category', '학사')}")

                analyzed_notices.append(analysis)

            except Exception as e:
                print(f"  [오류] 분석 실패: {str(e)}")
                # AI 분석 자체가 실패한 경우 원본 데이터 유지
                notice['analyzed'] = False
                analyzed_notices.append(notice)

        print(f"\n[통계] AI 분석 완료: {len(analyzed_notices)}개")
        return analyzed_notices

    def _step3_save_to_db(self, notices: List[Dict[str, Any]]) -> List[str]:
        """3단계: DB 저장 (임베딩 포함)"""
        print("\n" + "-"*60)
        print("[3단계] DB 저장" + (" (임베딩 포함)" if self.use_vector_search else ""))
        print("-"*60)

        saved_ids = []

        for i, notice in enumerate(notices, 1):
            print(f"\n[{i}/{len(notices)}] 저장 중...")

            # 벡터 검색 모드: 임베딩 포함 저장
            if self.use_vector_search and notice.get("content_embedding"):
                notice_id = self.notice_service.save_notice_with_embedding(
                    notice_data=notice,
                    embedding=notice.get("content_embedding"),
                    enriched_metadata=notice.get("enriched_metadata")
                )
            else:
                notice_id = self.notice_service.save_analyzed_notice(notice)

            if notice_id:
                saved_ids.append(notice_id)
                # 중요: 저장된 ID를 원본 notice 딕셔너리에 업데이트
                # step5에서 캘린더 이벤트 생성 시 필요
                notice["id"] = notice_id

        print(f"\n[통계] DB 저장 완료: {len(saved_ids)}개")
        return saved_ids

    def _step4_calculate_relevance(
        self,
        notice_ids: List[str]
    ) -> Dict[str, List[Dict[str, Any]]]:
        """4단계: 하이브리드 검색으로 관련 사용자 찾기 (메모리에서만 처리)"""
        print("\n" + "-"*60)
        print("[4단계] 하이브리드 검색 기반 관련 사용자 찾기")
        print("-"*60)

        # notice_id -> 관련 사용자 리스트 매핑
        relevance_results = {}

        for i, notice_id in enumerate(notice_ids, 1):
            print(f"\n[{i}/{len(notice_ids)}] 공지 {notice_id[:8]}... 관련 사용자 검색 중")

            try:
                # 하이브리드 검색으로 관련 사용자 찾기
                relevant_users = self.hybrid_search_service.find_relevant_users(
                    notice_id=notice_id,
                    min_score=0.5,
                    max_users=50
                )

                # 상위 결과에 대해 리랭킹 (선택적)
                if len(relevant_users) > 10 and self.reranking_service.should_rerank(relevant_users):
                    relevant_users = self.reranking_service.rerank_users_for_notice(
                        notice_id=notice_id,
                        candidate_users=relevant_users,
                        top_n=10
                    )

                # 메모리에만 저장 (ai_analysis 테이블 사용 안 함)
                relevance_results[notice_id] = relevant_users

                print(f"  [완료] {len(relevant_users)}명 관련 사용자 발견")

            except Exception as e:
                print(f"  [오류] 관련도 계산 실패: {str(e)}")
                relevance_results[notice_id] = []

        total_users = sum(len(users) for users in relevance_results.values())
        print(f"\n[통계] 관련 사용자 검색 완료: {len(notice_ids)}개 공지, 총 {total_users}명 알림 대상")

        return relevance_results

    def _step5_send_notifications(
        self,
        relevance_results: Dict[str, List[Dict[str, Any]]]
    ) -> int:
        """6단계: 푸시 알림 발송 (device_tokens 테이블 기반 FCM 발송)"""
        print("\n" + "-"*60)
        print("[6단계] 푸시 알림 발송")
        print("-"*60)

        notification_count = 0
        fcm_sent_count = 0

        try:
            for notice_id, relevant_users in relevance_results.items():
                if not relevant_users:
                    continue

                # 공지사항 정보 조회
                notice_result = self.supabase.table("notices")\
                    .select("title, ai_summary, category")\
                    .eq("id", notice_id)\
                    .single()\
                    .execute()

                notice = notice_result.data if notice_result.data else {}
                notice_title = notice.get("title", "새 공지사항")
                notice_body = notice.get("ai_summary", "")

                print(f"\n[알림] 공지 {notice_id[:8]}... 알림 발송 중 ({len(relevant_users)}명)")

                for user_data in relevant_users:
                    user_id = user_data.get("user_id")
                    relevance_score = user_data.get("total_score", user_data.get("score", 0.5))

                    # 알림 로그 저장 (notification_logs 테이블) - FCM 발송 전에 저장
                    try:
                        self.supabase.table("notification_logs").insert({
                            "user_id": user_id,
                            "notice_id": notice_id,
                            "title": notice_title,
                            "body": notice_body,
                            "sent_at": datetime.now().isoformat(),
                            "is_read": False
                        }).execute()
                        notification_count += 1
                    except Exception as e:
                        print(f"  [오류] 알림 로그 저장 실패: {str(e)}")
                        continue

                    # FCM 푸시 알림 발송
                    if self.fcm_service:
                        try:
                            result = self.fcm_service.send_to_user(
                                user_id=user_id,
                                title=notice_title,
                                body=notice_body,
                                data={
                                    "notice_id": notice_id,
                                    "category": notice.get("category", ""),
                                    "type": "new_notice"
                                }
                            )
                            if result["sent"] > 0:
                                fcm_sent_count += result["sent"]
                                print(f"  [완료] user {user_id[:8]}... "
                                      f"(관련도: {relevance_score:.2f}, "
                                      f"FCM: {result['sent']}건 발송)")
                            else:
                                print(f"  [완료] user {user_id[:8]}... "
                                      f"(관련도: {relevance_score:.2f}, "
                                      f"FCM 토큰 없음 - 로그만 저장)")
                        except Exception as e:
                            print(f"  [경고] FCM 발송 실패 (로그는 저장됨): {str(e)}")
                    else:
                        print(f"  [완료] user {user_id[:8]}... "
                              f"(관련도: {relevance_score:.2f}, "
                              f"FCM 미설정 - 로그만 저장)")

            print(f"\n[통계] 알림 로그 저장: {notification_count}건")
            if self.fcm_service:
                print(f"[통계] FCM 푸시 발송: {fcm_sent_count}건")
            else:
                print("[주의] FCM 미설정으로 실제 푸시 알림은 발송되지 않았습니다")

        except Exception as e:
            print(f"\n[오류] 알림 발송 실패: {str(e)}")

        return notification_count

    def _print_final_stats(
        self,
        start_time: datetime,
        new_count: int,
        analyzed_count: int,
        saved_count: int,
        relevance_count: int,
        notification_count: int
    ):
        """최종 통계 출력"""
        end_time = datetime.now()
        elapsed = (end_time - start_time).total_seconds()

        print("\n" + "="*60)
        print("[완료] 전체 파이프라인 완료!")
        print("="*60)
        print(f"\n[최종 통계]")
        print(f"  - 새 공지 크롤링: {new_count}개")
        print(f"  - AI 분석 완료: {analyzed_count}개")
        print(f"  - DB 저장: {saved_count}개")
        print(f"  - 관련도 분석: {relevance_count}건")
        print(f"  - 알림 발송: {notification_count}건")
        print(f"  - 소요 시간: {elapsed:.2f}초")
        print(f"  - 완료 시각: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print("="*60 + "\n")


def main():
    """메인 함수"""
    try:
        # 환경 변수 로드
        from dotenv import load_dotenv
        load_dotenv()

        # 파이프라인 실행
        pipeline = CrawlAndNotifyPipeline()
        pipeline.run()

    except KeyboardInterrupt:
        print("\n\n[경고] 사용자에 의해 중단되었습니다.")
    except Exception as e:
        print(f"\n[오류] 치명적 오류: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
