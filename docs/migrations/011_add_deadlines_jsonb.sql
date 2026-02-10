-- 복수 마감일 처리를 위한 마이그레이션
-- notices 테이블에 deadlines JSONB 컬럼 추가
-- 형식: [{"label": "대상명", "date": "YYYY-MM-DD"}, ...]

ALTER TABLE notices ADD COLUMN IF NOT EXISTS deadlines JSONB DEFAULT '[]';

-- JSONB 인덱스 추가 (날짜 기반 검색 최적화)
CREATE INDEX IF NOT EXISTS idx_notices_deadlines ON notices USING GIN (deadlines);

COMMENT ON COLUMN notices.deadlines IS '복수 마감일 목록 (JSONB 배열: [{label, date}, ...])';

-- 기존 deadline 데이터를 deadlines JSONB 배열로 백필
-- deadline이 있고 deadlines가 비어있는 레코드만 대상
UPDATE notices
SET deadlines = jsonb_build_array(
    jsonb_build_object('label', '전체 마감', 'date', to_char(deadline, 'YYYY-MM-DD'))
)
WHERE deadline IS NOT NULL
  AND (deadlines IS NULL OR deadlines = '[]'::jsonb);
