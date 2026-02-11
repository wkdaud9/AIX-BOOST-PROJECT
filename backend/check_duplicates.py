# -*- coding: utf-8 -*-
"""
중복 알림 원인 진단 스크립트

이 파일이 하는 일:
1. notices 테이블에서 같은 제목의 공지가 여러 개 있는지 확인
2. notification_logs에서 같은 사용자에게 중복 발송된 알림 확인
3. 중복 원인 분석 (같은 notice_id인지, 다른 notice_id인지)

실행 방법:
python check_duplicates.py
"""

import os
from collections import defaultdict
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)


def check_duplicate_notices():
    """같은 제목의 공지가 여러 개 저장되어 있는지 확인합니다."""
    print("=" * 60)
    print("[1] 중복 제목 공지사항 확인")
    print("=" * 60)

    result = supabase.table("notices")\
        .select("id, title, source_url, source_board, board_seq, created_at")\
        .order("created_at", desc=True)\
        .limit(500)\
        .execute()

    notices = result.data or []
    print(f"최근 공지 {len(notices)}개 조회 완료\n")

    # 제목별 그룹화
    by_title = defaultdict(list)
    for n in notices:
        by_title[n["title"]].append(n)

    # 2개 이상인 제목만 출력
    duplicates = {t: items for t, items in by_title.items() if len(items) >= 2}

    if not duplicates:
        print("✅ 중복 제목 공지 없음\n")
        return

    print(f"⚠️  중복 제목 공지 {len(duplicates)}건 발견!\n")
    for title, items in duplicates.items():
        print(f"  📌 \"{title[:50]}...\"")
        for item in items:
            board = item.get("source_board", "?")
            seq = item.get("board_seq", "?")
            url_short = item.get("source_url", "")[-60:]
            print(f"     - id: {item['id'][:8]}... | 게시판: {board} | 순번: {seq}")
            print(f"       URL: ...{url_short}")
        print()


def check_duplicate_notifications():
    """같은 사용자에게 비슷한 제목으로 중복 발송된 알림을 확인합니다."""
    print("=" * 60)
    print("[2] 중복 알림 발송 확인")
    print("=" * 60)

    result = supabase.table("notification_logs")\
        .select("id, user_id, notice_id, title, sent_at, notification_type")\
        .order("sent_at", desc=True)\
        .limit(500)\
        .execute()

    logs = result.data or []
    print(f"최근 알림 로그 {len(logs)}개 조회 완료\n")

    # 같은 user_id + 같은 title 그룹화
    by_user_title = defaultdict(list)
    for log in logs:
        key = (log["user_id"], log["title"])
        by_user_title[key].append(log)

    # 2개 이상인 것만 출력
    duplicates = {k: items for k, items in by_user_title.items() if len(items) >= 2}

    if not duplicates:
        print("✅ 중복 알림 없음\n")
        return

    print(f"⚠️  중복 알림 {len(duplicates)}건 발견!\n")
    for (user_id, title), items in duplicates.items():
        print(f"  📌 사용자: {user_id[:8]}... | \"{title[:40]}...\"")

        notice_ids = set(item["notice_id"] for item in items)
        if len(notice_ids) > 1:
            print(f"     🔴 원인: 다른 notice_id → 같은 공지가 DB에 2개 저장됨 (게시판 중복 가능성)")
        else:
            print(f"     🟡 원인: 같은 notice_id → 파이프라인 중복 실행 가능성")

        for item in items:
            print(f"     - notice_id: {item['notice_id'][:8]}... | "
                  f"발송: {item['sent_at'][:19]} | "
                  f"타입: {item.get('notification_type', '?')}")
        print()


def check_device_tokens():
    """같은 사용자에게 여러 토큰이 등록되어 있는지 확인합니다."""
    print("=" * 60)
    print("[3] 디바이스 토큰 중복 확인")
    print("=" * 60)

    result = supabase.table("device_tokens")\
        .select("id, user_id, device_type, token")\
        .execute()

    tokens = result.data or []
    print(f"전체 토큰 {len(tokens)}개 조회 완료\n")

    # 사용자별 그룹화
    by_user = defaultdict(list)
    for t in tokens:
        by_user[t["user_id"]].append(t)

    # 2개 이상인 사용자 출력
    multi_token_users = {u: items for u, items in by_user.items() if len(items) >= 2}

    if not multi_token_users:
        print("✅ 모든 사용자가 토큰 1개씩\n")
        return

    print(f"⚠️  토큰 2개 이상 사용자 {len(multi_token_users)}명\n")
    for user_id, items in multi_token_users.items():
        print(f"  📌 사용자: {user_id[:8]}... ({len(items)}개 토큰)")
        for item in items:
            token_short = item["token"][:20]
            print(f"     - {item['device_type']}: {token_short}...")
        print()


def main():
    """진단 실행"""
    print("\n🔍 중복 알림 원인 진단 시작\n")

    check_duplicate_notices()
    check_duplicate_notifications()
    check_device_tokens()

    print("=" * 60)
    print("🔍 진단 완료")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
