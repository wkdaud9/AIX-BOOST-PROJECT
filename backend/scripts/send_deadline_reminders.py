#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
마감일 리마인더 알림 스크립트

이 파일이 하는 일:
매일 00:00(KST)에 Render Cron Job으로 실행되어,
마감일이 임박한 공지사항에 대해 사용자별 설정에 맞춰 알림을 발송합니다.

동작 방식:
1. deadline이 D-1 ~ D-7인 공지사항 조회
2. 사용자별 deadline_reminder_days 설정 확인
3. 설정에 맞는 사용자에게만 알림 발송
4. 중복 발송 방지 (notification_logs 테이블 체크)

실행 방법:
python backend/scripts/send_deadline_reminders.py
"""

import os
import sys
from datetime import datetime, timedelta
from typing import List, Dict, Any

# 프로젝트 루트를 Python 경로에 추가
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

from supabase import create_client
from services.fcm_service import FCMService


class DeadlineReminderPipeline:
    """마감일 리마인더 알림 파이프라인"""

    def __init__(self):
        """파이프라인을 초기화합니다."""
        print("\n" + "="*60)
        print("[시작] 마감일 리마인더 알림 파이프라인")
        print(f"[시간] {datetime.now().isoformat()}")
        print("="*60)

        # Supabase 클라이언트
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_KEY")
        self.supabase = create_client(self.supabase_url, self.supabase_key)

        # FCM 서비스 초기화
        try:
            self.fcm_service = FCMService()
            print("[완료] FCM 서비스 초기화 완료")
        except Exception as e:
            self.fcm_service = None
            print(f"[경고] FCM 서비스 초기화 실패: {str(e)}")

    def run(self) -> Dict[str, int]:
        """전체 파이프라인을 실행합니다."""
        start_time = datetime.now()

        # 1. 마감 임박 공지 조회 (D-1 ~ D-7)
        upcoming_notices = self._find_upcoming_deadlines()
        if not upcoming_notices:
            print("\n[완료] 마감 임박 공지가 없습니다.")
            return {"notices": 0, "sent": 0, "skipped": 0}

        # 2. 사용자별 알림 설정 조회
        user_settings = self._load_user_settings()

        # 3. 알림 발송
        sent_count, skipped_count = self._send_reminders(
            upcoming_notices, user_settings
        )

        # 4. 통계 출력
        elapsed = (datetime.now() - start_time).total_seconds()
        print(f"\n{'='*60}")
        print(f"[완료] 마감일 리마인더 파이프라인 종료")
        print(f"  - 마감 임박 공지: {len(upcoming_notices)}건")
        print(f"  - 알림 발송: {sent_count}건")
        print(f"  - 스킵 (설정/중복): {skipped_count}건")
        print(f"  - 소요 시간: {elapsed:.1f}초")
        print(f"{'='*60}")

        return {
            "notices": len(upcoming_notices),
            "sent": sent_count,
            "skipped": skipped_count
        }

    def _find_upcoming_deadlines(self) -> List[Dict[str, Any]]:
        """D-1 ~ D-7 범위의 마감 임박 공지를 조회합니다."""
        print("\n[1단계] 마감 임박 공지 조회")

        today = datetime.now().date()
        date_from = today + timedelta(days=1)   # D-1 (내일)
        date_to = today + timedelta(days=7)     # D-7

        print(f"  - 조회 범위: {date_from} ~ {date_to}")

        try:
            result = self.supabase.table("notices")\
                .select("id, title, ai_summary, category, deadline, deadlines")\
                .gte("deadline", date_from.isoformat())\
                .lte("deadline", date_to.isoformat())\
                .execute()

            notices = result.data or []

            # 각 공지의 D-day 계산
            for notice in notices:
                deadline_date = datetime.strptime(
                    notice["deadline"][:10], "%Y-%m-%d"
                ).date()
                notice["days_until"] = (deadline_date - today).days

            print(f"  - 발견: {len(notices)}건")
            for n in notices:
                print(f"    - D-{n['days_until']}: {n['title'][:40]}...")

            return notices

        except Exception as e:
            print(f"  [오류] 마감 공지 조회 실패: {str(e)}")
            return []

    def _load_user_settings(self) -> Dict[str, Dict[str, Any]]:
        """사용자별 알림 설정을 조회합니다."""
        print("\n[2단계] 사용자 알림 설정 조회")

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

            print(f"  - {len(settings)}명의 설정 로드 완료")
            return settings

        except Exception as e:
            print(f"  [오류] 사용자 설정 조회 실패: {str(e)}")
            return {}

    def _send_reminders(
        self,
        notices: List[Dict[str, Any]],
        user_settings: Dict[str, Dict[str, Any]]
    ) -> tuple:
        """마감일 리마인더를 발송합니다."""
        print("\n[3단계] 리마인더 발송")

        sent_count = 0
        skipped_count = 0

        for notice in notices:
            notice_id = notice["id"]
            days_until = notice["days_until"]
            title = notice.get("title", "공지사항")
            summary = notice.get("ai_summary", "")

            # 알림 제목/본문 생성
            alert_title = f"마감 D-{days_until}: {title[:30]}"
            alert_body = summary if summary else f"'{title}'의 마감일이 {days_until}일 남았습니다."

            # 해당 공지에 리마인더를 받을 사용자 필터링
            for user_id, settings in user_settings.items():
                mode = settings.get("notification_mode", "all_on")
                reminder_days = settings.get("deadline_reminder_days", 3)

                # 알림 모드 체크: 일정 알림은 schedule_only 또는 all_on에서만
                if mode == "all_off" or mode == "notice_only":
                    skipped_count += 1
                    continue

                # D-day 설정 체크: 사용자가 설정한 일수와 일치할 때만
                if days_until > reminder_days:
                    skipped_count += 1
                    continue

                # 중복 발송 체크
                if self._is_already_sent(user_id, notice_id):
                    skipped_count += 1
                    continue

                # 알림 로그 저장
                try:
                    self.supabase.table("notification_logs").insert({
                        "user_id": user_id,
                        "notice_id": notice_id,
                        "title": alert_title,
                        "body": alert_body,
                        "sent_at": datetime.now().isoformat(),
                        "is_read": False,
                        "notification_type": "deadline"
                    }).execute()
                    sent_count += 1
                except Exception as e:
                    # 중복 키 에러는 정상 (이미 발송됨)
                    if "duplicate" in str(e).lower():
                        skipped_count += 1
                        continue
                    print(f"  [오류] 알림 로그 저장 실패: {str(e)}")
                    continue

                # FCM 푸시 발송
                if self.fcm_service:
                    try:
                        result = self.fcm_service.send_to_user(
                            user_id=user_id,
                            title=alert_title,
                            body=alert_body,
                            data={
                                "notice_id": notice_id,
                                "category": notice.get("category", ""),
                                "type": "deadline",
                                "days_until": str(days_until)
                            }
                        )
                        if result["sent"] > 0:
                            print(f"  [발송] user {user_id[:8]}... D-{days_until} "
                                  f"FCM {result['sent']}건")
                    except Exception as e:
                        print(f"  [경고] FCM 발송 실패: {str(e)}")

        return sent_count, skipped_count

    def _is_already_sent(self, user_id: str, notice_id: str) -> bool:
        """해당 공지에 대해 이미 디데이 알림을 보냈는지 확인합니다."""
        try:
            result = self.supabase.table("notification_logs")\
                .select("id")\
                .eq("user_id", user_id)\
                .eq("notice_id", notice_id)\
                .eq("notification_type", "deadline")\
                .execute()

            return len(result.data or []) > 0
        except Exception:
            return False


if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()

    pipeline = DeadlineReminderPipeline()
    result = pipeline.run()

    print(f"\n실행 결과: {result}")
