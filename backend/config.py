# -*- coding: utf-8 -*-
"""
Backend 설정 파일
환경 변수 및 애플리케이션 설정을 관리합니다.
"""

import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    """기본 설정"""
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    FLASK_ENV = os.getenv('FLASK_ENV', 'development')

    # Supabase 설정
    SUPABASE_URL = os.getenv('SUPABASE_URL')
    SUPABASE_KEY = os.getenv('SUPABASE_KEY')

    # Gemini AI 설정
    GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

    # Firebase FCM 설정
    FIREBASE_CREDENTIALS_JSON = os.getenv('FIREBASE_CREDENTIALS_JSON')  # Render 배포용 (JSON 문자열)
    GOOGLE_APPLICATION_CREDENTIALS = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')  # 로컬 개발용 (파일 경로)

    # 크롤링 설정
    CRAWLER_INTERVAL = int(os.getenv('CRAWLER_INTERVAL', 3600))  # 기본 1시간

    # 카테고리 기반 이중 임계값 설정 (알림 필터링)
    CATEGORY_MATCH_MIN_SCORE = float(os.getenv('CATEGORY_MATCH_MIN_SCORE', 0.4))      # 관심 카테고리 최소 점수
    CATEGORY_UNMATCH_MIN_SCORE = float(os.getenv('CATEGORY_UNMATCH_MIN_SCORE', 0.75))  # 비관심 카테고리 최소 점수
    MIN_VECTOR_SCORE = float(os.getenv('MIN_VECTOR_SCORE', 0.2))                       # 벡터 유사도 최소값


class DevelopmentConfig(Config):
    """개발 환경 설정"""
    DEBUG = True


class ProductionConfig(Config):
    """프로덕션 환경 설정"""
    DEBUG = False


config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
