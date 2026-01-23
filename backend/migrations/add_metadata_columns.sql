-- ========================================
-- AIX-Boost DB 스키마 확장
-- 작성일: 2026-01-23
-- 목적: 작성자, 조회수, 원본ID, 첨부파일 컬럼 추가
-- ========================================

-- 1. 새 컬럼 추가
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS author TEXT,                    -- 작성자 또는 작성 부서
ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,   -- 원본 사이트 조회수
ADD COLUMN IF NOT EXISTS original_id TEXT,               -- 원본 게시물 번호 (예: dataSid)
ADD COLUMN IF NOT EXISTS attachments TEXT[];             -- 첨부파일 URL 배열

-- 2. original_id에 UNIQUE 제약 조건 추가 (중복 방지)
-- 이미 데이터가 있을 수 있으므로 안전하게 처리
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'notices_original_id_key'
    ) THEN
        ALTER TABLE notices ADD CONSTRAINT notices_original_id_key UNIQUE (original_id);
    END IF;
END $$;

-- 3. 인덱스 추가 (조회 성능 향상)
CREATE INDEX IF NOT EXISTS idx_notices_original_id ON notices(original_id);
CREATE INDEX IF NOT EXISTS idx_notices_author ON notices(author);
CREATE INDEX IF NOT EXISTS idx_notices_published_at ON notices(published_at DESC);

-- 4. 기존 데이터에 대한 정리 (선택사항)
-- 기존 데이터 중 original_id가 없는 경우 source_url에서 추출
UPDATE notices
SET original_id = substring(source_url from 'dataSid=([0-9]+)')
WHERE original_id IS NULL AND source_url LIKE '%dataSid=%';

-- 5. 확인 쿼리
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'notices'
ORDER BY ordinal_position;

COMMENT ON COLUMN notices.author IS '작성자 또는 작성 부서명';
COMMENT ON COLUMN notices.view_count IS '원본 사이트의 조회수';
COMMENT ON COLUMN notices.original_id IS '원본 웹사이트의 게시물 고유 번호 (중복 체크용)';
COMMENT ON COLUMN notices.attachments IS '첨부파일 다운로드 URL 배열';
