# -*- coding: utf-8 -*-
"""
크롤러 통합 관리자

🤔 이 파일이 하는 일:
3개의 크롤러(공지사항, 학사/장학, 모집공고)를 한번에 관리하고 실행합니다.

📚 비유:
- 3개 크롤러 = 3명의 일꾼 (각자 다른 게시판 담당)
- 이 매니저 = 3명의 일꾼을 지휘하는 관리자
"""

from typing import List, Dict, Any, Optional
from .notice_crawler import NoticeCrawler
from .scholarship_crawler import ScholarshipCrawler
from .recruitment_crawler import RecruitmentCrawler
from datetime import datetime
import sys
import os

# AI 분석 및 서비스 모듈 import
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from ai.analyzer import NoticeAnalyzer
from services.notice_service import NoticeService
from services.calendar_service import CalendarService


class CrawlerManager:
    """
    크롤러 통합 관리자

    🎯 목적:
    여러 크롤러를 한번에 실행하고 결과를 통합 관리합니다.

    🏗️ 주요 기능:
    1. crawl_all: 모든 게시판 크롤링
    2. crawl_category: 특정 카테고리만 크롤링
    3. get_statistics: 크롤링 통계 제공
    """

    def __init__(self):
        """
        크롤러 매니저를 초기화합니다.

        💡 예시:
        manager = CrawlerManager()
        모든_공지 = manager.crawl_all(max_pages=2)
        """
        # 3개의 크롤러 인스턴스 생성
        self.crawlers = {
            "공지사항": NoticeCrawler(),
            "학사/장학": ScholarshipCrawler(),
            "모집공고": RecruitmentCrawler()
        }

        print("\n" + "="*60)
        print("[OK] 크롤러 매니저 초기화 완료")
        print(f"[목록] 관리 중인 크롤러: {', '.join(self.crawlers.keys())}")
        print("="*60 + "\n")

    def crawl_all(self, max_pages: int = 1, max_notices: int = 10) -> Dict[str, List[Dict[str, Any]]]:
        """
        모든 게시판을 한번에 크롤링합니다.

        🔧 매개변수:
        - max_pages: 각 게시판당 크롤링할 최대 페이지 수
        - max_notices: 각 게시판당 최대 크롤링 개수 (기본값: 10)

        🎯 하는 일:
        1. 공지사항, 학사/장학, 모집공고 게시판을 순서대로 크롤링
        2. 각 카테고리별로 최대 max_notices개까지 수집
        3. 통합된 결과를 딕셔너리로 반환

        💡 예시:
        manager = CrawlerManager()
        결과 = manager.crawl_all(max_pages=2, max_notices=10)

        print(f"공지사항: {len(결과['공지사항'])}개")
        print(f"학사/장학: {len(결과['학사/장학'])}개")
        print(f"모집공고: {len(결과['모집공고'])}개")
        """
        print("\n" + "[시작] " + "="*54 + " [시작]")
        print("     전체 게시판 크롤링 시작")
        print("[시작] " + "="*54 + " [시작]\n")

        all_results = {}
        total_count = 0
        start_time = datetime.now()

        # 각 크롤러 실행
        for category, crawler in self.crawlers.items():
            print(f"\n{'─'*60}")
            print(f"[검색] [{category}] 크롤링 시작...")
            print(f"{'─'*60}")

            try:
                results = crawler.crawl(max_pages=max_pages, max_notices=max_notices)
                all_results[category] = results
                total_count += len(results)

                print(f"\n[OK] [{category}] 완료: {len(results)}개 수집")

            except Exception as e:
                print(f"\n[ERROR] [{category}] 크롤링 실패: {str(e)}")
                all_results[category] = []

        # 통계 출력
        end_time = datetime.now()
        elapsed = (end_time - start_time).total_seconds()

        print("\n" + "="*60)
        print("[완료] 전체 크롤링 완료!")
        print("="*60)
        print(f"\n[통계] 크롤링 통계:")
        for category, results in all_results.items():
            print(f"  - {category:15s}: {len(results):4d}개")
        print(f"\n  [총계] 총 합계: {total_count}개")
        print(f"  [시간] 소요 시간: {elapsed:.2f}초")
        print("="*60 + "\n")

        return all_results

    def crawl_category(self, category: str, max_pages: int = 1) -> List[Dict[str, Any]]:
        """
        특정 카테고리만 크롤링합니다.

        🔧 매개변수:
        - category: 크롤링할 카테고리 ("공지사항", "학사/장학", "모집공고")
        - max_pages: 크롤링할 최대 페이지 수

        🎯 하는 일:
        지정한 카테고리의 크롤러만 실행해서 결과를 반환합니다.

        💡 예시:
        manager = CrawlerManager()

        # 공지사항만 크롤링
        공지들 = manager.crawl_category("공지사항", max_pages=3)

        # 학사/장학만 크롤링
        학사공지들 = manager.crawl_category("학사/장학", max_pages=2)
        """
        if category not in self.crawlers:
            available = ', '.join(self.crawlers.keys())
            raise ValueError(
                f"[ERROR] 잘못된 카테고리: '{category}'\n"
                f"사용 가능한 카테고리: {available}"
            )

        print(f"\n[검색] [{category}] 크롤링 시작...")

        crawler = self.crawlers[category]
        results = crawler.crawl(max_pages=max_pages)

        print(f"[OK] [{category}] 완료: {len(results)}개 수집\n")

        return results

    def get_statistics(self, results: Dict[str, List[Dict[str, Any]]]) -> Dict[str, Any]:
        """
        크롤링 결과에 대한 통계를 계산합니다.

        🔧 매개변수:
        - results: crawl_all()의 반환값

        🎯 하는 일:
        카테고리별, 날짜별 통계를 계산해서 반환합니다.

        💡 예시:
        manager = CrawlerManager()
        결과 = manager.crawl_all()
        통계 = manager.get_statistics(결과)

        print(f"총 공지사항: {통계['total_count']}개")
        print(f"카테고리별: {통계['by_category']}")
        """
        stats = {
            "total_count": 0,
            "by_category": {},
            "latest_update": None
        }

        # 카테고리별 통계
        for category, items in results.items():
            stats["by_category"][category] = len(items)
            stats["total_count"] += len(items)

            # 최신 업데이트 날짜 찾기
            for item in items:
                pub_date = item.get("published_at")
                if pub_date:
                    if not stats["latest_update"] or pub_date > stats["latest_update"]:
                        stats["latest_update"] = pub_date

        return stats

    def filter_by_date(
        self,
        results: Dict[str, List[Dict[str, Any]]],
        start_date: datetime = None,
        end_date: datetime = None
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        날짜 범위로 결과를 필터링합니다.

        🔧 매개변수:
        - results: 크롤링 결과
        - start_date: 시작 날짜 (이후 공지만)
        - end_date: 종료 날짜 (이전 공지만)

        🎯 하는 일:
        지정한 날짜 범위의 공지사항만 필터링해서 반환합니다.

        �� 예시:
        from datetime import datetime, timedelta

        manager = CrawlerManager()
        결과 = manager.crawl_all()

        # 최근 7일 공지만 필터링
        일주일전 = datetime.now() - timedelta(days=7)
        최신공지 = manager.filter_by_date(결과, start_date=일주일전)
        """
        filtered = {}

        for category, items in results.items():
            filtered_items = []

            for item in items:
                pub_date = item.get("published_at")

                if not pub_date:
                    continue

                # 날짜 범위 확인
                if start_date and pub_date < start_date:
                    continue

                if end_date and pub_date > end_date:
                    continue

                filtered_items.append(item)

            filtered[category] = filtered_items

        return filtered

    def search_by_keyword(
        self,
        results: Dict[str, List[Dict[str, Any]]],
        keyword: str
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        키워드로 공지사항을 검색합니다.

        🔧 매개변수:
        - results: 크롤링 결과
        - keyword: 검색할 키워드

        🎯 하는 일:
        제목이나 내용에 키워드가 포함된 공지사항만 필터링합니다.

        💡 예시:
        manager = CrawlerManager()
        결과 = manager.crawl_all()

        # '수강신청' 키워드 검색
        수강신청_공지 = manager.search_by_keyword(결과, "수강신청")

        # '장학금' 키워드 검색
        장학금_공지 = manager.search_by_keyword(결과, "장학금")
        """
        searched = {}

        keyword_lower = keyword.lower()

        for category, items in results.items():
            searched_items = []

            for item in items:
                title = item.get("title", "").lower()
                content = item.get("content", "").lower()

                # 제목이나 내용에 키워드가 있는지 확인
                if keyword_lower in title or keyword_lower in content:
                    searched_items.append(item)

            searched[category] = searched_items

        return searched

    def crawl_and_analyze_all(
        self,
        max_pages: int = 1,
        save_to_db: bool = True,
        create_calendar: bool = True
    ) -> Dict[str, Any]:
        """
        크롤링 + AI 분석 + DB 저장 + 캘린더 생성을 한번에 수행합니다.

        🎯 목적:
        완전한 자동화 파이프라인을 실행합니다.
        크롤링 → AI 분석 → DB 저장 → 캘린더 이벤트 생성

        🔧 매개변수:
        - max_pages: 각 게시판당 크롤링할 최대 페이지 수
        - save_to_db: DB에 저장할지 여부 (기본: True)
        - create_calendar: 캘린더 이벤트 생성 여부 (기본: True)

        📊 반환값:
        {
            "crawled": {...},        # 크롤링 결과
            "analyzed": [...],       # AI 분석 결과
            "saved": {...},          # DB 저장 통계
            "calendar_events": int,  # 생성된 캘린더 이벤트 수
            "statistics": {...}      # 전체 통계
        }

        💡 예시:
        manager = CrawlerManager()
        result = manager.crawl_and_analyze_all(max_pages=2)
        print(f"분석 완료: {len(result['analyzed'])}개")
        print(f"DB 저장: {result['saved']['inserted']}개")
        """
        print("\n" + "="*60)
        print("🚀 크롤링 + AI 분석 + DB 저장 파이프라인 시작")
        print("="*60)

        start_time = datetime.now()

        # 1. 크롤링
        print("\n[1단계] 크롤링 중...")
        crawled_results = self.crawl_all(max_pages=max_pages)

        # 크롤링 결과를 평탄화 (모든 카테고리의 공지를 하나의 리스트로)
        all_notices = []
        for category, notices in crawled_results.items():
            for notice in notices:
                notice["category"] = category  # 카테고리 정보 추가
                all_notices.append(notice)

        print(f"\n✅ 크롤링 완료: 총 {len(all_notices)}개 공지사항")

        if not all_notices:
            print("\n⚠️ 크롤링된 공지사항이 없습니다. 종료합니다.")
            return {
                "crawled": crawled_results,
                "analyzed": [],
                "saved": {"total": 0, "inserted": 0, "updated": 0, "failed": 0},
                "calendar_events": 0,
                "statistics": {}
            }

        # 2. AI 분석
        print(f"\n[2단계] AI 분석 중... ({len(all_notices)}개)")
        analyzed_notices = []

        try:
            analyzer = NoticeAnalyzer()

            for i, notice in enumerate(all_notices, 1):
                print(f"\n  [{i}/{len(all_notices)}] 분석 중: {notice.get('title', '')[:40]}...")

                try:
                    # AI 종합 분석
                    analysis = analyzer.analyze_notice_comprehensive(notice)
                    analyzed_notices.append(analysis)

                except Exception as e:
                    print(f"  ❌ 분석 실패: {str(e)}")
                    # 분석 실패해도 원본 데이터는 유지
                    notice["analyzed"] = False
                    notice["error"] = str(e)
                    analyzed_notices.append(notice)

            print(f"\n✅ AI 분석 완료: {len(analyzed_notices)}개")

        except Exception as e:
            print(f"\n❌ AI 분석 초기화 실패: {str(e)}")
            analyzed_notices = all_notices

        # 3. DB 저장
        saved_stats = {"total": 0, "inserted": 0, "updated": 0, "failed": 0}

        if save_to_db:
            print(f"\n[3단계] DB 저장 중... ({len(analyzed_notices)}개)")

            try:
                notice_service = NoticeService()
                saved_stats = notice_service.batch_save_notices(analyzed_notices)

                print(f"\n✅ DB 저장 완료:")
                print(f"  - 신규: {saved_stats['inserted']}개")
                print(f"  - 업데이트: {saved_stats['updated']}개")
                print(f"  - 실패: {saved_stats['failed']}개")

            except Exception as e:
                print(f"\n❌ DB 저장 실패: {str(e)}")

        else:
            print("\n[3단계] DB 저장 건너뜀 (save_to_db=False)")

        # 4. 캘린더 이벤트 생성
        calendar_event_count = 0

        if create_calendar and save_to_db:
            print(f"\n[4단계] 캘린더 이벤트 생성 중...")

            try:
                calendar_service = CalendarService()

                for notice in analyzed_notices:
                    # 날짜 정보가 있는 공지사항만 처리
                    dates = notice.get("dates", {})
                    if not dates or not any(dates.values()):
                        continue

                    # 캘린더 이벤트 생성 (사용자 관심 카테고리 기반)
                    try:
                        event_ids = calendar_service.create_calendar_events(
                            notice_id=notice.get("id"),
                            dates=dates,
                            notice_title=notice.get("original_title", ""),
                            category=notice.get("category", "학사"),
                            user_ids=None  # None이면 관심 사용자 자동 조회
                        )
                        calendar_event_count += len(event_ids)

                    except Exception as e:
                        print(f"  ⚠️ 캘린더 이벤트 생성 실패: {str(e)}")
                        continue

                print(f"\n✅ 캘린더 이벤트 생성 완료: {calendar_event_count}개")

            except Exception as e:
                print(f"\n❌ 캘린더 서비스 초기화 실패: {str(e)}")

        elif not save_to_db:
            print("\n[4단계] 캘린더 이벤트 생성 건너뜀 (DB 저장 필요)")
        else:
            print("\n[4단계] 캘린더 이벤트 생성 건너뜀 (create_calendar=False)")

        # 5. 최종 통계
        end_time = datetime.now()
        elapsed = (end_time - start_time).total_seconds()

        statistics = {
            "total_crawled": len(all_notices),
            "total_analyzed": len([n for n in analyzed_notices if n.get("analyzed")]),
            "total_saved": saved_stats["inserted"] + saved_stats["updated"],
            "total_calendar_events": calendar_event_count,
            "elapsed_time": f"{elapsed:.2f}초",
            "by_category": {
                category: len(notices)
                for category, notices in crawled_results.items()
            }
        }

        print("\n" + "="*60)
        print("✅ 전체 파이프라인 완료!")
        print("="*60)
        print(f"\n[최종 통계]")
        print(f"  - 크롤링: {statistics['total_crawled']}개")
        print(f"  - AI 분석: {statistics['total_analyzed']}개")
        print(f"  - DB 저장: {statistics['total_saved']}개")
        print(f"  - 캘린더 이벤트: {statistics['total_calendar_events']}개")
        print(f"  - 소요 시간: {statistics['elapsed_time']}")
        print("="*60 + "\n")

        return {
            "crawled": crawled_results,
            "analyzed": analyzed_notices,
            "saved": saved_stats,
            "calendar_events": calendar_event_count,
            "statistics": statistics
        }

    def analyze_existing_notices(
        self,
        limit: int = 50,
        create_calendar: bool = True
    ) -> Dict[str, Any]:
        """
        DB에 이미 저장된 미처리 공지사항을 AI로 분석합니다.

        🎯 목적:
        이전에 크롤링만 하고 AI 분석을 하지 않은 공지사항을 분석합니다.

        🔧 매개변수:
        - limit: 분석할 최대 개수
        - create_calendar: 캘린더 이벤트 생성 여부

        📊 반환값:
        {
            "analyzed": int,      # 분석 완료 개수
            "failed": int,        # 분석 실패 개수
            "calendar_events": int  # 생성된 캘린더 이벤트 수
        }

        💡 예시:
        manager = CrawlerManager()
        result = manager.analyze_existing_notices(limit=100)
        print(f"분석 완료: {result['analyzed']}개")
        """
        print("\n" + "="*60)
        print("🔄 기존 공지사항 AI 분석 시작")
        print("="*60)

        try:
            # 1. 미처리 공지사항 조회
            notice_service = NoticeService()
            unprocessed = notice_service.get_unprocessed_notices(limit=limit)

            if not unprocessed:
                print("\n✅ 미처리 공지사항이 없습니다.")
                return {"analyzed": 0, "failed": 0, "calendar_events": 0}

            print(f"\n미처리 공지사항: {len(unprocessed)}개")

            # 2. AI 분석
            analyzer = NoticeAnalyzer()
            calendar_service = CalendarService() if create_calendar else None

            analyzed_count = 0
            failed_count = 0
            calendar_event_count = 0

            for i, notice in enumerate(unprocessed, 1):
                print(f"\n[{i}/{len(unprocessed)}] 분석 중...")

                try:
                    # AI 분석
                    analysis = analyzer.analyze_notice_comprehensive(notice)

                    # DB 업데이트
                    success = notice_service.update_ai_analysis(
                        notice_id=notice["id"],
                        analysis_result=analysis
                    )

                    if success:
                        analyzed_count += 1

                        # 캘린더 이벤트 생성
                        if create_calendar and calendar_service:
                            dates = analysis.get("dates", {})
                            if dates and any(dates.values()):
                                try:
                                    event_ids = calendar_service.create_calendar_events(
                                        notice_id=notice["id"],
                                        dates=dates,
                                        notice_title=notice.get("title", ""),
                                        category=analysis.get("category", "학사"),
                                        user_ids=None
                                    )
                                    calendar_event_count += len(event_ids)
                                except:
                                    pass

                    else:
                        failed_count += 1

                except Exception as e:
                    print(f"  ❌ 분석 실패: {str(e)}")
                    failed_count += 1

            print("\n" + "="*60)
            print("✅ 기존 공지사항 분석 완료!")
            print("="*60)
            print(f"  - 분석 완료: {analyzed_count}개")
            print(f"  - 분석 실패: {failed_count}개")
            print(f"  - 캘린더 이벤트: {calendar_event_count}개")
            print("="*60 + "\n")

            return {
                "analyzed": analyzed_count,
                "failed": failed_count,
                "calendar_events": calendar_event_count
            }

        except Exception as e:
            print(f"\n❌ 오류 발생: {str(e)}")
            return {"analyzed": 0, "failed": 0, "calendar_events": 0}


# 🧪 테스트 코드
if __name__ == "__main__":
    from datetime import timedelta

    print("=" * 70)
    print("🧪 크롤러 매니저 테스트")
    print("=" * 70)

    try:
        # 1. 매니저 생성
        print("\n[1단계] 크롤러 매니저 초기화...")
        manager = CrawlerManager()

        # 2. 특정 카테고리만 크롤링
        print("\n[2단계] 공지사항만 크롤링...")
        notices = manager.crawl_category("공지사항", max_pages=1)
        print(f"  결과: {len(notices)}개")

        # 3. 전체 크롤링
        print("\n[3단계] 전체 게시판 크롤링...")
        all_results = manager.crawl_all(max_pages=1)

        # 4. 통계 확인
        print("\n[4단계] 통계 확인...")
        stats = manager.get_statistics(all_results)
        print(f"\n[통계]:")
        print(f"  총 공지: {stats['total_count']}개")
        print(f"  카테고리별:")
        for cat, count in stats['by_category'].items():
            print(f"    - {cat}: {count}개")

        if stats['latest_update']:
            print(f"  최신 업데이트: {stats['latest_update']}")

        # 5. 키워드 검색
        print("\n[5단계] 키워드 검색 테스트...")
        search_results = manager.search_by_keyword(all_results, "안내")
        search_count = sum(len(items) for items in search_results.values())
        print(f"  '안내' 키워드 검색 결과: {search_count}개")

        # 6. 날짜 필터링
        print("\n[6단계] 날짜 필터링 테스트...")
        week_ago = datetime.now() - timedelta(days=7)
        recent_results = manager.filter_by_date(all_results, start_date=week_ago)
        recent_count = sum(len(items) for items in recent_results.values())
        print(f"  최근 7일 공지: {recent_count}개")

        print("\n" + "="*70)
        print("✅ 모든 테스트 완료!")
        print("="*70)

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
