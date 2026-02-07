# -*- coding: utf-8 -*-
"""
임베딩 서비스 모듈

이 파일이 하는 일:
텍스트를 숫자 벡터(임베딩)로 변환합니다.
이 벡터를 사용하면 텍스트 간의 의미적 유사도를 계산할 수 있습니다.

비유:
- 텍스트 = 사람
- 임베딩 = 사람의 DNA
- 유사도 검색 = DNA로 가족 찾기

예를 들어 "장학금 신청"과 "등록금 지원"은
겉보기에는 다른 단어지만, 임베딩으로 변환하면
"비슷한 의미"라는 것을 알 수 있습니다.
"""

import google.generativeai as genai
import os
from typing import List, Optional
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()


class EmbeddingService:
    """
    Google gemini-embedding-001 기반 임베딩 생성 서비스

    목적:
    텍스트를 768차원의 숫자 벡터로 변환합니다.
    이 벡터를 DB에 저장하면 빠른 유사도 검색이 가능합니다.

    참고: gemini-embedding-001은 기본 3072 차원이지만,
    HNSW 인덱스가 최대 2000 차원까지만 지원하므로 768로 축소합니다.

    사용 예시:
    service = EmbeddingService()
    embedding = service.create_embedding("장학금 신청 안내")
    # embedding = [0.123, -0.456, 0.789, ...]  # 768개의 숫자
    """

    # 모델 설정 (Gemini Embedding 모델 사용)
    MODEL_NAME = "models/gemini-embedding-001"
    # 768 차원으로 축소 출력 (HNSW 인덱스는 최대 2000 차원까지만 지원)
    DIMENSION = 768
    MAX_CHARS = 8000  # 최대 입력 문자 수 (약 3000 토큰)

    def __init__(self, api_key: Optional[str] = None):
        """
        임베딩 서비스를 초기화합니다.

        매개변수:
        - api_key: Gemini API 키 (없으면 환경변수에서 자동 로드)

        하는 일:
        1. API 키 설정
        2. Gemini API 연결 확인
        """
        self.api_key = api_key or os.getenv('GEMINI_API_KEY')

        if not self.api_key:
            raise ValueError(
                "Gemini API 키가 없습니다! "
                ".env 파일에 GEMINI_API_KEY를 설정하거나 "
                "EmbeddingService(api_key='your-key')로 직접 전달하세요."
            )

        # Gemini API 설정
        genai.configure(api_key=self.api_key)
        print(f"EmbeddingService 초기화 완료 (모델: {self.MODEL_NAME}, 차원: {self.DIMENSION})")

    def create_embedding(self, text: str) -> List[float]:
        """
        텍스트에 대한 임베딩 벡터를 생성합니다.

        매개변수:
        - text: 임베딩할 텍스트

        반환값:
        - 768차원 벡터 (List[float])

        사용 예시:
        embedding = service.create_embedding("2024학년도 장학금 신청 안내")
        print(len(embedding))  # 3072

        task_type 설명:
        - retrieval_document: 검색될 문서용 (공지사항, 사용자 프로필)
        - retrieval_query: 검색 쿼리용 (사용자 검색어)
        """
        # 텍스트 전처리
        text = self._preprocess_text(text)

        if not text:
            raise ValueError("임베딩할 텍스트가 비어있습니다.")

        try:
            # Gemini Embedding API 호출
            result = genai.embed_content(
                model=self.MODEL_NAME,
                content=text,
                task_type="retrieval_document",  # 문서 검색용
                output_dimensionality=self.DIMENSION  # 차원 축소
            )

            embedding = result['embedding']

            # 차원 검증
            if len(embedding) != self.DIMENSION:
                raise ValueError(
                    f"임베딩 차원 불일치: 예상 {self.DIMENSION}, 실제 {len(embedding)}"
                )

            return embedding

        except Exception as e:
            raise Exception(f"임베딩 생성 실패: {str(e)}")

    def create_query_embedding(self, query: str) -> List[float]:
        """
        검색 쿼리에 대한 임베딩을 생성합니다.

        매개변수:
        - query: 검색어

        반환값:
        - 768차원 벡터

        create_embedding과의 차이:
        - create_embedding: 저장될 문서용 (retrieval_document)
        - create_query_embedding: 검색 쿼리용 (retrieval_query)

        Google의 임베딩 모델은 문서와 쿼리를 다르게 인코딩하여
        검색 성능을 최적화합니다.

        사용 예시:
        # 사용자가 "장학금"을 검색했을 때
        query_embedding = service.create_query_embedding("장학금")
        # 이 벡터로 DB에서 유사한 공지사항을 검색
        """
        query = self._preprocess_text(query)

        if not query:
            raise ValueError("검색 쿼리가 비어있습니다.")

        try:
            result = genai.embed_content(
                model=self.MODEL_NAME,
                content=query,
                task_type="retrieval_query",  # 쿼리 검색용
                output_dimensionality=self.DIMENSION  # 차원 축소
            )

            return result['embedding']

        except Exception as e:
            raise Exception(f"쿼리 임베딩 생성 실패: {str(e)}")

    def batch_create_embeddings(
        self,
        texts: List[str],
        show_progress: bool = True
    ) -> List[List[float]]:
        """
        여러 텍스트에 대한 임베딩을 일괄 생성합니다.

        매개변수:
        - texts: 임베딩할 텍스트 리스트
        - show_progress: 진행 상황 출력 여부

        반환값:
        - 임베딩 벡터 리스트

        사용 예시:
        texts = ["공지1 내용", "공지2 내용", "공지3 내용"]
        embeddings = service.batch_create_embeddings(texts)
        print(len(embeddings))  # 3
        print(len(embeddings[0]))  # 3072
        """
        embeddings = []
        total = len(texts)

        for i, text in enumerate(texts, 1):
            try:
                embedding = self.create_embedding(text)
                embeddings.append(embedding)

                if show_progress and i % 10 == 0:
                    print(f"  임베딩 생성 진행: {i}/{total}")

            except Exception as e:
                print(f"  임베딩 생성 실패 (인덱스 {i}): {str(e)}")
                # 실패한 경우 빈 벡터 추가 (나중에 재시도 가능)
                embeddings.append([])

        if show_progress:
            success_count = sum(1 for e in embeddings if e)
            print(f"  임베딩 생성 완료: {success_count}/{total} 성공")

        return embeddings

    def create_notice_embedding_text(
        self,
        title: str,
        content: str,
        summary: Optional[str] = None,
        category: Optional[str] = None,
        keywords: Optional[List[str]] = None,
        target_departments: Optional[List[str]] = None
    ) -> str:
        """
        공지사항 정보를 임베딩용 텍스트로 조합합니다.

        매개변수:
        - title: 공지사항 제목
        - content: 공지사항 내용
        - summary: AI 요약 (있으면 내용 대신 사용)
        - category: 카테고리
        - keywords: 키워드 리스트
        - target_departments: 대상 학과 리스트

        반환값:
        - 임베딩용 조합 텍스트

        이 함수의 목적:
        임베딩의 품질을 높이기 위해 공지사항의 여러 정보를
        하나의 텍스트로 조합합니다. AI 요약이 있으면
        원본 내용보다 요약을 사용하여 노이즈를 줄입니다.
        """
        parts = []

        # 제목 (가장 중요)
        if title:
            parts.append(f"제목: {title}")

        # 카테고리
        if category:
            parts.append(f"카테고리: {category}")

        # AI 요약 (있으면 내용 대신 사용)
        if summary:
            parts.append(f"요약: {summary}")
        elif content:
            # 요약이 없으면 내용 앞부분만 사용
            content_preview = content[:1000]
            parts.append(f"내용: {content_preview}")

        # 대상 학과
        if target_departments:
            parts.append(f"대상 학과: {', '.join(target_departments)}")

        # 키워드
        if keywords:
            parts.append(f"키워드: {', '.join(keywords)}")

        return "\n".join(parts)

    def create_user_profile_embedding_text(
        self,
        department: Optional[str] = None,
        grade: Optional[int] = None,
        interests: Optional[List[str]] = None,
        categories: Optional[List[str]] = None,
        student_type: Optional[str] = None
    ) -> str:
        """
        사용자 프로필 정보를 임베딩용 텍스트로 조합합니다.

        매개변수:
        - department: 학과
        - grade: 학년
        - interests: 관심사 키워드 리스트
        - categories: 관심 카테고리 리스트
        - student_type: 학생 유형 (재학생/휴학생/졸업생)

        반환값:
        - 임베딩용 조합 텍스트

        사용 예시:
        text = service.create_user_profile_embedding_text(
            department="컴퓨터정보공학과",
            grade=3,
            interests=["AI", "장학금", "공모전"],
            categories=["장학", "취업"]
        )
        embedding = service.create_embedding(text)
        """
        parts = []

        if department:
            parts.append(f"학과: {department}")

        if grade:
            parts.append(f"학년: {grade}학년")

        if student_type:
            parts.append(f"학생 유형: {student_type}")

        if categories:
            parts.append(f"관심 카테고리: {', '.join(categories)}")

        if interests:
            parts.append(f"관심사: {', '.join(interests)}")

        # 기본값 (정보가 너무 적을 때)
        if not parts:
            parts.append("대학생 일반 관심사: 학사, 장학금, 취업, 행사")

        return "\n".join(parts)

    def _preprocess_text(self, text: str) -> str:
        """
        임베딩을 위한 텍스트 전처리

        하는 일:
        1. 앞뒤 공백 제거
        2. 연속 공백을 단일 공백으로
        3. 최대 길이 제한 (약 3000 토큰)

        최대 길이를 제한하는 이유:
        - 임베딩 모델의 최대 입력 토큰은 3,072개
        - 한글 기준 약 8,000자가 안전한 범위
        """
        if not text:
            return ""

        # 공백 정규화
        text = ' '.join(text.split())

        # 길이 제한
        if len(text) > self.MAX_CHARS:
            text = text[:self.MAX_CHARS]
            # 단어 중간에서 잘리지 않도록 마지막 공백까지 자름
            last_space = text.rfind(' ')
            if last_space > self.MAX_CHARS * 0.9:  # 90% 이상이면
                text = text[:last_space]

        return text

    def calculate_similarity(
        self,
        embedding1: List[float],
        embedding2: List[float]
    ) -> float:
        """
        두 임베딩 벡터 간의 코사인 유사도를 계산합니다.

        매개변수:
        - embedding1: 첫 번째 임베딩 벡터
        - embedding2: 두 번째 임베딩 벡터

        반환값:
        - 코사인 유사도 (0~1, 1에 가까울수록 유사)

        코사인 유사도란?
        두 벡터가 같은 방향을 가리키면 1,
        반대 방향이면 -1, 수직이면 0입니다.
        임베딩에서는 보통 0~1 사이 값이 나옵니다.

        사용 예시:
        emb1 = service.create_embedding("장학금 신청")
        emb2 = service.create_embedding("등록금 지원")
        similarity = service.calculate_similarity(emb1, emb2)
        print(similarity)  # 0.85 (높은 유사도)
        """
        import math

        # 벡터 길이가 다르면 에러
        if len(embedding1) != len(embedding2):
            raise ValueError("임베딩 벡터의 길이가 다릅니다.")

        # 내적 (dot product)
        dot_product = sum(a * b for a, b in zip(embedding1, embedding2))

        # 각 벡터의 크기 (magnitude)
        magnitude1 = math.sqrt(sum(a * a for a in embedding1))
        magnitude2 = math.sqrt(sum(b * b for b in embedding2))

        # 0으로 나누기 방지
        if magnitude1 == 0 or magnitude2 == 0:
            return 0.0

        # 코사인 유사도
        return dot_product / (magnitude1 * magnitude2)


# 테스트 코드
if __name__ == "__main__":
    print("=" * 60)
    print("임베딩 서비스 테스트 시작")
    print("=" * 60)

    try:
        # 1. 서비스 초기화
        print("\n[1단계] 임베딩 서비스 초기화 중...")
        service = EmbeddingService()

        # 2. 단일 텍스트 임베딩 테스트
        print("\n[2단계] 단일 텍스트 임베딩 테스트...")
        test_text = "2024학년도 1학기 국가장학금 신청 안내"
        embedding = service.create_embedding(test_text)
        print(f"  입력: {test_text}")
        print(f"  임베딩 차원: {len(embedding)}")
        print(f"  임베딩 샘플: [{embedding[0]:.4f}, {embedding[1]:.4f}, ..., {embedding[-1]:.4f}]")

        # 3. 유사도 테스트
        print("\n[3단계] 유사도 테스트...")
        texts = [
            "장학금 신청 방법",
            "등록금 납부 안내",
            "오늘 점심 메뉴"
        ]

        for text in texts:
            emb = service.create_embedding(text)
            similarity = service.calculate_similarity(embedding, emb)
            print(f"  '{test_text[:20]}...' vs '{text}': {similarity:.4f}")

        # 4. 공지사항 임베딩 텍스트 생성 테스트
        print("\n[4단계] 공지사항 임베딩 텍스트 생성 테스트...")
        notice_text = service.create_notice_embedding_text(
            title="2024학년도 국가장학금 신청 안내",
            content="국가장학금 신청 기간은 2024년 1월 2일부터...",
            summary="국가장학금 1월 2일부터 신청 시작",
            category="장학",
            keywords=["장학금", "등록금", "지원"]
        )
        print(f"  생성된 텍스트:\n{notice_text}")

        # 5. 사용자 프로필 임베딩 텍스트 생성 테스트
        print("\n[5단계] 사용자 프로필 임베딩 텍스트 생성 테스트...")
        profile_text = service.create_user_profile_embedding_text(
            department="컴퓨터정보공학과",
            grade=3,
            interests=["AI", "장학금", "공모전"],
            categories=["장학", "취업"]
        )
        print(f"  생성된 텍스트:\n{profile_text}")

        print("\n" + "=" * 60)
        print("모든 테스트 완료!")
        print("=" * 60)

    except Exception as e:
        print(f"\n테스트 실패: {str(e)}")
