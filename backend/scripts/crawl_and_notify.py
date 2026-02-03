#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
크롤링 + AI 분석 + 알림 파이프라인

🤔 이 파일이 하는 일:
15분마다 Render Cron Job에서 자동 실행되는 메인 스크립트입니다.
크롤링 → AI 분석 → 사용자별 관련도 계산 → 푸시 알림까지 전체 파이프라인을 실행합니다.

📚 실행 순서:
1. 크롤러 실행 (새 공지 감지)
2. AI 전체 분석 (요약, 카테고리, 중요도)
3. DB 저장 (notices 테이블)
4. 사용자별 관련도 계산 (ai_analysis 테이블)
5. 푸시 알림 발송 (relevance_score >= 0.5)
6. 알림 로그 저장 (notification_logs 테이블)

💡 실행 방법:
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
from services.notice_service import NoticeService
from services.ai_analysis_service import AIAnalysisService
from services.calendar_service import CalendarService
from supabase import create_client


class CrawlAndNotifyPipeline:
    """
    크롤링 + 분석 + 알림 파이프라인

    🎯 목적:
    전체 자동화 프로세스를 한 번에 실행합니다.
    """

    def __init__(self):
        """파이프라인을 초기화합니다."""
        print("\n" + "="*60)
        print("🚀 크롤링 + 분석 + 알림 파이프라인 시작")
        print("="*60)

        # 서비스 초기화
        self.notice_service = NoticeService()
        self.ai_analyzer = NoticeAnalyzer()
        self.ai_analysis_service = AIAnalysisService()
        self.calendar_service = CalendarService()

        # Supabase 클라이언트 (알림 로그용)
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_KEY")
        self.supabase = create_client(self.supabase_url, self.supabase_key)

        # 크롤러 초기화
        self.crawlers = {
            "공지사항": NoticeCrawler(),
            "학사/장학": ScholarshipCrawler(),
            "모집공고": RecruitmentCrawler()
        }

        print("✅ 파이프라인 초기화 완료\n")

    def run(self):
        """전체 파이프라인을 실행합니다."""
        start_time = datetime.now()

        try:
            # 1단계: 크롤링
            new_notices = self._step1_crawl()

            if not new_notices:
                print("\n✅ 새로운 공지사항이 없습니다. 종료합니다.")
                return

            # 2단계: AI 분석
            analyzed_notices = self._step2_analyze(new_notices)

            # 3단계: DB 저장
            saved_ids = self._step3_save_to_db(analyzed_notices)

            # 4단계: 사용자별 관련도 계산
            relevance_results = self._step4_calculate_relevance(saved_ids)

            # 5단계: 캘린더 이벤트 생성
            calendar_count = self._step5_create_calendar_events(analyzed_notices)

            # 6단계: 푸시 알림 발송
            notification_count = self._step6_send_notifications(relevance_results)

            # 최종 통계
            self._print_final_stats(
                start_time=start_time,
                new_count=len(new_notices),
                analyzed_count=len(analyzed_notices),
                saved_count=len(saved_ids),
                relevance_count=sum(r['notified'] for r in relevance_results.values()),
                calendar_count=calendar_count,
                notification_count=notification_count
            )

        except Exception as e:
            print(f"\n❌ 파이프라인 실행 실패: {str(e)}")
            import traceback
            traceback.print_exc()

    def _step1_crawl(self) -> List[Dict[str, Any]]:
        """1단계: 새 공지사항 크롤링"""
        print("\n" + "─"*60)
        print("📡 [1단계] 새 공지사항 크롤링")
        print("─"*60)

        all_new_notices = []

        for category, crawler in self.crawlers.items():
            print(f"\n🔍 [{category}] 크롤링 중...")

            # DB에서 마지막 저장된 공지 ID 조회
            last_id = self.notice_service.get_latest_original_id(category=category)

            # 최적화된 크롤링 (목록 먼저 확인)
            if hasattr(crawler, 'crawl_optimized'):
                new_notices = crawler.crawl_optimized(
                    last_known_id=last_id,
                    max_pages=3  # 최대 3페이지까지 확인
                )
            else:
                # 기존 크롤러는 일반 크롤링
                new_notices = crawler.crawl(max_pages=1)

            if new_notices:
                print(f"  ✅ {len(new_notices)}개 새 공지 발견")
                all_new_notices.extend(new_notices)
            else:
                print(f"  ℹ️ 새 공지 없음")

        print(f"\n📊 크롤링 완료: 총 {len(all_new_notices)}개 새 공지")
        return all_new_notices

    def _step2_analyze(self, notices: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """2단계: AI 전체 분석"""
        print("\n" + "─"*60)
        print("🤖 [2단계] AI 전체 분석")
        print("─"*60)

        analyzed_notices = []

        for i, notice in enumerate(notices, 1):
            title = notice.get('title', '')[:40]
            print(f"\n[{i}/{len(notices)}] {title}...")

            try:
                # AI 종합 분석 (요약, 카테고리, 중요도, 날짜)
                analysis = self.ai_analyzer.analyze_notice_comprehensive(notice)
                analyzed_notices.append(analysis)
                print(f"  ✅ 분석 완료 - {analysis.get('category', '기타')}/{analysis.get('priority', '일반')}")

            except Exception as e:
                print(f"  ❌ 분석 실패: {str(e)}")
                # 분석 실패해도 원본 데이터는 유지
                notice['analyzed'] = False
                analyzed_notices.append(notice)

        print(f"\n📊 AI 분석 완료: {len(analyzed_notices)}개")
        return analyzed_notices

    def _step3_save_to_db(self, notices: List[Dict[str, Any]]) -> List[str]:
        """3단계: DB 저장"""
        print("\n" + "─"*60)
        print("💾 [3단계] DB 저장")
        print("─"*60)

        saved_ids = []

        for i, notice in enumerate(notices, 1):
            print(f"\n[{i}/{len(notices)}] 저장 중...")

            notice_id = self.notice_service.save_analyzed_notice(notice)

            if notice_id:
                saved_ids.append(notice_id)

        print(f"\n📊 DB 저장 완료: {len(saved_ids)}개")
        return saved_ids

    def _step4_calculate_relevance(
        self,
        notice_ids: List[str]
    ) -> Dict[str, Dict[str, int]]:
        """4단계: 사용자별 관련도 계산"""
        print("\n" + "─"*60)
        print("🎯 [4단계] 사용자별 관련도 계산")
        print("─"*60)

        relevance_results = {}

        for i, notice_id in enumerate(notice_ids, 1):
            print(f"\n[{i}/{len(notice_ids)}] 공지 {notice_id[:8]}... 관련도 계산 중")

            try:
                # 전체 사용자에 대해 관련도 계산
                result = self.ai_analysis_service.batch_analyze_for_users(
                    notice_id=notice_id,
                    user_ids=None  # None = 전체 사용자
                )

                relevance_results[notice_id] = result
                print(f"  ✅ {result['analyzed']}명 분석 완료, {result['notified']}명 알림 대상")

            except Exception as e:
                print(f"  ❌ 관련도 계산 실패: {str(e)}")
                relevance_results[notice_id] = {"total": 0, "analyzed": 0, "notified": 0}

        total_notified = sum(r['notified'] for r in relevance_results.values())
        print(f"\n📊 관련도 계산 완료: {len(notice_ids)}개 공지, 총 {total_notified}건 알림 대상")

        return relevance_results

    def _step5_create_calendar_events(
        self,
        notices: List[Dict[str, Any]]
    ) -> int:
        """5단계: 캘린더 이벤트 생성"""
        print("\n" + "─"*60)
        print("📅 [5단계] 캘린더 이벤트 생성")
        print("─"*60)

        calendar_count = 0

        for i, notice in enumerate(notices, 1):
            dates = notice.get("dates", {})

            # 날짜 정보가 있는 공지만 처리
            if not dates or not any(dates.values()):
                continue

            print(f"\n[{i}/{len(notices)}] 캘린더 이벤트 생성 중...")

            try:
                event_ids = self.calendar_service.create_calendar_events(
                    notice_id=notice.get("id"),
                    dates=dates,
                    notice_title=notice.get("original_title", notice.get("title", "")),
                    category=notice.get("category", "기타"),
                    user_ids=None  # 관심 사용자 자동 조회
                )
                calendar_count += len(event_ids)
                print(f"  ✅ {len(event_ids)}개 이벤트 생성")

            except Exception as e:
                print(f"  ❌ 캘린더 생성 실패: {str(e)}")

        print(f"\n📊 캘린더 이벤트 생성 완료: {calendar_count}개")
        return calendar_count

    def _step6_send_notifications(
        self,
        relevance_results: Dict[str, Dict[str, int]]
    ) -> int:
        """6단계: 푸시 알림 발송"""
        print("\n" + "─"*60)
        print("🔔 [6단계] 푸시 알림 발송")
        print("─"*60)

        notification_count = 0

        try:
            # relevance_score >= 0.5인 분석 결과 조회
            for notice_id, result in relevance_results.items():
                if result['notified'] == 0:
                    continue

                print(f"\n📢 공지 {notice_id[:8]}... 알림 발송 중 ({result['notified']}명)")

                # ai_analysis 테이블에서 알림 대상 조회
                analyses = self.supabase.table("ai_analysis")\
                    .select("*, users(id, name, fcm_token), notices(title, category)")\
                    .eq("notice_id", notice_id)\
                    .gte("relevance_score", 0.5)\
                    .execute()

                for analysis in analyses.data:
                    user = analysis.get("users", {})
                    notice = analysis.get("notices", {})
                    fcm_token = user.get("fcm_token")

                    if not fcm_token:
                        print(f"  ⚠️ {user.get('name', 'Unknown')} - FCM 토큰 없음")
                        continue

                    # TODO: FCM 푸시 알림 발송 (나중에 구현)
                    # send_fcm_notification(fcm_token, notice['title'], ...)

                    # 알림 로그 저장
                    try:
                        self.supabase.table("notification_logs").insert({
                            "user_id": user["id"],
                            "notice_id": notice_id,
                            "type": "push",
                            "title": notice.get("title", ""),
                            "message": analysis.get("summary", ""),
                            "sent_at": datetime.now().isoformat(),
                            "status": "pending"  # FCM 구현 후 "sent"로 변경
                        }).execute()

                        notification_count += 1
                        print(f"  ✅ {user.get('name', 'Unknown')} - 알림 대기 중")

                    except Exception as e:
                        print(f"  ❌ 알림 로그 저장 실패: {str(e)}")

            print(f"\n📊 알림 발송 완료: {notification_count}건")
            print("⚠️ 주의: FCM 미구현으로 알림이 실제 발송되지 않았습니다")

        except Exception as e:
            print(f"\n❌ 알림 발송 실패: {str(e)}")

        return notification_count

    def _print_final_stats(
        self,
        start_time: datetime,
        new_count: int,
        analyzed_count: int,
        saved_count: int,
        relevance_count: int,
        calendar_count: int,
        notification_count: int
    ):
        """최종 통계 출력"""
        end_time = datetime.now()
        elapsed = (end_time - start_time).total_seconds()

        print("\n" + "="*60)
        print("✅ 전체 파이프라인 완료!")
        print("="*60)
        print(f"\n📊 최종 통계:")
        print(f"  - 새 공지 크롤링: {new_count}개")
        print(f"  - AI 분석 완료: {analyzed_count}개")
        print(f"  - DB 저장: {saved_count}개")
        print(f"  - 관련도 분석: {relevance_count}건")
        print(f"  - 캘린더 이벤트: {calendar_count}개")
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
        print("\n\n⚠️ 사용자에 의해 중단되었습니다.")
    except Exception as e:
        print(f"\n❌ 치명적 오류: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
