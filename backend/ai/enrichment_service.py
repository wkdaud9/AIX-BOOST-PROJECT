# -*- coding: utf-8 -*-
"""
데이터 보강 서비스 모듈

이 파일이 하는 일:
공지사항과 사용자 프로필의 메타데이터를 보강합니다.
- 공지사항에서 대상 학과/학년/키워드 추출
- 사용자 관심사를 유의어로 확장

왜 필요한가?
1. 공지: "컴퓨터정보공학과 3,4학년 대상" → 자동 추출
2. 사용자: "AI 관심" → "인공지능, 머신러닝, 딥러닝"으로 확장

이렇게 보강하면 벡터 검색의 정확도가 높아집니다.
"""

import re
from typing import Dict, List, Any, Optional


class EnrichmentService:
    """
    공지사항 및 사용자 프로필 데이터 보강 서비스

    역할:
    1. 공지사항에서 대상 학과/학년/학생유형 추출
    2. 키워드 확장 (유의어, 관련어)
    3. 액션 타입 감지 (신청, 제출, 참여 등)
    4. 긴급도 계산
    """

    # 2026학년도 국립군산대학교 학부/학과 현황 (대학 → 학과/학부)
    UNIVERSITY_DEPARTMENTS = {
        "컴퓨터소프트웨어특성화대학": [
            "컴퓨터정보공학과", "인공지능융합학과", "임베디드소프트웨어학과",
            "소프트웨어학과", "IT융합통신공학과",
        ],
        "인문콘텐츠융합대학": [
            "국어국문학과", "영어영문학과", "일어일문학과",
            "중어중문학과", "역사학과", "철학과",
        ],
        "해양·바이오특성화대학": [
            "생명과학과", "해양수산공공인재학과", "해양생명과학과",
            "해양생물자원학과", "수산생명의학과", "식품영양학과",
            "기관공학과", "식품생명공학과",
        ],
        "ICC특성화대학부": [
            "미디어문화학부", "아동학부", "사회복지학부",
            "법행정경찰학부", "간호학부", "의류학부", "해양경찰학부",
            "체육학부", "산업디자인학부", "기계공학부",
            "건축공학부", "공간디자인융합기술학부",
        ],
        "경영특성화대학": [
            "경영학부", "국제물류학과", "무역학과", "회계학부",
            "금융부동산경제학과", "벤처창업학과",
        ],
        "자율전공대학": [
            "자율전공학부", "미술학과", "음악과", "조선공학과",
        ],
        "첨단·에너지대학": [
            "이차전지·에너지학부", "스마트오션모빌리티공학과",
            "바이오헬스학과", "스마트시티학과",
        ],
        "융합과학공학대학": [
            "전자공학과", "전기공학과", "신소재공학과", "화학공학과",
            "환경공학과", "토목공학과", "해양건설공학과",
            "첨단과학기술학부", "수학과",
        ],
    }

    def __init__(self):
        """데이터 보강 서비스 초기화"""
        # 군산대학교 학과 목록 (UNIVERSITY_DEPARTMENTS에서 자동 생성)
        self.department_patterns = []
        for depts in self.UNIVERSITY_DEPARTMENTS.values():
            self.department_patterns.extend(depts)

        # 학과 약어/별칭 매핑
        self.department_aliases = {
            "컴공": "컴퓨터정보공학과",
            "컴정": "컴퓨터정보공학과",
            "인공지능": "인공지능융합학과",
            "임소": "임베디드소프트웨어학과",
            "소웨": "소프트웨어학과",
            "전자": "전자공학과",
            "전기": "전기공학과",
            "기계": "기계공학부",
            "경영": "경영학부",
            "국문": "국어국문학과",
            "영문": "영어영문학과",
            "일문": "일어일문학과",
            "중문": "중어중문학과",
            "간호": "간호학부",
            "건축": "건축공학부",
            "화공": "화학공학과",
            "토목": "토목공학과",
            "환경": "환경공학과",
            "신소재": "신소재공학과",
            "사복": "사회복지학부",
            "디자인": "산업디자인학부",
        }

        # 관심사 확장 사전
        self.interest_expansion = {
            "AI": ["인공지능", "머신러닝", "딥러닝", "데이터사이언스", "자연어처리"],
            "인공지능": ["AI", "머신러닝", "딥러닝", "데이터사이언스"],
            "프로그래밍": ["코딩", "개발", "소프트웨어", "알고리즘"],
            "개발": ["프로그래밍", "코딩", "소프트웨어", "웹개발", "앱개발"],
            "장학금": ["등록금", "학비", "지원금", "장학", "학자금"],
            "취업": ["채용", "인턴", "일자리", "구직", "커리어"],
            "인턴": ["취업", "채용", "현장실습", "인턴십"],
            "공모전": ["대회", "경진대회", "콘테스트", "해커톤"],
            "해커톤": ["공모전", "대회", "개발대회", "해킹대회"],
            "창업": ["스타트업", "벤처", "사업", "창업지원"],
            "연구": ["연구실", "대학원", "논문", "학술"],
            "대학원": ["연구", "석사", "박사", "진학"],
            "교환학생": ["해외", "유학", "어학연수", "국제교류"],
            "봉사": ["봉사활동", "자원봉사", "사회봉사"],
        }

        # 액션 타입 키워드
        self.action_keywords = {
            "신청": ["신청", "접수", "지원", "응모", "참가신청"],
            "제출": ["제출", "서류제출", "서류", "업로드"],
            "등록": ["등록", "가입", "수강등록", "수강신청"],
            "참여": ["참여", "참가", "참석", "출석"],
            "확인": ["확인", "조회", "열람", "공지"],
            "납부": ["납부", "결제", "입금", "등록금"],
        }

        print("EnrichmentService 초기화 완료")

    def enrich_notice(self, notice: Dict[str, Any]) -> Dict[str, Any]:
        """
        공지사항 데이터를 보강합니다.

        매개변수:
        - notice: 공지사항 딕셔너리 (title, content, category 등)

        반환값:
        - 보강된 공지사항 딕셔너리 (enriched_metadata 추가됨)

        추출 항목:
        - target_departments: 대상 학과 리스트
        - target_grades: 대상 학년 리스트
        - target_student_types: 대상 학생 유형 리스트
        - keywords_expanded: 확장된 키워드 리스트
        - action_type: 필요한 행동 (신청, 제출 등)
        """
        title = notice.get("title", "")
        content = notice.get("content", "")
        full_text = f"{title} {content}"

        enriched_metadata = {
            "target_departments": self._extract_departments(full_text),
            "target_grades": self._extract_grades(full_text),
            "target_student_types": self._extract_student_types(full_text),
            "keywords_expanded": self._expand_keywords(notice.get("keywords", [])),
            "action_type": self._detect_action_type(full_text),
            "is_for_all": self._is_for_all_students(full_text)
        }

        # 원본 notice에 enriched_metadata 추가
        notice["enriched_metadata"] = enriched_metadata
        return notice

    def enrich_user_profile(
        self,
        department: Optional[str] = None,
        grade: Optional[int] = None,
        interests: Optional[List[str]] = None,
        categories: Optional[List[str]] = None,
        student_type: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        사용자 프로필 데이터를 보강합니다.

        매개변수:
        - department: 학과
        - grade: 학년
        - interests: 관심사 키워드 리스트
        - categories: 관심 카테고리 리스트
        - student_type: 학생 유형

        반환값:
        - 보강된 프로필 딕셔너리

        보강 내용:
        - 관심사 확장 (유의어 추가)
        - 학과 기반 기본 관심사 추가
        - 학년 기반 관심사 추가
        """
        enriched_profile = {
            "original_interests": interests or [],
            "interests_expanded": [],
            "department_context": [],
            "grade_context": [],
            "career_interests": []
        }

        # 1. 관심사 확장
        if interests:
            expanded = self._expand_interests(interests)
            enriched_profile["interests_expanded"] = expanded

        # 2. 학과 기반 관심사 추가
        if department:
            dept_interests = self._get_department_interests(department)
            enriched_profile["department_context"] = dept_interests

        # 3. 학년 기반 관심사 추가
        if grade:
            grade_interests = self._get_grade_interests(grade)
            enriched_profile["grade_context"] = grade_interests

        # 4. 카테고리 기반 관심사 추가
        if categories:
            category_interests = self._get_category_interests(categories)
            enriched_profile["category_context"] = category_interests

        # 5. 학생 유형 기반 관심사
        if student_type:
            type_interests = self._get_student_type_interests(student_type)
            enriched_profile["career_interests"] = type_interests

        return enriched_profile

    def _extract_departments(self, text: str) -> List[str]:
        """
        텍스트에서 대상 학과를 추출합니다.

        추출 방법:
        1. 정규표현식으로 학과명 패턴 찾기
        2. 학과 약어 매핑 적용
        3. 중복 제거
        """
        found = []

        # 정규표현식 패턴들
        patterns = [
            r'([가-힣]+학과)',       # XX학과
            r'([가-힣]+공학부)',     # XX공학부
            r'([가-힣]+전공)',       # XX전공
            r'([가-힣]+학부)',       # XX학부
        ]

        for pattern in patterns:
            matches = re.findall(pattern, text)
            for match in matches:
                # 유효한 학과명인지 확인
                if self._is_valid_department(match):
                    found.append(match)

        # 약어 매핑
        for alias, full_name in self.department_aliases.items():
            if alias in text:
                found.append(full_name)

        return list(set(found))

    def _extract_grades(self, text: str) -> List[int]:
        """
        텍스트에서 대상 학년을 추출합니다.

        패턴 예시:
        - "3학년" → [3]
        - "3,4학년" → [3, 4]
        - "전학년" → []  (빈 리스트 = 전체 대상)
        """
        # 전학년 키워드 체크
        if any(kw in text for kw in ["전학년", "전체학년", "모든 학년", "전체 학생"]):
            return []

        grades = []

        # 패턴: "3학년", "3, 4학년", "3~4학년"
        patterns = [
            r'(\d)학년',                          # 단일 학년
            r'(\d),\s*(\d)학년',                  # 여러 학년 (콤마)
            r'(\d)~(\d)학년',                     # 범위 학년
            r'(\d)-(\d)학년',                     # 범위 학년 (하이픈)
        ]

        for pattern in patterns:
            matches = re.findall(pattern, text)
            for match in matches:
                if isinstance(match, tuple):
                    for g in match:
                        if g.isdigit() and 1 <= int(g) <= 6:
                            grades.append(int(g))
                elif match.isdigit() and 1 <= int(match) <= 6:
                    grades.append(int(match))

        return list(set(grades))

    def _extract_student_types(self, text: str) -> List[str]:
        """
        텍스트에서 대상 학생 유형을 추출합니다.

        유형:
        - 재학생, 휴학생, 졸업생, 졸업예정자
        - 학부생, 대학원생
        - 신입생, 편입생
        """
        types = []

        type_keywords = {
            "재학생": ["재학생", "재학 중"],
            "휴학생": ["휴학생", "휴학 중"],
            "졸업생": ["졸업생", "졸업자"],
            "졸업예정자": ["졸업예정자", "졸업예정"],
            "신입생": ["신입생", "신입학"],
            "편입생": ["편입생", "편입학"],
            "학부생": ["학부생", "학부"],
            "대학원생": ["대학원생", "대학원"]
        }

        for type_name, keywords in type_keywords.items():
            if any(kw in text for kw in keywords):
                types.append(type_name)

        return list(set(types))

    def _expand_keywords(self, keywords: List[str]) -> List[str]:
        """
        키워드를 유의어로 확장합니다.
        """
        if not keywords:
            return []

        expanded = set(keywords)

        for keyword in keywords:
            # 정확히 일치하는 경우
            if keyword in self.interest_expansion:
                expanded.update(self.interest_expansion[keyword])
            # 부분 일치하는 경우
            else:
                for key, synonyms in self.interest_expansion.items():
                    if key in keyword or keyword in key:
                        expanded.update(synonyms)

        return list(expanded)

    def _expand_interests(self, interests: List[str]) -> List[str]:
        """
        사용자 관심사를 확장합니다.
        """
        return self._expand_keywords(interests)

    def _detect_action_type(self, text: str) -> Optional[str]:
        """
        텍스트에서 필요한 액션 타입을 감지합니다.
        """
        for action_type, keywords in self.action_keywords.items():
            if any(kw in text for kw in keywords):
                return action_type
        return None

    def _is_for_all_students(self, text: str) -> bool:
        """
        전체 학생 대상 공지인지 확인합니다.
        """
        all_keywords = [
            "전체 학생", "모든 학생", "재학생 전원", "전학년",
            "학부생 전원", "전체 대상", "모든 학과"
        ]
        return any(kw in text for kw in all_keywords)

    def _is_valid_department(self, dept_name: str) -> bool:
        """
        유효한 학과명인지 확인합니다.
        """
        # 너무 짧거나 일반적인 단어 제외
        if len(dept_name) < 4:
            return False

        # 학과 목록에 있거나, 학과/공학부/전공으로 끝나는지 확인
        if dept_name in self.department_patterns:
            return True

        if dept_name.endswith(("학과", "공학부", "전공", "학부")):
            return True

        return False

    def _get_department_interests(self, department: str) -> List[str]:
        """
        학과 기반 기본 관심사를 반환합니다.
        2026학년도 군산대학교 전체 학과/학부 매핑.
        """
        dept_interests = {
            # 컴퓨터소프트웨어특성화대학
            "컴퓨터정보공학과": ["프로그래밍", "AI", "소프트웨어", "IT취업", "개발"],
            "인공지능융합학과": ["AI", "인공지능", "머신러닝", "딥러닝", "데이터"],
            "임베디드소프트웨어학과": ["임베디드", "IoT", "펌웨어", "시스템"],
            "소프트웨어학과": ["프로그래밍", "소프트웨어", "웹개발", "앱개발"],
            "IT융합통신공학과": ["통신", "네트워크", "IT", "정보통신"],
            # 인문콘텐츠융합대학
            "국어국문학과": ["국문학", "글쓰기", "교사", "출판"],
            "영어영문학과": ["영어", "통번역", "교사", "무역"],
            "일어일문학과": ["일본어", "통번역", "무역"],
            "중어중문학과": ["중국어", "통번역", "무역"],
            "역사학과": ["역사", "학예사", "교사", "공무원"],
            "철학과": ["인문학", "논리", "교육"],
            # 해양·바이오특성화대학
            "생명과학과": ["생명과학", "바이오", "연구", "대학원"],
            "해양수산공공인재학과": ["해양", "수산", "공무원", "공공기관"],
            "해양생명과학과": ["해양", "생명과학", "바이오", "연구"],
            "해양생물자원학과": ["해양", "생물자원", "연구"],
            "수산생명의학과": ["수산", "의학", "연구", "방역"],
            "식품영양학과": ["식품", "영양", "건강", "식품회사"],
            "기관공학과": ["기관", "선박", "해양", "엔진"],
            "식품생명공학과": ["식품", "생명공학", "바이오", "식품회사"],
            # ICC특성화대학부
            "미디어문화학부": ["미디어", "방송", "콘텐츠", "언론"],
            "아동학부": ["아동", "보육", "유아교육", "상담"],
            "사회복지학부": ["사회복지", "복지사", "상담", "공무원"],
            "법행정경찰학부": ["법학", "행정", "경찰", "공무원"],
            "간호학부": ["간호", "의료", "건강", "병원"],
            "의류학부": ["패션", "의류", "디자인", "섬유"],
            "해양경찰학부": ["해양경찰", "경찰", "공무원", "해양"],
            "체육학부": ["체육", "스포츠", "건강", "교사"],
            "산업디자인학부": ["디자인", "제품디자인", "UX", "산업디자인"],
            "기계공학부": ["기계", "자동차", "설계", "제조"],
            "건축공학부": ["건축", "시공", "설계", "건설"],
            "공간디자인융합기술학부": ["공간디자인", "인테리어", "건축", "설계"],
            # 경영특성화대학
            "경영학부": ["경영", "마케팅", "창업", "기업"],
            "국제물류학과": ["물류", "무역", "글로벌", "유통"],
            "무역학과": ["무역", "국제통상", "수출입", "글로벌"],
            "회계학부": ["회계", "세무", "재무", "금융"],
            "금융부동산경제학과": ["금융", "부동산", "경제", "투자"],
            "벤처창업학과": ["창업", "벤처", "스타트업", "사업"],
            # 자율전공대학
            "자율전공학부": ["전공탐색", "융합", "학제간"],
            "미술학과": ["미술", "예술", "전시", "창작"],
            "음악과": ["음악", "연주", "공연", "예술"],
            "조선공학과": ["조선", "선박", "해양", "설계"],
            # 첨단·에너지대학
            "이차전지·에너지학부": ["배터리", "에너지", "이차전지", "신재생에너지"],
            "스마트오션모빌리티공학과": ["해양", "모빌리티", "스마트", "자율운항"],
            "바이오헬스학과": ["바이오", "헬스케어", "의료", "건강"],
            "스마트시티학과": ["스마트시티", "도시", "IoT", "인프라"],
            # 융합과학공학대학
            "전자공학과": ["전자", "회로", "반도체", "전자기기"],
            "전기공학과": ["전기", "전력", "에너지", "전기기사"],
            "신소재공학과": ["신소재", "재료", "나노", "소재"],
            "화학공학과": ["화학", "화공", "플랜트", "에너지"],
            "환경공학과": ["환경", "수처리", "대기", "환경영향평가"],
            "토목공학과": ["토목", "건설", "구조", "인프라"],
            "해양건설공학과": ["해양", "건설", "해양구조물", "항만"],
            "첨단과학기술학부": ["반도체", "물리", "화학", "소재"],
            "수학과": ["수학", "데이터", "통계", "교사"],
        }

        return dept_interests.get(department, [])

    def _get_grade_interests(self, grade: int) -> List[str]:
        """
        학년 기반 관심사를 반환합니다.
        """
        grade_interests = {
            1: ["신입생", "교양과목", "동아리", "학교생활"],
            2: ["전공탐색", "복수전공", "봉사활동", "교환학생"],
            3: ["전공심화", "인턴", "공모전", "자격증"],
            4: ["취업", "졸업", "대학원", "채용"]
        }

        return grade_interests.get(grade, [])

    def _get_category_interests(self, categories: List[str]) -> List[str]:
        """
        사용자가 선택한 카테고리 기반 관심사를 반환합니다.
        """
        category_map = {
            "학사": ["수강신청", "학적", "성적", "졸업", "학사일정"],
            "장학": ["장학금", "학자금대출", "등록금", "지원금"],
            "취업": ["채용", "인턴", "취업박람회", "이력서", "면접"],
            "공모전": ["대회", "경진대회", "콘테스트", "해커톤", "공모"],
            "행사": ["축제", "세미나", "특강", "워크숍", "오리엔테이션"],
            "교육": ["교육프로그램", "특강", "진로교육", "세미나", "캠프"]
        }

        result = []
        for cat in categories:
            result.extend(category_map.get(cat, []))
        return list(set(result))

    def _get_student_type_interests(self, student_type: str) -> List[str]:
        """
        학생 유형 기반 관심사를 반환합니다.
        """
        type_interests = {
            "재학생": ["학사", "장학금", "수강"],
            "휴학생": ["복학", "학적"],
            "졸업예정자": ["취업", "졸업", "증명서"],
            "대학원생": ["연구", "논문", "학술"]
        }

        return type_interests.get(student_type, [])


# 테스트 코드
if __name__ == "__main__":
    print("=" * 60)
    print("데이터 보강 서비스 테스트 시작")
    print("=" * 60)

    service = EnrichmentService()

    # 1. 공지사항 보강 테스트
    print("\n[1단계] 공지사항 보강 테스트...")
    test_notice = {
        "title": "[긴급] 컴퓨터정보공학과 3,4학년 대상 현장실습 신청 안내",
        "content": """
        2024학년도 1학기 현장실습(인턴십) 프로그램을 아래와 같이 안내합니다.

        1. 신청 대상: 컴퓨터정보공학과 3학년, 4학년 재학생
        2. 신청 기간: 2024.02.01 ~ 2024.02.15
        3. 신청 방법: 학과 홈페이지에서 신청서 작성 후 제출

        자세한 사항은 학과 사무실로 문의바랍니다.
        """,
        "category": "취업",
        "keywords": ["인턴", "현장실습"]
    }

    enriched = service.enrich_notice(test_notice)
    print(f"\n  제목: {test_notice['title']}")
    print(f"\n  추출된 메타데이터:")
    for key, value in enriched["enriched_metadata"].items():
        print(f"    - {key}: {value}")

    # 2. 사용자 프로필 보강 테스트
    print("\n[2단계] 사용자 프로필 보강 테스트...")
    profile = service.enrich_user_profile(
        department="컴퓨터정보공학과",
        grade=3,
        interests=["AI", "공모전"],
        categories=["취업", "장학"],
        student_type="재학생"
    )

    print(f"\n  보강된 프로필:")
    for key, value in profile.items():
        print(f"    - {key}: {value}")

    # 3. 전체 대상 공지 테스트
    print("\n[3단계] 전체 대상 공지 테스트...")
    all_notice = {
        "title": "2024학년도 1학기 등록금 납부 안내",
        "content": "전체 재학생을 대상으로 등록금 납부 일정을 안내합니다.",
        "category": "학사"
    }

    enriched_all = service.enrich_notice(all_notice)
    print(f"\n  제목: {all_notice['title']}")
    print(f"  전체 대상 여부: {enriched_all['enriched_metadata']['is_for_all']}")
    print(f"  대상 학과: {enriched_all['enriched_metadata']['target_departments']}")

    print("\n" + "=" * 60)
    print("모든 테스트 완료!")
    print("=" * 60)
