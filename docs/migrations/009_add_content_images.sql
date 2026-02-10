-- ============================================================
-- 009_add_content_images.sql
-- 공지사항 본문 이미지 URL 저장용 컬럼 추가
--
-- 변경 사항:
--   - notices 테이블에 content_images TEXT[] 컬럼 추가
--   - 크롤링 시 추출한 이미지 URL을 저장하여 프론트엔드에서 표시
--
-- 실행 방법: Supabase SQL Editor에서 실행
-- ============================================================

-- content_images 컬럼 추가 (본문 내 이미지 URL 배열)
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS content_images TEXT[] DEFAULT '{}';

COMMENT ON COLUMN notices.content_images IS '본문 내 이미지 URL 배열 (크롤링 시 추출)';

-- 완료 메시지
DO $$
BEGIN
    RAISE NOTICE 'content_images 컬럼 추가 완료!';
    RAISE NOTICE '   - notices 테이블에 content_images TEXT[] 추가';
    RAISE NOTICE '   - 크롤링 재실행 시 이미지 URL이 저장됩니다';
END $$;
