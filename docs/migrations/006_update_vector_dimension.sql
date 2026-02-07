-- ============================================================
-- 006_update_vector_dimension.sql
-- 임베딩 모델 변경 (text-embedding-004 → gemini-embedding-001)
--
-- 변경 사항:
--   - 모델: text-embedding-004 → gemini-embedding-001
--   - 차원: 768 유지 (output_dimensionality 파라미터로 축소)
--
-- 참고: HNSW 인덱스는 최대 2000 차원까지만 지원하므로
--       gemini-embedding-001의 기본 3072 차원을 768로 축소합니다.
--
-- 실행 방법: Supabase SQL Editor에서 실행
-- ============================================================

-- ============================================================
-- 1. 기존 임베딩 데이터 삭제 (모델이 다르면 재생성 필요)
-- ============================================================
UPDATE notices SET content_embedding = NULL;
UPDATE user_preferences SET interests_embedding = NULL;

-- ============================================================
-- 2. 컬럼 설명 업데이트 (차원은 768로 유지)
-- ============================================================
COMMENT ON COLUMN notices.content_embedding IS '공지사항 내용의 768차원 벡터 임베딩 (gemini-embedding-001)';
COMMENT ON COLUMN user_preferences.interests_embedding IS '사용자 관심사의 768차원 벡터 임베딩 (gemini-embedding-001)';

-- ============================================================
-- 3. 기존 함수 삭제 (반환 타입 변경 시 필요)
-- ============================================================
DROP FUNCTION IF EXISTS search_notices_by_vector(vector, double precision, integer);
DROP FUNCTION IF EXISTS search_notices_by_vector(vector, float, int);
DROP FUNCTION IF EXISTS search_users_by_notice_vector(vector, double precision, integer);
DROP FUNCTION IF EXISTS search_users_by_notice_vector(vector, float, int);
DROP FUNCTION IF EXISTS hybrid_search_notices(vector, text, integer, double precision, integer);
DROP FUNCTION IF EXISTS hybrid_search_notices(vector, text, int, float, int);

-- ============================================================
-- 4. 벡터 검색 함수 재생성
-- ============================================================

-- 공지사항 벡터 검색 함수
CREATE OR REPLACE FUNCTION search_notices_by_vector(
    query_embedding vector(768),
    match_threshold float DEFAULT 0.3,
    match_count int DEFAULT 20
)
RETURNS TABLE (
    id uuid,
    title text,
    content text,
    category text,
    ai_summary text,
    published_at timestamptz,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id,
        n.title,
        n.content,
        n.category,
        n.ai_summary,
        n.published_at,
        1 - (n.content_embedding <=> query_embedding) AS similarity
    FROM notices n
    WHERE n.content_embedding IS NOT NULL
      AND 1 - (n.content_embedding <=> query_embedding) > match_threshold
    ORDER BY n.content_embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 사용자 벡터 검색 함수 (알림 발송용)
CREATE OR REPLACE FUNCTION search_users_by_notice_vector(
    notice_embedding vector(768),
    match_threshold float DEFAULT 0.3,
    match_count int DEFAULT 50
)
RETURNS TABLE (
    user_id uuid,
    similarity float,
    department text,
    grade int
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        up.user_id,
        1 - (up.interests_embedding <=> notice_embedding) AS similarity,
        u.department,
        u.grade
    FROM user_preferences up
    JOIN users u ON up.user_id = u.id
    WHERE up.interests_embedding IS NOT NULL
      AND up.notification_enabled = TRUE
      AND 1 - (up.interests_embedding <=> notice_embedding) > match_threshold
    ORDER BY up.interests_embedding <=> notice_embedding
    LIMIT match_count;
END;
$$;

-- 하이브리드 검색 함수
CREATE OR REPLACE FUNCTION hybrid_search_notices(
    query_embedding vector(768),
    user_department text DEFAULT NULL,
    user_grade int DEFAULT NULL,
    match_threshold float DEFAULT 0.3,
    match_count int DEFAULT 20
)
RETURNS TABLE (
    id uuid,
    title text,
    ai_summary text,
    category text,
    published_at timestamptz,
    similarity float,
    hard_filter_match boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id,
        n.title,
        n.ai_summary,
        n.category,
        n.published_at,
        1 - (n.content_embedding <=> query_embedding) AS similarity,
        CASE
            WHEN (n.enriched_metadata->'target_departments') IS NULL
                 OR jsonb_array_length(n.enriched_metadata->'target_departments') = 0
                 OR n.enriched_metadata->'target_departments' ? user_department
            THEN TRUE
            ELSE FALSE
        END AND
        CASE
            WHEN (n.enriched_metadata->'target_grades') IS NULL
                 OR jsonb_array_length(n.enriched_metadata->'target_grades') = 0
                 OR n.enriched_metadata->'target_grades' ? user_grade::text
            THEN TRUE
            ELSE FALSE
        END AS hard_filter_match
    FROM notices n
    WHERE n.content_embedding IS NOT NULL
      AND 1 - (n.content_embedding <=> query_embedding) > match_threshold
    ORDER BY
        CASE
            WHEN (n.enriched_metadata->'target_departments') IS NULL
                 OR jsonb_array_length(n.enriched_metadata->'target_departments') = 0
                 OR n.enriched_metadata->'target_departments' ? user_department
            THEN 0
            ELSE 1
        END,
        n.content_embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- ============================================================
-- 완료 메시지
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE '임베딩 모델 변경 완료!';
    RAISE NOTICE '   - 모델: text-embedding-004 → gemini-embedding-001';
    RAISE NOTICE '   - 차원: 768 유지 (output_dimensionality로 축소)';
    RAISE NOTICE '   - 기존 임베딩 데이터 삭제됨 (재생성 필요)';
    RAISE NOTICE '   - 검색 함수 업데이트됨';
    RAISE NOTICE '';
    RAISE NOTICE '다음 단계: 파이프라인 재실행하여 임베딩 재생성';
END $$;
