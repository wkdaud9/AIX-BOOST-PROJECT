-- 005_add_board_seq.sql
-- 크롤링 최적화를 위한 게시판 순번 관리 컬럼 추가
-- 실행일: 2026-02-06

-- ============================================
-- 1. 새 컬럼 추가
-- ============================================

-- source_board: 원본 게시판 구분 (공지사항, 학사장학, 모집공고)
ALTER TABLE notices ADD COLUMN IF NOT EXISTS source_board TEXT;

-- board_seq: 게시판 내 순번 (각 게시판별로 순차 증가)
ALTER TABLE notices ADD COLUMN IF NOT EXISTS board_seq INTEGER;

-- ============================================
-- 2. 인덱스 생성
-- ============================================

-- source_board 기본 인덱스
CREATE INDEX IF NOT EXISTS idx_notices_source_board ON notices(source_board);

-- source_board + board_seq 복합 인덱스 (최신 순번 조회 최적화)
CREATE INDEX IF NOT EXISTS idx_notices_board_seq ON notices(source_board, board_seq DESC);

-- ============================================
-- 3. priority 컬럼 삭제
-- ============================================
-- 사용자가 D-day를 보고 직접 판단하므로 priority 분석 불필요

ALTER TABLE notices DROP COLUMN IF EXISTS priority;

-- ============================================
-- 4. 컬럼 설명 추가
-- ============================================

COMMENT ON COLUMN notices.source_board IS '원본 게시판 구분: 공지사항, 학사장학, 모집공고';
COMMENT ON COLUMN notices.board_seq IS '게시판 내 순번 (중복 크롤링 방지용)';

-- ============================================
-- 5. 기존 데이터 처리 (Optional)
-- ============================================
-- 기존 데이터의 source_board는 NULL로 유지
-- 다음 크롤링부터 새 공지에만 적용
-- 필요시 URL 패턴으로 역추적 가능:
--   boardId=BBS_0000008 → 공지사항
--   boardId=BBS_0000064 → 학사장학
--   boardId=BBS_0000070 → 모집공고

-- 예시 (필요시 실행):
-- UPDATE notices SET source_board = '공지사항' WHERE source_url LIKE '%BBS_0000008%';
-- UPDATE notices SET source_board = '학사장학' WHERE source_url LIKE '%BBS_0000064%';
-- UPDATE notices SET source_board = '모집공고' WHERE source_url LIKE '%BBS_0000070%';
