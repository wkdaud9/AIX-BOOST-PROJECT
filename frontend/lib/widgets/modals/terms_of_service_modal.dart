import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 이용약관 모달 (토스 스타일)
class TermsOfServiceModal extends StatelessWidget {
  const TermsOfServiceModal({super.key});

  /// 모달 표시
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TermsOfServiceModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF060E1F) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 헤더
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '이용약관',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 내용
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '시행일: 2025년 2월 9일',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _buildSection(
                        context,
                        title: '제1조 (목적)',
                        content: '''
본 약관은 HeyBro(이하 "서비스")가 제공하는 공지사항 큐레이션 서비스의 이용조건 및 절차, 이용자와 서비스 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '제2조 (정의)',
                        content: '''
본 약관에서 사용하는 용어의 정의는 다음과 같습니다:

1. "서비스"란 HeyBro가 제공하는 공지사항 수집, 분석, 추천 및 알림 서비스를 말합니다.
2. "이용자"란 본 약관에 따라 서비스를 이용하는 회원을 말합니다.
3. "회원"이란 서비스에 가입하여 이용자 ID를 부여받은 자를 말합니다.
4. "공지사항"이란 군산대학교에서 발행하는 각종 안내문을 말합니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '제3조 (서비스의 제공)',
                        content: '''
서비스는 다음의 기능을 제공합니다:

1. 학내 공지사항 자동 수집 및 분류
2. AI 기반 공지사항 요약 및 추천
3. 북마크 및 일정 관리
4. 마감일 알림 서비스
5. 기타 서비스가 정하는 부가 서비스
''',
                      ),

                      _buildSection(
                        context,
                        title: '제4조 (회원가입)',
                        content: '''
1. 회원가입은 이용자가 본 약관에 동의하고, 서비스가 정한 양식에 따라 회원정보를 기입한 후 가입신청을 하면 완료됩니다.

2. 서비스는 다음 각 호에 해당하는 신청에 대해서는 승낙을 유보할 수 있습니다:
   - 실명이 아니거나 타인의 명의를 사용한 경우
   - 허위 정보를 기재한 경우
   - 기타 서비스가 정한 이용신청 요건이 충족되지 않은 경우
''',
                      ),

                      _buildSection(
                        context,
                        title: '제5조 (회원의 의무)',
                        content: '''
1. 회원은 다음 행위를 하여서는 안 됩니다:
   - 가입 신청 또는 변경 시 허위 내용 등록
   - 타인의 정보 도용
   - 서비스에 게시된 정보의 무단 변경
   - 서비스의 운영을 방해하는 행위
   - 기타 법령에 위반되는 행위

2. 회원은 본 약관 및 관계 법령을 준수하여야 합니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '제6조 (서비스의 변경 및 중단)',
                        content: '''
1. 서비스는 운영상, 기술상의 필요에 따라 제공하고 있는 서비스의 전부 또는 일부를 변경할 수 있습니다.

2. 서비스는 다음 각 호에 해당하는 경우 서비스의 전부 또는 일부를 제한하거나 중단할 수 있습니다:
   - 서비스 설비의 보수, 점검, 교체 등
   - 천재지변, 국가비상사태 등 불가항력의 경우
   - 기타 서비스 제공이 곤란한 경우
''',
                      ),

                      _buildSection(
                        context,
                        title: '제7조 (저작권)',
                        content: '''
1. 서비스가 작성한 저작물에 대한 저작권은 서비스에 귀속됩니다.

2. 이용자는 서비스를 이용함으로써 얻은 정보를 서비스의 사전 승낙 없이 복제, 전송, 출판, 배포, 방송 등의 방법으로 이용하거나 제3자에게 이용하게 하여서는 안 됩니다.

3. 공지사항 원문의 저작권은 해당 공지사항을 발행한 군산대학교 각 기관에 귀속됩니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '제8조 (면책조항)',
                        content: '''
1. 서비스는 군산대학교 공지사항을 자동으로 수집하여 제공하며, 공지사항 내용의 정확성에 대해서는 보증하지 않습니다.

2. 이용자는 중요한 정보의 경우 반드시 원문을 확인하시기 바랍니다.

3. 서비스는 이용자의 귀책사유로 인한 서비스 이용 장애에 대해 책임을 지지 않습니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '제9조 (분쟁해결)',
                        content: '''
1. 서비스와 이용자 간에 발생한 분쟁에 관한 소송은 대한민국 법을 준거법으로 합니다.

2. 서비스와 이용자 간에 발생한 분쟁에 관한 소송의 관할 법원은 민사소송법에 따릅니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '부칙',
                        content: '''
본 약관은 2025년 2월 9일부터 시행합니다.
''',
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      Center(
                        child: Text(
                          '© 2025 HeyBro. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : AppTheme.textSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required String content,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content.trim(),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
