# -*- coding: utf-8 -*-
"""
크롤링 스케줄러 서비스

이 파일이 하는 일:
1시간마다 자동으로 공지사항을 크롤링하여 DB에 저장합니다.
"""

from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime
import pytz
from crawler.crawler_manager import CrawlerManager
from services.supabase_service import SupabaseService


class SchedulerService:
    """
    크롤링 자동화 스케줄러

    목적:
    - 1시간마다 자동으로 크롤링 실행
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

        이 메서드는 1시간마다 자동으로 실행됩니다.
        """
        try:
            print("\n" + "="*60)
            print(f"[스케줄러] 자동 크롤링 시작: {datetime.now()}")
            print("="*60 + "\n")

            # 크롤러 실행
            manager = CrawlerManager()
            results = manager.crawl_all(max_pages=2)  # 각 카테고리당 2페이지

            # 크롤링된 데이터 수집
            all_notices = []
            for category, notices in results.items():
                all_notices.extend(notices)

            print(f"\n[스케줄러] 크롤링 완료: {len(all_notices)}개 수집")

            # DB에 저장
            if all_notices:
                supabase = SupabaseService()
                save_result = supabase.insert_notices(all_notices)

                print(f"\n[스케줄러] DB 저장 완료")
                print(f"   - 삽입: {save_result['inserted']}개")
                print(f"   - 중복: {save_result['duplicates']}개")
                print(f"   - 에러: {save_result['errors']}개")
            else:
                print(f"\n[스케줄러] 크롤링된 데이터 없음")

            print("\n" + "="*60)
            print(f"[스케줄러] 자동 크롤링 완료: {datetime.now()}")
            print(f"[스케줄러] 다음 실행: 1시간 후")
            print("="*60 + "\n")

        except Exception as e:
            print(f"\n[스케줄러 ERROR] 크롤링 중 에러 발생: {str(e)}")
            import traceback
            traceback.print_exc()

    def start(self):
        """
        스케줄러 시작

        1시간마다 crawl_and_save_job()을 실행합니다.
        """
        if self.is_running:
            print("[스케줄러] 이미 실행 중입니다")
            return

        # 1시간마다 실행되도록 설정
        self.scheduler.add_job(
            self.crawl_and_save_job,
            'interval',
            hours=1,
            id='auto_crawling',
            name='1시간마다 자동 크롤링',
            replace_existing=True
        )

        # 스케줄러 시작
        self.scheduler.start()
        self.is_running = True

        print("\n" + "="*60)
        print("[스케줄러] 자동 크롤링 스케줄러 시작")
        print(f"[스케줄러] 실행 주기: 1시간마다")
        print(f"[스케줄러] 현재 시각: {datetime.now(pytz.timezone('Asia/Seoul'))}")
        print(f"[스케줄러] 다음 실행: 1시간 후")
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
