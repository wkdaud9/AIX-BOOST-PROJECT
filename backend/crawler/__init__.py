# -*- coding: utf-8 -*-
"""
크롤러 모듈 초기화 파일
군산대학교 공지사항 크롤링 관련 기능들을 외부에서 쉽게 사용할 수 있게 해줍니다.
"""

from .base_crawler import BaseCrawler
from .notice_crawler import NoticeCrawler
from .scholarship_crawler import ScholarshipCrawler
from .recruitment_crawler import RecruitmentCrawler
from .crawler_manager import CrawlerManager

__all__ = [
    'BaseCrawler',
    'NoticeCrawler',
    'ScholarshipCrawler',
    'RecruitmentCrawler',
    'CrawlerManager'
]
