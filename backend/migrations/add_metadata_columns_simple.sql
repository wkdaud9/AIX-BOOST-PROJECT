-- ========================================
-- AIX-Boost DB 스키마 확장 (단순 버전)
-- 실행 방법: Supabase SQL Editor에 전체 복사 후 실행
-- ========================================

-- 1. 새 컬럼 추가
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS author TEXT,
ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS original_id TEXT,
ADD COLUMN IF NOT EXISTS attachments TEXT[];

-- 2. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_notices_original_id ON notices(original_id);
CREATE INDEX IF NOT EXISTS idx_notices_author ON notices(author);
CREATE INDEX IF NOT EXISTS idx_notices_published_at ON notices(published_at DESC);

-- 3. 기존 데이터 정리 (original_id 추출)
UPDATE notices
SET original_id = substring(source_url from 'dataSid=([0-9]+)')
WHERE original_id IS NULL AND source_url LIKE '%dataSid=%';
