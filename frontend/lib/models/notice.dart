/// 개별 마감일 항목 (복수 마감일 지원)
class Deadline {
  final String label; // 마감 대상 (예: "계약직(부산)", "전체 마감")
  final DateTime date; // 마감 날짜

  Deadline({required this.label, required this.date});

  /// JSON에서 Deadline 객체 생성
  factory Deadline.fromJson(Map<String, dynamic> json) {
    return Deadline(
      label: (json['label'] ?? '전체 마감').toString(),
      date: DateTime.parse(json['date'].toString()),
    );
  }

  /// Deadline 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    };
  }

  /// 마감일까지 남은 일수
  int get daysUntil {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  /// 마감 임박 여부 (3일 이내)
  bool get isSoon => daysUntil >= 0 && daysUntil <= 3;

  /// D-day 텍스트
  String get dDayText {
    final days = daysUntil;
    if (days > 0) return 'D-$days';
    if (days == 0) return 'D-Day';
    return '마감';
  }
}

/// 공지사항 모델 클래스
class Notice {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime date;
  final String? url;
  final bool isNew;
  final int views;
  final List<String> tags;
  final bool isBookmarked;
  final DateTime? deadline; // 대표 마감일 (가장 빠른 마감일)
  final String? author; // 작성자 또는 작성 부서
  final String? aiSummary; // AI 요약
  final String? priority; // 중요도 (긴급/중요/일반)
  final List<String> contentImages; // 본문 내 이미지 URL 목록
  final String displayMode; // AI가 판단한 표시 모드 (POSTER/DOCUMENT/HYBRID)
  final bool hasImportantImage; // AI가 판단한 이미지 중요도
  final int bookmarkCount; // 북마크 수
  final List<Deadline> deadlines; // 복수 마감일 목록

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.date,
    this.url,
    this.isNew = false,
    this.views = 0,
    this.tags = const [],
    this.isBookmarked = false,
    this.deadline,
    this.author,
    this.aiSummary,
    this.priority,
    this.contentImages = const [],
    this.displayMode = 'DOCUMENT',
    this.hasImportantImage = false,
    this.bookmarkCount = 0,
    this.deadlines = const [],
  });

  /// JSON에서 Notice 객체 생성 (Backend API 응답 매핑)
  /// null 값에 대한 안전한 처리를 포함합니다.
  factory Notice.fromJson(Map<String, dynamic> json) {
    // Backend API 응답 필드:
    // - published_at → date
    // - source_url → url
    // - view_count → views
    // - author → author
    // - ai_summary → aiSummary
    // - priority → priority
    // - deadline → deadline
    // - content_images → contentImages
    // - deadlines → deadlines (JSONB 배열)

    // published_at null 안전 처리
    DateTime publishedAt;
    try {
      publishedAt = json['published_at'] != null
          ? DateTime.parse(json['published_at'].toString())
          : DateTime.now();
    } catch (_) {
      publishedAt = DateTime.now();
    }

    // 게시일 기준 3일 이내면 새 공지사항으로 표시
    final daysSincePublished = DateTime.now().difference(publishedAt).inDays;
    final isNew = daysSincePublished <= 3;

    // deadline null 안전 처리
    DateTime? deadline;
    try {
      deadline = json['deadline'] != null
          ? DateTime.parse(json['deadline'].toString())
          : null;
    } catch (_) {
      deadline = null;
    }

    // deadlines JSONB 배열 파싱
    List<Deadline> deadlines = [];
    try {
      final rawDeadlines = json['deadlines'];
      if (rawDeadlines != null && rawDeadlines is List) {
        deadlines = rawDeadlines
            .where((d) => d is Map && d['date'] != null)
            .map((d) => Deadline.fromJson(Map<String, dynamic>.from(d)))
            .toList();
      }
    } catch (_) {
      deadlines = [];
    }

    return Notice(
      id: (json['id'] ?? '').toString(), // null 안전 처리
      title: (json['title'] ?? '').toString(), // null 안전 처리
      content: (json['content'] ?? '').toString(), // null 안전 처리
      category: (json['category'] ?? '공지사항').toString(), // null 안전 처리 (기본값: 공지사항)
      date: publishedAt,
      url: json['source_url']?.toString(), // null 안전 처리
      isNew: isNew,
      views: (json['view_count'] as int?) ?? 0, // DB의 view_count 필드 사용
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      deadline: deadline,
      author: json['author']?.toString(), // null 안전 처리
      aiSummary: json['ai_summary']?.toString(), // null 안전 처리
      priority: json['priority']?.toString(), // null 안전 처리
      contentImages: (json['content_images'] as List<dynamic>?)?.cast<String>() ?? [],
      displayMode: (json['display_mode'] ?? 'DOCUMENT').toString(),
      hasImportantImage: json['has_important_image'] as bool? ?? false,
      bookmarkCount: (json['bookmark_count'] as int?) ?? 0,
      deadlines: deadlines,
    );
  }

  /// Notice 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'date': date.toIso8601String(),
      'url': url,
      'is_new': isNew,
      'views': views,
      'tags': tags,
      'is_bookmarked': isBookmarked,
      'deadline': deadline?.toIso8601String(),
      'ai_summary': aiSummary,
      'priority': priority,
      'content_images': contentImages,
      'display_mode': displayMode,
      'has_important_image': hasImportantImage,
      'bookmark_count': bookmarkCount,
      'deadlines': deadlines.map((d) => d.toJson()).toList(),
    };
  }

  /// 공지사항 복사 (일부 필드 수정용)
  Notice copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    DateTime? date,
    String? url,
    bool? isNew,
    int? views,
    List<String>? tags,
    bool? isBookmarked,
    DateTime? deadline,
    String? author,
    String? aiSummary,
    String? priority,
    List<String>? contentImages,
    String? displayMode,
    bool? hasImportantImage,
    int? bookmarkCount,
    List<Deadline>? deadlines,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      date: date ?? this.date,
      url: url ?? this.url,
      isNew: isNew ?? this.isNew,
      views: views ?? this.views,
      tags: tags ?? this.tags,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      deadline: deadline ?? this.deadline,
      author: author ?? this.author,
      aiSummary: aiSummary ?? this.aiSummary,
      priority: priority ?? this.priority,
      contentImages: contentImages ?? this.contentImages,
      displayMode: displayMode ?? this.displayMode,
      hasImportantImage: hasImportantImage ?? this.hasImportantImage,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      deadlines: deadlines ?? this.deadlines,
    );
  }

  /// 날짜 포맷팅 (yyyy.MM.dd)
  String get formattedDate {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 마감일까지 남은 일수 (자정 기준, 모든 화면 통일)
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deadline!.year, deadline!.month, deadline!.day);
    return target.difference(today).inDays;
  }

  /// 마감 임박 여부 (3일 이내)
  bool get isDeadlineSoon {
    final days = daysUntilDeadline;
    return days != null && days >= 0 && days <= 3;
  }

  /// 복수 마감일 여부
  bool get hasMultipleDeadlines => deadlines.length > 1;

  /// 추가 마감일 수 ("외 N건" 표시용)
  int get additionalDeadlineCount => deadlines.length > 1 ? deadlines.length - 1 : 0;

  /// 가장 임박한 마감일 (deadlines 중)
  Deadline? get earliestDeadline {
    if (deadlines.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 아직 지나지 않은 마감일 중 가장 빠른 것
    final upcoming = deadlines.where((d) =>
        DateTime(d.date.year, d.date.month, d.date.day).compareTo(today) >= 0
    ).toList();
    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) => a.date.compareTo(b.date));
      return upcoming.first;
    }
    // 모두 지났으면 가장 최근 것
    final sorted = List<Deadline>.from(deadlines)..sort((a, b) => b.date.compareTo(a.date));
    return sorted.first;
  }

  /// POSTER 모드 여부 (이미지 중심 레이아웃)
  bool get isPosterMode => displayMode == 'POSTER';

  /// DOCUMENT 모드 여부 (텍스트 중심 레이아웃)
  bool get isDocumentMode => displayMode == 'DOCUMENT';

  /// HYBRID 모드 여부 (이미지+텍스트 혼합 레이아웃)
  bool get isHybridMode => displayMode == 'HYBRID';

  /// 이미지가 있는지 여부
  bool get hasImages => contentImages.isNotEmpty;
}
