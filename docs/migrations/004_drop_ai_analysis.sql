-- ============================================================
-- 004_drop_ai_analysis.sql
-- ai_analysis 테이블 삭제
--
-- 이유: 벡터 임베딩 기반 하이브리드 검색으로 전환
-- - 기존: 공지 × 사용자 조합마다 레코드 저장 (확장성 문제)
-- - 변경: 임베딩 비교로 실시간 관련도 계산 (ai_analysis 불필요)
--
-- 실행 방법: Supabase SQL Editor에서 실행
-- ============================================================

-- 1. 인덱스 삭제
DROP INDEX IF EXISTS idx_ai_analysis_user_id;
DROP INDEX IF EXISTS idx_ai_analysis_relevance;
DROP INDEX IF EXISTS idx_ai_analysis_cache;

-- 2. 테이블 삭제
DROP TABLE IF EXISTS ai_analysis;

-- 3. cleanup_old_cache 함수 삭제 (ai_analysis 의존)
DROP FUNCTION IF EXISTS cleanup_old_cache(int);

-- 완료 메시지
DO $$
BEGIN
    RAISE NOTICE 'ai_analysis 테이블 삭제 완료!';
    RAISE NOTICE '- 인덱스 삭제: idx_ai_analysis_user_id, idx_ai_analysis_relevance, idx_ai_analysis_cache';
    RAISE NOTICE '- 테이블 삭제: ai_analysis';
    RAISE NOTICE '- 함수 삭제: cleanup_old_cache';
END $$;
