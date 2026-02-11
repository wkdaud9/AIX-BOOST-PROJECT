-- 013: FCM 디바이스 토큰 테이블 추가
-- 한 사용자가 여러 기기에서 알림을 받을 수 있도록 지원합니다.
-- (예: 안드로이드 앱 + 아이폰 웹 브라우저)

CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,                                          -- FCM 디바이스 토큰
    device_type TEXT NOT NULL CHECK (device_type IN ('android', 'web', 'ios')),  -- 디바이스 유형
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(token)  -- 동일 토큰 중복 등록 방지 (FCM 토큰은 전역적으로 유일)
);

-- 인덱스: 사용자별 토큰 조회 최적화
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);

-- RLS 활성화
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- RLS 정책: 사용자는 자신의 디바이스 토큰만 조회/관리 가능
CREATE POLICY "Users can view own device tokens" ON device_tokens
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own device tokens" ON device_tokens
    FOR ALL USING (auth.uid() = user_id);

-- updated_at 자동 업데이트 트리거 (기존 함수 재사용)
CREATE TRIGGER update_device_tokens_updated_at BEFORE UPDATE ON device_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 컬럼 설명
COMMENT ON TABLE device_tokens IS '사용자별 FCM 디바이스 토큰 (멀티 디바이스 지원)';
COMMENT ON COLUMN device_tokens.token IS 'Firebase Cloud Messaging 디바이스 토큰';
COMMENT ON COLUMN device_tokens.device_type IS '디바이스 유형: android(네이티브 앱), web(PWA/웹), ios(향후 네이티브)';
