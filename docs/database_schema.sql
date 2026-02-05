-- AIX-Boost Database Schema
-- Supabase PostgreSQL

-- 사용자 테이블 (Supabase Auth와 연동)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    name TEXT,                -- 사용자 이름
    student_id TEXT UNIQUE,  -- 나중에 프로필 설정에서 입력 가능
    department TEXT,          -- 나중에 프로필 설정에서 입력 가능
    grade INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 사용자 선호도 테이블
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    categories TEXT[] DEFAULT '{}',
    keywords TEXT[] DEFAULT '{}',
    notification_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 공지사항 테이블
CREATE TABLE IF NOT EXISTS notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL,
    source_url TEXT NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE NOT NULL,
    crawled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    author TEXT,                                -- 작성자 또는 작성 부서명
    view_count INTEGER DEFAULT 0,              -- 원본 사이트의 조회수
    original_id TEXT UNIQUE,                   -- 원본 웹사이트의 게시물 고유 번호 (중복 체크용)
    attachments TEXT[],                        -- 첨부파일 다운로드 URL 배열
    ai_summary TEXT,
    extracted_dates DATE[],
    is_processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 추출된 이벤트 테이블
CREATE TABLE IF NOT EXISTS extracted_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    event_date DATE,
    event_time TIME,
    location TEXT,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 캘린더 이벤트 테이블
CREATE TABLE IF NOT EXISTS calendar_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notice_id UUID REFERENCES notices(id) ON DELETE SET NULL,
    extracted_event_id UUID REFERENCES extracted_events(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    location TEXT,
    is_synced BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 푸시 알림 로그 테이블
CREATE TABLE IF NOT EXISTS notification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notice_id UUID REFERENCES notices(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스 생성
CREATE INDEX idx_notices_category ON notices(category);
CREATE INDEX idx_notices_published_at ON notices(published_at DESC);
CREATE INDEX idx_notices_original_id ON notices(original_id);
CREATE INDEX idx_notices_author ON notices(author);
CREATE INDEX idx_calendar_events_user_id ON calendar_events(user_id);
CREATE INDEX idx_calendar_events_start_date ON calendar_events(start_date);
CREATE INDEX idx_notification_logs_user_id ON notification_logs(user_id);

-- RLS (Row Level Security) 활성화
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- RLS 정책: 사용자는 자신의 데이터만 조회/수정 가능
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view own preferences" ON user_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own preferences" ON user_preferences
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own calendar events" ON calendar_events
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own calendar events" ON calendar_events
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own notifications" ON notification_logs
    FOR SELECT USING (auth.uid() = user_id);

-- 공지사항은 모든 인증된 사용자가 조회 가능
CREATE POLICY "Authenticated users can view notices" ON notices
    FOR SELECT TO authenticated USING (TRUE);

-- 컬럼 설명 추가
COMMENT ON COLUMN notices.author IS '작성자 또는 작성 부서명';
COMMENT ON COLUMN notices.view_count IS '원본 사이트의 조회수';
COMMENT ON COLUMN notices.original_id IS '원본 웹사이트의 게시물 고유 번호 (중복 체크용)';
COMMENT ON COLUMN notices.attachments IS '첨부파일 다운로드 URL 배열';
COMMENT ON COLUMN notices.category IS '공지사항 카테고리: 학사(수강신청,학적,성적,졸업), 장학(장학금,학자금대출,등록금), 취업(채용,인턴십,취업박람회), 행사(입학식,졸업식,축제,오리엔테이션), 교육(특강,교육프로그램,진로교육,세미나), 공모전(대회,경진대회,콘테스트)';

-- 자동 업데이트 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- updated_at 자동 업데이트 트리거
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notices_updated_at BEFORE UPDATE ON notices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_calendar_events_updated_at BEFORE UPDATE ON calendar_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 사용자 생성 시 user_preferences 자동 생성 트리거 함수
CREATE OR REPLACE FUNCTION create_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
    -- 새로운 사용자가 생성되면 user_preferences 테이블에 기본값으로 행 삽입
    INSERT INTO user_preferences (user_id, categories, keywords, notification_enabled)
    VALUES (NEW.id, '{}', '{}', TRUE);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- users 테이블에 INSERT 시 user_preferences 자동 생성 트리거
CREATE TRIGGER trigger_create_user_preferences
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_preferences();

-- auth.users 생성 시 users 테이블 자동 생성 트리거 함수
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- auth.users에 새로운 사용자가 생성되면 users 테이블에도 행 삽입
    INSERT INTO public.users (id, email, created_at)
    VALUES (NEW.id, NEW.email, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- auth.users 테이블에 INSERT 시 users 테이블 자동 생성 트리거
-- 주의: 이 트리거는 Supabase 대시보드의 SQL Editor에서 실행해야 합니다
-- (auth 스키마는 RLS가 적용되어 있어 SECURITY DEFINER 권한 필요)
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();
