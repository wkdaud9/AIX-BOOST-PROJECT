# -*- coding: utf-8 -*-
"""
display_mode 백필 + OCR 텍스트 정리 스크립트

이 스크립트가 하는 일:
1. 기존 공지사항의 display_mode를 휴리스틱으로 결정하여 업데이트
2. content에 포함된 [이미지 내용] 섹션을 제거하여 순수 크롤링 텍스트로 복원

실행 방법:
    cd backend
    python scripts/backfill_display_mode.py

옵션:
    --dry-run: 실제 저장 없이 변환 결과만 미리보기
    --limit N: 최대 N개 공지만 처리
"""

import os
import sys
import argparse

# 프로젝트 루트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

from supabase import create_client, Client


def get_supabase_client() -> Client:
    """Supabase 클라이언트 생성"""
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")
    if not url or not key:
        raise ValueError("SUPABASE_URL, SUPABASE_KEY 환경변수가 필요합니다")
    return create_client(url, key)


def determine_display_mode(notice: dict) -> tuple:
    """
    기존 공지사항의 display_mode를 휴리스틱으로 결정합니다.

    반환값: (display_mode, has_important_image)
    """
    content = notice.get('content', '') or ''
    content_images = notice.get('content_images', None) or []
    has_images = len(content_images) > 0

    # OCR 텍스트 제거 후 순수 본문 길이 측정
    clean_content = clean_ocr_from_content(content)
    content_length = len(clean_content.strip())

    if not has_images:
        return 'DOCUMENT', False

    # 이미지 있음
    if content_length < 50:
        # 본문이 거의 없고 이미지만 있는 경우 -> POSTER
        return 'POSTER', True
    elif content_length < 200:
        # 짧은 본문 + 이미지 -> HYBRID
        return 'HYBRID', True
    else:
        # 긴 본문 + 이미지 -> DOCUMENT (이미지는 보조)
        return 'DOCUMENT', False


def clean_ocr_from_content(content: str) -> str:
    """기존 content에서 [이미지 내용] 섹션을 제거합니다."""
    marker = "\n\n[이미지 내용]\n"
    if marker in content:
        return content.split(marker)[0].strip()
    return content


def run_backfill(dry_run: bool = False, limit: int = None):
    """백필 실행"""
    print(f"\n{'='*60}")
    print("display_mode 백필 + OCR 텍스트 정리")
    print(f"   모드: {'DRY-RUN (미리보기)' if dry_run else '실제 업데이트'}")
    if limit:
        print(f"   제한: {limit}개")
    print(f"{'='*60}\n")

    # Supabase 연결
    supabase = get_supabase_client()

    # 모든 공지사항 조회
    query = supabase.table("notices").select(
        "id, title, content, content_images"
    ).order("published_at", desc=True)
    if limit:
        query = query.limit(limit)

    result = query.execute()
    notices = result.data or []

    print(f"대상 공지사항: {len(notices)}개\n")

    if not notices:
        print("업데이트할 공지사항이 없습니다.")
        return

    # 통계
    stats = {'POSTER': 0, 'DOCUMENT': 0, 'HYBRID': 0}
    ocr_cleaned = 0
    updated = 0
    failed = 0

    for i, notice in enumerate(notices, 1):
        notice_id = notice['id']
        title = (notice.get('title', '') or '')[:40]
        content = notice.get('content', '') or ''

        print(f"[{i}/{len(notices)}] {title}...")

        # display_mode 결정
        display_mode, has_important_image = determine_display_mode(notice)
        stats[display_mode] += 1

        # OCR 텍스트 제거
        clean_content = clean_ocr_from_content(content)
        content_changed = clean_content != content

        if content_changed:
            ocr_cleaned += 1

        if dry_run:
            print(f"    -> display_mode: {display_mode}, has_important_image: {has_important_image}")
            if content_changed:
                removed_len = len(content) - len(clean_content)
                print(f"    -> [이미지 내용] 제거: {removed_len}자 삭제")
        else:
            try:
                update_data = {
                    "display_mode": display_mode,
                    "has_important_image": has_important_image,
                }
                if content_changed:
                    update_data["content"] = clean_content

                supabase.table("notices").update(update_data).eq("id", notice_id).execute()
                updated += 1
                print(f"    -> {display_mode} {'(OCR 정리)' if content_changed else ''}")
            except Exception as e:
                print(f"    -> 실패: {str(e)}")
                failed += 1

    # 결과 요약
    print(f"\n{'='*60}")
    print("백필 완료!")
    print(f"   POSTER: {stats['POSTER']}개")
    print(f"   DOCUMENT: {stats['DOCUMENT']}개")
    print(f"   HYBRID: {stats['HYBRID']}개")
    print(f"   OCR 텍스트 정리: {ocr_cleaned}개")
    if not dry_run:
        print(f"   업데이트 성공: {updated}개")
        print(f"   실패: {failed}개")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="display_mode 백필 스크립트")
    parser.add_argument("--dry-run", action="store_true", help="실제 저장 없이 미리보기")
    parser.add_argument("--limit", type=int, default=None, help="최대 처리 개수")
    args = parser.parse_args()

    run_backfill(dry_run=args.dry_run, limit=args.limit)
