# -*- coding: utf-8 -*-
"""
FCM 푸시 알림 테스트 스크립트

사용법:
1. Flutter 앱에서 FCM 토큰 받기
2. 이 스크립트 실행: python test_fcm.py
3. FCM 토큰 입력
4. 알림 수신 확인
"""

import os
import sys
import threading
import time
from datetime import datetime
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# 프로젝트 루트 경로 추가
sys.path.insert(0, os.path.dirname(__file__))

from services.fcm_service import FCMService
from supabase import create_client, Client


def test_fcm_direct():
    """
    FCM 토큰을 직접 입력받아서 테스트 알림을 발송합니다.
    """
    print("=" * 60)
    print("FCM 푸시 알림 테스트")
    print("=" * 60)
    print()

    # FCM 토큰 입력받기
    print("📱 Flutter 앱에서 FCM 토큰을 복사해서 입력하세요.")
    print("   (앱 실행 후 로그에서 'FCM Token:' 으로 시작하는 줄 확인)")
    print()
    fcm_token = input("FCM 토큰: ").strip()

    if not fcm_token:
        print("❌ 토큰이 입력되지 않았습니다.")
        return

    # 디바이스 타입 선택
    print("\n디바이스 타입을 선택하세요:")
    print("1. Android")
    print("2. Web (PWA)")
    device_type_choice = input("선택 (1 또는 2): ").strip()

    device_type = "android" if device_type_choice == "1" else "web"

    # FCM 서비스 초기화
    print("\n🔧 FCM 서비스 초기화 중...")
    try:
        fcm_service = FCMService()
    except Exception as e:
        print(f"❌ FCM 초기화 실패: {e}")
        return

    # 테스트 알림 발송
    print(f"\n📤 테스트 알림 발송 중... (디바이스: {device_type})")

    title = "🎓 [테스트] 군산대 새 공지사항"
    body = f"FCM 테스트 알림입니다! ({datetime.now().strftime('%H:%M:%S')})"
    data = {
        "notice_id": "test_123",
        "category": "일반공지",
        "url": "https://www.kunsan.ac.kr"
    }

    success, error = fcm_service.send_to_token(
        token=fcm_token,
        title=title,
        body=body,
        data=data,
        device_type=device_type
    )

    if success:
        print("\n✅ 알림 발송 성공!")
        print(f"   제목: {title}")
        print(f"   내용: {body}")
        print("\n📱 디바이스에서 알림을 확인하세요!")
    else:
        print(f"\n❌ 알림 발송 실패: {error}")
        if error == "UNREGISTERED":
            print("   → FCM 토큰이 만료되었거나 등록 해제되었습니다.")
        elif error == "INVALID_TOKEN":
            print("   → FCM 토큰 형식이 잘못되었습니다.")


def test_fcm_with_db():
    """
    Supabase에 테스트 사용자와 토큰을 등록하고 알림을 발송합니다.
    """
    print("=" * 60)
    print("FCM 푸시 알림 테스트 (DB 연동)")
    print("=" * 60)
    print()

    # Supabase 클라이언트 초기화
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"),
        os.getenv("SUPABASE_KEY")
    )

    # FCM 토큰 입력
    print("📱 Flutter 앱에서 FCM 토큰을 복사해서 입력하세요.")
    fcm_token = input("FCM 토큰: ").strip()

    if not fcm_token:
        print("❌ 토큰이 입력되지 않았습니다.")
        return

    # 디바이스 타입 선택
    print("\n디바이스 타입을 선택하세요:")
    print("1. Android")
    print("2. Web (PWA)")
    device_type_choice = input("선택 (1 또는 2): ").strip()
    device_type = "android" if device_type_choice == "1" else "web"

    # 테스트 사용자 생성/조회
    print("\n🔍 테스트 사용자 확인 중...")
    try:
        # users 테이블에서 테스트 사용자 조회
        result = supabase.table("users").select("*").eq("email", "test@kunsan.ac.kr").execute()

        if result.data:
            user_id = result.data[0]["id"]
            print(f"✅ 기존 테스트 사용자 사용: {user_id}")
        else:
            print("ℹ️  테스트 사용자가 없습니다. users 테이블에 먼저 회원가입을 해주세요.")
            return

    except Exception as e:
        print(f"❌ 사용자 조회 실패: {e}")
        return

    # FCM 토큰 등록
    print("\n📝 FCM 토큰 등록 중...")
    try:
        # 기존 토큰 삭제 (중복 방지)
        supabase.table("device_tokens").delete().eq("user_id", user_id).eq("token", fcm_token).execute()

        # 새 토큰 등록
        supabase.table("device_tokens").insert({
            "user_id": user_id,
            "token": fcm_token,
            "device_type": device_type
        }).execute()

        print("✅ FCM 토큰 등록 완료")

    except Exception as e:
        print(f"❌ 토큰 등록 실패: {e}")
        return

    # FCM 서비스 초기화 및 알림 발송
    print("\n🔧 FCM 서비스 초기화 중...")
    try:
        fcm_service = FCMService()
    except Exception as e:
        print(f"❌ FCM 초기화 실패: {e}")
        return

    print(f"\n📤 사용자 알림 발송 중... (user_id: {user_id})")

    title = "🎓 [테스트] 군산대 새 공지사항"
    body = f"DB 연동 테스트 알림입니다! ({datetime.now().strftime('%H:%M:%S')})"
    data = {
        "notice_id": "test_db_123",
        "category": "학사공지",
        "url": "https://www.kunsan.ac.kr"
    }

    result = fcm_service.send_to_user(
        user_id=user_id,
        title=title,
        body=body,
        data=data
    )

    print("\n📊 발송 결과:")
    print(f"   성공: {result['sent']}건")
    print(f"   실패: {result['failed']}건")
    print(f"   삭제된 토큰: {result['tokens_removed']}개")

    if result['sent'] > 0:
        print("\n✅ 알림 발송 성공!")
        print("📱 디바이스에서 알림을 확인하세요!")
    else:
        print("\n❌ 알림 발송 실패")


def test_fcm_broadcast_all():
    """
    DB에 등록된 모든 디바이스 토큰에 테스트 알림을 일괄 발송합니다.
    """
    print("=" * 60)
    print("FCM 푸시 알림 테스트 (전체 디바이스 일괄 발송)")
    print("=" * 60)
    print()

    # Supabase 클라이언트 초기화
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"),
        os.getenv("SUPABASE_KEY")
    )

    # 모든 디바이스 토큰 조회
    print("🔍 DB에서 모든 디바이스 토큰 조회 중...")
    try:
        result = supabase.table("device_tokens")\
            .select("id, user_id, token, device_type")\
            .execute()
        all_tokens = result.data or []
    except Exception as e:
        print(f"❌ 토큰 조회 실패: {e}")
        return

    if not all_tokens:
        print("⚠️  등록된 디바이스 토큰이 없습니다.")
        return

    # 조회 결과 요약 출력
    user_ids = set(t["user_id"] for t in all_tokens)
    device_types = {}
    for t in all_tokens:
        dt = t["device_type"]
        device_types[dt] = device_types.get(dt, 0) + 1

    print(f"✅ 총 {len(all_tokens)}개 토큰 발견 (사용자 {len(user_ids)}명)")
    for dt, count in device_types.items():
        print(f"   - {dt}: {count}개")

    # 발송 확인
    print()
    confirm = input("⚠️  위 디바이스 전체에 테스트 알림을 보내시겠습니까? (y/N): ").strip().lower()
    if confirm != "y":
        print("❌ 발송이 취소되었습니다.")
        return

    # FCM 서비스 초기화
    print("\n🔧 FCM 서비스 초기화 중...")
    try:
        fcm_service = FCMService()
    except Exception as e:
        print(f"❌ FCM 초기화 실패: {e}")
        return

    # 전체 토큰에 알림 발송
    title = "🎓 [전체 테스트] 군산대 알림 시스템"
    body = f"전체 발송 테스트입니다! ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})"
    data = {
        "notice_id": "test_broadcast",
        "category": "일반공지",
        "url": "https://www.kunsan.ac.kr"
    }

    print(f"\n📤 전체 발송 시작... (총 {len(all_tokens)}개 토큰)")
    print()

    sent = 0
    failed = 0
    tokens_to_remove = []

    for i, token_data in enumerate(all_tokens, 1):
        user_short = token_data["user_id"][:8]
        device_type = token_data["device_type"]
        print(f"  [{i}/{len(all_tokens)}] 사용자 {user_short}... ({device_type}) → ", end="")

        success, error = fcm_service.send_to_token(
            token=token_data["token"],
            title=title,
            body=body,
            data=data,
            device_type=device_type
        )

        if success:
            sent += 1
            print("✅ 성공")
        else:
            failed += 1
            print(f"❌ 실패 ({error})")
            # 만료/무효 토큰은 삭제 대상으로 표시
            if error in ("UNREGISTERED", "INVALID_TOKEN"):
                tokens_to_remove.append(token_data["id"])

    # 무효 토큰 정리
    removed = 0
    if tokens_to_remove:
        print(f"\n🗑️  무효 토큰 {len(tokens_to_remove)}개 정리 중...")
        for token_id in tokens_to_remove:
            try:
                supabase.table("device_tokens")\
                    .delete()\
                    .eq("id", token_id)\
                    .execute()
                removed += 1
            except Exception as e:
                print(f"   토큰 삭제 실패 ({token_id[:8]}...): {e}")

    # 결과 출력
    print()
    print("=" * 60)
    print("📊 전체 발송 결과")
    print("=" * 60)
    print(f"   전체 토큰: {len(all_tokens)}개")
    print(f"   성공: {sent}건")
    print(f"   실패: {failed}건")
    print(f"   삭제된 무효 토큰: {removed}개")
    print()

    if sent > 0:
        print("✅ 알림 발송 완료! 각 디바이스에서 알림을 확인하세요.")
    else:
        print("❌ 모든 발송이 실패했습니다.")


def test_concurrent_duplicate():
    """
    실제 FCM 푸시 알림을 보내서 중복 알림 방지를 테스트합니다.

    테스트 흐름:
    [Phase 1] 락 없이 2개 스레드 동시 발송 → 폰에 알림 2개 도착 (버그 재현)
    [Phase 2] 락 적용 후 2개 스레드 동시 발송 → 폰에 알림 1개만 도착 (수정 확인)
    """
    print("=" * 60)
    print("실제 FCM 푸시 알림 중복 테스트")
    print("=" * 60)
    print()

    # Supabase 클라이언트 초기화
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"),
        os.getenv("SUPABASE_KEY")
    )

    # 테스트용 공지 1개 조회
    print("🔍 테스트용 공지사항 조회 중...")
    notice_result = supabase.table("notices")\
        .select("id, title, ai_summary, category")\
        .order("created_at", desc=True)\
        .limit(1)\
        .execute()

    if not notice_result.data:
        print("❌ 공지사항이 없습니다.")
        return

    notice = notice_result.data[0]
    notice_id = notice["id"]
    notice_title = notice["title"]
    print(f"✅ 공지: {notice_title[:50]}...")
    print(f"   ID: {notice_id}")

    # 테스트용 사용자 조회 (디바이스 토큰이 있는 사용자)
    print("\n🔍 알림 발송 대상 사용자 조회 중...")
    token_result = supabase.table("device_tokens")\
        .select("user_id")\
        .execute()

    if not token_result.data:
        print("❌ 등록된 디바이스 토큰이 없습니다.")
        return

    user_ids = list(set(t["user_id"] for t in token_result.data))
    print(f"✅ 대상 사용자: {len(user_ids)}명")

    # FCM 서비스 초기화
    print("\n🔧 FCM 서비스 초기화 중...")
    try:
        fcm_service = FCMService()
    except Exception as e:
        print(f"❌ FCM 초기화 실패: {e}")
        return

    # ──────────────────────────────────────────────────────
    # Phase 1: 락 없이 동시 발송 (버그 재현 → 폰에 2개 도착)
    # ──────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print("📌 Phase 1: 락 없이 동시 발송 (버그 재현)")
    print("   → 폰에 알림이 2개 도착해야 합니다")
    print("=" * 60)

    # 기존 알림 로그 정리
    supabase.table("notification_logs")\
        .delete()\
        .eq("notice_id", notice_id)\
        .eq("notification_type", "new_notice")\
        .execute()

    phase1_results = {"A": {"push": 0, "log": 0, "skip": 0},
                      "B": {"push": 0, "log": 0, "skip": 0}}

    def send_without_lock(thread_name):
        """락 없이 FCM 발송 + notification_logs INSERT (기존 버그 로직)"""
        for user_id in user_ids:
            # 중복 체크 (SELECT)
            existing = supabase.table("notification_logs")\
                .select("id")\
                .eq("user_id", user_id)\
                .eq("notice_id", notice_id)\
                .eq("notification_type", "new_notice")\
                .execute()

            if existing.data and len(existing.data) > 0:
                phase1_results[thread_name]["skip"] += 1
                print(f"  [{thread_name}] {user_id[:8]}... → ⏭️ 스킵 (이미 존재)")
                continue

            # 실제 FCM 푸시 알림 발송
            title = f"🔴 [Phase1-{thread_name}] 중복 테스트"
            body = f"락 없이 발송 ({thread_name}) - {datetime.now().strftime('%H:%M:%S')}"
            result = fcm_service.send_to_user(
                user_id=user_id,
                title=title,
                body=body,
                data={"notice_id": notice_id, "type": "new_notice", "test": "phase1"}
            )
            phase1_results[thread_name]["push"] += result["sent"]
            print(f"  [{thread_name}] {user_id[:8]}... → 📤 FCM 발송 {result['sent']}건")

            # notification_logs INSERT
            try:
                supabase.table("notification_logs").insert({
                    "user_id": user_id,
                    "notice_id": notice_id,
                    "title": title,
                    "body": body,
                    "sent_at": datetime.now().isoformat(),
                    "is_read": False,
                    "notification_type": "new_notice"
                }).execute()
                phase1_results[thread_name]["log"] += 1
            except Exception as e:
                print(f"  [{thread_name}] {user_id[:8]}... → ❌ DB 실패 ({e})")

    print(f"\n📤 Phase 1 시작: 2개 스레드 동시 발송 (사용자 {len(user_ids)}명)")
    print("-" * 60)

    t1 = threading.Thread(target=send_without_lock, args=("A",))
    t2 = threading.Thread(target=send_without_lock, args=("B",))
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    # Phase 1 결과
    print()
    print("-" * 60)
    print("📊 Phase 1 결과:")
    for name in ("A", "B"):
        r = phase1_results[name]
        print(f"  스레드 {name}: FCM {r['push']}건, DB {r['log']}건, 스킵 {r['skip']}건")

    log_result = supabase.table("notification_logs")\
        .select("id, user_id")\
        .eq("notice_id", notice_id)\
        .eq("notification_type", "new_notice")\
        .execute()
    phase1_logs = log_result.data or []

    from collections import Counter
    p1_counts = Counter(log["user_id"] for log in phase1_logs)
    p1_dups = {uid: cnt for uid, cnt in p1_counts.items() if cnt > 1}

    total_pushes = sum(r["push"] for r in phase1_results.values())
    if p1_dups:
        print(f"\n🔴 Phase 1 결과: 중복 발생! (DB {len(phase1_logs)}건, FCM 총 {total_pushes}건)")
        print("   → 폰에 알림이 2개 왔는지 확인하세요!")
    else:
        print(f"\n🟡 Phase 1: 타이밍상 중복이 안 생겼습니다 (재시도 필요)")
    print()

    # 폰 확인 대기
    input("📱 폰에서 알림 개수를 확인한 후 Enter를 누르세요...")

    # ──────────────────────────────────────────────────────
    # Phase 2: 락 적용 후 동시 발송 (수정 확인 → 폰에 1개만 도착)
    # ──────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print("📌 Phase 2: 락 적용 후 동시 발송 (수정 확인)")
    print("   → 폰에 알림이 1개만 도착해야 합니다")
    print("=" * 60)

    # 기존 알림 로그 정리
    supabase.table("notification_logs")\
        .delete()\
        .eq("notice_id", notice_id)\
        .eq("notification_type", "new_notice")\
        .execute()

    phase2_lock = threading.Lock()
    phase2_results = {"A": {"push": 0, "log": 0, "skip": 0},
                      "B": {"push": 0, "log": 0, "skip": 0}}

    def send_with_lock(thread_name):
        """락 적용하여 FCM 발송 + notification_logs INSERT (수정된 로직)"""
        with phase2_lock:
            for user_id in user_ids:
                # 중복 체크 (SELECT)
                existing = supabase.table("notification_logs")\
                    .select("id")\
                    .eq("user_id", user_id)\
                    .eq("notice_id", notice_id)\
                    .eq("notification_type", "new_notice")\
                    .execute()

                if existing.data and len(existing.data) > 0:
                    phase2_results[thread_name]["skip"] += 1
                    print(f"  [{thread_name}] {user_id[:8]}... → ⏭️ 스킵 (이미 존재)")
                    continue

                # 실제 FCM 푸시 알림 발송
                title = f"🟢 [Phase2-{thread_name}] 락 테스트"
                body = f"락 적용 발송 ({thread_name}) - {datetime.now().strftime('%H:%M:%S')}"
                result = fcm_service.send_to_user(
                    user_id=user_id,
                    title=title,
                    body=body,
                    data={"notice_id": notice_id, "type": "new_notice", "test": "phase2"}
                )
                phase2_results[thread_name]["push"] += result["sent"]
                print(f"  [{thread_name}] {user_id[:8]}... → 📤 FCM 발송 {result['sent']}건")

                # notification_logs INSERT
                try:
                    supabase.table("notification_logs").insert({
                        "user_id": user_id,
                        "notice_id": notice_id,
                        "title": title,
                        "body": body,
                        "sent_at": datetime.now().isoformat(),
                        "is_read": False,
                        "notification_type": "new_notice"
                    }).execute()
                    phase2_results[thread_name]["log"] += 1
                except Exception as e:
                    print(f"  [{thread_name}] {user_id[:8]}... → ❌ DB 실패 ({e})")

    print(f"\n📤 Phase 2 시작: 2개 스레드 동시 발송 + Lock (사용자 {len(user_ids)}명)")
    print("-" * 60)

    t3 = threading.Thread(target=send_with_lock, args=("A",))
    t4 = threading.Thread(target=send_with_lock, args=("B",))
    t3.start()
    t4.start()
    t3.join()
    t4.join()

    # Phase 2 결과
    print()
    print("-" * 60)
    print("📊 Phase 2 결과:")
    for name in ("A", "B"):
        r = phase2_results[name]
        print(f"  스레드 {name}: FCM {r['push']}건, DB {r['log']}건, 스킵 {r['skip']}건")

    log_result2 = supabase.table("notification_logs")\
        .select("id, user_id")\
        .eq("notice_id", notice_id)\
        .eq("notification_type", "new_notice")\
        .execute()
    phase2_logs = log_result2.data or []

    p2_counts = Counter(log["user_id"] for log in phase2_logs)
    p2_dups = {uid: cnt for uid, cnt in p2_counts.items() if cnt > 1}

    total_pushes2 = sum(r["push"] for r in phase2_results.values())
    if p2_dups:
        print(f"\n🔴 Phase 2: 중복 발생! Lock이 제대로 작동하지 않습니다")
    else:
        print(f"\n🟢 Phase 2 결과: 중복 없음! (DB {len(phase2_logs)}건, FCM 총 {total_pushes2}건)")
        print("   → 폰에 알림이 1개만 왔는지 확인하세요!")

    # 최종 비교
    print()
    print("=" * 60)
    print("📋 최종 비교")
    print("=" * 60)
    print(f"  Phase 1 (락 없음): FCM {sum(r['push'] for r in phase1_results.values())}건, "
          f"DB {len(phase1_logs)}건 → {'🔴 중복' if p1_dups else '🟡 중복 미발생'}")
    print(f"  Phase 2 (락 적용): FCM {total_pushes2}건, "
          f"DB {len(phase2_logs)}건 → {'🔴 중복' if p2_dups else '🟢 정상'}")
    print("=" * 60)

    # 테스트 알림 로그 정리
    print("\n🗑️  테스트 알림 로그 정리 중...")
    supabase.table("notification_logs")\
        .delete()\
        .eq("notice_id", notice_id)\
        .eq("notification_type", "new_notice")\
        .execute()
    print("✅ 정리 완료")


def main():
    """메인 함수"""
    print("\nFCM 테스트 방식을 선택하세요:")
    print("1. 직접 테스트 (토큰만 입력)")
    print("2. DB 연동 테스트 (토큰 + 사용자 등록)")
    print("3. 전체 발송 테스트 (DB의 모든 토큰에 발송)")
    print("4. 동시 실행 중복 테스트 (버그 재현)")
    print()

    choice = input("선택 (1, 2, 3 또는 4): ").strip()
    print()

    if choice == "1":
        test_fcm_direct()
    elif choice == "2":
        test_fcm_with_db()
    elif choice == "3":
        test_fcm_broadcast_all()
    elif choice == "4":
        test_concurrent_duplicate()
    else:
        print("❌ 잘못된 선택입니다.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  테스트가 중단되었습니다.")
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
