# -*- coding: utf-8 -*-
"""
크롤러 상세 테스트 스크립트
크롤링한 데이터의 상세 정보를 확인합니다.
"""

import json
from crawler import NoticeCrawler

def print_notice_detail(notice, index):
    """공지사항 상세 정보를 예쁘게 출력"""
    print(f"\n{'='*70}")
    print(f"📋 공지사항 #{index}")
    print(f"{'='*70}")

    # 각 필드 출력
    for key, value in notice.items():
        # 값이 너무 길면 일부만 표시
        if isinstance(value, str) and len(value) > 150:
            display_value = value[:150] + "..."
        elif isinstance(value, list):
            display_value = f"[{len(value)}개 항목] {value[:3] if len(value) > 3 else value}"
        else:
            display_value = value

        print(f"  {key:20s}: {display_value}")


def main():
    print("="*70)
    print("🧪 크롤러 상세 데이터 확인 테스트")
    print("="*70)

    # 1. 크롤러 생성
    print("\n[1단계] 공지사항 크롤러 초기화 중...")
    crawler = NoticeCrawler()

    # 2. 1페이지만 크롤링 (빠른 테스트)
    print("\n[2단계] 공지사항 크롤링 중 (1페이지)...")
    notices = crawler.crawl(max_pages=1)

    # 3. 전체 개수 출력
    print(f"\n{'='*70}")
    print(f"✅ 총 {len(notices)}개 공지사항 수집 완료")
    print(f"{'='*70}")

    # 4. 각 공지사항 상세 정보 출력
    if notices:
        # 첫 번째 공지의 모든 필드 확인
        print("\n📊 수집된 데이터 필드 목록:")
        first_notice = notices[0]
        for key in first_notice.keys():
            print(f"  ✓ {key}")

        # 처음 3개만 상세하게 출력
        print(f"\n{'='*70}")
        print("📄 상세 정보 (처음 3개만 표시)")
        print(f"{'='*70}")

        for i, notice in enumerate(notices[:3], 1):
            print_notice_detail(notice, i)

        # 5. JSON 형태로도 저장 (옵션)
        print(f"\n{'='*70}")
        print("💾 JSON 파일로 저장하기")
        print(f"{'='*70}")

        save_option = input("\n크롤링 결과를 JSON 파일로 저장하시겠습니까? (y/n): ")

        if save_option.lower() == 'y':
            filename = "crawled_notices.json"
            with open(filename, 'w', encoding='utf-8') as f:
                # datetime 객체를 문자열로 변환
                notices_json = []
                for notice in notices:
                    notice_copy = notice.copy()
                    if 'published_at' in notice_copy:
                        notice_copy['published_at'] = str(notice_copy['published_at'])
                    if 'crawled_at' in notice_copy:
                        notice_copy['crawled_at'] = str(notice_copy['crawled_at'])
                    notices_json.append(notice_copy)

                json.dump(notices_json, f, ensure_ascii=False, indent=2)

            print(f"✅ 저장 완료: {filename}")
            print(f"   파일 위치: backend/{filename}")

    else:
        print("\n⚠️ 크롤링된 공지사항이 없습니다.")
        print("   - 인터넷 연결을 확인하세요")
        print("   - 군산대 홈페이지가 정상인지 확인하세요")

    print(f"\n{'='*70}")
    print("✅ 테스트 완료!")
    print(f"{'='*70}\n")


if __name__ == "__main__":
    main()
