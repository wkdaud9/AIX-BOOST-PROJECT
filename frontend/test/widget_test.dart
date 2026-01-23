// AIX-Boost 앱 위젯 테스트

import 'package:flutter_test/flutter_test.dart';

import 'package:aix_boost/main.dart';

void main() {
  testWidgets('AIX-Boost app smoke test', (WidgetTester tester) async {
    // 앱 빌드 및 프레임 렌더링
    await tester.pumpWidget(const AIXBoostApp());

    // 홈 화면이 정상적으로 로드되는지 확인
    expect(find.text('AIX-Boost'), findsOneWidget);
  });
}
