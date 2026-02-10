-- 015: 알림 설정 컬럼 추가 (user_preferences 테이블)
-- 프론트엔드 알림 설정을 백엔드와 동기화하기 위한 컬럼 추가

-- 알림 모드: 'all_off', 'schedule_only', 'notice_only', 'all_on'
ALTER TABLE user_preferences
    ADD COLUMN IF NOT EXISTS notification_mode TEXT DEFAULT 'all_on';

-- 마감일 알림 D-day 설정 (1~7일 전)
ALTER TABLE user_preferences
    ADD COLUMN IF NOT EXISTS deadline_reminder_days INTEGER DEFAULT 3;

-- notification_logs 테이블에 알림 유형 컬럼 추가
-- 'new_notice': 새 공지 알림, 'deadline': 마감일 리마인더
ALTER TABLE notification_logs
    ADD COLUMN IF NOT EXISTS notification_type TEXT DEFAULT 'new_notice';

-- 디데이 알림 중복 방지 인덱스
-- 같은 공지에 대해 같은 사용자에게 같은 유형의 알림은 1번만 발송
CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_logs_unique_deadline
    ON notification_logs(user_id, notice_id, notification_type)
    WHERE notification_type = 'deadline';

COMMENT ON COLUMN user_preferences.notification_mode IS '알림 모드: all_off(모두끔), schedule_only(일정만), notice_only(공지만), all_on(모두켬)';
COMMENT ON COLUMN user_preferences.deadline_reminder_days IS '마감일 알림 D-day (1~7일 전, 기본 3일)';
COMMENT ON COLUMN notification_logs.notification_type IS '알림 유형: new_notice(새 공지), deadline(마감일 리마인더)';
