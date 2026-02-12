# -*- coding: utf-8 -*-
"""
스케줄러 서비스

이 파일이 하는 일:
1. 15분마다 자동으로 공지사항을 크롤링하여 AI 분석 및 알림을 수행합니다.
2. 매일 09:00(KST)에 마감일 임박 공지에 대한 디데이 리마인더를 발송합니다.
"""

from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime
import pytz
import sys
import os

# 프로젝트 루트를 Python 경로에 추가
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)


class SchedulerService:
    """
    자동화 스케줄러

    목적:
    - 15분마다 자동으로 크롤링 실행
    - 매일 09:00(KST)에 디데이 리마인더 발송
    - 백그라운드에서 비동기적으로 실행
    - 에러 발생 시 로깅 및 계속 실행
    """

    def __init__(self):
        """스케줄러 초기화"""
        self.scheduler = BackgroundScheduler(timezone=pytz.timezone('Asia/Seoul'))
        self.is_running = False

    def crawl_and_save_job(self):
        """
        크롤링 작업 실행 (스케줄러가 호출)

        이 메서드는 15분마다 자동으로 실행됩니다.
        크롤링 + AI 분석 + 사용자별 관련도 계산 + 알림 발송까지 전체 파이프라인을 수행합니다.
        """
        try:
            print("\n" + "="*60)
            print(f"[스케줄러] 자동 크롤링 시작: {datetime.now()}")
            print("="*60 + "\n")

            # 전체 파이프라인 실행
            from scripts.crawl_and_notify import CrawlAndNotifyPipeline
            pipeline = CrawlAndNotifyPipeline()
            pipeline.run()

            print("\n" + "="*60)
            print(f"[스케줄러] 자동 크롤링 완료: {datetime.now()}")
            print(f"[스케줄러] 다음 실행: 15분 후")
            print("="*60 + "\n")

        except Exception as e:
            print(f"\n[스케줄러 ERROR] 크롤링 중 에러 발생: {str(e)}")
            import traceback
            traceback.print_exc()

    def deadline_reminder_job(self):
        """
        디데이 리마인더 발송 작업 (스케줄러가 호출)

        매일 09:00(KST)에 자동으로 실행됩니다.
        마감일 임박 공지에 대해 사용자별 설정에 맞춰 알림을 발송합니다.
        """
        try:
            print("\n" + "="*60)
            print(f"[스케줄러] 디데이 리마인더 발송 시작: {datetime.now()}")
            print("="*60 + "\n")

            from scripts.send_deadline_reminders import DeadlineReminderPipeline
            pipeline = DeadlineReminderPipeline()
            result = pipeline.run()

            print("\n" + "="*60)
            print(f"[스케줄러] 디데이 리마인더 발송 완료: {datetime.now()}")
            print(f"  - 결과: {result}")
            print(f"[스케줄러] 다음 실행: 내일 09:00 KST")
            print("="*60 + "\n")

        except Exception as e:
            print(f"\n[스케줄러 ERROR] 디데이 리마인더 중 에러 발생: {str(e)}")
            import traceback
            traceback.print_exc()

    def view_count_update_job(self):
        """
        조회수 업데이트 작업 (하루 2회 실행)

        최근 7일 이내 공지의 조회수를 원본 사이트에서 갱신합니다.
        크롤링 파이프라인과 분리하여 서버 부하를 줄입니다.
        """
        try:
            print("\n" + "="*60)
            print(f"[스케줄러] 조회수 업데이트 시작: {datetime.now()}")
            print("="*60 + "\n")

            import re
            from datetime import timedelta, timezone
            from services.supabase_service import get_supabase_client
            from crawler.notice_crawler import NoticeCrawler

            supabase = get_supabase_client()
            crawler = NoticeCrawler()

            # 7일 이내 공지 조회 (최대 30개)
            since = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
            result = supabase.table("notices")\
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
            updated = 0

            for notice in notices:
                source_url = notice.get("source_url")
                if not source_url:
                    continue

                try:
                    soup = crawler.fetch_page(source_url, delay_range=(0.5, 1.0))
                    if not soup:
                        continue

                    bv_txt01 = soup.select_one('div.bv_txt01')
                    if not bv_txt01:
                        del soup
                        continue

                    new_views = None
                    for span in bv_txt01.find_all('span'):
                        if '조회수' in span.get_text():
                            match = re.search(r'(\d+)', span.get_text())
                            if match:
                                new_views = int(match.group(1))
                                break

                    del soup

                    if new_views is None:
                        continue

                    old_views = notice.get("view_count") or 0
                    if new_views > old_views:
                        supabase.table("notices")\
                            .update({"view_count": new_views})\
                            .eq("id", notice["id"])\
                            .execute()
                        updated += 1

                except Exception:
                    continue

            print(f"  [완료] {updated}건 조회수 업데이트 완료")

            print("\n" + "="*60)
            print(f"[스케줄러] 조회수 업데이트 완료: {datetime.now()}")
            print("="*60 + "\n")

        except Exception as e:
            print(f"\n[스케줄러 ERROR] 조회수 업데이트 중 에러 발생: {str(e)}")
            import traceback
            traceback.print_exc()

    def start(self):
        """
        스케줄러 시작

        - 15분마다 crawl_and_save_job() 실행
        - 매일 08:00, 20:00(KST) view_count_update_job() 실행
        - 매일 09:00(KST) deadline_reminder_job() 실행
        """
        if self.is_running:
            print("[스케줄러] 이미 실행 중입니다")
            return

        # 15분마다 크롤링 실행
        self.scheduler.add_job(
            self.crawl_and_save_job,
            'interval',
            minutes=15,
            id='auto_crawling',
            name='15분마다 자동 크롤링',
            replace_existing=True
        )

        # 하루 2회(08:00, 20:00 KST) 조회수 업데이트
        self.scheduler.add_job(
            self.view_count_update_job,
            'cron',
            hour='8,20',
            minute=0,
            id='view_count_update',
            name='하루 2회 조회수 업데이트',
            replace_existing=True
        )

        # 매일 09:00(KST)에 디데이 리마인더 발송
        self.scheduler.add_job(
            self.deadline_reminder_job,
            'cron',
            hour=9,
            minute=0,
            id='deadline_reminder',
            name='매일 09:00 디데이 리마인더',
            replace_existing=True
        )

        # 스케줄러 시작
        self.scheduler.start()
        self.is_running = True

        print("\n" + "="*60)
        print("[스케줄러] 자동화 스케줄러 시작")
        print(f"[스케줄러] 1) 크롤링: 15분마다")
        print(f"[스케줄러] 2) 조회수 업데이트: 매일 08:00, 20:00 KST")
        print(f"[스케줄러] 3) 디데이 리마인더: 매일 09:00 KST")
        print(f"[스케줄러] 현재 시각: {datetime.now(pytz.timezone('Asia/Seoul'))}")
        print("="*60 + "\n")

    def stop(self):
        """스케줄러 중지"""
        if not self.is_running:
            print("[스케줄러] 실행 중이 아닙니다")
            return

        self.scheduler.shutdown()
        self.is_running = False

        print("\n[스케줄러] 자동 크롤링 스케줄러 중지")

    def get_jobs(self):
        """등록된 작업 목록 조회"""
        jobs = self.scheduler.get_jobs()
        return [
            {
                'id': job.id,
                'name': job.name,
                'next_run_time': str(job.next_run_time)
            }
            for job in jobs
        ]
