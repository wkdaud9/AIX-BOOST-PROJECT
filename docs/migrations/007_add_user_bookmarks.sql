-- 007: 사용자 북마크 테이블 추가
-- 사용자별 공지사항 즐겨찾기(북마크) 기능을 위한 테이블

-- 북마크 테이블 생성
CREATE TABLE IF NOT EXISTS user_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, notice_id)
);

-- 인덱스 생성
CREATE INDEX idx_user_bookmarks_user_id ON user_bookmarks(user_id);
CREATE INDEX idx_user_bookmarks_notice_id ON user_bookmarks(notice_id);
CREATE INDEX idx_user_bookmarks_created_at ON user_bookmarks(user_id, created_at DESC);

-- RLS 활성화
ALTER TABLE user_bookmarks ENABLE ROW LEVEL SECURITY;

-- RLS 정책: 사용자는 자신의 북마크만 조회/관리 가능
CREATE POLICY "Users can view own bookmarks" ON user_bookmarks
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own bookmarks" ON user_bookmarks
    FOR ALL USING (auth.uid() = user_id);

-- 컬럼 설명
COMMENT ON TABLE user_bookmarks IS '사용자별 공지사항 북마크(즐겨찾기)';
COMMENT ON COLUMN user_bookmarks.user_id IS '사용자 ID (users 테이블 FK)';
COMMENT ON COLUMN user_bookmarks.notice_id IS '공지사항 ID (notices 테이블 FK)';
