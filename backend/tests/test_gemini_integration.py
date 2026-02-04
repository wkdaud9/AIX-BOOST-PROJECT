# -*- coding: utf-8 -*-
"""
Gemini AI 통합 테스트

🤔 이 파일이 하는 일:
크롤링 → AI 분석 → DB 저장 → 캘린더 이벤트 생성의 전체 파이프라인을 테스트합니다.

📚 실행 방법:
cd backend
python -m tests.test_gemini_integration
"""

import sys
import os
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()

# 경로 설정
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from ai.analyzer import NoticeAnalyzer
from ai.gemini_client import GeminiClient
from services.notice_service import NoticeService
from services.calendar_service import CalendarService


def test_gemini_client():
    """
    Gemini 클라이언트 초기화 및 기본 동작 테스트
    """
    print("\n" + "="*60)
    print("🧪 테스트 1: Gemini 클라이언트 초기화")
    print("="*60)

    try:
        client = GeminiClient()
        print("✅ Gemini 클라이언트 초기화 성공")

        # 간단한 텍스트 생성 테스트
        response = client.generate_text("안녕하세요! 간단히 인사해주세요.", temperature=0.3)
        print(f"✅ Gemini 응답: {response[:100]}...")

        return True
    except Exception as e:
        print(f"❌ 테스트 실패: {str(e)}")
        return False


def test_analyzer():
    """
    공지사항 분석기 테스트
    """
    print("\n" + "="*60)
    print("🧪 테스트 2: 공지사항 AI 분석")
    print("="*60)

    try:
        analyzer = NoticeAnalyzer()

        # 테스트 공지사항
        test_notice = {
            "title": "[학사공지] 2024학년도 1학기 수강신청 안내",
            "content": """
            수강신청 일정을 다음과 같이 안내합니다.

            1. 수강신청 기간
               - 4학년: 2024년 2월 1일 10:00 ~ 2월 2일 18:00
               - 3학년: 2024년 2월 2일 10:00 ~ 2월 3일 18:00
               - 2학년: 2024년 2월 3일 10:00 ~ 2월 4일 18:00
               - 1학년: 2024년 2월 4일 10:00 ~ 2월 5일 18:00

            2. 수강신청 방법
               - 학교 포털 접속 후 '수강신청' 메뉴 이용
               - 최대 21학점까지 신청 가능

            학생지원처 학사운영팀
            """,
            "url": "https://kunsan.ac.kr/notice/test-123",
            "date": "2024-01-20"
        }

        # 종합 분석 테스트
        print("\n[종합 분석] 시작...")
        result = analyzer.analyze_notice_comprehensive(test_notice)

        print("\n✅ 분석 결과:")
        print(f"  📝 요약: {result.get('summary', '')[:100]}...")
        print(f"  🏷️ 카테고리: {result.get('category', '')}")
        print(f"  ⚡ 중요도: {result.get('priority', '')}")
        print(f"  📅 날짜 정보:")

        dates = result.get('dates', {})
        for key, value in dates.items():
            print(f"    - {key}: {value}")

        return True
    except Exception as e:
        print(f"❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def test_notice_service():
    """
    공지사항 서비스 테스트 (실제 DB 저장은 하지 않음)
    """
    print("\n" + "="*60)
    print("🧪 테스트 3: 공지사항 서비스")
    print("="*60)

    try:
        service = NoticeService()
        print("✅ NoticeService 초기화 성공")

        # 미처리 공지사항 조회 테스트
        print("\n미처리 공지사항 조회 중...")
        unprocessed = service.get_unprocessed_notices(limit=5)
        print(f"✅ 미처리 공지사항: {len(unprocessed)}개")

        return True
    except Exception as e:
        print(f"❌ 테스트 실패: {str(e)}")
        return False


def test_calendar_service():
    """
    캘린더 서비스 테스트 (실제 이벤트 생성은 하지 않음)
    """
    print("\n" + "="*60)
    print("🧪 테스트 4: 캘린더 서비스")
    print("="*60)

    try:
        service = CalendarService()
        print("✅ CalendarService 초기화 성공")

        # 다가오는 이벤트 조회 테스트
        print("\n다가오는 이벤트 조회 중...")
        upcoming = service.get_upcoming_events(days_ahead=7)
        print(f"✅ 다가오는 이벤트: {len(upcoming)}개")

        return True
    except Exception as e:
        print(f"❌ 테스트 실패: {str(e)}")
        return False


def test_full_pipeline():
    """
    전체 파이프라인 테스트 (크롤링 제외)
    """
    print("\n" + "="*60)
    print("🧪 테스트 5: 전체 파이프라인 (AI 분석 → DB 저장)")
    print("="*60)

    try:
        # 1. AI 분석
        print("\n[1단계] AI 분석 중...")
        analyzer = NoticeAnalyzer()

        test_notice = {
            "title": "[테스트] 장학금 신청 안내",
            "content": """
            2024학년도 1학기 장학금 신청을 다음과 같이 안내합니다.

            신청 기간: 2024년 2월 10일 ~ 2월 20일
            신청 방법: 학교 포털에서 온라인 신청

            장학복지팀
            """,
            "url": f"https://kunsan.ac.kr/test/scholarship-{os.getpid()}",
            "date": "2024-02-01"
        }

        analysis = analyzer.analyze_notice_comprehensive(test_notice)
        print(f"✅ AI 분석 완료")
        print(f"  - 카테고리: {analysis.get('category')}")
        print(f"  - 중요도: {analysis.get('priority')}")

        # 2. DB 저장
        print("\n[2단계] DB 저장 중...")
        notice_service = NoticeService()

        notice_id = notice_service.save_analyzed_notice(analysis)

        if notice_id:
            print(f"✅ DB 저장 완료: {notice_id}")

            # 3. 캘린더 이벤트 생성 (날짜가 있으면)
            dates = analysis.get('dates', {})
            if dates and any(dates.values()):
                print("\n[3단계] 캘린더 이벤트 생성 중...")
                calendar_service = CalendarService()

                # 실제 사용자 ID 대신 테스트 스킵
                print("  ℹ️ 실제 사용자 ID가 필요하여 캘린더 생성은 스킵합니다.")

            return True
        else:
            print("❌ DB 저장 실패")
            return False

    except Exception as e:
        print(f"❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """
    모든 테스트 실행
    """
    print("\n" + "="*60)
    print("🚀 Gemini AI 통합 테스트 시작")
    print("="*60)
    print(f"\n⚙️ 환경 변수:")
    print(f"  - GEMINI_API_KEY: {'✅ 설정됨' if os.getenv('GEMINI_API_KEY') else '❌ 없음'}")
    print(f"  - SUPABASE_URL: {'✅ 설정됨' if os.getenv('SUPABASE_URL') else '❌ 없음'}")
    print(f"  - SUPABASE_KEY: {'✅ 설정됨' if os.getenv('SUPABASE_KEY') else '❌ 없음'}")

    # 환경 변수 체크
    if not all([
        os.getenv('GEMINI_API_KEY'),
        os.getenv('SUPABASE_URL'),
        os.getenv('SUPABASE_KEY')
    ]):
        print("\n❌ 필수 환경 변수가 설정되지 않았습니다. .env 파일을 확인하세요.")
        return

    # 테스트 실행
    tests = [
        ("Gemini 클라이언트", test_gemini_client),
        ("공지사항 AI 분석", test_analyzer),
        ("공지사항 서비스", test_notice_service),
        ("캘린더 서비스", test_calendar_service),
        ("전체 파이프라인", test_full_pipeline),
    ]

    results = []

    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n❌ {test_name} 테스트 중 예외 발생: {str(e)}")
            results.append((test_name, False))

    # 최종 결과
    print("\n" + "="*60)
    print("📊 테스트 결과 요약")
    print("="*60)

    passed = 0
    failed = 0

    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status} - {test_name}")

        if result:
            passed += 1
        else:
            failed += 1

    print("\n" + "="*60)
    print(f"총 {len(results)}개 테스트 중 {passed}개 통과, {failed}개 실패")
    print("="*60 + "\n")

    if failed == 0:
        print("🎉 모든 테스트 통과!")
    else:
        print("⚠️ 일부 테스트 실패. 위의 에러 메시지를 확인하세요.")


if __name__ == "__main__":
    main()
