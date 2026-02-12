# -*- coding: utf-8 -*-
"""
콘텐츠 Markdown 마이그레이션 스크립트

이 스크립트가 하는 일:
기존 DB의 공지사항 content를 source_url에서 HTML을 다시 가져와
Markdown으로 변환하여 업데이트합니다.
AI 재분석 없이 content 컬럼만 갱신합니다.

실행 방법:
    cd backend
    python scripts/migrate_content_to_markdown.py

옵션:
    --dry-run: 실제 저장 없이 변환 결과만 미리보기
    --limit N: 최대 N개 공지만 처리
"""

import os
import sys
import re
import time
import random
import argparse
import requests
from bs4 import BeautifulSoup
from markdownify import markdownify as md, MarkdownConverter

# 프로젝트 루트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


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
    """text-align CSS 속성을 마커로 보존하는 Markdown 변환기"""

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


from dotenv import load_dotenv
load_dotenv()

from supabase import create_client, Client

# 군산대 기본 URL
BASE_URL = "https://www.kunsan.ac.kr"


def get_supabase_client() -> Client:
    """Supabase 클라이언트 생성"""
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")
    if not url or not key:
        raise ValueError("SUPABASE_URL, SUPABASE_KEY 환경변수가 필요합니다")
    return create_client(url, key)


def fetch_and_convert(source_url: str, session: requests.Session) -> dict:
    """
    source_url에서 HTML을 가져와 Markdown으로 변환합니다.

    반환값:
    - {"content": "마크다운 텍스트", "content_images": ["url1", ...]}
    - 실패 시 None
    """
    try:
        response = session.get(source_url, timeout=10)
        response.raise_for_status()
        response.encoding = 'utf-8'

        soup = BeautifulSoup(response.text, 'html.parser')

        # 본문 요소 찾기 (크롤러와 동일한 셀렉터)
        content_elem = (
            soup.select_one('div.bv_content_text') or
            soup.select_one('.board-view-content') or
            soup.select_one('.view-content') or
            soup.select_one('.cont_box')
        )

        if not content_elem:
            return None

        # 이미지 상대경로 → 절대경로 변환
        for img in content_elem.select('img'):
            src = img.get('src', '')
            if src and not src.startswith('http'):
                img['src'] = BASE_URL + src

        # HTML → Markdown 변환 + 정렬 보존 + 파편화된 서식 정리
        content_md = clean_markdown(md_with_align(
            str(content_elem),
            heading_style="ATX",
            strip=['script', 'style'],
        ))

        # 이미지 URL 추출
        content_images = []
        for img in content_elem.select('img'):
            src = img.get('src', '')
            if src:
                content_images.append(src)

        return {
            "content": content_md,
            "content_images": content_images,
        }

    except Exception as e:
        print(f"    ❌ HTML 가져오기 실패: {str(e)}")
        return None


def run_migration(dry_run: bool = False, limit: int = None):
    """마이그레이션 실행"""
    print(f"\n{'='*60}")
    print("📝 콘텐츠 Markdown 마이그레이션")
    print(f"   모드: {'DRY-RUN (미리보기)' if dry_run else '실제 업데이트'}")
    if limit:
        print(f"   제한: {limit}개")
    print(f"{'='*60}\n")

    # Supabase 연결
    supabase = get_supabase_client()

    # 모든 공지사항 source_url 가져오기
    query = supabase.table("notices").select("id, title, source_url").order("published_at", desc=True)
    if limit:
        query = query.limit(limit)

    result = query.execute()
    notices = result.data or []

    print(f"📋 대상 공지사항: {len(notices)}개\n")

    if not notices:
        print("⚠️ 업데이트할 공지사항이 없습니다.")
        return

    # HTTP 세션 (크롤러와 동일한 헤더)
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept-Language': 'ko-KR,ko;q=0.9',
        'Referer': f'{BASE_URL}/',
    })

    success_count = 0
    skip_count = 0
    fail_count = 0

    for i, notice in enumerate(notices, 1):
        notice_id = notice['id']
        title = notice.get('title', '')[:40]
        source_url = notice.get('source_url')

        print(f"[{i}/{len(notices)}] {title}...")

        if not source_url:
            print(f"    ⏭️ source_url 없음, 건너뜀")
            skip_count += 1
            continue

        # HTML 가져와서 Markdown 변환
        converted = fetch_and_convert(source_url, session)

        if not converted:
            print(f"    ❌ 변환 실패")
            fail_count += 1
            continue

        content_md = converted["content"]
        content_images = converted["content_images"]

        if dry_run:
            # 미리보기: 첫 200자만 표시
            preview = content_md[:200].replace('\n', '\\n')
            print(f"    ✅ 변환 완료 ({len(content_md)}자, 이미지 {len(content_images)}개)")
            print(f"    📄 미리보기: {preview}...")
        else:
            # 실제 DB 업데이트
            try:
                update_data = {"content": content_md}
                if content_images:
                    update_data["content_images"] = content_images

                supabase.table("notices").update(update_data).eq("id", notice_id).execute()
                print(f"    ✅ 업데이트 완료 ({len(content_md)}자, 이미지 {len(content_images)}개)")
            except Exception as e:
                print(f"    ❌ DB 업데이트 실패: {str(e)}")
                fail_count += 1
                continue

        success_count += 1

        # 서버 부담 방지: 0.5~1초 랜덤 대기
        time.sleep(random.uniform(0.5, 1.0))

    # 결과 요약
    print(f"\n{'='*60}")
    print(f"✅ 마이그레이션 완료!")
    print(f"   성공: {success_count}개")
    print(f"   건너뜀: {skip_count}개")
    print(f"   실패: {fail_count}개")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="콘텐츠 Markdown 마이그레이션")
    parser.add_argument("--dry-run", action="store_true", help="실제 저장 없이 미리보기")
    parser.add_argument("--limit", type=int, default=None, help="최대 처리 개수")
    args = parser.parse_args()

    run_migration(dry_run=args.dry_run, limit=args.limit)
