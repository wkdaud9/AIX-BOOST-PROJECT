-- 010_add_display_mode.sql
-- AI가 판단한 표시 모드 및 이미지 중요도 컬럼 추가
--
-- display_mode: POSTER / DOCUMENT / HYBRID
-- has_important_image: 이미지에 핵심 정보 포함 여부

ALTER TABLE notices
ADD COLUMN IF NOT EXISTS display_mode TEXT DEFAULT 'DOCUMENT';

ALTER TABLE notices
ADD COLUMN IF NOT EXISTS has_important_image BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN notices.display_mode IS 'AI가 판단한 표시 모드: POSTER(이미지 중심), DOCUMENT(텍스트 중심), HYBRID(혼합)';
COMMENT ON COLUMN notices.has_important_image IS 'AI가 판단한 이미지 중요도 (포스터/도표 등 핵심 정보 포함 여부)';
