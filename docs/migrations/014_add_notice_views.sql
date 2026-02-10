-- 014: 공지사항 조회 기록 테이블 추가
-- 사용자별 공지사항 열람 기록을 저장하여
-- 학과/학년별 인기 공지를 집계합니다.

-- 조회 기록 테이블 생성
CREATE TABLE IF NOT EXISTS notice_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, notice_id)  -- 사용자당 공지당 1건만 기록
);

-- 인덱스 생성
CREATE INDEX idx_notice_views_user_id ON notice_views(user_id);
CREATE INDEX idx_notice_views_notice_id ON notice_views(notice_id);
CREATE INDEX idx_notice_views_viewed_at ON notice_views(viewed_at DESC);

-- RLS 활성화
ALTER TABLE notice_views ENABLE ROW LEVEL SECURITY;

-- RLS 정책: 인증된 사용자는 자신의 조회 기록 관리 가능
CREATE POLICY "Users can manage own notice views" ON notice_views
    FOR ALL USING (auth.uid() = user_id);

-- 서비스 키로 전체 조회 허용 (백엔드 API용)
CREATE POLICY "Service can read all notice views" ON notice_views
    FOR SELECT USING (true);

-- 컬럼 설명
COMMENT ON TABLE notice_views IS '사용자별 공지사항 조회 기록 (학과/학년별 인기 공지 집계용)';
COMMENT ON COLUMN notice_views.user_id IS '조회한 사용자 ID (users 테이블 FK)';
COMMENT ON COLUMN notice_views.notice_id IS '조회한 공지사항 ID (notices 테이블 FK)';
COMMENT ON COLUMN notice_views.viewed_at IS '최초 조회 시각';

-- ============================================================
-- RPC 함수: 특정 사용자 그룹의 인기 공지사항 조회
-- ============================================================
CREATE OR REPLACE FUNCTION get_popular_notices_by_users(
    user_ids UUID[],
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    notice_id UUID,
    title TEXT,
    ai_summary TEXT,
    category TEXT,
    source_url TEXT,
    published_at TIMESTAMP WITH TIME ZONE,
    view_count_in_group BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id AS notice_id,
        n.title,
        n.ai_summary,
        n.category,
        n.source_url,
        n.published_at,
        COUNT(nv.id) AS view_count_in_group
    FROM notice_views nv
    JOIN notices n ON n.id = nv.notice_id
    WHERE nv.user_id = ANY(user_ids)
    GROUP BY n.id, n.title, n.ai_summary, n.category, n.source_url, n.published_at
    ORDER BY view_count_in_group DESC, n.published_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_popular_notices_by_users IS '특정 사용자 그룹(학과/학년 동료)이 많이 본 공지사항 조회';
