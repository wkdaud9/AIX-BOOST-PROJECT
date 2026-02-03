-- Migration: AI 분석 및 캘린더 기능 강화를 위한 컬럼 추가
-- Created: 2026-02-03
-- Description: Gemini AI 분석 결과와 캘린더 이벤트 관리를 위한 필드 추가

-- ========================================
-- 1. notices 테이블에 AI 분석 관련 컬럼 추가
-- ========================================

-- AI 분석 완료 시간 추가
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS ai_analyzed_at TIMESTAMP WITH TIME ZONE;

-- 중요도 컬럼 추가 (긴급, 중요, 일반)
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT '일반'
CHECK (priority IN ('긴급', '중요', '일반'));

-- 컬럼 설명 추가
COMMENT ON COLUMN notices.ai_analyzed_at IS 'Gemini AI 분석 완료 시간';
COMMENT ON COLUMN notices.priority IS '공지사항 중요도: 긴급, 중요, 일반';

-- 인덱스 추가 (중요도 기반 검색 최적화)
CREATE INDEX IF NOT EXISTS idx_notices_priority ON notices(priority);
CREATE INDEX IF NOT EXISTS idx_notices_ai_analyzed_at ON notices(ai_analyzed_at);

-- ========================================
-- 2. calendar_events 테이블에 이벤트 관리 컬럼 추가
-- ========================================

-- 이벤트 타입 추가 (시작일, 종료일, 마감일)
ALTER TABLE calendar_events
ADD COLUMN IF NOT EXISTS event_type VARCHAR(50) DEFAULT '일정'
CHECK (event_type IN ('시작일', '종료일', '마감일', '일정'));

-- 종일 이벤트 여부
ALTER TABLE calendar_events
ADD COLUMN IF NOT EXISTS is_all_day BOOLEAN DEFAULT true;

-- 알림 발송 여부
ALTER TABLE calendar_events
ADD COLUMN IF NOT EXISTS is_notified BOOLEAN DEFAULT false;

-- 컬럼 설명 추가
COMMENT ON COLUMN calendar_events.event_type IS '이벤트 타입: 시작일, 종료일, 마감일, 일정';
COMMENT ON COLUMN calendar_events.is_all_day IS '종일 이벤트 여부';
COMMENT ON COLUMN calendar_events.is_notified IS '푸시 알림 발송 완료 여부';

-- 인덱스 추가 (이벤트 타입 및 알림 상태 기반 검색)
CREATE INDEX IF NOT EXISTS idx_calendar_events_event_type ON calendar_events(event_type);
CREATE INDEX IF NOT EXISTS idx_calendar_events_notified ON calendar_events(is_notified);

-- ========================================
-- 3. 기존 데이터 마이그레이션
-- ========================================

-- 기존 공지사항의 기본 중요도를 '일반'으로 설정 (이미 DEFAULT로 설정됨)
-- 추가 로직 불필요

-- 기존 캘린더 이벤트의 기본값 설정 (이미 DEFAULT로 설정됨)
-- 추가 로직 불필요

-- ========================================
-- 4. 검증 쿼리
-- ========================================

-- 마이그레이션 완료 확인
DO $$
BEGIN
    -- notices 테이블 검증
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notices'
        AND column_name IN ('ai_analyzed_at', 'priority')
    ) THEN
        RAISE NOTICE '✅ notices 테이블 마이그레이션 완료';
    END IF;

    -- calendar_events 테이블 검증
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'calendar_events'
        AND column_name IN ('event_type', 'is_all_day', 'is_notified')
    ) THEN
        RAISE NOTICE '✅ calendar_events 테이블 마이그레이션 완료';
    END IF;
END $$;
