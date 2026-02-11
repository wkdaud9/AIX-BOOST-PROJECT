-- 북마크 수 컬럼 추가 (notices 테이블)
-- 사용자별 북마크 토글 시 직접 증감하여 실시간 집계 불필요

ALTER TABLE notices ADD COLUMN IF NOT EXISTS bookmark_count INTEGER DEFAULT 0;

-- 기존 user_bookmarks 데이터로 백필
UPDATE notices n
SET bookmark_count = (
    SELECT COUNT(*)
    FROM user_bookmarks ub
    WHERE ub.notice_id = n.id
);

-- bookmark_count 증감용 RPC 함수 (동시성 안전한 atomic 연산)
CREATE OR REPLACE FUNCTION increment_bookmark_count(nid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notices SET bookmark_count = bookmark_count + 1 WHERE id = nid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION decrement_bookmark_count(nid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notices SET bookmark_count = GREATEST(bookmark_count - 1, 0) WHERE id = nid;
END;
$$ LANGUAGE plpgsql;
