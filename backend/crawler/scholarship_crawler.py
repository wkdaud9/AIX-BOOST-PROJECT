# -*- coding: utf-8 -*-
"""
군산대학교 학사/장학 크롤러

🤔 이 파일이 하는 일:
군산대학교 홈페이지의 학사/장학 게시판에서 최신 공지를 가져옵니다.

📚 비유:
- 학사/장학 게시판 = 장학금, 수강신청 등 학사 관련 공지가 있는 게시판
- 이 크롤러 = 학생들에게 중요한 학사 정보를 찾아서 알려주는 도우미
"""

from .notice_crawler import NoticeCrawler


class ScholarshipCrawler(NoticeCrawler):
    """
    군산대학교 학사/장학 크롤러

    🎯 목적:
    군산대학교 홈페이지의 학사/장학 게시판을 크롤링합니다.

    🏗️ 특징:
    - NoticeCrawler를 상속받아 같은 방식으로 작동
    - 게시판 ID와 카테고리만 다름
    - 장학금, 수강신청, 학사일정 등의 정보를 수집
    """

    # 학사/장학 게시판 설정
    SOURCE_BOARD = "학사/장학"  # DB 순번 조회 시 게시판 구분용

    BOARD_PARAMS = {
        "boardId": "BBS_0000009",
        "menuCd": "DOM_000000105001002000",
        "orderBy": "REGISTER_DATE DESC",
        "paging": "ok"
    }

    def __init__(self):
        """
        학사/장학 크롤러를 초기화합니다.

        💡 예시:
        crawler = ScholarshipCrawler()
        공지들 = crawler.crawl(max_pages=2)
        """
        # 부모 클래스 초기화 (카테고리만 변경)
        BaseCrawler.__init__(self, base_url=self.BASE_URL, category="학사/장학")

        print(f"[OK] 학사/장학 크롤러 초기화 완료")
        print(f"[INFO] 게시판 ID: {self.BOARD_PARAMS['boardId']}")


# Import를 위해 필요
from .base_crawler import BaseCrawler


# 🧪 테스트 코드
if __name__ == "__main__":
    print("=" * 60)
    print("🧪 군산대학교 학사/장학 크롤러 테스트")
    print("=" * 60)

    try:
        # 1. 크롤러 생성
        print("\n[1단계] 크롤러 초기화...")
        crawler = ScholarshipCrawler()

        # 2. 학사/장학 공지 크롤링
        print("\n[2단계] 학사/장학 공지 크롤링 시작...")
        notices = crawler.crawl(max_pages=1)

        # 3. 결과 출력
        print("\n[3단계] 크롤링 결과:")
        print(f"총 {len(notices)}개 공지사항 수집\n")

        for i, notice in enumerate(notices[:3], 1):
            print(f"\n{'─'*60}")
            print(f"[학사/장학 공지 {i}]")
            print(f"📌 제목: {notice['title']}")
            print(f"📅 작성일: {notice['published_at']}")
            print(f"🏷️ 카테고리: {notice['category']}")
            print(f"🔗 링크: {notice['source_url']}")
            print(f"📝 내용 미리보기: {notice['content'][:100]}...")

        print(f"\n{'='*60}")
        print("✅ 테스트 완료!")
        print(f"{'='*60}")

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
