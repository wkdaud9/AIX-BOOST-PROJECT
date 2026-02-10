import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 개인정보 처리방침 모달 (토스 스타일)
class PrivacyPolicyModal extends StatelessWidget {
  const PrivacyPolicyModal({super.key});

  /// 모달 표시
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrivacyPolicyModal(),
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
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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
                        '개인정보 처리방침',
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
                        '최종 수정일: 2025년 2월 9일',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _buildSection(
                        context,
                        title: '1. 개인정보의 수집 및 이용 목적',
                        content: '''
HeyBro(이하 "서비스")는 다음의 목적을 위하여 개인정보를 처리합니다:

• 회원 가입 및 관리: 회원제 서비스 이용에 따른 본인확인, 회원자격 유지·관리, 서비스 부정이용 방지
• 서비스 제공: 맞춤형 공지사항 추천, 일정 관리, 알림 서비스 제공
• 서비스 개선: 서비스 이용 통계 분석, 사용자 경험 개선
''',
                      ),

                      _buildSection(
                        context,
                        title: '2. 수집하는 개인정보 항목',
                        content: '''
서비스는 다음의 개인정보 항목을 수집합니다:

필수 항목:
• 이메일 주소 (로그인 및 계정 식별)
• 이름 또는 닉네임

선택 항목:
• 학과/전공 정보
• 학년 정보
• 관심 카테고리
• 기기 정보 (푸시 알림용)
''',
                      ),

                      _buildSection(
                        context,
                        title: '3. 개인정보의 보유 및 이용 기간',
                        content: '''
• 회원 탈퇴 시까지 보유
• 탈퇴 후 30일 이내 파기
• 법령에 따른 보존 필요 시 해당 기간 동안 보관

※ 서비스 이용 기록은 부정이용 방지를 위해 탈퇴 후 1년간 보관될 수 있습니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '4. 개인정보의 제3자 제공',
                        content: '''
서비스는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.

다만, 다음의 경우에는 예외로 합니다:
• 이용자가 사전에 동의한 경우
• 법령의 규정에 의한 경우
• 서비스 제공에 필요한 경우 (예: 푸시 알림 서비스)
''',
                      ),

                      _buildSection(
                        context,
                        title: '5. 개인정보의 안전성 확보 조치',
                        content: '''
서비스는 개인정보의 안전성 확보를 위해 다음의 조치를 취하고 있습니다:

• 개인정보의 암호화
• 해킹 등에 대비한 보안시스템 구축
• 개인정보 취급 직원의 최소화 및 교육
• 개인정보에 대한 접근 제한
''',
                      ),

                      _buildSection(
                        context,
                        title: '6. 이용자의 권리',
                        content: '''
이용자는 언제든지 다음의 권리를 행사할 수 있습니다:

• 개인정보 열람 요구
• 개인정보 정정·삭제 요구
• 개인정보 처리 정지 요구
• 회원 탈퇴

위 권리 행사는 앱 내 설정 또는 고객센터를 통해 가능합니다.
''',
                      ),

                      _buildSection(
                        context,
                        title: '7. 개인정보 보호책임자',
                        content: '''
서비스의 개인정보 관련 문의는 아래로 연락해 주시기 바랍니다:

• 담당: HeyBro 개인정보 보호팀
• 이메일: privacy@kunsan.ac.kr
• 주소: 전라북도 군산시 대학로 558 군산대학교
''',
                      ),

                      _buildSection(
                        context,
                        title: '8. 개인정보 처리방침 변경',
                        content: '''
본 개인정보 처리방침은 법령, 정책 또는 서비스 변경에 따라 수정될 수 있습니다.

변경 시 앱 내 공지사항 또는 푸시 알림을 통해 안내드립니다.
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
