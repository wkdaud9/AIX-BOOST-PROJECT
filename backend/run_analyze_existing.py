# -*- coding: utf-8 -*-
"""
기존 공지사항 AI 분석 실행 스크립트

🤔 이 파일이 하는 일:
DB에 저장된 미처리 공지사항을 Gemini AI로 분석하여 요약 정보를 저장합니다.

📚 실행 방법:
cd backend
python run_analyze_existing.py
"""

import sys
import os
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()

# 경로 설정
sys.path.append(os.path.dirname(__file__))

from crawler.crawler_manager import CrawlerManager


def main():
    """
    기존 공지사항 AI 분석 실행
    """
    print("\n" + "="*60)
    print("🚀 기존 공지사항 AI 분석 시작")
    print("="*60)

    # 환경 변수 체크
    print(f"\n⚙️ 환경 변수:")
    print(f"  - GEMINI_API_KEY: {'✅ 설정됨' if os.getenv('GEMINI_API_KEY') else '❌ 없음'}")
    print(f"  - SUPABASE_URL: {'✅ 설정됨' if os.getenv('SUPABASE_URL') else '❌ 없음'}")
    print(f"  - SUPABASE_KEY: {'✅ 설정됨' if os.getenv('SUPABASE_KEY') else '❌ 없음'}")

    if not all([
        os.getenv('GEMINI_API_KEY'),
        os.getenv('SUPABASE_URL'),
        os.getenv('SUPABASE_KEY')
    ]):
        print("\n❌ 필수 환경 변수가 설정되지 않았습니다. .env 파일을 확인하세요.")
        return

    try:
        # CrawlerManager 초기화
        manager = CrawlerManager()

        # 기존 공지사항 분석 (최대 100개)
        result = manager.analyze_existing_notices(
            limit=100           # 최대 100개 분석
        )

        # 결과 출력
        print("\n" + "="*60)
        print("📊 최종 결과")
        print("="*60)
        print(f"  ✅ 분석 완료: {result['analyzed']}개")
        print(f"  ❌ 분석 실패: {result['failed']}개")
        print("="*60 + "\n")

        if result['analyzed'] > 0:
            print("🎉 성공적으로 완료되었습니다!")
        else:
            print("⚠️ 분석된 공지사항이 없습니다. DB에 미처리 공지사항이 있는지 확인하세요.")

    except Exception as e:
        print(f"\n❌ 오류 발생: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
