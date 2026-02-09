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


def main():
    """메인 함수"""
    print("\nFCM 테스트 방식을 선택하세요:")
    print("1. 직접 테스트 (토큰만 입력)")
    print("2. DB 연동 테스트 (토큰 + 사용자 등록)")
    print()

    choice = input("선택 (1 또는 2): ").strip()
    print()

    if choice == "1":
        test_fcm_direct()
    elif choice == "2":
        test_fcm_with_db()
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
