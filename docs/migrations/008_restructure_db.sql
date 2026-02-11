-- ============================================================
-- 008_restructure_db.sql
-- DB 구조 정리: 불필요한 테이블 삭제, notices에 deadline 컬럼 추가
--
-- 변경 사항:
-- 1. extracted_events 테이블 DROP (미사용)
-- 2. calendar_events 테이블 DROP (user_bookmarks + deadline으로 대체)
-- 3. notices 테이블: deadline DATE 추가, crawled_at/extracted_dates 삭제
-- 4. notices, user_bookmarks, notification_logs 데이터 초기화
--
-- 주의: users, user_preferences 데이터는 유지됩니다.
-- 실행 방법: Supabase SQL Editor에서 실행
-- ============================================================

-- ========================================
-- 1. 데이터 초기화 (유저 데이터 유지)
-- ========================================

-- 외래키 의존 테이블부터 순서대로 삭제
TRUNCATE TABLE notification_logs CASCADE;
TRUNCATE TABLE user_bookmarks CASCADE;
TRUNCATE TABLE notices CASCADE;

-- ========================================
-- 2. 불필요한 테이블 삭제
-- ========================================

-- calendar_events 관련 트리거/인덱스는 테이블과 함께 삭제됨
DROP TABLE IF EXISTS calendar_events CASCADE;
DROP TABLE IF EXISTS extracted_events CASCADE;

-- ========================================
-- 3. notices 테이블 구조 변경
-- ========================================

-- deadline 컬럼 추가 (AI가 판단한 최종 마감일)
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS deadline DATE;

-- deadline 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_notices_deadline ON notices(deadline);

-- 컬럼 설명
COMMENT ON COLUMN notices.deadline IS 'AI가 판단한 최종 마감일 (YYYY-MM-DD)';

-- crawled_at 컬럼 삭제 (created_at으로 대체)
ALTER TABLE notices DROP COLUMN IF EXISTS crawled_at;

-- extracted_dates 컬럼 삭제 (deadline으로 대체)
ALTER TABLE notices DROP COLUMN IF EXISTS extracted_dates;

-- ========================================
-- 4. 검증
-- ========================================
DO $$
BEGIN
    -- notices.deadline 존재 확인
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notices' AND column_name = 'deadline'
    ) THEN
        RAISE NOTICE 'notices.deadline 컬럼 추가 완료';
    END IF;

    -- crawled_at 삭제 확인
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notices' AND column_name = 'crawled_at'
    ) THEN
        RAISE NOTICE 'notices.crawled_at 컬럼 삭제 완료';
    END IF;

    -- extracted_dates 삭제 확인
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notices' AND column_name = 'extracted_dates'
    ) THEN
        RAISE NOTICE 'notices.extracted_dates 컬럼 삭제 완료';
    END IF;

    -- calendar_events 삭제 확인
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'calendar_events'
    ) THEN
        RAISE NOTICE 'calendar_events 테이블 삭제 완료';
    END IF;

    -- extracted_events 삭제 확인
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'extracted_events'
    ) THEN
        RAISE NOTICE 'extracted_events 테이블 삭제 완료';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'DB 구조 정리 완료!';
    RAISE NOTICE '- users/user_preferences 데이터 유지';
    RAISE NOTICE '- notices: deadline 추가, crawled_at/extracted_dates 삭제';
    RAISE NOTICE '- calendar_events, extracted_events 테이블 삭제';
    RAISE NOTICE '========================================';
END $$;
