# -*- coding: utf-8 -*-
"""
군산대학교 공지사항 크롤러

🤔 이 파일이 하는 일:
군산대학교 홈페이지의 공지사항 게시판에서 최신 공지를 가져옵니다.

📚 비유:
- 학교 게시판 = 공지사항이 붙어있는 큰 게시판
- 이 크롤러 = 게시판을 보고 중요한 공지를 사진 찍어서 저장하는 학생
"""

from .base_crawler import BaseCrawler
from typing import List, Dict, Any, Optional
from datetime import datetime
import sys
import os

# NoticeService import를 위해 경로 추가
sys.path.append(os.path.dirname(os.path.dirname(__file__)))


class NoticeCrawler(BaseCrawler):
    """
    군산대학교 공지사항 크롤러

    🎯 목적:
    군산대학교 홈페이지의 공지사항 게시판을 크롤링합니다.

    🏗️ 작동 방식:
    1. 공지사항 목록 페이지 접속
    2. 각 공지사항의 제목, 작성일, 링크 추출
    3. 상세 페이지 접속해서 본문 내용 가져오기
    4. 데이터 정리해서 반환
    """

    # 군산대학교 공지사항 URL 설정
    BASE_URL = "https://www.kunsan.ac.kr"
    LIST_URL = "https://www.kunsan.ac.kr/board/list.kunsan"

    # URL 파라미터 (게시판 설정)
    BOARD_PARAMS = {
        "boardId": "BBS_0000008",
        "menuCd": "DOM_000000105001001000",
        "contentsSid": "211",
        "cpath": ""
    }

    def __init__(self):
        """
        공지사항 크롤러를 초기화합니다.

        💡 예시:
        crawler = NoticeCrawler()
        공지들 = crawler.crawl(max_pages=3)  # 최대 3페이지 크롤링
        """
        super().__init__(
            base_url=self.BASE_URL,
            category="공지사항"
        )

    def check_new_notices(self, last_known_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        목록 페이지만 확인하여 새로운 공지가 있는지 체크합니다.

        🎯 목적:
        DB의 마지막 original_id와 비교하여 새 공지가 있을 때만 상세 크롤링을 수행합니다.
        학교 서버 부담을 최소화하고 크롤링 속도를 향상시킵니다.

        🔧 매개변수:
        - last_known_id: DB에 저장된 마지막 공지 ID

        📊 반환값:
        - 새로운 공지사항 목록 (ID와 URL만 포함)

        💡 예시:
        crawler = NoticeCrawler()
        new_notices = crawler.check_new_notices(last_known_id="12345")
        if new_notices:
            print(f"{len(new_notices)}개 새 공지 발견!")
        """
        print(f"\n[체크] 새 공지사항 확인 중... (마지막 ID: {last_known_id})")

        # 1페이지 목록만 가져오기
        params = self.BOARD_PARAMS.copy()
        params['pagerOffset'] = '0'

        soup = self.fetch_page(self.LIST_URL, params=params)

        if not soup:
            print("[ERROR] 목록 페이지 로드 실패")
            return []

        # 목록 추출
        notices = self._extract_notice_list(soup)

        if not notices:
            print("[INFO] 목록에서 공지사항을 찾지 못했습니다")
            return []

        # last_known_id가 없으면 모든 공지를 새 공지로 간주
        if not last_known_id:
            print(f"[OK] 첫 크롤링 - {len(notices)}개 모두 처리")
            return notices

        # 새로운 공지만 필터링
        new_notices = []
        for notice in notices:
            notice_id = notice.get("notice_id")

            # 마지막 알려진 ID를 만나면 중단
            if notice_id == last_known_id:
                print(f"[OK] 마지막 저장 공지 발견 - {len(new_notices)}개 새 공지")
                break

            new_notices.append(notice)

        # 모든 공지가 새 공지인 경우 (마지막 ID를 찾지 못함)
        if len(new_notices) == len(notices):
            print(f"[WARNING] 마지막 ID를 찾지 못함 - 모든 공지 처리 ({len(new_notices)}개)")

        return new_notices

    def crawl_optimized(
        self,
        last_known_id: Optional[str] = None,
        max_pages: int = 1
    ) -> List[Dict[str, Any]]:
        """
        최적화된 크롤링을 수행합니다.

        🎯 목적:
        1. 목록 페이지만 먼저 확인
        2. 새 공지가 있을 때만 상세 페이지 크롤링
        3. 학교 서버 부담 최소화

        🔧 매개변수:
        - last_known_id: DB에 저장된 마지막 공지 ID
        - max_pages: 최대 페이지 수 (기본값: 1)

        📊 반환값:
        - 크롤링한 공지사항 리스트 (상세 정보 포함)

        💡 예시:
        from services.notice_service import NoticeService

        service = NoticeService()
        last_id = service.get_latest_original_id(category="공지사항")

        crawler = NoticeCrawler()
        notices = crawler.crawl_optimized(last_known_id=last_id)
        print(f"새로운 공지: {len(notices)}개")
        """
        print(f"\n{'='*50}")
        print(f"[최적화 크롤링] 시작")
        print(f"{'='*50}\n")

        all_notices = []

        # 페이지별로 확인
        for page in range(1, max_pages + 1):
            print(f"\n[페이지 {page}/{max_pages}] 목록 확인 중...")

            # 목록 페이지 가져오기
            params = self.BOARD_PARAMS.copy()
            params['pagerOffset'] = str((page - 1) * 10)

            soup = self.fetch_page(self.LIST_URL, params=params)

            if not soup:
                print(f"[WARNING] 페이지 {page} 로드 실패")
                break

            # 목록 추출
            notices_list = self._extract_notice_list(soup)

            if not notices_list:
                print(f"[INFO] 페이지 {page}에서 공지사항을 찾지 못했습니다")
                break

            # 새로운 공지만 필터링
            new_notices = []
            found_last_id = False

            for notice in notices_list:
                notice_id = notice.get("notice_id")

                # 마지막 알려진 ID를 만나면 중단
                if last_known_id and notice_id == last_known_id:
                    print(f"[OK] 마지막 저장 공지 발견 - 크롤링 중단")
                    found_last_id = True
                    break

                new_notices.append(notice)

            if not new_notices:
                print(f"[INFO] 페이지 {page}에 새 공지 없음")
                if found_last_id:
                    break
                continue

            print(f"[OK] 새 공지 {len(new_notices)}개 발견 - 상세 크롤링 시작")

            # 새 공지만 상세 크롤링
            for i, notice_preview in enumerate(new_notices, 1):
                print(f"  [{i}/{len(new_notices)}] {notice_preview['title'][:30]}...")

                detail = self._crawl_notice_detail(notice_preview)

                if detail:
                    # original_id 추가
                    detail["original_id"] = notice_preview.get("notice_id")
                    all_notices.append(detail)

            # 마지막 ID를 찾았으면 더 이상 페이지를 돌지 않음
            if found_last_id:
                break

        print(f"\n{'='*50}")
        print(f"[완료] 최적화 크롤링 완료: 총 {len(all_notices)}개 새 공지")
        print(f"{'='*50}\n")

        return all_notices

    def crawl(self, max_pages: int = 1) -> List[Dict[str, Any]]:
        """
        공지사항을 크롤링합니다.

        🔧 매개변수:
        - max_pages: 크롤링할 최대 페이지 수 (기본값: 1)

        🎯 하는 일:
        1. 목록 페이지에서 공지사항 목록 가져오기
        2. 각 공지사항의 상세 페이지 접속
        3. 제목, 내용, 작성일 등 추출
        4. 리스트로 정리해서 반환

        💡 예시:
        crawler = NoticeCrawler()
        notices = crawler.crawl(max_pages=2)

        for notice in notices:
            print(f"제목: {notice['title']}")
            print(f"작성일: {notice['published_at']}")
        """
        print(f"\n{'='*50}")
        print(f"[크롤링] 공지사항 크롤링 시작 (최대 {max_pages}페이지)")
        print(f"{'='*50}\n")

        all_notices = []

        # 페이지별로 크롤링
        for page in range(1, max_pages + 1):
            print(f"\n[페이지 {page}/{max_pages}] 크롤링 중...")

            # 페이지 파라미터 추가
            params = self.BOARD_PARAMS.copy()
            params['pagerOffset'] = str((page - 1) * 10)  # 페이지네이션

            # 목록 페이지 가져오기
            soup = self.fetch_page(self.LIST_URL, params=params)

            if not soup:
                print(f"[WARNING] 페이지 {page} 로드 실패")
                continue

            # 공지사항 목록 추출
            notices = self._extract_notice_list(soup)

            if not notices:
                print(f"[INFO] 페이지 {page}에서 공지사항을 찾지 못했습니다")
                break

            print(f"[OK] {len(notices)}개 공지사항 발견")

            # 각 공지사항의 상세 정보 가져오기
            for i, notice_preview in enumerate(notices, 1):
                print(f"  [{i}/{len(notices)}] {notice_preview['title'][:30]}...")

                # 상세 페이지 크롤링
                detail = self._crawl_notice_detail(notice_preview)

                if detail:
                    all_notices.append(detail)

            print(f"[OK] 페이지 {page} 크롤링 완료: {len(notices)}개")

        print(f"\n{'='*50}")
        print(f"[완료] 전체 크롤링 완료: 총 {len(all_notices)}개 공지사항")
        print(f"{'='*50}\n")

        return all_notices

    def _extract_notice_list(self, soup) -> List[Dict[str, Any]]:
        """
        목록 페이지에서 공지사항 목록을 추출합니다.

        🔧 매개변수:
        - soup: BeautifulSoup 객체

        🎯 하는 일:
        게시판 목록에서 각 공지사항의 기본 정보(제목, 링크, 날짜)를 추출합니다.

        💡 반환값:
        [
            {
                "title": "제목",
                "url": "상세페이지 링크",
                "date": "작성일",
                "notice_id": "게시물 ID"
            },
            ...
        ]
        """
        notices = []

        # 게시판 테이블 찾기
        # 군산대 게시판은 보통 <table> 또는 <div class="board-list"> 형태
        board_rows = soup.select('tbody tr')  # 일반적인 게시판 구조

        if not board_rows:
            # 다른 형태의 게시판 구조 시도
            board_rows = soup.select('.board-list li') or soup.select('.notice-list li')

        for row in board_rows:
            try:
                # 제목과 링크 추출
                title_elem = row.select_one('td.title a') or row.select_one('.title a') or row.select_one('a')

                if not title_elem:
                    continue

                title = self.clean_text(title_elem.get_text())
                link = title_elem.get('href', '')

                # 상대 경로면 절대 경로로 변환
                if link and not link.startswith('http'):
                    link = self.BASE_URL + link

                # 날짜 추출
                date_elem = row.select_one('td.date') or row.select_one('.date') or row.select_one('.reg-date')
                date_str = self.clean_text(date_elem.get_text()) if date_elem else None

                # 게시물 ID 추출 (URL에서)
                notice_id = None
                if 'nttId=' in link:
                    notice_id = link.split('nttId=')[1].split('&')[0]
                elif 'id=' in link:
                    notice_id = link.split('id=')[1].split('&')[0]

                notices.append({
                    "title": title,
                    "url": link,
                    "date": date_str,
                    "notice_id": notice_id
                })

            except Exception as e:
                print(f"    [WARNING] 목록 항목 파싱 실패: {str(e)}")
                continue

        return notices

    def _crawl_notice_detail(self, notice_preview: Dict[str, Any]) -> Dict[str, Any]:
        """
        공지사항 상세 페이지를 크롤링합니다.

        🔧 매개변수:
        - notice_preview: 목록에서 가져온 공지사항 기본 정보

        🎯 하는 일:
        1. 상세 페이지 접속
        2. 본문 내용 추출
        3. 작성자, 조회수 등 메타 정보 추출
        4. 데이터베이스 저장 형식으로 정리

        💡 반환값:
        {
            "title": "제목",
            "content": "본문 내용",
            "published_at": datetime 객체,
            "source_url": "원본 링크",
            "category": "공지사항",
            ...
        }
        """
        url = notice_preview.get('url')

        if not url:
            return None

        # 상세 페이지 가져오기
        soup = self.fetch_page(url)

        if not soup:
            return None

        try:
            # 제목 추출
            title = notice_preview.get('title', '')

            # 본문 내용 추출 (div.bv_content_text에서만 추출)
            content_elem = (
                soup.select_one('div.bv_content_text') or
                soup.select_one('.board-view-content') or
                soup.select_one('.view-content') or
                soup.select_one('.cont_box')
            )

            content = self.clean_text(content_elem.get_text()) if content_elem else ""

            # 본문이 너무 짧으면 경고만 출력 (전체 텍스트 사용 안 함)
            if len(content) < 50:
                print(f"    [WARNING] 본문이 너무 짧음: {title[:30]}... (길이: {len(content)})")

            # 작성일 추출 (상세 페이지의 div.bv_txt01에서)
            date_str = None
            author = None
            views = None

            bv_txt01 = soup.select_one('div.bv_txt01')
            if bv_txt01:
                import re
                for span in bv_txt01.find_all('span'):
                    span_text = span.get_text()

                    # 작성일 추출: "작성일 : 2026-01-22"
                    if '작성일' in span_text:
                        date_match = re.search(r'(\d{4}-\d{2}-\d{2})', span_text)
                        if date_match:
                            date_str = date_match.group(1)

                    # 작성자 추출: "작성자 : 총무과"
                    elif '작성자' in span_text:
                        author_match = re.search(r'작성자\s*:\s*(.+)', span_text)
                        if author_match:
                            author = author_match.group(1).strip()

                    # 조회수 추출: "조회수 : 160"
                    elif '조회수' in span_text:
                        views_match = re.search(r'(\d+)', span_text)
                        if views_match:
                            views = int(views_match.group(1))

            # 상세 페이지에서 못 찾으면 목록에서 가져온 날짜 사용
            if not date_str:
                date_str = notice_preview.get('date', '')

            # 날짜 파싱
            published_at = self.parse_date(date_str)

            # 파싱 실패 시 경고 로그 출력 후 현재 시간 사용
            if not published_at:
                print(f"    [WARNING] 작성일 파싱 실패 (현재 시간 사용): {title[:30]}...")
                published_at = datetime.now()

            # 첨부파일 URL 추출 (div.bv_file01에서)
            attachments = []
            bv_file01 = soup.select_one('div.bv_file01')
            if bv_file01:
                # a.down_window 링크들 추출
                for link in bv_file01.select('a.down_window'):
                    href = link.get('href', '')
                    if href:
                        # 상대 경로면 절대 경로로 변환
                        if not href.startswith('http'):
                            href = self.BASE_URL + href
                        attachments.append(href)

            # 첨부파일을 못 찾았으면 기존 방식으로 시도
            if not attachments:
                attachments = self.extract_attachment_urls(soup)

            # 데이터 저장 형식으로 변환
            notice_data = self.save_to_dict(
                title=title,
                content=content,
                published_at=published_at,
                source_url=url,
                author=author,
                views=views,
                attachments=attachments,
                notice_id=notice_preview.get('notice_id')
            )

            return notice_data

        except Exception as e:
            print(f"    [ERROR] 상세 페이지 파싱 실패: {str(e)}")
            return None


# 🧪 테스트 코드
if __name__ == "__main__":
    print("=" * 60)
    print("🧪 군산대학교 공지사항 크롤러 테스트")
    print("=" * 60)

    try:
        # 1. 크롤러 생성
        print("\n[1단계] 크롤러 초기화...")
        crawler = NoticeCrawler()

        # 2. 공지사항 크롤링 (1페이지만)
        print("\n[2단계] 공지사항 크롤링 시작...")
        notices = crawler.crawl(max_pages=1)

        # 3. 결과 출력
        print("\n[3단계] 크롤링 결과:")
        print(f"총 {len(notices)}개 공지사항 수집\n")

        for i, notice in enumerate(notices[:3], 1):  # 처음 3개만 출력
            print(f"\n{'─'*60}")
            print(f"[공지 {i}]")
            print(f"📌 제목: {notice['title']}")
            print(f"📅 작성일: {notice['published_at']}")
            print(f"🏷️ 카테고리: {notice['category']}")
            print(f"🔗 링크: {notice['source_url']}")
            print(f"📝 내용 미리보기: {notice['content'][:100]}...")

            if notice.get('author'):
                print(f"✍️ 작성자: {notice['author']}")

            if notice.get('views'):
                print(f"👀 조회수: {notice['views']}")

            if notice.get('attachments'):
                print(f"📎 첨부파일: {len(notice['attachments'])}개")

        print(f"\n{'='*60}")
        print("✅ 테스트 완료!")
        print(f"{'='*60}")

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
