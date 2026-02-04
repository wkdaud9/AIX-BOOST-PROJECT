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
  final List<String> extractedDates; // AI가 추출한 일정 날짜들

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
    this.extractedDates = const [],
  });

  /// JSON에서 Notice 객체 생성 (Backend API 응답 매핑)
  factory Notice.fromJson(Map<String, dynamic> json) {
    // Backend API 응답 필드:
    // - published_at → date
    // - source_url → url
    // - view_count → views
    // - author → author
    // - ai_summary → aiSummary
    // - priority → priority
    // - extracted_dates → extractedDates

    final publishedAt = json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : DateTime.now();

    // 게시일 기준 3일 이내면 새 공지사항으로 표시
    final daysSincePublished = DateTime.now().difference(publishedAt).inDays;
    final isNew = daysSincePublished <= 3;

    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      date: publishedAt,
      url: json['source_url'] as String?,
      isNew: isNew,
      views: json['view_count'] as int? ?? 0, // DB의 view_count 필드 사용
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      author: json['author'] as String?, // 작성자 필드 추가
      aiSummary: json['ai_summary'] as String?, // AI 요약 추가
      priority: json['priority'] as String?, // 중요도 추가
      extractedDates: (json['extracted_dates'] as List<dynamic>?)?.cast<String>() ?? [],
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
      'extracted_dates': extractedDates,
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
    List<String>? extractedDates,
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
      extractedDates: extractedDates ?? this.extractedDates,
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
}
