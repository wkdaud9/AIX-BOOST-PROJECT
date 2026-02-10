-- ============================================================
-- 003_vector_embedding.sql
-- 벡터 임베딩 기반 하이브리드 검색 시스템을 위한 스키마 변경
--
-- 목적: ai_analysis 테이블의 확장성 문제 해결
-- - Before: 공지 1개 x 사용자 N명 = N회 Gemini API 호출
-- - After: 공지 1개 x 임베딩 1회 = 1회 API 호출
--
-- 실행 방법: Supabase SQL Editor에서 실행
-- ============================================================

-- ============================================================
-- 1. pgvector 확장 활성화
-- ============================================================
-- Supabase에서 기본 제공되는 확장입니다.
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- 2. notices 테이블에 임베딩 컬럼 추가
-- ============================================================
-- content_embedding: 공지사항 내용의 768차원 벡터 임베딩
-- enriched_metadata: AI가 추출한 대상 학과/학년/키워드 등 메타데이터
ALTER TABLE notices
ADD COLUMN IF NOT EXISTS content_embedding vector(768),
ADD COLUMN IF NOT EXISTS enriched_metadata JSONB DEFAULT '{}';

-- enriched_metadata 구조 예시:
-- {
--   "target_departments": ["컴퓨터정보공학과", "전자공학과"],
--   "target_grades": [3, 4],
--   "target_student_types": ["재학생"],
--   "keywords_expanded": ["AI", "인공지능", "머신러닝"],
--   "action_type": "신청",      -- 신청, 참여, 확인, 제출 등
--   "urgency_level": 3          -- 1(낮음) ~ 5(매우높음)
-- }

COMMENT ON COLUMN notices.content_embedding IS '공지사항 내용의 768차원 벡터 임베딩 (text-embedding-004)';
COMMENT ON COLUMN notices.enriched_metadata IS 'AI가 추출한 대상 학과/학년/키워드 등 메타데이터';

-- ============================================================
-- 3. user_preferences 테이블에 임베딩 컬럼 추가
-- ============================================================
-- interests_embedding: 사용자 관심사의 768차원 벡터 임베딩
-- enriched_profile: 확장된 관심사 및 프로필 정보
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS interests_embedding vector(768),
ADD COLUMN IF NOT EXISTS enriched_profile JSONB DEFAULT '{}';

-- enriched_profile 구조 예시:
-- {
--   "interests_expanded": ["AI", "인공지능", "딥러닝", "머신러닝"],
--   "academic_focus": ["개발", "연구"],
--   "career_interests": ["IT기업", "스타트업"],
--   "department_context": ["프로그래밍", "소프트웨어"]
-- }

COMMENT ON COLUMN user_preferences.interests_embedding IS '사용자 관심사의 768차원 벡터 임베딩';
COMMENT ON COLUMN user_preferences.enriched_profile IS '확장된 관심사 및 프로필 정보';

-- ============================================================
-- 4. 벡터 검색 인덱스 생성
-- ============================================================
-- IVFFlat 인덱스: 대규모 벡터 검색에 효율적
-- lists 값은 데이터 크기에 따라 조정 (sqrt(row_count) 권장)

-- notices 테이블 벡터 인덱스 (코사인 유사도)
CREATE INDEX IF NOT EXISTS idx_notices_embedding
ON notices USING ivfflat (content_embedding vector_cosine_ops)
WITH (lists = 100);

-- user_preferences 테이블 벡터 인덱스 (코사인 유사도)
CREATE INDEX IF NOT EXISTS idx_user_preferences_embedding
ON user_preferences USING ivfflat (interests_embedding vector_cosine_ops)
WITH (lists = 50);

-- enriched_metadata GIN 인덱스 (JSONB 검색용)
CREATE INDEX IF NOT EXISTS idx_notices_enriched_metadata
ON notices USING GIN (enriched_metadata);

CREATE INDEX IF NOT EXISTS idx_user_preferences_enriched_profile
ON user_preferences USING GIN (enriched_profile);

-- ============================================================
-- 5. 벡터 유사도 검색 함수 생성
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
    priority varchar,
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
        n.priority,
        n.published_at,
        1 - (n.content_embedding <=> query_embedding) AS similarity
    FROM notices n
    WHERE n.content_embedding IS NOT NULL
      AND 1 - (n.content_embedding <=> query_embedding) > match_threshold
    ORDER BY n.content_embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

COMMENT ON FUNCTION search_notices_by_vector IS '벡터 유사도 기반 공지사항 검색';

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

COMMENT ON FUNCTION search_users_by_notice_vector IS '공지사항과 관련된 사용자 검색 (알림 발송용)';

-- ============================================================
-- 6. 하이브리드 검색 함수 (하드 필터링 + 벡터 검색)
-- ============================================================

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
    priority varchar,
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
        n.priority,
        n.published_at,
        1 - (n.content_embedding <=> query_embedding) AS similarity,
        -- 하드 필터 매칭 여부
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
        -- 하드 필터 매칭 우선, 그 다음 유사도 순
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

COMMENT ON FUNCTION hybrid_search_notices IS '하이브리드 검색 (하드 필터링 + 벡터 유사도)';

-- ============================================================
-- 완료 메시지
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE '벡터 임베딩 마이그레이션 완료!';
    RAISE NOTICE '   - pgvector 확장 활성화';
    RAISE NOTICE '   - notices 테이블에 content_embedding, enriched_metadata 추가';
    RAISE NOTICE '   - user_preferences 테이블에 interests_embedding, enriched_profile 추가';
    RAISE NOTICE '   - 벡터 검색 인덱스 생성';
    RAISE NOTICE '   - 검색 함수 생성';
    RAISE NOTICE '';
    RAISE NOTICE '다음 단계: migrate_embeddings.py 스크립트로 기존 공지사항 임베딩 생성';
END $$;
