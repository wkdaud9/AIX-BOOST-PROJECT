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
import re
import sys
import threading
from datetime import datetime, timedelta
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
from config import Config
from services.notice_service import NoticeService
from services.hybrid_search_service import HybridSearchService
from services.reranking_service import RerankingService
from services.fcm_service import FCMService
from supabase import create_client

# 파이프라인 동시 실행 방지용 락 (스케줄러 + API 동시 호출 방지)
_pipeline_lock = threading.Lock()


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
        # 동시 실행 방지: 이미 실행 중이면 스킵
        if not _pipeline_lock.acquire(blocking=False):
            print("\n[스킵] 다른 파이프라인이 이미 실행 중입니다. 건너뜁니다.")
            return

        start_time = datetime.now()

        try:
            # 0단계: 최근 공지 조회수 업데이트 (7일 이내)
            self._step0_update_view_counts()

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

        finally:
            _pipeline_lock.release()

    def _step0_update_view_counts(self):
        """
        0단계: 최근 7일 공지의 조회수를 원본 사이트에서 갱신합니다.

        크롤링 시점의 조회수 스냅샷만 저장되므로,
        최근 공지는 원본 사이트 조회수가 계속 올라갑니다.
        이 단계에서 최근 공지의 source_url을 방문하여 최신 조회수를 업데이트합니다.
        """
        print("\n" + "-"*60)
        print("[0단계] 최근 공지 조회수 업데이트")
        print("-"*60)

        try:
            # 7일 이내 공지 조회 (최대 30개)
            since = (datetime.now() - timedelta(days=7)).isoformat()
            result = self.supabase.table("notices")\
                .select("id, source_url, view_count")\
                .gte("published_at", since)\
                .not_.is_("source_url", "null")\
                .order("published_at", desc=True)\
                .limit(30)\
                .execute()

            notices = result.data or []
            if not notices:
                print("  [정보] 업데이트할 최근 공지 없음")
                return

            print(f"  [정보] {len(notices)}개 공지 조회수 확인 중...")

            # 아무 크롤러나 하나 사용 (fetch_page용)
            crawler = list(self.crawlers.values())[0]
            updated = 0

            for notice in notices:
                source_url = notice.get("source_url")
                if not source_url:
                    continue

                try:
                    # 상세 페이지에서 조회수 추출
                    soup = crawler.fetch_page(source_url, delay_range=(0.5, 1.0))
                    if not soup:
                        continue

                    bv_txt01 = soup.select_one('div.bv_txt01')
                    if not bv_txt01:
                        continue

                    new_views = None
                    for span in bv_txt01.find_all('span'):
                        if '조회수' in span.get_text():
                            match = re.search(r'(\d+)', span.get_text())
                            if match:
                                new_views = int(match.group(1))
                                break

                    if new_views is None:
                        continue

                    old_views = notice.get("view_count") or 0
                    if new_views > old_views:
                        self.supabase.table("notices")\
                            .update({"view_count": new_views})\
                            .eq("id", notice["id"])\
                            .execute()
                        updated += 1

                except Exception as e:
                    # 개별 공지 실패는 무시하고 계속 진행
                    continue

            print(f"  [완료] {updated}건 조회수 업데이트 완료")

        except Exception as e:
            # 조회수 업데이트 실패해도 크롤링은 계속 진행
            print(f"  [경고] 조회수 업데이트 중 오류 (무시하고 진행): {str(e)}")

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

    def _load_user_categories(self) -> Dict[str, List[str]]:
        """사용자별 선호 카테고리를 일괄 조회합니다."""
        try:
            result = self.supabase.table("user_preferences")\
                .select("user_id, categories")\
                .execute()

            user_categories = {}
            for pref in (result.data or []):
                user_categories[pref["user_id"]] = pref.get("categories") or []

            print(f"  [정보] {len(user_categories)}명의 선호 카테고리 로드 완료")
            return user_categories

        except Exception as e:
            print(f"  [경고] 사용자 카테고리 로드 실패: {str(e)}")
            return {}

    def _step4_calculate_relevance(
        self,
        notice_ids: List[str]
    ) -> Dict[str, List[Dict[str, Any]]]:
        """4단계: 하이브리드 검색 + 카테고리 기반 이중 임계값 필터링"""
        print("\n" + "-"*60)
        print("[4단계] 하이브리드 검색 기반 관련 사용자 찾기 (이중 임계값)")
        print("-"*60)

        # 환경변수에서 임계값 로드
        category_match_min = Config.CATEGORY_MATCH_MIN_SCORE
        category_unmatch_min = Config.CATEGORY_UNMATCH_MIN_SCORE
        min_vector_score = Config.MIN_VECTOR_SCORE

        print(f"  [설정] 관심 카테고리 임계값: {category_match_min}")
        print(f"  [설정] 비관심 카테고리 임계값: {category_unmatch_min}")
        print(f"  [설정] 최소 벡터 점수: {min_vector_score}")

        # 사용자 선호 카테고리 캐시 (전체 조회 1회)
        user_categories_map = self._load_user_categories()

        relevance_results = {}

        for i, notice_id in enumerate(notice_ids, 1):
            print(f"\n[{i}/{len(notice_ids)}] 공지 {notice_id[:8]}... 관련 사용자 검색 중")

            try:
                # 공지사항 카테고리 조회
                notice_result = self.supabase.table("notices")\
                    .select("category")\
                    .eq("id", notice_id)\
                    .single()\
                    .execute()
                notice_category = (notice_result.data or {}).get("category", "")

                # 하이브리드 검색 (낮은 임계값으로 넓게 검색)
                relevant_users = self.hybrid_search_service.find_relevant_users(
                    notice_id=notice_id,
                    min_score=category_match_min,
                    max_users=50
                )

                # 카테고리 기반 이중 임계값 필터링
                filtered_users = []
                for user_data in relevant_users:
                    user_id = user_data.get("user_id")
                    total_score = user_data.get("total_score", 0)
                    vector_score = user_data.get("vector_score", 0)

                    # 최소 벡터 점수 체크 (raw similarity 기준)
                    raw_similarity = vector_score / 0.7 if vector_score > 0 else 0
                    if raw_similarity < min_vector_score:
                        continue

                    # 카테고리 매칭 여부 확인
                    user_cats = user_categories_map.get(user_id, [])
                    is_category_match = notice_category in user_cats

                    # 이중 임계값 적용
                    threshold = category_match_min if is_category_match else category_unmatch_min
                    if total_score >= threshold:
                        user_data["category_match"] = is_category_match
                        filtered_users.append(user_data)

                # 상위 결과에 대해 리랭킹 (선택적)
                if len(filtered_users) > 10 and self.reranking_service.should_rerank(filtered_users):
                    filtered_users = self.reranking_service.rerank_users_for_notice(
                        notice_id=notice_id,
                        candidate_users=filtered_users,
                        top_n=10
                    )

                relevance_results[notice_id] = filtered_users

                print(f"  [완료] {len(relevant_users)}명 검색 → "
                      f"{len(filtered_users)}명 필터링 통과 "
                      f"(카테고리: {notice_category})")

            except Exception as e:
                print(f"  [오류] 관련도 계산 실패: {str(e)}")
                relevance_results[notice_id] = []

        total_users = sum(len(users) for users in relevance_results.values())
        print(f"\n[통계] 관련 사용자 검색 완료: {len(notice_ids)}개 공지, 총 {total_users}명 알림 대상")

        return relevance_results

    def _load_user_notification_settings(self) -> Dict[str, Dict[str, Any]]:
        """사용자별 알림 설정을 일괄 조회합니다."""
        try:
            result = self.supabase.table("user_preferences")\
                .select("user_id, notification_mode, deadline_reminder_days")\
                .execute()

            settings = {}
            for pref in (result.data or []):
                settings[pref["user_id"]] = {
                    "notification_mode": pref.get("notification_mode", "all_on"),
                    "deadline_reminder_days": pref.get("deadline_reminder_days", 3)
                }
            return settings

        except Exception as e:
            print(f"  [경고] 알림 설정 로드 실패: {str(e)}")
            return {}

    def _step5_send_notifications(
        self,
        relevance_results: Dict[str, List[Dict[str, Any]]]
    ) -> int:
        """6단계: 푸시 알림 발송 (사용자 알림 설정 반영)"""
        print("\n" + "-"*60)
        print("[6단계] 푸시 알림 발송 (알림 설정 반영)")
        print("-"*60)

        notification_count = 0
        fcm_sent_count = 0
        skipped_count = 0

        # 사용자 알림 설정 일괄 로드
        user_settings = self._load_user_notification_settings()

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

                    # 사용자 알림 설정 확인
                    settings = user_settings.get(user_id, {"notification_mode": "all_on"})
                    mode = settings.get("notification_mode", "all_on")

                    # 알림 모드 체크: 새 공지 알림은 notice_only 또는 all_on에서만 발송
                    if mode == "all_off" or mode == "schedule_only":
                        skipped_count += 1
                        continue

                    # 중복 발송 체크
                    try:
                        existing = self.supabase.table("notification_logs")\
                            .select("id")\
                            .eq("user_id", user_id)\
                            .eq("notice_id", notice_id)\
                            .eq("notification_type", "new_notice")\
                            .execute()
                        if existing.data and len(existing.data) > 0:
                            skipped_count += 1
                            continue
                    except Exception:
                        pass

                    # 알림 로그 저장 (notification_logs 테이블) - FCM 발송 전에 저장
                    try:
                        self.supabase.table("notification_logs").insert({
                            "user_id": user_id,
                            "notice_id": notice_id,
                            "title": notice_title,
                            "body": notice_body,
                            "sent_at": datetime.now().isoformat(),
                            "is_read": False,
                            "notification_type": "new_notice"
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
            print(f"[통계] 알림 설정으로 스킵: {skipped_count}건")
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
