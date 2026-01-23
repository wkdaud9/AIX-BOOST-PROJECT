-- ========================================
-- AIX-Boost DB 리셋 및 업그레이드
-- 실행 순서: 1. 기존 데이터 삭제 → 2. 컬럼 추가 → 3. 인덱스 생성
-- ========================================

-- 1️⃣ 기존 데이터 전체 삭제 (깔끔하게 시작)
DELETE FROM notices;

-- 2️⃣ 새 컬럼 추가
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS author TEXT,
ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS original_id TEXT,
ADD COLUMN IF NOT EXISTS attachments TEXT[];

-- 3️⃣ 인덱스 생성 (조회 성능 향상)
CREATE INDEX IF NOT EXISTS idx_notices_original_id ON notices(original_id);
CREATE INDEX IF NOT EXISTS idx_notices_author ON notices(author);
CREATE INDEX IF NOT EXISTS idx_notices_published_at ON notices(published_at DESC);

-- 4️⃣ 확인: notices 테이블 구조 보기
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'notices'
ORDER BY ordinal_position;
