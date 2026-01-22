# -*- coding: utf-8 -*-
"""
크롤러 통합 관리자

🤔 이 파일이 하는 일:
3개의 크롤러(공지사항, 학사/장학, 모집공고)를 한번에 관리하고 실행합니다.

📚 비유:
- 3개 크롤러 = 3명의 일꾼 (각자 다른 게시판 담당)
- 이 매니저 = 3명의 일꾼을 지휘하는 관리자
"""

from typing import List, Dict, Any
from .notice_crawler import NoticeCrawler
from .scholarship_crawler import ScholarshipCrawler
from .recruitment_crawler import RecruitmentCrawler
from datetime import datetime


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
        print("✅ 크롤러 매니저 초기화 완료")
        print(f"📋 관리 중인 크롤러: {', '.join(self.crawlers.keys())}")
        print("="*60 + "\n")

    def crawl_all(self, max_pages: int = 1) -> Dict[str, List[Dict[str, Any]]]:
        """
        모든 게시판을 한번에 크롤링합니다.

        🔧 매개변수:
        - max_pages: 각 게시판당 크롤링할 최대 페이지 수

        🎯 하는 일:
        1. 공지사항, 학사/장학, 모집공고 게시판을 순서대로 크롤링
        2. 각 카테고리별로 결과를 분류해서 저장
        3. 통합된 결과를 딕셔너리로 반환

        💡 예시:
        manager = CrawlerManager()
        결과 = manager.crawl_all(max_pages=2)

        print(f"공지사항: {len(결과['공지사항'])}개")
        print(f"학사/장학: {len(결과['학사/장학'])}개")
        print(f"모집공고: {len(결과['모집공고'])}개")
        """
        print("\n" + "🚀 " + "="*56 + " 🚀")
        print("     전체 게시판 크롤링 시작")
        print("🚀 " + "="*56 + " 🚀\n")

        all_results = {}
        total_count = 0
        start_time = datetime.now()

        # 각 크롤러 실행
        for category, crawler in self.crawlers.items():
            print(f"\n{'─'*60}")
            print(f"🔍 [{category}] 크롤링 시작...")
            print(f"{'─'*60}")

            try:
                results = crawler.crawl(max_pages=max_pages)
                all_results[category] = results
                total_count += len(results)

                print(f"\n✅ [{category}] 완료: {len(results)}개 수집")

            except Exception as e:
                print(f"\n❌ [{category}] 크롤링 실패: {str(e)}")
                all_results[category] = []

        # 통계 출력
        end_time = datetime.now()
        elapsed = (end_time - start_time).total_seconds()

        print("\n" + "="*60)
        print("🎉 전체 크롤링 완료!")
        print("="*60)
        print(f"\n📊 크롤링 통계:")
        for category, results in all_results.items():
            print(f"  • {category:15s}: {len(results):4d}개")
        print(f"\n  🎯 총 합계: {total_count}개")
        print(f"  ⏱️ 소요 시간: {elapsed:.2f}초")
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
                f"❌ 잘못된 카테고리: '{category}'\n"
                f"사용 가능한 카테고리: {available}"
            )

        print(f"\n🔍 [{category}] 크롤링 시작...")

        crawler = self.crawlers[category]
        results = crawler.crawl(max_pages=max_pages)

        print(f"✅ [{category}] 완료: {len(results)}개 수집\n")

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
        print(f"\n📊 통계:")
        print(f"  총 공지: {stats['total_count']}개")
        print(f"  카테고리별:")
        for cat, count in stats['by_category'].items():
            print(f"    • {cat}: {count}개")

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
