import 'package:flutter/material.dart';

/// 앱 전체 테마 정의 - 트렌디하고 세련된 모바일 UI
class AppTheme {
  // 프라이머리 컬러 (딥 네이비 블루)
  static const Color primaryColor = Color(0xFF0F2854);
  static const Color primaryLight = Color(0xFF4988C4);
  static const Color primaryDark = Color(0xFF0A1D40);

  // 세컨더리 컬러 (미드 네이비)
  static const Color secondaryColor = Color(0xFF1C4D8D);
  static const Color secondaryLight = Color(0xFF4988C4);
  static const Color secondaryDark = Color(0xFF143A6B);

  // 배경 컬러 (밝고 시원한 블루그레이)
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color surfaceColor = Colors.white;
  static const Color surfaceLight = Color(0xFFF5F9FC);

  // 텍스트 컬러 (네이비 기반 가독성)
  static const Color textPrimary = Color(0xFF0F2854);
  static const Color textSecondary = Color(0xFF5A7BA6);
  static const Color textHint = Color(0xFFA8C4D9);

  // 상태 컬러 (세련된 톤)
  static const Color successColor = Color(0xFF2A9D8F);
  static const Color warningColor = Color(0xFFE9A040);
  static const Color errorColor = Color(0xFFE05263);
  static const Color infoColor = Color(0xFF4988C4);

  // 라이트 틴트 (섹션 배경, 하이라이트)
  static const Color lightTint = Color(0xFFBDE8F5);

  // 공지사항 카테고리 컬러 (트렌디한 파스텔 톤)
  static const Map<String, Color> categoryColors = {
    '학사': Color(0xFF4988C4),       // 액센트 블루
    '학사공지': Color(0xFF4988C4),   // 액센트 블루
    '장학': Color(0xFF56C596),       // 부드러운 그린
    '취업': Color(0xFFFFB84D),       // 부드러운 오렌지
    '행사': Color(0xFFAD7FFF),       // 부드러운 퍼플
    '학생활동': Color(0xFFAD7FFF),   // 부드러운 퍼플
    '시설': Color(0xFF5DDAB4),       // 부드러운 민트
    '교육': Color(0xFF3A78B5),       // 네이비 블루
    '공모전': Color(0xFFFFD66B),     // 부드러운 골드
    '기타': Color(0xFF9AA5B8),       // 부드러운 그레이
  };

  /// 라이트 테마
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,

    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),

    // AppBar 테마
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      backgroundColor: surfaceColor,
      foregroundColor: textPrimary,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Card 테마 (세련된 그림자와 둥근 모서리)
    cardTheme: CardThemeData(
      elevation: 0,
      color: surfaceColor,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    // 텍스트 테마
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textSecondary,
      ),
    ),

    // 입력 필드 테마 (부드러운 디자인)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: textHint.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: textHint.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),

    // 버튼 테마 (부드러운 그림자와 둥근 모서리)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    // 아이콘 테마
    iconTheme: const IconThemeData(
      color: textPrimary,
      size: 24,
    ),
  );

  /// 다크 테마
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF060E1F),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,

    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Color(0xFF0F2854),
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    ),

    // AppBar 테마 (다크)
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      backgroundColor: Color(0xFF060E1F),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Card 테마 (다크)
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF0F2854),
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    // 텍스트 테마 (다크)
    textTheme: TextTheme(
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      headlineSmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.white.withOpacity(0.7),
      ),
    ),

    // 입력 필드 테마 (다크)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1C4D8D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),

    // 버튼 테마 (다크)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    // 아이콘 테마 (다크)
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: 24,
    ),

    // BottomNavigationBar 테마 (다크)
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF060E1F),
      selectedItemColor: primaryLight,
      unselectedItemColor: Colors.white54,
    ),

    // Divider 테마 (다크)
    dividerTheme: DividerThemeData(
      color: Colors.white.withOpacity(0.1),
    ),
  );

  /// 카테고리별 색상 가져오기
  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? categoryColors['기타']!;
  }
}

/// 스페이싱 상수
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// 보더 라디우스 상수 (더 둥글고 부드러운 디자인)
class AppRadius {
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double round = 999.0;
}

/// 그림자 스타일 (트렌디한 부드러운 그림자)
class AppShadow {
  // 부드러운 그림자 (기본 카드, 버튼 등)
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // 중간 그림자 (강조 카드, 슬라이드 카드 등)
  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // 강한 그림자 (배너, 부동 버튼 등)
  static List<BoxShadow> get strong => [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // 컬러 그림자 (Primary 강조)
  static List<BoxShadow> coloredPrimary(double opacity) => [
        BoxShadow(
          color: AppTheme.primaryColor.withOpacity(opacity * 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // 컬러 그림자 (Secondary 강조)
  static List<BoxShadow> coloredSecondary(double opacity) => [
        BoxShadow(
          color: AppTheme.secondaryColor.withOpacity(opacity * 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

/// 애니메이션 지속 시간
class AppDuration {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}
