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

    def start(self):
        """
        스케줄러 시작

        - 15분마다 crawl_and_save_job() 실행
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
        print(f"[스케줄러] 2) 디데이 리마인더: 매일 09:00 KST")
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
