// Backend API 연동 테스트
// 이 테스트는 실제 Backend 서버가 localhost:5000에서 실행 중일 때만 통과합니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:aix_boost/services/api_service.dart';

void main() {
  group('Backend API Integration Tests', () {
    final apiService = ApiService(baseUrl: 'http://localhost:5000');

    test('Health Check - Backend 서버 연결 확인', () async {
      try {
        final response = await apiService.healthCheck();
        expect(response['health'], 'ok');
        print('✓ Health check successful');
      } catch (e) {
        fail('Backend 서버에 연결할 수 없습니다: $e');
      }
    });

    test('공지사항 목록 조회 - getNotices()', () async {
      try {
        final notices = await apiService.getNotices(limit: 5);
        expect(notices, isA<List>());
        expect(notices.length, greaterThan(0));

        // 첫 번째 공지사항 구조 검증
        final firstNotice = notices[0];
        expect(firstNotice, containsPair('id', isA<String>()));
        expect(firstNotice, containsPair('title', isA<String>()));
        expect(firstNotice, containsPair('content', isA<String>()));
        expect(firstNotice, containsPair('category', isA<String>()));
        expect(firstNotice, containsPair('published_at', isA<String>()));

        print('✓ Fetched ${notices.length} notices');
        print('✓ First notice: ${firstNotice['title']}');
      } catch (e) {
        fail('공지사항 목록을 가져오는데 실패했습니다: $e');
      }
    });

    test('공지사항 상세 조회 - getNoticeById()', () async {
      try {
        // 먼저 목록에서 첫 번째 공지사항 ID를 가져옴
        final notices = await apiService.getNotices(limit: 1);
        expect(notices.length, greaterThan(0));

        final noticeId = notices[0]['id'] as String;

        // 해당 ID로 상세 조회
        final notice = await apiService.getNoticeById(noticeId);
        expect(notice['id'], noticeId);
        expect(notice['title'], isA<String>());

        print('✓ Fetched notice detail: ${notice['title']}');
      } catch (e) {
        fail('공지사항 상세 조회에 실패했습니다: $e');
      }
    });

    test('통계 조회 - getStatistics()', () async {
      try {
        final stats = await apiService.getStatistics();
        expect(stats, isA<Map>());

        print('✓ Statistics fetched: $stats');
      } catch (e) {
        fail('통계 조회에 실패했습니다: $e');
      }
    });
  });
}
