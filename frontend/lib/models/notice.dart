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
  final DateTime? deadline; // 마감일 (있는 경우)
  final String? author; // 작성자 또는 작성 부서
  final String? aiSummary; // AI 요약
  final String? priority; // 중요도 (긴급/중요/일반)
  final List<String> contentImages; // 본문 내 이미지 URL 목록
  final String displayMode; // AI가 판단한 표시 모드 (POSTER/DOCUMENT/HYBRID)
  final bool hasImportantImage; // AI가 판단한 이미지 중요도

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
    );
  }

  /// 날짜 포맷팅 (yyyy.MM.dd)
  String get formattedDate {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 마감일까지 남은 일수 (있는 경우)
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    final now = DateTime.now();
    final difference = deadline!.difference(now);
    return difference.inDays;
  }

  /// 마감 임박 여부 (3일 이내)
  bool get isDeadlineSoon {
    final days = daysUntilDeadline;
    return days != null && days >= 0 && days <= 3;
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
