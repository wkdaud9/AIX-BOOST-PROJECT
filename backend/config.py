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

    # 크롤링 설정
    CRAWLER_INTERVAL = int(os.getenv('CRAWLER_INTERVAL', 3600))  # 기본 1시간


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
