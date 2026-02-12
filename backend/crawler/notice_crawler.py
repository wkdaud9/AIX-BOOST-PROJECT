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
from markdownify import markdownify as md, MarkdownConverter
import re
import sys
import os


def clean_markdown(text: str) -> str:
    """
    markdownify 출력의 파편화된 서식을 정리합니다.

    학교 홈페이지 HTML에서 <b>2026</b><b>년</b> 같이 태그가 파편화되어 있으면
    markdownify가 **2026****년** 으로 변환하므로 이를 **2026년** 으로 병합합니다.
    """
    # 1. 연속된 bold 마커 병합: **text****text** → **texttext**
    text = text.replace('****', '')
    # 2. 인접한 bold 구간 병합: **text** **text** → **text text**
    text = re.sub(r'\*\*(\s+)\*\*', r'\1', text)
    # 3. 빈 bold 제거: **  ** → (빈 문자열)
    text = re.sub(r'\*\*\s*\*\*', '', text)
    # 4. 특수문자 주위 파편화된 bold 제거: **※** → ※, **‧** → ‧
    text = re.sub(r'\*\*([^\w\s])\*\*', r'\1', text)
    # 5. 짝이 맞지 않는 bold 마커 제거 (줄 단위로 ** 개수가 홀수면 제거)
    lines = text.split('\n')
    fixed_lines = []
    for line in lines:
        if line.count('**') % 2 != 0:
            line = line.replace('**', '')
        fixed_lines.append(line)
    text = '\n'.join(fixed_lines)
    # 6. 이스케이프된 asterisk 복원: \* → * (markdownify가 * 를 \* 로 이스케이프)
    text = text.replace('\\*', '*')
    # 7. 연속 빈 줄 정리 (3줄 이상 → 2줄)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


class AlignPreservingConverter(MarkdownConverter):
    """
    text-align CSS 속성을 마커로 보존하는 Markdown 변환기

    markdownify는 기본적으로 inline style을 무시하므로 text-align: center 등이 사라집니다.
    이 변환기는 정렬 정보를 {=center=}...{=/center=} 마커로 보존하여
    프론트엔드에서 정렬을 복원할 수 있게 합니다.
    """

    def _get_align(self, el):
        """엘리먼트의 text-align 속성 확인 (CSS style + HTML align 속성)"""
        style = el.get('style', '') if hasattr(el, 'get') else ''
        align_attr = el.get('align', '') if hasattr(el, 'get') else ''

        if 'text-align' in style:
            match = re.search(r'text-align\s*:\s*(center|right)', style)
            if match:
                return match.group(1)
        if align_attr in ('center', 'right'):
            return align_attr
        return None

    def convert_p(self, el, text, *args, **kwargs):
        """p 태그 변환 시 text-align 보존"""
        result = super().convert_p(el, text, *args, **kwargs)
        align = self._get_align(el)
        if align and result.strip():
            stripped = result.strip()
            result = f'\n\n{{={align}=}}{stripped}{{=/{align}=}}\n\n'
        return result

    def convert_div(self, el, text, *args, **kwargs):
        """div 태그 변환 시 text-align 보존 (하위 요소에 마커가 없는 경우만)"""
        result = super().convert_div(el, text, *args, **kwargs)
        align = self._get_align(el)
        # 하위 요소에서 이미 마커가 추가된 경우 중복 방지
        if align and result.strip() and '{=' not in result:
            lines = result.strip().split('\n')
            marked = []
            for line in lines:
                if line.strip():
                    marked.append(f'{{={align}=}}{line}{{=/{align}=}}')
                else:
                    marked.append(line)
            result = '\n\n' + '\n'.join(marked) + '\n\n'
        return result

    def convert_center(self, el, text, *args, **kwargs):
        """<center> 태그를 center 마커로 변환"""
        if text.strip():
            return f'\n\n{{=center=}}{text.strip()}{{=/center=}}\n\n'
        return text


def md_with_align(html, **kwargs):
    """text-align 보존 Markdown 변환 헬퍼 함수"""
    return AlignPreservingConverter(**kwargs).convert(html)


# NoticeService import를 위해 경로 추가
sys.path.append(os.path.dirname(os.path.dirname(__file__)))


class NoticeCrawler(BaseCrawler):
    """
    군산대학교 공지사항 크롤러

    🎯 목적:
    군산대학교 홈페이지의 공지사항 게시판을 크롤링합니다.

    🏗️ 작동 방식:
    1. 공지사항 목록 페이지 접속
    2. 각 공지사항의 제목, 작성일, 링크, 순번 추출
    3. DB의 마지막 순번보다 큰 공지만 상세 크롤링
    4. 데이터 정리해서 반환
    """

    # 군산대학교 공지사항 URL 설정
    BASE_URL = "https://www.kunsan.ac.kr"
    LIST_URL = "https://www.kunsan.ac.kr/board/list.kunsan"

    # URL 파라미터 (게시판 설정)
    BOARD_PARAMS = {
        "boardId": "BBS_0000008",
        "menuCd": "DOM_000000105001001000",
        "orderBy": "REGISTER_DATE DESC",
        "paging": "ok"
    }

    # 원본 게시판 이름 (source_board 저장용)
    SOURCE_BOARD = "공지사항"

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
        params['startPage'] = '1'

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
        last_board_seq: Optional[int] = None,
        max_pages: int = 1,
        max_notices: int = 10,
        **kwargs  # 하위 호환성을 위해 existing_urls 등 무시
    ) -> List[Dict[str, Any]]:
        """
        최적화된 크롤링을 수행합니다. (순번 기반 중복 체크)

        🎯 목적:
        1. DB에서 해당 게시판의 마지막 순번 조회
        2. 목록 페이지에서 마지막 순번보다 큰 공지만 크롤링
        3. 게시판당 최대 max_notices개까지만 크롤링
        4. 학교 서버 부담 최소화 + DB 조회 비용 감소

        🔧 매개변수:
        - last_board_seq: DB에 저장된 마지막 순번 (없으면 내부에서 조회)
        - max_pages: 최대 페이지 수 (기본값: 1)
        - max_notices: 게시판당 최대 크롤링 개수 (기본값: 10)

        📊 반환값:
        - 크롤링한 공지사항 리스트 (상세 정보 포함)

        💡 예시:
        crawler = NoticeCrawler()
        notices = crawler.crawl_optimized(max_pages=1, max_notices=10)
        print(f"새로운 공지: {len(notices)}개")
        """
        print(f"\n{'='*50}")
        print(f"[최적화 크롤링] 순번 기반 중복 체크 ({self.SOURCE_BOARD})")
        print(f"{'='*50}\n")

        # 마지막 순번이 없으면 DB에서 조회
        if last_board_seq is None:
            last_board_seq = self._get_last_board_seq()

        print(f"[정보] DB 마지막 순번: {last_board_seq if last_board_seq else '없음 (첫 크롤링)'}")
        print(f"[정보] 최대 크롤링 개수: {max_notices}개")

        all_notices = []

        # 페이지별로 확인
        for page in range(1, max_pages + 1):
            # 이미 최대 개수에 도달했으면 중단
            if len(all_notices) >= max_notices:
                print(f"[정보] 최대 크롤링 개수({max_notices}개) 도달 - 중단")
                break

            print(f"\n[페이지 {page}/{max_pages}] 목록 확인 중...")

            # 목록 페이지 가져오기
            params = self.BOARD_PARAMS.copy()
            params['startPage'] = str(page)

            soup = self.fetch_page(self.LIST_URL, params=params)

            if not soup:
                print(f"[WARNING] 페이지 {page} 로드 실패")
                break

            # 목록 추출
            notices_list = self._extract_notice_list(soup)

            if not notices_list:
                print(f"[INFO] 페이지 {page}에서 공지사항을 찾지 못했습니다")
                break

            # 순번 기반으로 새로운 공지만 필터링
            new_notices = []
            found_old = False

            for notice in notices_list:
                board_seq = notice.get("board_seq")

                # 순번이 없는 경우 (공지 등) 또는 마지막 순번보다 큰 경우만 처리
                if board_seq is None:
                    # 순번 없는 공지(상단 고정 등)는 URL 기반으로 중복 체크
                    continue

                if last_board_seq and board_seq <= last_board_seq:
                    found_old = True
                    print(f"[정보] 기존 공지 발견 (순번 {board_seq}) - 이후 스킵")
                    break

                new_notices.append(notice)

            if not new_notices:
                print(f"[INFO] 페이지 {page}에 새 공지 없음")
                break

            # 남은 수용 가능 개수만큼만 자르기
            remaining = max_notices - len(all_notices)
            if len(new_notices) > remaining:
                new_notices = new_notices[:remaining]

            print(f"[OK] 새 공지 {len(new_notices)}개 발견 - 상세 크롤링 시작")

            # 새 공지만 상세 크롤링
            for i, notice_preview in enumerate(new_notices, 1):
                print(f"  [{i}/{len(new_notices)}] {notice_preview['title'][:30]}...")

                detail = self._crawl_notice_detail(notice_preview)

                if detail:
                    # original_id, source_board, board_seq 추가
                    detail["original_id"] = notice_preview.get("notice_id")
                    detail["source_board"] = self.SOURCE_BOARD
                    detail["board_seq"] = notice_preview.get("board_seq")
                    all_notices.append(detail)

            # 기존 공지가 발견되면 더 이상 페이지를 돌지 않음
            if found_old:
                break

        print(f"\n{'='*50}")
        print(f"[완료] 최적화 크롤링 완료: 총 {len(all_notices)}개 새 공지")
        print(f"{'='*50}\n")

        return all_notices

    def _get_last_board_seq(self) -> Optional[int]:
        """
        DB에서 해당 게시판의 마지막 순번을 조회합니다.

        🎯 목적:
        순번 기반 중복 체크를 위해 DB에 저장된 최신 순번을 가져옵니다.

        📊 반환값:
        - 마지막 순번 (없으면 None)
        """
        try:
            from supabase import create_client
            import os

            url = os.getenv("SUPABASE_URL")
            key = os.getenv("SUPABASE_KEY")

            if not url or not key:
                print("[WARNING] Supabase 환경변수 없음 - None 반환")
                return None

            client = create_client(url, key)

            # 해당 게시판의 최대 순번 조회
            result = client.table("notices")\
                .select("board_seq")\
                .eq("source_board", self.SOURCE_BOARD)\
                .not_.is_("board_seq", "null")\
                .order("board_seq", desc=True)\
                .limit(1)\
                .execute()

            if result.data and result.data[0].get("board_seq"):
                return result.data[0]["board_seq"]

            return None

        except Exception as e:
            print(f"[WARNING] 마지막 순번 조회 실패: {str(e)}")
            return None

    def crawl(self, max_pages: int = 1, max_notices: int = 10) -> List[Dict[str, Any]]:
        """
        공지사항을 크롤링합니다.

        🔧 매개변수:
        - max_pages: 크롤링할 최대 페이지 수 (기본값: 1)
        - max_notices: 게시판당 최대 크롤링 개수 (기본값: 10)

        🎯 하는 일:
        1. 목록 페이지에서 공지사항 목록 가져오기
        2. 각 공지사항의 상세 페이지 접속
        3. 제목, 내용, 작성일 등 추출
        4. 최대 max_notices개까지만 수집하여 반환

        💡 예시:
        crawler = NoticeCrawler()
        notices = crawler.crawl(max_pages=2, max_notices=10)

        for notice in notices:
            print(f"제목: {notice['title']}")
            print(f"작성일: {notice['published_at']}")
        """
        print(f"\n{'='*50}")
        print(f"[크롤링] 공지사항 크롤링 시작 (최대 {max_pages}페이지, 최대 {max_notices}개)")
        print(f"{'='*50}\n")

        all_notices = []

        # 페이지별로 크롤링
        for page in range(1, max_pages + 1):
            # 이미 최대 개수에 도달했으면 중단
            if len(all_notices) >= max_notices:
                print(f"[정보] 최대 크롤링 개수({max_notices}개) 도달 - 중단")
                break

            print(f"\n[페이지 {page}/{max_pages}] 크롤링 중...")

            # 페이지 파라미터 추가
            params = self.BOARD_PARAMS.copy()
            params['startPage'] = str(page)  # 페이지네이션

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

            # 남은 수용 가능 개수만큼만 처리
            remaining = max_notices - len(all_notices)
            notices_to_crawl = notices[:remaining]

            print(f"[OK] {len(notices)}개 발견, {len(notices_to_crawl)}개 상세 크롤링")

            # 각 공지사항의 상세 정보 가져오기
            for i, notice_preview in enumerate(notices_to_crawl, 1):
                print(f"  [{i}/{len(notices_to_crawl)}] {notice_preview['title'][:30]}...")

                # 상세 페이지 크롤링
                detail = self._crawl_notice_detail(notice_preview)

                if detail:
                    all_notices.append(detail)

            print(f"[OK] 페이지 {page} 크롤링 완료: {len(notices_to_crawl)}개")

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
        게시판 목록에서 각 공지사항의 기본 정보(제목, 링크, 날짜, 순번)를 추출합니다.

        💡 반환값:
        [
            {
                "title": "제목",
                "url": "상세페이지 링크",
                "date": "작성일",
                "notice_id": "게시물 ID",
                "board_seq": 5125  # 게시판 내 순번
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

                # 순번 추출 (td.pcv_moh_768에서)
                # 군산대 게시판 HTML: <td class="pcv_moh_768">5125</td>
                board_seq = None
                seq_elem = row.select_one('td.pcv_moh_768')
                if seq_elem:
                    seq_text = self.clean_text(seq_elem.get_text())
                    # 숫자만 추출 (공지 등 특수 표시 제외)
                    if seq_text.isdigit():
                        board_seq = int(seq_text)

                notices.append({
                    "title": title,
                    "url": link,
                    "date": date_str,
                    "notice_id": notice_id,
                    "board_seq": board_seq
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
            # 제목 추출 - 상세 페이지에서 완전한 제목 가져오기
            title_elem = (
                soup.select_one('div.bv_title') or
                soup.select_one('.board-view-title') or
                soup.select_one('.view-title') or
                soup.select_one('h3.title') or
                soup.select_one('h2.title')
            )

            if title_elem:
                title = self.clean_text(title_elem.get_text())
            else:
                # 상세 페이지에서 제목을 찾지 못하면 목록 제목 사용
                title = notice_preview.get('title', '')

            # 본문 내용 추출 (div.bv_content_text에서만 추출)
            content_elem = (
                soup.select_one('div.bv_content_text') or
                soup.select_one('.board-view-content') or
                soup.select_one('.view-content') or
                soup.select_one('.cont_box')
            )

            # 본문을 Markdown으로 변환 (표/구조 보존)
            if content_elem:
                # 이미지 src 상대경로를 절대경로로 변환 (Markdown 변환 전)
                for img in content_elem.select('img'):
                    src = img.get('src', '')
                    if src and not src.startswith('http'):
                        img['src'] = self.BASE_URL + src

                content = clean_markdown(md_with_align(
                    str(content_elem),
                    heading_style="ATX",
                    strip=['script', 'style'],
                ))
            else:
                content = ""

            # 본문 내 이미지 URL 추출 (이미지 공지 처리용)
            content_images = []
            if content_elem:
                for img in content_elem.select('img'):
                    src = img.get('src', '')
                    if src:
                        content_images.append(src)

            # 본문이 너무 짧고 이미지가 있으면 이미지 공지로 표시
            plain_text_len = len(content_elem.get_text().strip()) if content_elem else 0
            if plain_text_len < 50:
                if content_images:
                    print(f"    [INFO] 이미지 공지 감지: {len(content_images)}개 이미지 발견")
                else:
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
                original_id=notice_preview.get('notice_id')
            )

            # 이미지 공지인 경우 이미지 URL 추가
            if content_images:
                notice_data["content_images"] = content_images

            return notice_data

        except Exception as e:
            print(f"    [ERROR] 상세 페이지 파싱 실패: {str(e)}")
            return None

        finally:
            # BeautifulSoup 객체 명시적 해제 (메모리 절약)
            del soup


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
