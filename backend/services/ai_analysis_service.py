# -*- coding: utf-8 -*-
"""
AI 분석 서비스 모듈 (사용자별 관련도 계산)

🤔 이 파일이 하는 일:
사용자 프로필과 공지사항을 비교하여 맞춤형 관련도 점수를 계산합니다.
같은 공지사항이라도 사용자마다 다른 점수를 받게 되어 개인화된 알림이 가능합니다.

📚 비유:
- 공지사항 = 우편물
- 사용자 프로필 = 주소 + 관심사
- 이 서비스 = 우편물을 보고 "이 사람에게 중요한가?"를 판단하는 우체국 직원
"""

import os
import sys
from typing import Dict, Any, List, Optional
from datetime import datetime
from supabase import create_client, Client

# 상위 디렉토리 모듈 import
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from ai.gemini_client import get_gemini_model
from ai.prompts import get_user_relevance_prompt, get_batch_relevance_prompt
import json


class AIAnalysisService:
    """
    사용자별 공지사항 관련도 분석 서비스

    🎯 목적:
    사용자의 학과, 학년, 관심사 등을 고려하여 공지사항과의 관련도를 계산합니다.

    🏗️ 주요 기능:
    1. calculate_relevance: 단일 공지사항 관련도 계산
    2. calculate_batch_relevance: 여러 공지사항 일괄 처리
    3. save_analysis: 분석 결과를 ai_analysis 테이블에 저장
    4. get_relevant_notices: 사용자에게 관련 있는 공지사항 조회
    """

    def __init__(self):
        """서비스를 초기화합니다."""
        # Supabase 클라이언트
        self.url: str = os.getenv("SUPABASE_URL")
        self.key: str = os.getenv("SUPABASE_KEY")

        if not self.url or not self.key:
            raise ValueError(
                "❌ SUPABASE_URL과 SUPABASE_KEY 환경 변수가 필요합니다"
            )

        self.client: Client = create_client(self.url, self.key)

        # Gemini 모델
        self.model = get_gemini_model()

        print("✅ AIAnalysisService 초기화 완료")

    def calculate_relevance(
        self,
        notice: Dict[str, Any],
        user_profile: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        단일 공지사항에 대한 사용자 관련도를 계산합니다.

        🔧 매개변수:
        - notice: 공지사항 데이터
          {
              "id": "uuid",
              "summary": "공지 요약",
              "category": "학사",
              ...
          }
        - user_profile: 사용자 정보
          {
              "department": "컴퓨터정보공학과",
              "grade": 3,
              "interests": ["AI", "장학금"],
              "student_type": "재학생"
          }

        📊 반환값:
        {
            "relevance_score": 0.85,
            "reason": "학과 관련 필수 공지",
            "action_required": true
        }
        """
        try:
            # 프롬프트 생성
            prompt = get_user_relevance_prompt(
                notice_summary=notice.get("summary", notice.get("ai_summary", "")),
                notice_category=notice.get("category", "기타"),
                user_profile=user_profile
            )

            # Gemini API 호출
            response = self.model.generate_content(prompt)
            result_text = response.text.strip()

            # JSON 파싱
            # ```json ... ``` 형식 제거
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()

            analysis = json.loads(result_text)

            # 검증
            if "relevance_score" not in analysis:
                raise ValueError("relevance_score 누락")

            # 점수 범위 확인 (0~1)
            score = float(analysis["relevance_score"])
            if score < 0 or score > 1:
                print(f"⚠️ 점수 범위 초과: {score} → 클리핑")
                score = max(0.0, min(1.0, score))
                analysis["relevance_score"] = score

            return analysis

        except json.JSONDecodeError as e:
            print(f"❌ JSON 파싱 실패: {str(e)}")
            print(f"원본 응답: {result_text[:200]}")
            # 기본값 반환
            return {
                "relevance_score": 0.3,
                "reason": "분석 실패 - 기본 점수 부여",
                "action_required": False
            }

        except Exception as e:
            print(f"❌ 관련도 계산 실패: {str(e)}")
            return {
                "relevance_score": 0.3,
                "reason": "분석 오류",
                "action_required": False
            }

    def calculate_batch_relevance(
        self,
        notices: List[Dict[str, Any]],
        user_profile: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        여러 공지사항에 대한 관련도를 한 번에 계산합니다.

        🎯 목적:
        API 호출 횟수를 줄여서 비용과 시간을 절약합니다.

        🔧 매개변수:
        - notices: 공지사항 리스트 (최대 10개 권장)
        - user_profile: 사용자 정보

        📊 반환값:
        [
            {
                "notice_id": "uuid-1",
                "relevance_score": 0.9,
                "reason": "...",
                "action_required": true
            },
            ...
        ]
        """
        if not notices:
            return []

        # 배치 크기 제한 (한 번에 최대 10개)
        batch_size = 10
        all_results = []

        for i in range(0, len(notices), batch_size):
            batch = notices[i:i + batch_size]

            try:
                # 프롬프트 생성
                prompt = get_batch_relevance_prompt(
                    notices=batch,
                    user_profile=user_profile
                )

                # Gemini API 호출
                response = self.model.generate_content(prompt)
                result_text = response.text.strip()

                # JSON 파싱
                if "```json" in result_text:
                    result_text = result_text.split("```json")[1].split("```")[0].strip()
                elif "```" in result_text:
                    result_text = result_text.split("```")[1].split("```")[0].strip()

                batch_results = json.loads(result_text)

                # results 배열 추출
                if "results" in batch_results:
                    all_results.extend(batch_results["results"])
                else:
                    all_results.extend(batch_results)

            except Exception as e:
                print(f"❌ 배치 {i//batch_size + 1} 분석 실패: {str(e)}")
                # 개별 처리로 폴백
                for notice in batch:
                    individual_result = self.calculate_relevance(notice, user_profile)
                    individual_result["notice_id"] = notice.get("id")
                    all_results.append(individual_result)

        return all_results

    def save_analysis(
        self,
        notice_id: str,
        user_id: str,
        analysis_result: Dict[str, Any]
    ) -> bool:
        """
        분석 결과를 ai_analysis 테이블에 저장합니다.

        🔧 매개변수:
        - notice_id: 공지사항 ID
        - user_id: 사용자 ID
        - analysis_result: 분석 결과
          {
              "relevance_score": 0.85,
              "reason": "...",
              "action_required": true
          }

        📊 반환값:
        - 저장 성공 여부 (True/False)
        """
        try:
            # DB 저장 데이터 준비
            db_data = {
                "notice_id": notice_id,
                "user_id": user_id,
                "relevance_score": float(analysis_result.get("relevance_score", 0.0)),
                "summary": analysis_result.get("reason", ""),
                "action_required": analysis_result.get("action_required", False),
                "analyzed_at": datetime.now().isoformat()
            }

            # 중복 체크 (같은 notice_id + user_id 조합)
            existing = self.client.table("ai_analysis")\
                .select("id")\
                .eq("notice_id", notice_id)\
                .eq("user_id", user_id)\
                .execute()

            if existing.data:
                # 업데이트
                result = self.client.table("ai_analysis")\
                    .update(db_data)\
                    .eq("notice_id", notice_id)\
                    .eq("user_id", user_id)\
                    .execute()
            else:
                # 신규 저장
                result = self.client.table("ai_analysis")\
                    .insert(db_data)\
                    .execute()

            return bool(result.data)

        except Exception as e:
            print(f"❌ ai_analysis 저장 실패: {str(e)}")
            return False

    def get_relevant_notices(
        self,
        user_id: str,
        min_score: float = 0.5,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        사용자에게 관련 있는 공지사항을 조회합니다.

        🔧 매개변수:
        - user_id: 사용자 ID
        - min_score: 최소 관련도 점수 (기본값: 0.5)
        - limit: 최대 개수 (기본값: 50)

        📊 반환값:
        - 관련 공지사항 리스트 (관련도 높은 순)
        """
        try:
            result = self.client.table("ai_analysis")\
                .select("*, notices(*)")\
                .eq("user_id", user_id)\
                .gte("relevance_score", min_score)\
                .order("relevance_score", desc=True)\
                .order("analyzed_at", desc=True)\
                .limit(limit)\
                .execute()

            if result.data:
                print(f"📋 관련 공지 {len(result.data)}개 조회 (점수 >= {min_score})")
                return result.data
            else:
                return []

        except Exception as e:
            print(f"❌ 관련 공지 조회 실패: {str(e)}")
            return []

    def batch_analyze_for_users(
        self,
        notice_id: str,
        user_ids: List[str] = None
    ) -> Dict[str, int]:
        """
        하나의 공지사항에 대해 여러 사용자의 관련도를 계산합니다.

        🎯 목적:
        새 공지가 등록되었을 때 모든 사용자에게 맞춤 분석을 수행합니다.

        🔧 매개변수:
        - notice_id: 공지사항 ID
        - user_ids: 사용자 ID 리스트 (None이면 전체 사용자)

        📊 반환값:
        {
            "total": 전체 사용자 수,
            "analyzed": 분석 완료 수,
            "notified": 알림 발송 대상 수 (score >= 0.5)
        }
        """
        try:
            # 1. 공지사항 조회
            notice = self.client.table("notices")\
                .select("*")\
                .eq("id", notice_id)\
                .single()\
                .execute()

            if not notice.data:
                print(f"❌ 공지사항을 찾을 수 없습니다: {notice_id}")
                return {"total": 0, "analyzed": 0, "notified": 0}

            notice_data = notice.data

            # 2. 사용자 목록 조회
            if user_ids:
                users_query = self.client.table("users")\
                    .select("*")\
                    .in_("id", user_ids)
            else:
                users_query = self.client.table("users").select("*")

            users_result = users_query.execute()
            users = users_result.data

            if not users:
                print("⚠️ 사용자가 없습니다")
                return {"total": 0, "analyzed": 0, "notified": 0}

            print(f"📊 {len(users)}명 사용자에 대해 관련도 분석 시작...")

            # 3. 각 사용자별 관련도 계산
            analyzed_count = 0
            notified_count = 0

            for i, user in enumerate(users, 1):
                print(f"\n[{i}/{len(users)}] {user.get('name', 'Unknown')} 분석 중...")

                # 사용자 프로필 구성
                user_profile = {
                    "department": user.get("department", "정보 없음"),
                    "grade": user.get("grade", 1),
                    "interests": user.get("interests", []),
                    "student_type": user.get("student_type", "재학생")
                }

                # 관련도 계산
                analysis = self.calculate_relevance(notice_data, user_profile)

                # DB 저장
                success = self.save_analysis(
                    notice_id=notice_id,
                    user_id=user["id"],
                    analysis_result=analysis
                )

                if success:
                    analyzed_count += 1
                    score = analysis.get("relevance_score", 0.0)

                    # 알림 발송 대상 카운트 (점수 >= 0.5)
                    if score >= 0.5:
                        notified_count += 1
                        print(f"  ✅ 점수: {score:.2f} - 알림 발송 대상")
                    else:
                        print(f"  ℹ️ 점수: {score:.2f} - 알림 제외")

            print(f"\n📊 분석 완료:")
            print(f"  - 전체: {len(users)}명")
            print(f"  - 분석 완료: {analyzed_count}명")
            print(f"  - 알림 발송 대상: {notified_count}명")

            return {
                "total": len(users),
                "analyzed": analyzed_count,
                "notified": notified_count
            }

        except Exception as e:
            print(f"❌ 배치 분석 실패: {str(e)}")
            import traceback
            traceback.print_exc()
            return {"total": 0, "analyzed": 0, "notified": 0}


# 🧪 테스트 코드
if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()

    print("=" * 50)
    print("🧪 AIAnalysisService 테스트 시작")
    print("=" * 50)

    try:
        # 1. 서비스 초기화
        print("\n[1단계] AIAnalysisService 초기화 중...")
        service = AIAnalysisService()

        # 2. 테스트 공지사항
        test_notice = {
            "id": "test-notice-1",
            "summary": "컴퓨터공학과 AI 관련 공모전 안내. 3학년 이상 참여 가능.",
            "category": "행사"
        }

        # 3. 테스트 사용자 프로필
        test_user_profile = {
            "department": "컴퓨터정보공학과",
            "grade": 3,
            "interests": ["AI", "머신러닝", "공모전"],
            "student_type": "재학생"
        }

        # 4. 관련도 계산
        print("\n[2단계] 관련도 계산 중...")
        analysis = service.calculate_relevance(test_notice, test_user_profile)

        print(f"\n📊 분석 결과:")
        print(f"  - 관련도 점수: {analysis['relevance_score']}")
        print(f"  - 이유: {analysis['reason']}")
        print(f"  - 조치 필요: {analysis['action_required']}")

        print("\n" + "=" * 50)
        print("✅ AIAnalysisService 테스트 완료!")
        print("=" * 50)

    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()
