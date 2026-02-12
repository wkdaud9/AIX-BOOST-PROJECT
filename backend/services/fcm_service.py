# -*- coding: utf-8 -*-
"""
FCM 푸시 알림 서비스

이 파일이 하는 일:
Firebase Cloud Messaging을 통해 사용자에게 푸시 알림을 발송합니다.
Android 네이티브 앱과 Web(iPhone PWA) 모두 지원합니다.
"""

import os
import json
from typing import List, Dict, Any, Optional, Tuple

import firebase_admin
from firebase_admin import credentials, messaging
from services.supabase_service import get_supabase_client


class FCMService:
    """
    Firebase Cloud Messaging 서비스

    목적:
    - FCM 토큰 기반 푸시 알림 발송
    - 단건/다건 발송 지원
    - 만료/무효 토큰 자동 정리
    """

    _initialized = False  # Firebase 앱 중복 초기화 방지

    def __init__(self):
        """Firebase Admin SDK 및 Supabase 클라이언트를 초기화합니다."""
        self._init_firebase()
        self.supabase = get_supabase_client()
        print("[FCM] FCMService 초기화 완료")

    @classmethod
    def _init_firebase(cls):
        """
        Firebase Admin SDK를 초기화합니다.

        환경변수 FIREBASE_CREDENTIALS_JSON에 서비스 계정 JSON 문자열을 설정하거나,
        GOOGLE_APPLICATION_CREDENTIALS에 파일 경로를 설정합니다.
        """
        if cls._initialized:
            return

        cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

        if cred_json:
            # Render 등 클라우드 환경: JSON 문자열로 직접 전달
            cred_dict = json.loads(cred_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            print("[FCM] Firebase 초기화 완료 (JSON 환경변수)")
        elif cred_path:
            # 로컬 개발 환경: 파일 경로로 전달
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print(f"[FCM] Firebase 초기화 완료 (파일: {cred_path})")
        else:
            raise ValueError(
                "FIREBASE_CREDENTIALS_JSON 또는 GOOGLE_APPLICATION_CREDENTIALS "
                "환경 변수가 필요합니다"
            )

        cls._initialized = True

    def get_user_tokens(self, user_id: str) -> List[Dict[str, str]]:
        """
        사용자의 모든 디바이스 토큰을 조회합니다.

        매개변수:
        - user_id: 사용자 UUID

        반환값:
        - [{"id": "token_row_id", "token": "fcm_token", "device_type": "android"}, ...]
        """
        try:
            result = self.supabase.table("device_tokens")\
                .select("id, token, device_type")\
                .eq("user_id", user_id)\
                .execute()
            return result.data or []
        except Exception as e:
            print(f"[FCM] 토큰 조회 실패 (user={user_id[:8]}...): {str(e)}")
            return []

    def send_to_token(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
        device_type: str = "android"
    ) -> Tuple[bool, Optional[str]]:
        """
        단일 토큰에 푸시 알림을 발송합니다.

        매개변수:
        - token: FCM 디바이스 토큰
        - title: 알림 제목
        - body: 알림 내용
        - data: 커스텀 데이터 페이로드 (선택)
        - device_type: 디바이스 유형 ('android' | 'web' | 'ios')

        반환값:
        - (성공여부, 에러메시지 또는 None)
        """
        try:
            message_kwargs = {
                "token": token,
                "notification": messaging.Notification(
                    title=title,
                    body=body
                ),
                "data": data or {}
            }

            # Android 전용 설정 (헤드업 알림 + 소리 + 진동 + 잠금화면 표시)
            if device_type == "android":
                message_kwargs["android"] = messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        click_action="FLUTTER_NOTIFICATION_CLICK",
                        channel_id="aix_boost_notifications",
                        default_sound=True,
                        default_vibrate_timings=True,
                        visibility="public",

                    )
                )

            # Web(PWA) 전용 설정 - iPhone 사용자 대상
            if device_type == "web":
                message_kwargs["webpush"] = messaging.WebpushConfig(
                    notification=messaging.WebpushNotification(
                        icon="/icons/icon-192x192.png"
                    )
                    # fcm_options는 HTTPS URL이 필요하므로 제거
                )

            message = messaging.Message(**message_kwargs)
            response = messaging.send(message)
            print(f"[FCM] 발송 성공: {response}")
            return True, None

        except messaging.UnregisteredError:
            # 토큰이 만료/해제됨 -> 삭제 대상
            return False, "UNREGISTERED"
        except ValueError as e:
            # 토큰 형식이 잘못됨 또는 파라미터 오류 -> 삭제 대상
            error_msg = str(e)
            if "token" in error_msg.lower() or "invalid" in error_msg.lower():
                return False, "INVALID_TOKEN"
            print(f"[FCM] 발송 실패 (ValueError): {error_msg}")
            return False, error_msg
        except Exception as e:
            print(f"[FCM] 발송 실패: {str(e)}")
            return False, str(e)

    def send_to_user(
        self,
        user_id: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        사용자의 모든 디바이스에 푸시 알림을 발송합니다.

        매개변수:
        - user_id: 사용자 UUID
        - title: 알림 제목
        - body: 알림 내용
        - data: 커스텀 데이터 페이로드 (선택)

        반환값:
        - {"sent": 성공수, "failed": 실패수, "tokens_removed": 삭제된_토큰수}
        """
        tokens = self.get_user_tokens(user_id)
        if not tokens:
            return {"sent": 0, "failed": 0, "tokens_removed": 0}

        sent = 0
        failed = 0
        tokens_to_remove = []

        for token_data in tokens:
            success, error = self.send_to_token(
                token=token_data["token"],
                title=title,
                body=body,
                data=data,
                device_type=token_data["device_type"]
            )

            if success:
                sent += 1
            else:
                failed += 1
                # 만료/무효 토큰은 DB에서 삭제
                if error in ("UNREGISTERED", "INVALID_TOKEN"):
                    tokens_to_remove.append(token_data["id"])

        # 무효 토큰 정리
        removed = self._remove_invalid_tokens(tokens_to_remove)

        return {"sent": sent, "failed": failed, "tokens_removed": removed}

    def send_to_multiple_users(
        self,
        user_ids: List[str],
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        여러 사용자에게 일괄 푸시 알림을 발송합니다.

        send_each() 배치 API를 사용하여 효율적으로 발송합니다.

        매개변수:
        - user_ids: 사용자 UUID 리스트
        - title: 알림 제목
        - body: 알림 내용
        - data: 커스텀 데이터 페이로드 (선택)

        반환값:
        - {"total_users": 전체, "total_sent": 성공, "total_failed": 실패, "total_removed": 삭제}
        """
        if not user_ids:
            return {"total_users": 0, "total_sent": 0, "total_failed": 0, "total_removed": 0}

        # 1. 모든 사용자의 토큰을 한 번에 조회
        try:
            result = self.supabase.table("device_tokens")\
                .select("id, user_id, token, device_type")\
                .in_("user_id", user_ids)\
                .execute()
            all_tokens = result.data or []
        except Exception as e:
            print(f"[FCM] 토큰 일괄 조회 실패: {str(e)}")
            return {"total_users": len(user_ids), "total_sent": 0, "total_failed": 0, "total_removed": 0}

        if not all_tokens:
            return {"total_users": len(user_ids), "total_sent": 0, "total_failed": 0, "total_removed": 0}

        # 2. 메시지 빌드
        messages = []
        token_map = {}  # index -> token_data (실패 시 토큰 정리용)

        for token_data in all_tokens:
            message_kwargs = {
                "token": token_data["token"],
                "notification": messaging.Notification(title=title, body=body),
                "data": data or {}
            }

            device_type = token_data.get("device_type", "android")
            if device_type == "android":
                message_kwargs["android"] = messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        click_action="FLUTTER_NOTIFICATION_CLICK",
                        channel_id="aix_boost_notifications",
                        default_sound=True,
                        default_vibrate_timings=True,
                        visibility="public",

                    )
                )
            elif device_type == "web":
                message_kwargs["webpush"] = messaging.WebpushConfig(
                    notification=messaging.WebpushNotification(
                        icon="/icons/icon-192x192.png"
                    )
                )

            token_map[len(messages)] = token_data
            messages.append(messaging.Message(**message_kwargs))

        # 3. 배치 발송 (최대 500개씩)
        total_sent = 0
        total_failed = 0
        tokens_to_remove = []
        BATCH_SIZE = 500

        for batch_start in range(0, len(messages), BATCH_SIZE):
            batch = messages[batch_start:batch_start + BATCH_SIZE]

            try:
                response = messaging.send_each(batch)

                for i, send_response in enumerate(response.responses):
                    idx = batch_start + i
                    if send_response.success:
                        total_sent += 1
                    else:
                        total_failed += 1
                        error = send_response.exception
                        if isinstance(error, messaging.UnregisteredError):
                            tokens_to_remove.append(token_map[idx]["id"])
                        elif isinstance(error, ValueError) and (
                            "token" in str(error).lower() or "invalid" in str(error).lower()
                        ):
                            tokens_to_remove.append(token_map[idx]["id"])

            except Exception as e:
                print(f"[FCM] 배치 발송 실패: {str(e)}")
                total_failed += len(batch)

        # 4. 무효 토큰 정리
        total_removed = self._remove_invalid_tokens(tokens_to_remove)

        print(f"[FCM] 일괄 발송 완료: {total_sent}성공, {total_failed}실패, {total_removed}토큰 삭제")

        return {
            "total_users": len(user_ids),
            "total_sent": total_sent,
            "total_failed": total_failed,
            "total_removed": total_removed
        }

    def _remove_invalid_tokens(self, token_ids: List[str]) -> int:
        """
        만료/무효 토큰을 DB에서 일괄 삭제합니다.

        매개변수:
        - token_ids: 삭제할 device_tokens 행의 ID 리스트

        반환값:
        - 삭제된 토큰 수
        """
        if not token_ids:
            return 0

        try:
            self.supabase.table("device_tokens")\
                .delete()\
                .in_("id", token_ids)\
                .execute()
            print(f"[FCM] 무효 토큰 {len(token_ids)}개 일괄 삭제")
            return len(token_ids)
        except Exception as e:
            print(f"[FCM] 토큰 일괄 삭제 실패, 개별 삭제 시도: {str(e)}")
            removed = 0
            for token_id in token_ids:
                try:
                    self.supabase.table("device_tokens")\
                        .delete()\
                        .eq("id", token_id)\
                        .execute()
                    removed += 1
                except Exception:
                    pass
            return removed
